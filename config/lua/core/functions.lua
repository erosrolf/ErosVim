local M = {}

-- =========================================================
-- Меню "Go to..."
-- =========================================================
function M.goto_menu()
  local choices = {
    { label = "Definition",      action = vim.lsp.buf.definition },
    { label = "Declaration",     action = vim.lsp.buf.declaration },
    { label = "Implementation",  action = vim.lsp.buf.implementation },
    { label = "Type Definition", action = vim.lsp.buf.type_definition },
    { label = "References",      action = vim.lsp.buf.references },
    { label = "Hover (Doc)",     action = vim.lsp.buf.hover },
  }

  vim.ui.select(choices, {
    prompt = "Go to...",
    format_item = function(item) return item.label end,
  }, function(choice)
    if choice then choice.action() end
  end)
end

-- =========================================================
-- Диагностика в loclist
-- =========================================================
function M.show_diagnostics_list()
  vim.diagnostic.setloclist({ open = true })
  vim.cmd("botright lopen | resize 15")
end

-- =========================================================
-- Smart close buffer
-- =========================================================
function M.smart_close_buffer()
  local modified = vim.bo.modified
  local bufs = #vim.fn.getbufinfo({ buflisted = 1 })

  local function close(force)
    -- Закрываем aerial, если открыт
    local ok, aerial = pcall(require, "aerial")
    if ok and aerial and aerial.is_open and aerial.is_open() then
      aerial.close()
    end

    vim.cmd((bufs <= 1) and (force and "q!" or "confirm q") or (force and "bdelete!" or "bdelete"))
  end

  if not modified then
    close(false)
    return
  end

  vim.ui.select({ "Выйти без сохранения", "Сохранить и закрыть", "Отмена" }, { prompt = "Буфер изменён. Что сделать?" },
    function(choice)
      if choice == "Сохранить и закрыть" then
        vim.cmd("write")
        close(false)
      elseif choice == "Выйти без сохранения" then
        close(true)
      end
    end)
end

-- =========================================================
-- Git diff preview window (gitsigns hunk popup)
-- =========================================================
function M.preview_hunk_popup()
  local width = vim.api.nvim_win_get_width(0)
  local ok, gs = pcall(require, "gitsigns")
  if not ok or not gs then return end

  local hunks = gs.get_hunks(vim.api.nvim_get_current_buf())
  if not hunks then return end

  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local target = nil

  for _, h in ipairs(hunks) do
    local start_line = h.added.start
    local end_line = h.added.start + h.added.count
    if cursor >= start_line and cursor <= end_line then
      target = h
      break
    end
  end

  if not target then
    vim.notify("Нет изменений в текущей строке", vim.log.levels.INFO)
    return
  end

  local lines = {}

  for _, l in ipairs(target.removed.lines or {}) do
    table.insert(lines, "- " .. l)
  end

  if #(target.removed.lines or {}) > 0 and #(target.added.lines or {}) > 0 then
    table.insert(lines, "")
  end

  for _, l in ipairs(target.added.lines or {}) do
    table.insert(lines, "+ " .. l)
  end

  vim.lsp.util.open_floating_preview(lines, "diff", {
    border = "rounded",
    width = width,
    title = "Git Hunk",
    title_pos = "center",
    focusable = false,
    close_events = { "CursorMoved", "InsertEnter" },
  })
end

-- =========================================================
-- Copy absolute path + whole buffer content to system clipboard (+)
-- =========================================================
function M.copy_file_path_and_content()
  local path = vim.fn.expand("%:p")
  if path == "" then
    vim.notify("No file path for current buffer", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, "\n")

  local result = path .. "\n\n" .. text
  vim.fn.setreg("+", result)
  vim.notify("Copied file path + content to clipboard", vim.log.levels.INFO)
end

