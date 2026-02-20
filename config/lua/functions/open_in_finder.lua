local M = {}

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
    if is_file(name) then
      cmd = { "open", "-R", name }
    else
      local dir = is_dir(name) and name or vim.fn.fnamemodify(name, ":h")
      cmd = { "open", dir }
    end
  elseif sys:find("windows") then
    if is_file(name) then
      cmd = { "explorer.exe", "/select,", name }
    else
      local dir = is_dir(name) and name or vim.fn.fnamemodify(name, ":h")
      cmd = { "explorer.exe", dir }
    end
  else
    local dir = is_dir(name) and name or vim.fn.fnamemodify(name, ":h")
    cmd = { "xdg-open", dir }
  end

  local ok = vim.fn.jobstart(cmd, { detach = true }) > 0
  if not ok then
    notify("Не удалось запустить файловый менеджер", vim.log.levels.ERROR)
  end
end

function M.setup()
  pcall(vim.api.nvim_create_user_command, "OpenBufferInFinder", function()
    require("core.functions").open_buffer_in_finder()
  end, {})
end

return M
