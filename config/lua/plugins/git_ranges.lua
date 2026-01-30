-- lua/git_ranges/init.lua
local M = {}

M.config = {
  width = 1,
  develop_ref = "develop",

  refresh_debounce_ms = 120,
  sync_debounce_ms = 30,

  panel_mode = "minimap", -- "list" | "minimap"

  -- Panel marker char (thin bar)
  marker_char = "",      -- можно заменить на "|"

  priority = { red = 3, green = 2, orange = 1 },

  hl = {
    -- Hover highlight in main buffer (visible only)
    hover_group = "GitRangesHover",
    hover_link = "Visual",

    -- Base highlight in main buffer (gray only)
    base_group = "GitRangesBaseGray",
    base_link = "CursorLine",
    base_blend = 88,

    -- Panel bar colors
    panel_red = "GitRangesPanelRed",
    panel_green = "GitRangesPanelGreen",
    panel_orange = "GitRangesPanelOrange",
    panel_red_link = "DiffDelete",
    panel_green_link = "DiffAdd",
    panel_orange_link = "DiffChange",
  },

  highlight_only_visible = true,
  visible_highlight_cap = 700,
}

-- tabpage -> state
M._state = {}

-- namespaces
M._base_ns = vim.api.nvim_create_namespace("git_ranges_base")
M._hover_ns = vim.api.nvim_create_namespace("git_ranges_hover")
M._panel_ns = vim.api.nvim_create_namespace("git_ranges_panel")

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

local function count_listed_real_file_buffers()
  local infos = vim.fn.getbufinfo({ buflisted = 1 })
  local n = 0
  for _, bi in ipairs(infos) do
    local b = bi.bufnr
    if vim.api.nvim_buf_is_valid(b) and is_real_file_buffer(b) then
      n = n + 1
    end
  end
  return n
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

local function normalize_items(items, priority)
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

local function compute_unsaved_ranges(buf)
  if not vim.bo[buf].modified then return {} end
  local path = vim.api.nvim_buf_get_name(buf)
  if not path_is_file(path) then return {} end

  local disk = vim.fn.readfile(path)
  local mem = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local disk_s = table.concat(disk, "\n")
  local mem_s = table.concat(mem, "\n")

  local unified = vim.diff(disk_s, mem_s, { result_type = "unified", ctxlen = 0 })
  local lines = vim.split(unified, "\n", { plain = true })
  return parse_unified0_hunks(lines)
end

local function compute_saved_ranges(path, git_root)
  local rel = relpath_from_root(git_root, path)
  local out = vim.fn.systemlist({ "git", "-C", git_root, "diff", "--unified=0", "HEAD", "--", rel })
  if vim.v.shell_error ~= 0 then return {} end
  return parse_unified0_hunks(out)
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

local function with_debounce(fn, ms)
  local timer = vim.loop.new_timer()
  local scheduled = false
  return function()
    if scheduled then return end
    scheduled = true
    timer:stop()
    timer:start(ms, 0, function()
      scheduled = false
      vim.schedule(fn)
    end)
  end
end

local function is_panel_win(win)
  if type(win) ~= "number" then return false end
  if not vim.api.nvim_win_is_valid(win) then return false end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].filetype == "git_ranges"
end

local function ensure_hl()
  local h = M.config.hl

  if vim.fn.hlexists(h.hover_group) == 0 then
    vim.api.nvim_set_hl(0, h.hover_group, { link = h.hover_link })
  end

  if vim.fn.hlexists(h.base_group) == 0 then
    local ok = pcall(vim.api.nvim_set_hl, 0, h.base_group, { link = h.base_link, blend = h.base_blend })
    if not ok then
      vim.api.nvim_set_hl(0, h.base_group, { link = h.base_link })
    end
  end

  if vim.fn.hlexists(h.panel_red) == 0 then
    vim.api.nvim_set_hl(0, h.panel_red, { link = h.panel_red_link })
  end
  if vim.fn.hlexists(h.panel_green) == 0 then
    vim.api.nvim_set_hl(0, h.panel_green, { link = h.panel_green_link })
  end
  if vim.fn.hlexists(h.panel_orange) == 0 then
    vim.api.nvim_set_hl(0, h.panel_orange, { link = h.panel_orange_link })
  end
