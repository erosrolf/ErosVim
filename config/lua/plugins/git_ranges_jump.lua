-- lua/git_ranges_jump/init.lua
-- Jump across 3 groups of changes:
--   red    = unsaved (buffer vs file on disk)
--   green  = saved but uncommitted (working tree vs HEAD)  [from gitsigns if available]
--   orange = diff vs develop (develop...HEAD)              [via git diff]
--
-- Usage:
--   require("git_ranges_jump").setup({
--     develop_ref = "develop",
--     keymaps = { next = "]d", prev = "[d" },
--   })
--
-- Commands:
--   :GitRangesJumpRefresh
--   :GitRangesJumpNext
--   :GitRangesJumpPrev

local M = {}

M.config = {
  develop_ref = "develop",

  -- which layers are enabled
  enable = { red = true, green = true, orange = true },

  -- priority when ranges overlap (bigger wins)
  priority = { red = 3, green = 2, orange = 1 },

  -- throttle expensive recomputes (git + diff)
  refresh_debounce_ms = 120,

  -- keymaps (set to nil/false to disable)
  keymaps = { next = "]d", prev = "[d" },

  -- if true: don't jump in diff mode (let native ]d/[d work)
  respect_diff_mode = true,
}

-- per-buffer cache
M._buf_state = {} -- [bufnr] = { items=..., last_ms=..., last_tick=..., last_path=... }

-- ---------------- utils ----------------

local function now_ms()
  -- hrtime is ns
  return math.floor(vim.loop.hrtime() / 1e6)
end

local function tbl_shallow_copy(t)
  local r = {}
  for k, v in pairs(t) do r[k] = v end
  return r
end

local function is_real_file_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  if vim.bo[buf].buftype ~= "" then return false end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then return false end
  return true
end

local function path_is_file(path)
  if path == "" then return false end
  local st = vim.loop.fs_stat(path)
  return st and st.type == "file"
end

