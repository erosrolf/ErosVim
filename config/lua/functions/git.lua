local M = {}

function M.git_diff_to_buffer(count)
  count = tonumber(count) or 0
  local target = (count > 0) and ("HEAD~" .. count) or "HEAD"
  local cmd = "git diff " .. target
  local output = vim.fn.systemlist(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Git diff failed: " .. cmd, vim.log.levels.ERROR)
    return
  end
  if #output == 0 then
    vim.notify("No changes vs " .. target, vim.log.levels.INFO)
    return
  end

  vim.fn.setreg("+", table.concat(output, "\n"))

  vim.cmd("enew")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].filetype = "diff"
  vim.api.nvim_buf_set_name(buf, "git-diff:" .. target)

  vim.notify(("Git diff vs %s (copied to clipboard)"):format(target), vim.log.levels.INFO)
end

local function get_repo_root(abs_path)
  local dir = vim.fn.fnamemodify(abs_path, ":h")
  local res = vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true, cwd = dir }):wait()
  if res.code ~= 0 then return nil end
  return vim.trim(res.stdout)
end

local function relpath(root, abs)
  root = root:gsub("/+$", "")
  if abs:sub(1, #root + 1) ~= root .. "/" then return nil end
  return abs:sub(#root + 2)
end

function M.diffsplit_file_from_develop(opts)
  opts = opts or {}
  local base = opts.base or "develop"
  local vertical = (opts.vertical ~= false) -- default true

  local left_win = vim.api.nvim_get_current_win()
  local left_buf = vim.api.nvim_get_current_buf()
  local abs = vim.api.nvim_buf_get_name(left_buf)
  if abs == "" then
    vim.notify("Current buffer has no file", vim.log.levels.WARN)
    return
  end

  -- repo root
  local dir = vim.fn.fnamemodify(abs, ":h")
  local root_res = vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true, cwd = dir }):wait()
  if root_res.code ~= 0 then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end
  local root = vim.trim(root_res.stdout)

  -- relpath
  root = root:gsub("/+$", "")
  if abs:sub(1, #root + 1) ~= root .. "/" then
    vim.notify("File is outside repo root", vim.log.levels.WARN)
    return
  end
  local rel = abs:sub(#root + 2)

  -- git show base:file
  local show_res = vim.system({ "git", "show", ("%s:%s"):format(base, rel) }, { text = true, cwd = root }):wait()
  if show_res.code ~= 0 then
    vim.notify(("Can't read %s:%s"):format(base, rel), vim.log.levels.WARN)
    return
  end

  -- open split
  if vertical then
    vim.cmd("vsplit")
  else
    vim.cmd("split")
  end
  local right_win = vim.api.nvim_get_current_win()

  local right_buf = vim.api.nvim_create_buf(false, true) -- scratch
  vim.api.nvim_win_set_buf(right_win, right_buf)

  local lines = vim.split(show_res.stdout or "", "\n", { plain = true })
  vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, lines)

  -- buffer opts (readonly view)
  vim.bo[right_buf].buftype = "nofile"
  vim.bo[right_buf].bufhidden = "wipe"
  vim.bo[right_buf].swapfile = false
  vim.bo[right_buf].modifiable = false
  vim.bo[right_buf].readonly = true
  vim.bo[right_buf].filetype = vim.bo[left_buf].filetype
  vim.api.nvim_buf_set_name(right_buf, ("[%s] %s"):format(base, rel))

  -- align cursor line
  local cur = vim.api.nvim_win_get_cursor(left_win)
  local last = vim.api.nvim_buf_line_count(right_buf)
  vim.api.nvim_win_set_cursor(right_win, { math.min(cur[1], last), cur[2] })

  -- enable diff in both windows
  vim.api.nvim_set_current_win(left_win)
  vim.cmd("diffthis")
  vim.api.nvim_set_current_win(right_win)
  vim.cmd("diffthis")

  -- sync scroll + cursor
  for _, w in ipairs({ left_win, right_win }) do
    vim.api.nvim_win_set_option(w, "scrollbind", true)
    vim.api.nvim_win_set_option(w, "cursorbind", true)
  end

  -- easy close: q in right buffer closes window and disables diff/binds
  vim.keymap.set("n", "q", function()
    -- turn off diff + binds in both if still valid
    for _, w in ipairs({ left_win, right_win }) do
      if vim.api.nvim_win_is_valid(w) then
        pcall(vim.api.nvim_win_set_option, w, "scrollbind", false)
        pcall(vim.api.nvim_win_set_option, w, "cursorbind", false)
        pcall(vim.cmd, "diffoff!")
      end
    end
    if vim.api.nvim_win_is_valid(right_win) then
      vim.api.nvim_win_close(right_win, true)
    end
    if vim.api.nvim_win_is_valid(left_win) then
      vim.api.nvim_set_current_win(left_win)
    end
  end, { buffer = right_buf, silent = true, desc = "Close develop diffsplit" })
end

local function find_hunk_for_line(diff_lines, cursor_line)
  -- Парсим unified diff и ищем ханк, который покрывает cursor_line (по "new file" диапазону)
  local i = 1
  while i <= #diff_lines do
    local line = diff_lines[i]
    local a1, a2, b1, b2 = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
    if b1 then
      b1 = tonumber(b1)
      b2 = tonumber(b2)
      if b2 == nil or b2 == 0 then b2 = 1 end

      local start_new = b1
      local end_new = b1 + b2 - 1

      -- Собираем строки ханка до следующего @@
      local hunk = { line }
      i = i + 1
      while i <= #diff_lines and not diff_lines[i]:match("^@@ ") do
        table.insert(hunk, diff_lines[i])
        i = i + 1
      end

      -- Если это чистое удаление, git часто даёт +c,0; но мы нормализовали b2=1.
      if cursor_line >= start_new and cursor_line <= end_new then
        return hunk
      end
    else
      i = i + 1
    end
  end
  return nil
end

function M.preview_hunk_vs_develop(opts)
  opts = opts or {}
  local base = opts.base or "develop"

  local buf = vim.api.nvim_get_current_buf()
  local abs = vim.api.nvim_buf_get_name(buf)
  if abs == "" then
    vim.notify("Current buffer has no file", vim.log.levels.WARN)
    return
  end

  local root = get_repo_root(abs)
  if not root then
    vim.notify("Not a git repo", vim.log.levels.WARN)
    return
  end

  local rel = relpath(root, abs)
  if not rel then
    vim.notify("File is outside repo root", vim.log.levels.WARN)
    return
  end

  -- Возьмём diff с контекстом, чтобы hunk выглядел нормально
  local res = vim.system({
    "git", "diff", "--no-color", "-U3", (base .. "...HEAD"), "--", rel
  }, { text = true, cwd = root }):wait()

  if res.code ~= 0 then
    vim.notify(("git diff failed vs %s"):format(base), vim.log.levels.ERROR)
    return
  end

  local out = res.stdout or ""
  if out == "" then
    vim.notify(("No differences vs %s"):format(base), vim.log.levels.INFO)
    return
  end

  local diff_lines = vim.split(out, "\n", { plain = true })
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  local hunk = find_hunk_for_line(diff_lines, cursor_line)
  if not hunk then
    vim.notify(("No hunk under cursor vs %s"):format(base), vim.log.levels.INFO)
    return
  end

  -- Красиво: уберём "diff --git / index / --- / +++" если они попали (обычно они выше @@ и не попадают)
  -- Покажем как diff
  local width = math.max(60, vim.api.nvim_win_get_width(0) - 4)

  vim.lsp.util.open_floating_preview(
    hunk,
    "diff",
    {
      border = "rounded",
      width = width,
      title = ("Git hunk vs %s"):format(base),
      title_pos = "center",
      focusable = false,
      close_events = { "CursorMoved", "InsertEnter" },
    }
  )
end

--------------------------------------------------
-- Пробуем достать Git Hunk через gitsigns,
-- если его нет то пробуем вывести Git Hunk относительно develop
--------------------------------------------------
local function cursor_in_gitsigns_hunk(hunk, lnum)
  -- gitsigns hunks usually have: hunk.added.start/count OR hunk.removed.start/count
  local a = hunk.added or {}
  local r = hunk.removed or {}

  local function in_range(s, c)
    s = tonumber(s); c = tonumber(c)
    if not s or not c then return false end
    if c <= 0 then c = 1 end
    return lnum >= s and lnum <= (s + c - 1)
  end

  return in_range(a.start, a.count) or in_range(r.start, r.count)
end

function M.preview_hunk_smart(opts)
  opts = opts or {}
  local base = opts.base or "develop"

  local buf = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]

  -- 1) Try gitsigns if available and there is a hunk under cursor
  local ok_gs, gs = pcall(require, "gitsigns")
  if ok_gs and gs and type(gs.get_hunks) == "function" then
    local hunks = gs.get_hunks(buf)
    if hunks and type(hunks) == "table" then
      for _, h in ipairs(hunks) do
        if cursor_in_gitsigns_hunk(h, lnum) then
          -- Found hunk -> show native preview
          gs.preview_hunk()
          return
        end
      end
    end
  end

  -- 2) Fallback: show hunk vs develop
  if type(M.preview_hunk_vs_develop) == "function" then
    M.preview_hunk_vs_develop({ base = base })
  else
    vim.notify("preview_hunk_vs_develop() is not available", vim.log.levels.WARN)
  end
end

function M.setup()
  vim.api.nvim_create_user_command("GitDiffHead", function(opts)
    M.git_diff_to_buffer(opts.args)
  end, {
    nargs = "?",
    complete = function() return { "1", "2", "3", "5", "10" } end,
    desc = "Git diff vs HEAD~N (default: HEAD)",
  })
end

return M