end

local function clear_base(st)
  if not st then return end
  if st.owner_buf and vim.api.nvim_buf_is_valid(st.owner_buf) then
    pcall(vim.api.nvim_buf_clear_namespace, st.owner_buf, M._base_ns, 0, -1)
  end
end

local function clear_hover(st)
  if not st then return end
  if st.owner_buf and vim.api.nvim_buf_is_valid(st.owner_buf) then
    pcall(vim.api.nvim_buf_clear_namespace, st.owner_buf, M._hover_ns, 0, -1)
  end
end

local function clear_panel_marks(st)
  if not st then return end
  if st.buf and vim.api.nvim_buf_is_valid(st.buf) then
    pcall(vim.api.nvim_buf_clear_namespace, st.buf, M._panel_ns, 0, -1)
  end
end

local function pick_main_win_in_tab(tab)
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    local b = vim.api.nvim_win_get_buf(w)
    if is_real_file_buffer(b) then return w end
  end
  return nil
end

local function get_visible_range(win)
  local top = vim.fn.line("w0", win)
  local bot = vim.fn.line("w$", win)
  if top < 1 then top = 1 end
  if bot < top then bot = top end
  return top, bot
end

local function apply_visible_base_highlights(st)
  clear_base(st)
end

local function apply_visible_hover(st, item)
  -- отключаем hover подсветку в основном буфере
  clear_hover(st)
end

local function center_main_on_item(st, item)
  if not st or not item then return end
  local main_win = st.main_win
  if not (main_win and vim.api.nvim_win_is_valid(main_win)) then
    main_win = pick_main_win_in_tab(st.tab)
  end
  if not (main_win and vim.api.nvim_win_is_valid(main_win)) then return end

  pcall(vim.api.nvim_win_set_cursor, main_win, { item.start, 0 })
  vim.api.nvim_win_call(main_win, function()
    vim.cmd("normal! zz")
  end)

  apply_visible_base_highlights(st)
  apply_visible_hover(st, item)
end

local function find_nearest_item_index(items, line)
  if not items or #items == 0 then return nil end
  local lo, hi = 1, #items
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    if items[mid].start < line then lo = mid + 1 else hi = mid - 1 end
  end

  local cand = {}
  if lo >= 1 and lo <= #items then cand[#cand + 1] = lo end
  if lo - 1 >= 1 and lo - 1 <= #items then cand[#cand + 1] = lo - 1 end

  local best_i, best_d = cand[1], math.huge
  for _, i in ipairs(cand) do
    local it = items[i]
    local d
    if line < it.start then d = it.start - line
    elseif line > it.finish then d = line - it.finish
    else d = 0 end
    if d < best_d then best_d = d; best_i = i end
  end
  return best_i
end

-- ===== Panel layout =====

local function panel_hl_for_kind(kind)
  local h = M.config.hl
  if kind == "red" then return h.panel_red end
  if kind == "green" then return h.panel_green end
  return h.panel_orange
end