local function git_root_for_path(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  if dir == "" then return nil end
  local out = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 or not out[1] or out[1] == "" then return nil end
  return out[1]
end

local function relpath_from_root(root, path)
  if not root or root == "" then return path end
  if path:sub(1, #root) == root then
    return path:sub(#root + 2)
  end
  return path
end

local function parse_unified0_hunks(diff_lines)
  local ranges = {}
  for _, line in ipairs(diff_lines) do
    local _, _, new_start_s, new_count_s = line:find("^@@%s%-%d+,?%d*%s%+(%d+),?(%d*)%s@@")
    if new_start_s then
      local new_start = tonumber(new_start_s)
      local new_count = tonumber((new_count_s ~= "" and new_count_s) or "1")
      if new_count and new_count > 0 then
        ranges[#ranges + 1] = { start = new_start, finish = new_start + new_count - 1 }
      end
    end
  end
  return ranges
end

-- Normalize: split overlaps into segments, pick best priority, then merge adjacent
local function normalize_items(items, priority)
  if not items or #items == 0 then return {} end

  table.sort(items, function(x, y)
    if x.start ~= y.start then return x.start < y.start end
    return (priority[x.kind] or 0) > (priority[y.kind] or 0)
  end)

  local boundaries = {}
  for _, it in ipairs(items) do
    boundaries[#boundaries + 1] = it.start
    boundaries[#boundaries + 1] = it.finish + 1
  end
  table.sort(boundaries)

  local uniq = {}
  do
    local last = nil
    for _, b in ipairs(boundaries) do
      if b ~= last then uniq[#uniq + 1] = b end
      last = b
    end
  end

  local segments = {}
  for i = 1, #uniq - 1 do
    local s = uniq[i]
    local e = uniq[i + 1] - 1
    if s <= e then
      local best_kind, best_p = nil, -1
      for _, it in ipairs(items) do
        if not (e < it.start or s > it.finish) then
          local p = priority[it.kind] or 0
          if p > best_p then
            best_p = p
            best_kind = it.kind
          end
        end
      end
      if best_kind then
        segments[#segments + 1] = { start = s, finish = e, kind = best_kind }
      end
    end
  end

  local merged = {}
  for _, seg in ipairs(segments) do
    local last = merged[#merged]
    if last and last.kind == seg.kind and last.finish + 1 >= seg.start then
      last.finish = math.max(last.finish, seg.finish)
    else
      merged[#merged + 1] = seg
    end
  end

  local out = {}
  for _, m in ipairs(merged) do
    out[#out + 1] = { start = m.start, finish = m.finish, kind = m.kind }
  end
  return out
end

-- ---------------- compute ranges ----------------

local function compute_unsaved_ranges(buf)
  if not vim.bo[buf].modified then return {} end
  local path = vim.api.nvim_buf_get_name(buf)
  if not path_is_file(path) then return {} end

  local ok_disk, disk = pcall(vim.fn.readfile, path)
  if not ok_disk or type(disk) ~= "table" then return {} end
  local mem = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local disk_s = table.concat(disk, "\n")
  local mem_s = table.concat(mem, "\n")

  local unified = vim.diff(disk_s, mem_s, { result_type = "unified", ctxlen = 0 })
  local lines = vim.split(unified, "\n", { plain = true })
  return parse_unified0_hunks(lines)
end

local function compute_orange_ranges(path, git_root, develop_ref)
  local rel = relpath_from_root(git_root, path)
  local out = vim.fn.systemlist({
    "git", "-C", git_root,
    "diff", "--unified=0", "--diff-filter=AM",
    develop_ref .. "...HEAD", "--", rel
  })
  if vim.v.shell_error ~= 0 then return {} end
  return parse_unified0_hunks(out)
end

-- Try to read hunks from gitsigns.
-- We support a few shapes:
--   1) h.head contains '@@ -a,b +c,d @@'  -> parse that
--   2) h.added = { start=..., count=... } -> use that
local function compute_green_ranges_from_gitsigns()
  local gs = package.loaded.gitsigns
  if not gs then return {} end
  if type(gs.get_hunks) ~= "function" then return {} end

  local ok, hunks = pcall(gs.get_hunks)
  if not ok or type(hunks) ~= "table" then return {} end

  local ranges = {}
  for _, h in ipairs(hunks) do
    if type(h) == "table" then
      if type(h.added) == "table" and tonumber(h.added.start) and tonumber(h.added.count) then
        local s = tonumber(h.added.start)
        local c = tonumber(h.added.count)
        if c and c > 0 then
          ranges[#ranges + 1] = { start = s, finish = s + c - 1 }
        end
      elseif type(h.head) == "string" then
        local parsed = parse_unified0_hunks({ h.head })
        for _, r in ipairs(parsed) do
          ranges[#ranges + 1] = r
        end
      end
    end
  end
  return ranges
end

-- ---------------- caching + build items ----------------

local function build_items_for_buf(buf, force)
  if not is_real_file_buffer(buf) then return {} end

  local path = vim.api.nvim_buf_get_name(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)

  local st = M._buf_state[buf] or {}
  M._buf_state[buf] = st

  local ms = now_ms()
  local debounce = M.config.refresh_debounce_ms or 0

  if not force then
    if st.items
      and st.last_ms
      and (ms - st.last_ms) < debounce
      and st.last_tick == tick
      and st.last_path == path
    then
      return st.items
    end
  end

  local items = {}

  if M.config.enable.red then
    for _, r in ipairs(compute_unsaved_ranges(buf)) do
      items[#items + 1] = { start = r.start, finish = r.finish, kind = "red" }
    end
  end

  if M.config.enable.green then
    -- If file is modified but unsaved, gitsigns still reflects last saved state,
    -- which is fine: green = saved-but-uncommitted.
    for _, r in ipairs(compute_green_ranges_from_gitsigns()) do
      items[#items + 1] = { start = r.start, finish = r.finish, kind = "green" }
    end
  end

  if M.config.enable.orange then
    local root = git_root_for_path(path)
    if root then
      for _, r in ipairs(compute_orange_ranges(path, root, M.config.develop_ref)) do
        items[#items + 1] = { start = r.start, finish = r.finish, kind = "orange" }
      end
    end
  end

  local normalized = normalize_items(items, M.config.priority)

  st.items = normalized
  st.last_ms = ms
  st.last_tick = tick
  st.last_path = path

  return normalized
end

-- ---------------- jumping ----------------

local function find_next_index(items, line)
  if not items or #items == 0 then return nil end

  -- if inside an item, treat "next" as next item after the containing one
  for i, it in ipairs(items) do
    if line >= it.start and line <= it.finish then
      if i < #items then return i + 1 end
      return 1
    end
  end

  -- otherwise first item whose start > line
  for i, it in ipairs(items) do
    if it.start > line then return i end
  end
  return 1
end

local function find_prev_index(items, line)
  if not items or #items == 0 then return nil end

  for i, it in ipairs(items) do
    if line >= it.start and line <= it.finish then
      if i > 1 then return i - 1 end
      return #items
    end
  end

  for i = #items, 1, -1 do
    if items[i].start < line then return i end
  end
  return #items
end

local function jump_to_item(win, item)
  if not item then return end
  if not (win and vim.api.nvim_win_is_valid(win)) then return end
  pcall(vim.api.nvim_win_set_cursor, win, { item.start, 0 })
  vim.api.nvim_win_call(win, function()
    vim.cmd("normal! zz")
  end)
end

function M.refresh(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  build_items_for_buf(buf, true)
end

function M.jump_next()
  if M.config.respect_diff_mode and vim.wo.diff then
    vim.cmd("normal! ]d")
    return
  end

  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  if not is_real_file_buffer(buf) then return end

  local items = build_items_for_buf(buf, false)
  if #items == 0 then return end

  local line = vim.api.nvim_win_get_cursor(win)[1]
  local idx = find_next_index(items, line)
  jump_to_item(win, items[idx])
end

function M.jump_prev()
  if M.config.respect_diff_mode and vim.wo.diff then
    vim.cmd("normal! [d")
    return
  end

  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  if not is_real_file_buffer(buf) then return end

  local items = build_items_for_buf(buf, false)
  if #items == 0 then return end

  local line = vim.api.nvim_win_get_cursor(win)[1]
  local idx = find_prev_index(items, line)
  jump_to_item(win, items[idx])
end

-- ---------------- setup ----------------

function M.setup(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", tbl_shallow_copy(M.config), opts)
  end

  vim.api.nvim_create_user_command("GitRangesJumpRefresh", function()
    M.refresh(vim.api.nvim_get_current_buf())
  end, {})

  vim.api.nvim_create_user_command("GitRangesJumpNext", function() M.jump_next() end, {})
  vim.api.nvim_create_user_command("GitRangesJumpPrev", function() M.jump_prev() end, {})

  -- Optional keymaps
  if M.config.keymaps and M.config.keymaps.next then
    vim.keymap.set("n", M.config.keymaps.next, function() M.jump_next() end,
      { silent = true, desc = "Next change (unsaved/HEAD/develop)" })
  end
  if M.config.keymaps and M.config.keymaps.prev then
    vim.keymap.set("n", M.config.keymaps.prev, function() M.jump_prev() end,
      { silent = true, desc = "Prev change (unsaved/HEAD/develop)" })
  end

  -- Light cache invalidation:
  -- if you want: keep it cheap and only clear cache on writes / buffer changes.
  vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter" }, {
    callback = function(ev)
      local b = ev.buf
      if not is_real_file_buffer(b) then return end
      -- don't force recompute, just allow next jump to rebuild
      local st = M._buf_state[b]
      if st then st.last_ms = 0 end
    end,
  })
end

return M
