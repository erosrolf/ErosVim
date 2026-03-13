-- Подсветка "закоммиченных" отличий текущей ветки от develop:
-- git diff develop...HEAD -- <file>
-- Знаки рисуем в signcolumn фиолетовыми группами.

local M = {}

local group = vim.api.nvim_create_augroup("DevelopDiffSigns", { clear = true })
local pending = {}
local dirty_buffers = {}

M.config = {
  base = "develop",
  priority = 10,
  debounce_ms = 150,
  enabled = true,
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
  vim.fn.sign_unplace("DevelopDiffSigns", { buffer = buf })
end

local function setup_hl_and_signs()
  vim.api.nvim_set_hl(0, "DevelopDiffAdd", { fg = "#a855f7" })
  vim.api.nvim_set_hl(0, "DevelopDiffChange", { fg = "#a855f7" })
  vim.api.nvim_set_hl(0, "DevelopDiffDelete", { fg = "#a855f7" })

  vim.fn.sign_define("DevelopDiffAddSign", { text = "▒", texthl = "DevelopDiffAdd" })
  vim.fn.sign_define("DevelopDiffChangeSign", { text = "▒", texthl = "DevelopDiffChange" })
  vim.fn.sign_define("DevelopDiffDeleteSign", { text = "▒", texthl = "DevelopDiffDelete" })
end

local function parse_unified0(diff_text)
  local add, change, del = {}, {}, {}

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
      elseif b2 == 0 and a2 > 0 then
        del[b1] = true
      else
        for l = b1, b1 + b2 - 1 do
          change[l] = true
        end
      end
    end
  end

  return add, change, del
end

local function place_sign(buf, lnum, kind)
  local sign_name = ({
    add = "DevelopDiffAddSign",
    change = "DevelopDiffChangeSign",
    delete = "DevelopDiffDeleteSign",
  })[kind]

  if not sign_name then
    return
  end

  vim.fn.sign_place(0, "DevelopDiffSigns", sign_name, buf, {
    lnum = lnum,
    priority = M.config.priority,
  })
end

local function get_diff_text(root, rel)
  local code_ref = select(1, system_text({ "git", "rev-parse", "--verify", M.config.base }, root))
  if code_ref ~= 0 then
    return nil
  end

  local code, out = system_text(
    { "git", "diff", "--no-color", "--unified=0", (M.config.base .. "...HEAD"), "--", rel },
    root
  )
  if code ~= 0 then
    return nil
  end

  return out or ""
end

local function update_now(buf)
  if not M.config.enabled then
    clear_signs(buf)
    dirty_buffers[buf] = false
    return
  end

  if not buf_is_real_file(buf) then
    dirty_buffers[buf] = false
    return
  end

  local abs = vim.api.nvim_buf_get_name(buf)
  local root = get_repo_root(abs)
  if not root then
    clear_signs(buf)
    dirty_buffers[buf] = false
    return
  end

  local rel = relpath_from_root(root, abs)
  if not rel then
    clear_signs(buf)
    dirty_buffers[buf] = false
    return
  end

  local out = get_diff_text(root, rel)

  clear_signs(buf)

  if not out or out == "" then
    dirty_buffers[buf] = false
    return
  end

  local add, change, del = parse_unified0(out)

  for lnum, _ in pairs(del) do
    place_sign(buf, lnum, "delete")
  end
  for lnum, _ in pairs(change) do
    place_sign(buf, lnum, "change")
  end
  for lnum, _ in pairs(add) do
    place_sign(buf, lnum, "add")
  end

  dirty_buffers[buf] = false
end

local function schedule_update(buf)
  local old = pending[buf]
  if old then
    old:stop()
    old:close()
  end

  local t = vim.uv.new_timer()
  pending[buf] = t

  t:start(M.config.debounce_ms, 0, function()
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        update_now(buf)
      end
    end)
  end)
end

function M.refresh(buf)
  schedule_update(buf or vim.api.nvim_get_current_buf())
end

function M.toggle()
  M.config.enabled = not M.config.enabled
  vim.notify(("Develop diff signs: %s"):format(M.config.enabled and "ON" or "OFF"))
  M.refresh()
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  setup_hl_and_signs()

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FocusGained" }, {
    group = group,
    callback = function(args)
      schedule_update(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(args)
      dirty_buffers[args.buf] = true
    end,
  })

  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    callback = function()
      local mode = vim.fn.mode()
      if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
        return
      end

      local buf = vim.api.nvim_get_current_buf()
      if dirty_buffers[buf] then
        schedule_update(buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(args)
      local t = pending[args.buf]
      if t then
        t:stop()
        t:close()
        pending[args.buf] = nil
      end
      dirty_buffers[args.buf] = nil
    end,
  })
end

return M