-- =========================================================
-- Format JSON exactly like project hook: jq -M -S --indent 4 .
-- Returns true if buffer was changed, false otherwise.
-- =========================================================
function M.format_json_like_hook(bufnr)
  bufnr = bufnr or 0

  if vim.bo[bufnr].filetype ~= "json" then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines == 0 then
    return false
  end

  if vim.fn.executable("jq") ~= 1 then
    vim.notify("jq not found in PATH", vim.log.levels.WARN)
    return false
  end

  local input = table.concat(lines, "\n")
  local cmd = { "jq", "-M", "-S", "--indent", "4", "." }
  local output = vim.fn.system(cmd, input)

  if vim.v.shell_error ~= 0 then
    vim.notify("jq failed: buffer is not valid JSON", vim.log.levels.WARN)
    return false
  end

  local out_lines = vim.split(output, "\n", { plain = true })
  if out_lines[#out_lines] == "" then
    table.remove(out_lines, #out_lines)
  end

  -- No changes -> do nothing
  if #out_lines == #lines then
    local same = true
    for i = 1, #lines do
      if lines[i] ~= out_lines[i] then
        same = false
        break
      end
    end
    if same then
      return false
    end
  end

  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, out_lines)
  vim.fn.winrestview(view)
  return true
end

-- =========================================================
-- clangd: manual compile_commands.json picker (persistent)
-- =========================================================
local function _cc_state_file()
  return vim.fn.stdpath("state") .. "/clangd_compile_commands_path.txt"
end

local function _cc_load()
  local f = _cc_state_file()
  if vim.fn.filereadable(f) ~= 1 then return nil end
  local lines = vim.fn.readfile(f)
  local p = lines and lines[1] or nil
  if p and p ~= "" then return p end
  return nil
end

local function _cc_save(path)
  vim.fn.writefile({ path }, _cc_state_file())
end

-- Returns absolute path to selected compile_commands.json (or nil)
function M.get_clangd_compile_commands_path()
  if vim.g.clangd_compile_commands_path and vim.g.clangd_compile_commands_path ~= "" then
    return vim.g.clangd_compile_commands_path
  end

  local saved = _cc_load()
  if saved and saved ~= "" then
    vim.g.clangd_compile_commands_path = saved
    return saved
  end

  return nil
end

local function _stop_clangd_clients()
  local clients = {}

  if vim.lsp.get_clients then
    clients = vim.lsp.get_clients({ name = "clangd" })
  elseif vim.lsp.get_active_clients then
    clients = vim.lsp.get_active_clients({ name = "clangd" })
  end

  local ids = {}
  for _, c in ipairs(clients or {}) do
    if type(c) == "table" and c.id then
      table.insert(ids, c.id)
    end
  end

  if vim.lsp.stop_client and #ids > 0 then
    -- stop_client can accept list of ids; force=true
    pcall(vim.lsp.stop_client, ids, true)
  end
end

-- Set from current buffer (must be compile_commands.json)
-- Also restarts clangd so it picks the new DB immediately.
function M.set_clangd_compile_commands_from_current_buffer(opts)
  opts = opts or {}

  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)

  if path == "" then
    vim.notify("No file path for current buffer", vim.log.levels.WARN)
    return
  end

  path = vim.fn.fnamemodify(path, ":p")

  if vim.fn.fnamemodify(path, ":t") ~= "compile_commands.json" then
    vim.notify("Open compile_commands.json and run :ClangdUseCC", vim.log.levels.WARN)
    return
  end

  if vim.fn.filereadable(path) ~= 1 then
    vim.notify("compile_commands.json is not readable: " .. path, vim.log.levels.ERROR)
    return
  end

  vim.g.clangd_compile_commands_path = path
  _cc_save(path)

  vim.notify("clangd compile_commands.json set:\n" .. path, vim.log.levels.INFO)

  if opts.restart == false then
    return
  end

  _stop_clangd_clients()

  -- Reopen buffer to trigger lspconfig attach (root/config)
  vim.cmd("edit")

  -- Start clangd (ignore errors if lspconfig command is not available)
  pcall(vim.cmd, "LspStart clangd")

  vim.notify("clangd restarted", vim.log.levels.INFO)
end

-- =========================================================
-- git diff vs HEAD~N to buffer
-- =========================================================
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

  -- clipboard
  vim.fn.setreg("+", table.concat(output, "\n"))

  -- scratch buffer
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