local function build_minimap_layout(st)
  if not st.items or #st.items == 0 or not st.owner_buf then
    st.panel_lines = { " " }
    st.row_to_item = {}
    st.marker_rows = {}
    st.row_kind = {}
    return
  end

  if not st.main_win or not vim.api.nvim_win_is_valid(st.main_win) then
    st.main_win = pick_main_win_in_tab(st.tab)
  end
  if not (st.main_win and vim.api.nvim_win_is_valid(st.main_win)) then
    st.panel_lines = { " " }
    st.row_to_item = {}
    st.marker_rows = {}
    st.row_kind = {}
    return
  end

  local H = vim.api.nvim_win_get_height(st.win)
  if H < 1 then H = 1 end

  local total_lines = vim.api.nvim_buf_line_count(st.owner_buf)
  if total_lines < 1 then total_lines = 1 end

  local lines = {}
  for _ = 1, H do lines[#lines + 1] = " " end

  local row_to_item = {}
  local row_kind_pr = {}
  local row_kind = {}
  local marker_rows = {}

  for idx, it in ipairs(st.items) do
    local denom = math.max(1, total_lines - 1)
    local t = (it.start - 1) / denom
    local row = math.floor(t * (H - 1)) + 1
    row = math.max(1, math.min(row, H))

    local p = M.config.priority[it.kind] or 0
    local prevp = row_kind_pr[row] or -1
    if p > prevp then
      row_kind_pr[row] = p
      row_to_item[row] = idx
      row_kind[row] = it.kind
      lines[row] = M.config.marker_char
    end
  end

  for r, _ in pairs(row_to_item) do marker_rows[#marker_rows + 1] = r end
  table.sort(marker_rows)

  st.panel_lines = lines
  st.row_to_item = row_to_item
  st.marker_rows = marker_rows
  st.row_kind = row_kind
end

local function build_list_layout(st)
  st.row_to_item = {}
  st.marker_rows = {}
  st.row_kind = {}

  if not st.items or #st.items == 0 then
    st.panel_lines = { " " }
    return
  end

  local lines = {}
  for idx, it in ipairs(st.items) do
    lines[#lines + 1] = M.config.marker_char
    st.row_to_item[#lines] = idx
    st.row_kind[#lines] = it.kind
    st.marker_rows[#st.marker_rows + 1] = #lines
  end
  st.panel_lines = lines
end

local function render_panel(st)
  if not (st.buf and vim.api.nvim_buf_is_valid(st.buf)) then return end
  if not (st.win and vim.api.nvim_win_is_valid(st.win)) then return end

  if M.config.panel_mode == "minimap" then
    build_minimap_layout(st)
  else
    build_list_layout(st)
  end

  local lines = st.panel_lines or { " " }
  if #lines == 0 then lines = { " " } end

  vim.bo[st.buf].modifiable = true
  vim.api.nvim_buf_set_lines(st.buf, 0, -1, false, lines)
  vim.bo[st.buf].modifiable = false

  -- Apply per-row highlights for bars
  ensure_hl()
  clear_panel_marks(st)
  for _, row in ipairs(st.marker_rows or {}) do
    local kind = st.row_kind and st.row_kind[row] or nil
    if kind then
      local hl = panel_hl_for_kind(kind)
      pcall(vim.api.nvim_buf_add_highlight, st.buf, M._panel_ns, hl, row - 1, 0, -1)
    end
  end
end

local function panel_set_cursor_no_focus(st, row)
  if not st or not (st.win and vim.api.nvim_win_is_valid(st.win)) then return end
  local maxrow = vim.api.nvim_buf_line_count(st.buf)
  if maxrow < 1 then maxrow = 1 end
  row = math.max(1, math.min(row, maxrow))
  pcall(vim.api.nvim_win_set_cursor, st.win, { row, 0 })
end

local function panel_row_for_item_index(st, idx)
  if not st or not st.row_to_item or not st.marker_rows then return nil end
  for _, r in ipairs(st.marker_rows) do
    if st.row_to_item[r] == idx then
      return r
    end
  end
  return nil
end

local function panel_item_index_at_cursor(st)
  if not st or not st.row_to_item then return nil end
  local row = vim.api.nvim_win_get_cursor(st.win)[1]
  return st.row_to_item[row]
end

local function panel_next_marker_row(st, dir)
  if not st or not st.marker_rows or #st.marker_rows == 0 then return nil end
  local row = vim.api.nvim_win_get_cursor(st.win)[1]
  if dir > 0 then
    for _, r in ipairs(st.marker_rows) do
      if r > row then return r end
    end
    return st.marker_rows[#st.marker_rows]
  else
    for i = #st.marker_rows, 1, -1 do
      local r = st.marker_rows[i]
      if r < row then return r end
    end
    return st.marker_rows[1]
  end
end

-- ===== Lifecycle =====

local function ensure_panel_for_tab(tab)
  local st = M._state[tab]
  if st and st.win and vim.api.nvim_win_is_valid(st.win) and st.buf and vim.api.nvim_buf_is_valid(st.buf) then
    return st
  end

  st = st or {}
  st.tab = tab

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "git_ranges://panel")

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].modified = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "git_ranges"

  local curwin = vim.api.nvim_get_current_win()
  vim.cmd("topleft " .. M.config.width .. "vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].winfixwidth = true
  vim.wo[win].spell = false
  vim.wo[win].list = false

  pcall(vim.api.nvim_win_set_width, win, M.config.width)
  vim.api.nvim_set_current_win(curwin)

  st.buf = buf
  st.win = win
  st.items = {}
  st.owner_buf = nil
  st.main_win = nil
  st.last_hover_item_idx = nil

  st._last_top, st._last_bot = nil, nil
  st._base_for_buf = nil

  st.panel_lines = { " " }
  st.row_to_item = {}
  st.marker_rows = {}
  st.row_kind = {}

  M._state[tab] = st
  return st
end

local function close_panel_for_tab(tab)
  local st = M._state[tab]
  if not st then return end
  clear_base(st)
  clear_hover(st)
  clear_panel_marks(st)
  if st.win and vim.api.nvim_win_is_valid(st.win) then
    pcall(vim.api.nvim_win_close, st.win, true)
  end
  st.win = nil
  if st.buf and vim.api.nvim_buf_is_valid(st.buf) then
    pcall(vim.api.nvim_buf_delete, st.buf, { force = true })
  end
  st.buf = nil
  M._state[tab] = nil
end

-- ===== Core rebuild/sync =====

local function rebuild_ranges_for_context()
  local tab = vim.api.nvim_get_current_tabpage()
  local st = ensure_panel_for_tab(tab)

  local cur_win = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_get_current_buf()

  st.tab = tab

  -- If in panel: don't wipe, just rerender
  if is_panel_win(cur_win) then
    if st.owner_buf and vim.api.nvim_buf_is_valid(st.owner_buf) then
      render_panel(st)
      apply_visible_base_highlights(st)
      if st.last_hover_item_idx and st.items[st.last_hover_item_idx] then
        apply_visible_hover(st, st.items[st.last_hover_item_idx])
      end
    end
    return
  end

  st.main_win = cur_win

  if not is_real_file_buffer(cur_buf) then
    st.owner_buf = nil
    st.items = {}
    st.last_hover_item_idx = nil
    clear_base(st)
    clear_hover(st)
    render_panel(st)
    return
  end

  local path = vim.api.nvim_buf_get_name(cur_buf)
  local root = git_root_for_path(path)
  if not root then
    st.owner_buf = cur_buf
    st.items = {}
    st.last_hover_item_idx = nil
    clear_base(st)
    clear_hover(st)
    render_panel(st)
    return
  end

  local items = {}

  for _, r in ipairs(compute_unsaved_ranges(cur_buf)) do
    items[#items + 1] = { start = r.start, finish = r.finish, kind = "red" }
  end

  if not vim.bo[cur_buf].modified then
    for _, r in ipairs(compute_saved_ranges(path, root)) do
      items[#items + 1] = { start = r.start, finish = r.finish, kind = "green" }
    end
  end

  for _, r in ipairs(compute_orange_ranges(path, root, M.config.develop_ref)) do
    items[#items + 1] = { start = r.start, finish = r.finish, kind = "orange" }
  end

  st.owner_buf = cur_buf
  st.items = normalize_items(items, M.config.priority)

  st._last_top, st._last_bot = nil, nil
  st._base_for_buf = nil

  render_panel(st)

  local cur_line = vim.api.nvim_win_get_cursor(cur_win)[1]
  local item_idx = find_nearest_item_index(st.items, cur_line)
  st.last_hover_item_idx = item_idx

  if item_idx then
    local row = panel_row_for_item_index(st, item_idx)
    if row then panel_set_cursor_no_focus(st, row) end
  end

  apply_visible_base_highlights(st)
  if item_idx and st.items[item_idx] then
    apply_visible_hover(st, st.items[item_idx])
  else
    clear_hover(st)
  end
end

local function sync_panel_to_main_no_focus()
  local tab = vim.api.nvim_get_current_tabpage()
  local st = M._state[tab]
  if not st then return end

  local win = vim.api.nvim_get_current_win()
  if is_panel_win(win) then return end

  local buf = vim.api.nvim_win_get_buf(win)
  if not is_real_file_buffer(buf) then return end
  if st.owner_buf ~= buf then return end

  apply_visible_base_highlights(st)

  if not st.items or #st.items == 0 then
    st.last_hover_item_idx = nil
    clear_hover(st)
    return
  end

  local line = vim.api.nvim_win_get_cursor(win)[1]
  local item_idx = find_nearest_item_index(st.items, line)
  st.last_hover_item_idx = item_idx

  if item_idx then
    local row = panel_row_for_item_index(st, item_idx)
    if row then panel_set_cursor_no_focus(st, row) end
    apply_visible_hover(st, st.items[item_idx])
  else
    clear_hover(st)
  end
end

local refresh_debounced
local sync_debounced

local function focus_panel()
  local tab = vim.api.nvim_get_current_tabpage()
  local st = ensure_panel_for_tab(tab)
  if st.win and vim.api.nvim_win_is_valid(st.win) then
    vim.api.nvim_set_current_win(st.win)
  end
end

local function focus_main()
  local tab = vim.api.nvim_get_current_tabpage()
  local st = M._state[tab]
  if not st then return end
  if st.main_win and vim.api.nvim_win_is_valid(st.main_win) then
    vim.api.nvim_set_current_win(st.main_win)
    return
  end
  local w = pick_main_win_in_tab(tab)
  if w then vim.api.nvim_set_current_win(w) end
end

function M.setup(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", tbl_shallow_copy(M.config), opts)
  end

  refresh_debounced = refresh_debounced or with_debounce(rebuild_ranges_for_context, M.config.refresh_debounce_ms)
  sync_debounced = sync_debounced or with_debounce(sync_panel_to_main_no_focus, M.config.sync_debounce_ms)

  vim.api.nvim_create_user_command("GitRangesFocus", function() focus_panel() end, {})
  vim.api.nvim_create_user_command("GitRangesMain", function() focus_main() end, {})
  vim.api.nvim_create_user_command("GitRangesRefresh", function() rebuild_ranges_for_context() end, {})
  vim.api.nvim_create_user_command("GitRangesClose", function()
    close_panel_for_tab(vim.api.nvim_get_current_tabpage())
  end, {})

  -- Panel hover behavior
  vim.api.nvim_create_autocmd("CursorMoved", {
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if not is_panel_win(win) then return end

      local tab = vim.api.nvim_get_current_tabpage()
      local st = M._state[tab]
      if not st or not st.items or #st.items == 0 then
        clear_hover(st)
        return
      end

      local row = vim.api.nvim_win_get_cursor(win)[1]
      local item_idx = st.row_to_item[row]

      if not item_idx then
        -- snap to nearest marker
        local best_row, best_d = nil, math.huge
        for _, r in ipairs(st.marker_rows or {}) do
          local d = math.abs(r - row)
          if d < best_d then best_d = d; best_row = r end
        end
        if best_row then
          panel_set_cursor_no_focus(st, best_row)
          item_idx = st.row_to_item[best_row]
        end
      end
      if not item_idx then
        clear_hover(st)
        return
      end

      st.last_hover_item_idx = item_idx
      apply_visible_base_highlights(st)
      apply_visible_hover(st, st.items[item_idx])
      center_main_on_item(st, st.items[item_idx])
    end,
  })

  -- Scroll-sync without focus
  vim.api.nvim_create_autocmd({ "CursorMoved", "WinScrolled" }, {
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if is_panel_win(win) then return end
      sync_debounced()
    end,
  })

  -- Auto-refresh (safe even when entering panel)
  vim.api.nvim_create_autocmd({
    "BufEnter",
    "BufWritePost",
    "TextChanged",
    "TextChangedI",
    "InsertLeave",
    "WinEnter",
  }, {
    callback = function()
      refresh_debounced()
    end,
  })

  vim.api.nvim_create_autocmd({ "VimEnter", "TabNewEntered" }, {
    callback = function()
      ensure_panel_for_tab(vim.api.nvim_get_current_tabpage())
      refresh_debounced()
    end,
  })

  vim.api.nvim_create_autocmd({ "VimResized" }, {
    callback = function()
      local tab = vim.api.nvim_get_current_tabpage()
      local st = M._state[tab]
      if st and st.win and vim.api.nvim_win_is_valid(st.win) then
        pcall(vim.api.nvim_win_set_width, st.win, M.config.width)
        render_panel(st)
      end
    end,
  })

  -- Close panel if last real file buffer is gone
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    callback = function()
      if count_listed_real_file_buffers() <= 0 then
        -- close all panels (all tabs)
        for tab, _ in pairs(M._state) do
          close_panel_for_tab(tab)
        end
      end
    end,
  })

  -- Panel: hard read-only + keymaps
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "git_ranges",
    callback = function(ev)
      local b = ev.buf

      vim.bo[b].buftype = "nofile"
      vim.bo[b].bufhidden = "wipe"
      vim.bo[b].swapfile = false
      vim.bo[b].undofile = false
      vim.bo[b].modifiable = false
      vim.bo[b].readonly = true
      vim.bo[b].modified = false
      vim.bo[b].buflisted = false

      vim.api.nvim_create_autocmd({ "BufWriteCmd", "FileWriteCmd" }, {
        buffer = b,
        callback = function() return true end,
      })

      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = b, silent = true, nowait = true, desc = desc })
      end

      map("n", "q", focus_main, "Back to main window")
      map("n", "<Esc>", focus_main, "Back to main window")

      -- IMPORTANT FIX: no unary + in Lua
      map("n", "j", function()
        local st = M._state[vim.api.nvim_get_current_tabpage()]
        if not st then return end
        local r = panel_next_marker_row(st, 1)
        if r then panel_set_cursor_no_focus(st, r) end
      end, "Next marker")

      map("n", "k", function()
        local st = M._state[vim.api.nvim_get_current_tabpage()]
        if not st then return end
        local r = panel_next_marker_row(st, -1)
        if r then panel_set_cursor_no_focus(st, r) end
      end, "Prev marker")

      map("n", "<CR>", function()
        local tab = vim.api.nvim_get_current_tabpage()
        local st = M._state[tab]
        if not st or not st.items or #st.items == 0 then return end
        local item_idx = panel_item_index_at_cursor(st)
        if not item_idx then return end
        st.last_hover_item_idx = item_idx
        apply_visible_base_highlights(st)
        apply_visible_hover(st, st.items[item_idx])
        center_main_on_item(st, st.items[item_idx])
        focus_main()
      end, "Jump and focus main")

      -- Block edits
      local block = function() return "" end
      for _, key in ipairs({
        "i","I","a","A","o","O",
        "c","C","s","S","r","R",
        "x","X","d","D",
        "p","P",
        "u","<C-r>",
        ".", "J", "gJ",
      }) do
        map("n", key, block, "Blocked edit")
      end
    end,
  })
end

return M

