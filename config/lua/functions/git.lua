local M = {}

M.config = {
  base = "develop",
}

local function get_base(opts)
  opts = opts or {}
  return opts.base or M.config.base or "develop"
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

local function get_current_file()
  local buf = vim.api.nvim_get_current_buf()
  local abs = vim.api.nvim_buf_get_name(buf)
  if abs == "" then
    return nil, buf
  end
  return abs, buf
end

local function get_repo_root(abs_path)
  local dir = vim.fn.fnamemodify(abs_path, ":h")
  local res = vim.system({ "git", "rev-parse", "--show-toplevel" }, {
    text = true,
    cwd = dir,
  }):wait()

  if res.code ~= 0 then
    return nil
  end

  return vim.trim(res.stdout)
end

local function relpath(root, abs)
  root = root:gsub("/+$", "")
  if abs:sub(1, #root + 1) ~= root .. "/" then
    return nil
  end
  return abs:sub(#root + 2)
end

local function get_repo_and_relpath(abs)
  local root = get_repo_root(abs)
  if not root then
    return nil, nil
  end

  local rel = relpath(root, abs)
  if not rel then
    return nil, nil
  end

  return root, rel
end

local function system_git(args, cwd)
  local res = vim.system(args, {
    text = true,
    cwd = cwd,
  }):wait()

  return res
end

local function split_lines(text)
  if not text or text == "" then
    return {}
  end
  return vim.split(text, "\n", { plain = true })
end

local function create_scratch_buffer(opts)
  opts = opts or {}

  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  vim.bo[buf].buflisted = false

  if opts.name and opts.name ~= "" then
    vim.api.nvim_buf_set_name(buf, opts.name)
  end

  if opts.filetype and opts.filetype ~= "" then
    vim.bo[buf].filetype = opts.filetype
  end

  return buf
end

local function set_buffer_readonly(buf)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].modified = false
end

local function open_in_new_buffer(lines, opts)
  opts = opts or {}

  vim.cmd("enew")

  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].buflisted = false

  if opts.filetype and opts.filetype ~= "" then
    vim.bo[buf].filetype = opts.filetype
  end

  if opts.name and opts.name ~= "" then
    vim.api.nvim_buf_set_name(buf, opts.name)
  end

  return buf
end

local function read_file_from_base(root, rel, base)
  local res = system_git({
    "git",
    "show",
    ("%s:%s"):format(base, rel),
  }, root)

  if res.code ~= 0 then
    return nil, res
  end

  return res.stdout or "", res
end

local function build_branch_diff(root, rel, base, context_lines)
  context_lines = tonumber(context_lines) or 3

  local res = system_git({
    "git",
    "diff",
    "--no-color",
    ("-U%d"):format(context_lines),
    base .. "...HEAD",
    "--",
    rel,
  }, root)

  if res.code ~= 0 then
    return nil, res
  end

  return res.stdout or "", res
end

local function find_hunk_for_line(diff_lines, cursor_line)
  local i = 1

  while i <= #diff_lines do
    local line = diff_lines[i]
    local _, _, _, b1, b2 = line:find("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")

    if b1 then
      b1 = tonumber(b1)
      b2 = tonumber(b2)

      if b2 == nil or b2 == 0 then
        b2 = 1
      end

      local start_new = b1
      local finish_new = b1 + b2 - 1

      local hunk = { line }
      i = i + 1

      while i <= #diff_lines and not diff_lines[i]:match("^@@ ") do
        table.insert(hunk, diff_lines[i])
        i = i + 1
      end

      if cursor_line >= start_new and cursor_line <= finish_new then
        return hunk
      end
    else
      i = i + 1
    end
  end

  return nil
end

function M.set_base(base)
  if not base or base == "" then
    notify("Git base must not be empty", vim.log.levels.WARN)
    return
  end

  M.config.base = base
  notify(("Git base set to: %s"):format(base))
end

function M.get_base()
  return M.config.base
end

function M.git_diff_to_buffer(count)
  count = tonumber(count) or 0

  local target = (count > 0) and ("HEAD~" .. count) or "HEAD"
  local cmd = { "git", "diff", target }
  local res = system_git(cmd, vim.fn.getcwd())

  if res.code ~= 0 then
    notify("Git diff failed: git diff " .. target, vim.log.levels.ERROR)
    return
  end

  local output = split_lines(res.stdout or "")
  if #output == 0 then
    notify(("No changes vs %s"):format(target), vim.log.levels.INFO)
    return
  end

  vim.fn.setreg("+", table.concat(output, "\n"))

  open_in_new_buffer(output, {
    filetype = "diff",
    name = "git-diff:" .. target,
  })

  notify(("Git diff vs %s (copied to clipboard)"):format(target), vim.log.levels.INFO)
end