-- =========================================================
-- User commands (define once)
-- =========================================================
if not vim.g.__core_functions_cmds_defined then
  vim.g.__core_functions_cmds_defined = true

  -- clangd
  vim.api.nvim_create_user_command("ClangdUseCC", function()
    require("core.functions").set_clangd_compile_commands_from_current_buffer({ restart = true })
  end, {})

  vim.api.nvim_create_user_command("ClangdShowCC", function()
    local p = require("core.functions").get_clangd_compile_commands_path()
    if p then
      vim.notify("clangd compile_commands.json:\n" .. p, vim.log.levels.INFO)
    else
      vim.notify("clangd compile_commands.json is not set", vim.log.levels.WARN)
    end
  end, {})

  -- build tools (delegated to plugins/eros_build_tool.lua)
  vim.api.nvim_create_user_command("PickCwdBuild", function(opts)
    local bt = _build_tool()
    if not bt then
      vim.notify("plugins.eros_build_tool is not available", vim.log.levels.ERROR)
      return
    end
    bt.pick_cwd_build(opts.args)
  end, {
    nargs = 1,
    desc = "Set build CWD to <repo_root>/<arg> and load .nvim-build.lua there",
    complete = function(_, line)
      local bt = _build_tool()
      if bt and bt.complete_pick_cwd_build then
        return bt.complete_pick_cwd_build(line)
      end
      return {}
    end,
  })

  vim.api.nvim_create_user_command("PickCwdBuildShow", function()
    local bt = _build_tool()
    if not bt or not bt.show_cwd_build then
      vim.notify("plugins.eros_build_tool is not available", vim.log.levels.ERROR)
      return
    end
    bt.show_cwd_build()
  end, { desc = "Show current build CWD" })

  vim.api.nvim_create_user_command("PickCwdBuildClear", function()
    local bt = _build_tool()
    if not bt or not bt.clear_cwd_build then
      vim.notify("plugins.eros_build_tool is not available", vim.log.levels.ERROR)
      return
    end
    bt.clear_cwd_build()
  end, { desc = "Clear saved build CWD" })

  vim.api.nvim_create_user_command("BuildTarget", function(cmdopts)
    local bt = _build_tool()
    if not bt or not bt.build_target then
      vim.notify("plugins.eros_build_tool is not available", vim.log.levels.ERROR)
      return
    end
    bt.build_target({ target = cmdopts.args })
  end, {
    nargs = "?",
    desc = "Build target (infer from current file via build.ninja, or provide explicit target)",
  })

  vim.api.nvim_create_user_command("BuildLog", function()
    local bt = _build_tool()
    if not bt or not bt.show_build_log then
      vim.notify("plugins.eros_build_tool is not available", vim.log.levels.ERROR)
      return
    end
    bt.show_build_log()
  end, { desc = "Reopen last build/test log window" })

  -- git diff
  vim.api.nvim_create_user_command("GitDiffHead", function(opts)
    require("core.functions").git_diff_to_buffer(opts.args)
  end, {
    nargs = "?",
    complete = function()
      return { "1", "2", "3", "5", "10" }
    end,
    desc = "Git diff vs HEAD~N (default: HEAD)",
  })

  ------ open current buffer in Finder / File Manager ------
  function M.open_buffer_in_finder()
    local buf = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(buf)

    local function notify(msg, level)
      vim.notify(msg, level or vim.log.levels.INFO, { title = "OpenBufferInFinder" })
    end

    local function is_dir(path)
      local st = vim.loop.fs_stat(path)
      return st and st.type == "directory"
    end

    local function is_file(path)
      local st = vim.loop.fs_stat(path)
      return st and st.type == "file"
    end

    -- Если буфер не привязан к файлу — откроем cwd
    if name == nil or name == "" then
      local cwd = vim.loop.cwd()
      if not cwd or cwd == "" then
        notify("Не удалось определить cwd", vim.log.levels.ERROR)
        return
      end
      name = cwd
    else
      name = vim.fn.fnamemodify(name, ":p")
    end

    local sys = (vim.loop.os_uname().sysname or ""):lower()
    local cmd

    if sys:find("darwin") then
      -- macOS: если файл — показать в Finder, если папка — открыть папку
      if is_file(name) then
        cmd = { "open", "-R", name }
      else
        local dir = is_dir(name) and name or vim.fn.fnamemodify(name, ":h")
        cmd = { "open", dir }
      end
    elseif sys:find("windows") then
      -- Windows: выделить файл в проводнике или открыть папку
      if is_file(name) then
        cmd = { "explorer.exe", "/select,", name }
      else
        local dir = is_dir(name) and name or vim.fn.fnamemodify(name, ":h")
        cmd = { "explorer.exe", dir }
      end
    else
      -- Linux/Unix: открыть папку через xdg-open
      local dir = is_dir(name) and name or vim.fn.fnamemodify(name, ":h")
      cmd = { "xdg-open", dir }
    end

    local ok = vim.fn.jobstart(cmd, { detach = true }) > 0
    if not ok then
      notify("Не удалось запустить файловый менеджер", vim.log.levels.ERROR)
      return
    end

    -- Ненавязчиво
    -- notify("Открыл в файловом менеджере")
  end

  -- Команда :OpenBufferInFinder
  pcall(vim.api.nvim_create_user_command, "OpenBufferInFinder", function()
    require("core.functions").open_buffer_in_finder()
  end, {})
end

return M
