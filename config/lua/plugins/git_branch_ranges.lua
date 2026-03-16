local M = {}

local group = vim.api.nvim_create_augroup("GitBranchRanges", { clear = true })
local cache = {}

M.config = {
  base_ref = "develop",
  priority = 10,
  enabled = true,
  sign_text = "▒",
  notify_on_no_ranges = false,
}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function buf_is_real_file(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  if vim.bo[buf].buftype ~= "" then
    return false
  end

  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= nil and name ~= ""
end

local function system_text(cmd, cwd)
  local obj = vim.system(cmd, { text = true, cwd = cwd }):wait()
  return obj.code, obj.stdout or "", obj.stderr or ""
end

local function get_repo_root(abs_path)
  local dir = vim.fn.fnamemodify(abs_path, ":h")
  local code, out = system_text({ "git", "rev-parse", "--show-toplevel" }, dir)
  if code ~= 0 then
    return nil
  end

  out = trim(out)
  if out == "" then
    return nil
  end

  return out
end

local function relpath_from_root(root, abs_path)
  root = root:gsub("/+$", "")
  if abs_path:sub(1, #root + 1) ~= root .. "/" then
    return nil
  end
  return abs_path:sub(#root + 2)
end

local function clear_signs(buf)
  vim.fn.sign_unplace("GitBranchRanges", { buffer = buf })
end

local function setup_hl_and_signs()
  vim.api.nvim_set_hl(0, "GitBranchRangeAdd",    { fg = "#a855f7" })
  vim.api.nvim_set_hl(0, "GitBranchRangeChange", { fg = "#a855f7" })
  vim.api.nvim_set_hl(0, "GitBranchRangeDelete", { fg = "#a855f7" })

  vim.fn.sign_define("GitBranchRangeAddSign", {
    text = M.config.sign_text,
    texthl = "GitBranchRangeAdd",
  })
  vim.fn.sign_define("GitBranchRangeChangeSign", {
    text = M.config.sign_text,
    texthl = "GitBranchRangeChange",
  })
  vim.fn.sign_define("GitBranchRangeDeleteSign", {
    text = M.config.sign_text,
    texthl = "GitBranchRangeDelete",
  })
end

local function parse_unified0(diff_text)
  local add = {}
  local change = {}
  local del = {}
  local ranges = {}

  for line in diff_text:gmatch("[^\n]+") do
    local a1, a2, b1, b2 = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
    if b1 then
      a1 = tonumber(a1)
      a2 = tonumber(a2) or 1
      b1 = tonumber(b1)
      b2 = tonumber(b2) or 1

      if a2 == 0 and b2 > 0 then
        for l = b1, b1 + b2 - 1 do
          add[l] = true
        end
        ranges[#ranges + 1] = {
          start = b1,
          finish = b1 + b2 - 1,
          kind = "add",
        }
      elseif b2 == 0 and a2 > 0 then
        del[b1] = true
        ranges[#ranges + 1] = {
          start = b1,
          finish = b1,
          kind = "delete",
        }
      else
        for l = b1, b1 + b2 - 1 do
          change[l] = true
        end
        ranges[#ranges + 1] = {
          start = b1,
          finish = b1 + b2 - 1,
          kind = "change",
        }
      end
    end
  end

  table.sort(ranges, function(x, y)
    if x.start ~= y.start then
      return x.start < y.start
    end
    return x.finish < y.finish
  end)

  return add, change, del, ranges
end

local function place_sign(buf, lnum, kind)
  local sign_name = ({
    add = "GitBranchRangeAddSign",
    change = "GitBranchRangeChangeSign",
    delete = "GitBranchRangeDeleteSign",
  })[kind]

  if not sign_name then
    return
  end

  vim.fn.sign_place(0, "GitBranchRanges", sign_name, buf, {
    lnum = lnum,
    priority = M.config.priority,
  })
end

local function get_diff_text(root, rel)
  local verify_code = select(1, system_text({
    "git",
    "rev-parse",
    "--verify",
    M.config.base_ref,
  }, root))

  if verify_code ~= 0 then
    return nil
  end

  local code, out = system_text({
    "git",
    "diff",
    "--no-color",
    "--unified=0",
    M.config.base_ref .. "...HEAD",
    "--",
    rel,
  }, root)

  if code ~= 0 then
    return nil
  end

  return out or ""
end

local function clear_cache_for_buf(buf)
  cache[buf] = nil
end

local function update_now(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  if not M.config.enabled then
    clear_signs(buf)
    clear_cache_for_buf(buf)
    return
  end

  if not buf_is_real_file(buf) then
    clear_signs(buf)
    clear_cache_for_buf(buf)
    return
  end

  local abs = vim.api.nvim_buf_get_name(buf)
  local root = get_repo_root(abs)
  if not root then
    clear_signs(buf)
    clear_cache_for_buf(buf)
    return
  end

  local rel = relpath_from_root(root, abs)
  if not rel then
    clear_signs(buf)
    clear_cache_for_buf(buf)
    return
  end

  local out = get_diff_text(root, rel)

  clear_signs(buf)

  if not out or out == "" then
    cache[buf] = {
      root = root,
      rel = rel,
      ranges = {},
    }
    return
  end

  local add, change, del, ranges = parse_unified0(out)

  cache[buf] = {
    root = root,
    rel = rel,
    ranges = ranges,
  }

  for lnum, _ in pairs(del) do
    place_sign(buf, lnum, "delete")
  end
  for lnum, _ in pairs(change) do
    place_sign(buf, lnum, "change")
  end
  for lnum, _ in pairs(add) do
    place_sign(buf, lnum, "add")
  end
end

local function current_ranges(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  if cache[buf] == nil then
    update_now(buf)
  end

  local entry = cache[buf]
  if not entry then
    return {}
  end

  return entry.ranges or {}
end

local function current_line()
  return vim.api.nvim_win_get_cursor(0)[1]
end

local function jump_to_range(range)
  if not range then
    return
  end

  vim.api.nvim_win_set_cursor(0, { range.start, 0 })
  vim.cmd("normal! zz")
end

local function find_next_range(ranges, line)
  if not ranges or #ranges == 0 then
    return nil
  end

  for _, r in ipairs(ranges) do
    if r.start > line then
      return r
    end
  end

  return ranges[1]
end

local function find_prev_range(ranges, line)
  if not ranges or #ranges == 0 then
    return nil
  end

  for i = #ranges, 1, -1 do
    local r = ranges[i]
    if r.finish < line then
      return r
    end
  end

  return ranges[#ranges]
end

function M.refresh(buf)
  update_now(buf or vim.api.nvim_get_current_buf())
end

function M.toggle()
  M.config.enabled = not M.config.enabled
  vim.notify(("Git branch ranges: %s"):format(M.config.enabled and "ON" or "OFF"))

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      update_now(buf)
    end
  end
end

function M.get_ranges(buf)
  return current_ranges(buf)
end

function M.next_range()
  local buf = vim.api.nvim_get_current_buf()
  local ranges = current_ranges(buf)

  if #ranges == 0 then
    if M.config.notify_on_no_ranges then
      vim.notify(("No branch ranges vs %s"):format(M.config.base_ref), vim.log.levels.INFO)
    end
    return
  end

  jump_to_range(find_next_range(ranges, current_line()))
end

function M.prev_range()
  local buf = vim.api.nvim_get_current_buf()
  local ranges = current_ranges(buf)

  if #ranges == 0 then
    if M.config.notify_on_no_ranges then
      vim.notify(("No branch ranges vs %s"):format(M.config.base_ref), vim.log.levels.INFO)
    end
    return
  end

  jump_to_range(find_prev_range(ranges, current_line()))
end

function M.get_base_ref()
  return M.config.base_ref
end

function M.set_base_ref(ref)
  if not ref or ref == "" then
    vim.notify("Git branch ranges: empty base ref", vim.log.levels.WARN)
    return
  end

  M.config.base_ref = ref
  vim.notify(("BranchRanges base: %s"):format(ref), vim.log.levels.INFO)

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      clear_cache_for_buf(buf)
      update_now(buf)
    end
  end
end

function M.reset_base_ref()
  M.set_base_ref("develop")
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  setup_hl_and_signs()

  vim.api.nvim_create_user_command("BranchRangesBase", function(cmd)
    if not cmd.args or cmd.args == "" then
      vim.notify(("BranchRanges base: %s"):format(M.get_base_ref()), vim.log.levels.INFO)
      return
    end

    M.set_base_ref(cmd.args)
  end, {
    nargs = "?",
  })

  vim.api.nvim_create_user_command("BranchRangesResetBase", function()
    M.reset_base_ref()
  end, {})

  vim.api.nvim_create_user_command("BranchRangesRefresh", function()
    M.refresh()
  end, {})

  vim.api.nvim_create_user_command("BranchRangesToggle", function()
    M.toggle()
  end, {})

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = group,
    callback = function(args)
      update_now(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(args)
      clear_signs(args.buf)
      clear_cache_for_buf(args.buf)
    end,
  })
end

return M