function M.diffsplit_file_from_base(opts)
  opts = opts or {}

  local base = get_base(opts)
  local vertical = (opts.vertical ~= false)

  local left_win = vim.api.nvim_get_current_win()
  local left_buf = vim.api.nvim_get_current_buf()
  local abs = vim.api.nvim_buf_get_name(left_buf)

  if abs == "" then
    notify("Current buffer has no file", vim.log.levels.WARN)
    return
  end

  local root, rel = get_repo_and_relpath(abs)
  if not root then
    notify("Not a git repo or file is outside repo root", vim.log.levels.WARN)
    return
  end

  local content = read_file_from_base(root, rel, base)
  if not content then
    notify(("Can't read %s:%s"):format(base, rel), vim.log.levels.WARN)
    return
  end

  if vertical then
    vim.cmd("vsplit")
  else
    vim.cmd("split")
  end

  local right_win = vim.api.nvim_get_current_win()
  local right_buf = create_scratch_buffer({
    name = ("[%s] %s"):format(base, rel),
    filetype = vim.bo[left_buf].filetype,
  })

  vim.api.nvim_win_set_buf(right_win, right_buf)

  local lines = split_lines(content)
  vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, lines)
  set_buffer_readonly(right_buf)

  local cur = vim.api.nvim_win_get_cursor(left_win)
  local last = math.max(1, vim.api.nvim_buf_line_count(right_buf))
  vim.api.nvim_win_set_cursor(right_win, { math.min(cur[1], last), cur[2] })

  vim.api.nvim_set_current_win(left_win)
  vim.cmd("diffthis")
  vim.api.nvim_set_current_win(right_win)
  vim.cmd("diffthis")

  for _, w in ipairs({ left_win, right_win }) do
    vim.api.nvim_win_set_option(w, "scrollbind", true)
    vim.api.nvim_win_set_option(w, "cursorbind", true)
  end

  vim.keymap.set("n", "q", function()
    for _, w in ipairs({ left_win, right_win }) do
      if vim.api.nvim_win_is_valid(w) then
        pcall(vim.api.nvim_win_set_option, w, "scrollbind", false)
        pcall(vim.api.nvim_win_set_option, w, "cursorbind", false)
      end
    end

    local curwin = vim.api.nvim_get_current_win()

    if vim.api.nvim_win_is_valid(left_win) then
      vim.api.nvim_set_current_win(left_win)
      pcall(vim.cmd, "diffoff!")
    end

    if vim.api.nvim_win_is_valid(right_win) then
      vim.api.nvim_set_current_win(right_win)
      pcall(vim.cmd, "diffoff!")
    end

    if vim.api.nvim_win_is_valid(right_win) then
      vim.api.nvim_win_close(right_win, true)
    end

    if vim.api.nvim_win_is_valid(left_win) then
      vim.api.nvim_set_current_win(left_win)
    elseif vim.api.nvim_win_is_valid(curwin) then
      vim.api.nvim_set_current_win(curwin)
    end
  end, {
    buffer = right_buf,
    silent = true,
    desc = ("Close diffsplit vs %s"):format(base),
  })
end

function M.preview_hunk_vs_base(opts)
  opts = opts or {}

  local base = get_base(opts)
  local abs = get_current_file()

  if not abs then
    notify("Current buffer has no file", vim.log.levels.WARN)
    return
  end

  local root, rel = get_repo_and_relpath(abs)
  if not root then
    notify("Not a git repo or file is outside repo root", vim.log.levels.WARN)
    return
  end

  local diff_text = build_branch_diff(root, rel, base, opts.context_lines or 3)
  if not diff_text then
    notify(("git diff failed vs %s"):format(base), vim.log.levels.ERROR)
    return
  end

  if diff_text == "" then
    notify(("No differences vs %s"):format(base), vim.log.levels.INFO)
    return
  end

  local diff_lines = split_lines(diff_text)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local hunk = find_hunk_for_line(diff_lines, cursor_line)

  if not hunk then
    notify(("No hunk under cursor vs %s"):format(base), vim.log.levels.INFO)
    return
  end

  local width = math.max(60, vim.api.nvim_win_get_width(0) - 4)

  vim.lsp.util.open_floating_preview(hunk, "diff", {
    border = "rounded",
    width = width,
    title = ("Hunk vs %s"):format(base),
    title_pos = "center",
    focusable = false,
    close_events = { "CursorMoved", "InsertEnter" },
  })
end

function M.setup(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end

  vim.api.nvim_create_user_command("GitDiffHead", function(command_opts)
    M.git_diff_to_buffer(command_opts.args)
  end, {
    nargs = "?",
    complete = function()
      return { "1", "2", "3", "5", "10" }
    end,
    desc = "Git diff vs HEAD~N (default: HEAD)",
  })

  vim.api.nvim_create_user_command("GitBase", function(command_opts)
    if not command_opts.args or command_opts.args == "" then
      notify(("Current git base: %s"):format(M.get_base()))
      return
    end

    M.set_base(command_opts.args)
  end, {
    nargs = "?",
    desc = "Show or set git base branch",
  })

  vim.api.nvim_create_user_command("GitDiffsplitBase", function(command_opts)
    M.diffsplit_file_from_base({
      base = command_opts.args ~= "" and command_opts.args or nil,
      vertical = true,
    })
  end, {
    nargs = "?",
    desc = "Open current file in diffsplit vs base branch",
  })

  vim.api.nvim_create_user_command("GitPreviewHunkBase", function(command_opts)
    M.preview_hunk_vs_base({
      base = command_opts.args ~= "" and command_opts.args or nil,
    })
  end, {
    nargs = "?",
    desc = "Preview hunk under cursor vs base branch",
  })
end

function M.mini_diff_go(where)
  local ok = pcall(function()
    MiniDiff.goto_hunk(where)
  end)

  if not ok then
    vim.notify("MiniDiff navigation is unavailable", vim.log.levels.WARN)
  end
end

function M.mini_diff_apply()
  local ok = pcall(function()
    MiniDiff.operator("apply")()
  end)

  if not ok then
    vim.notify("MiniDiff apply is unavailable", vim.log.levels.WARN)
  end
end

function M.mini_diff_reset()
  local ok = pcall(function()
    MiniDiff.operator("reset")()
  end)

  if not ok then
    vim.notify("MiniDiff reset is unavailable", vim.log.levels.WARN)
  end
end

return M
