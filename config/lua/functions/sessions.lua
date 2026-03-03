-- functions/sessions.lua
-- ==========================================================
-- Sessions: naming policy + simple menu
-- Name:
--   - if git repo: <branch>__<dirname>__<dd-mm-yy>
--   - else:        <dirname>__<dd-mm-yy>
--
-- Behavior:
--   - NO AUTOLOAD on empty nvim start (disabled on purpose)
--   - Optional autosave on exit (enabled by default, but safe)
-- ==========================================================

local M = {}

local function cwd_basename()
  return vim.fs.basename(vim.uv.cwd() or vim.fn.getcwd())
end

local function today()
  return os.date("%d-%m-%y") -- dd-mm-yy (safe for filenames)
end

local function sanitize(s)
  s = s:gsub("%s+", "_")
  s = s:gsub("[/\\:%*%?%\"%<%>%|]", "_")
  return s
end

local function system_lines(cmd)
  local res = vim.system(cmd, { text = true }):wait()
  if res.code ~= 0 then return nil end
  if not res.stdout then return nil end
  local out = vim.trim(res.stdout)
  if out == "" then return nil end
  return out
end

local function is_git_repo()
  local out = system_lines({ "git", "rev-parse", "--is-inside-work-tree" })
  return out == "true"
end

local function git_branch()
  local br = system_lines({ "git", "rev-parse", "--abbrev-ref", "HEAD" })
  if br and br ~= "HEAD" then return br end
  local sha = system_lines({ "git", "rev-parse", "--short", "HEAD" })
  return sha or "detached"
end

local function session_prefix()
  local dir = sanitize(cwd_basename())
  local date = today()

  if is_git_repo() then
    local br = sanitize(git_branch())
    return ("%s__%s__%s"):format(br, dir, date)
  end

  return ("%s__%s"):format(dir, date)
end

local function sessions_dir()
  local ok, sessions = pcall(require, "mini.sessions")
  if not ok then return nil end
  return (sessions.config and sessions.config.directory) or (vim.fn.stdpath("state") .. "/sessions")
end

local function find_latest_session_with_prefix(prefix)
  local dir = sessions_dir()
  if not dir then return nil end

  local best_path, best_mtime = nil, -1

  local ok = pcall(function()
    for name, t in vim.fs.dir(dir) do
      if t == "file" and name:sub(1, #prefix) == prefix then
        local path = dir .. "/" .. name
        local st = vim.uv.fs_stat(path)
        local mtime = st and st.mtime and st.mtime.sec or 0
        if mtime > best_mtime then
          best_mtime = mtime
          best_path = path
        end
      end
    end
  end)

  if not ok or not best_path then return nil end

  local filename = vim.fs.basename(best_path)
  return filename:gsub("%.vim$", "")
end

local function has_real_file_buffers()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b)
      and vim.bo[b].buflisted
      and vim.bo[b].buftype == ""
      and vim.api.nvim_buf_get_name(b) ~= "" then
      return true
    end
  end
  return false
end

-- ==========================================================
-- Public: menu actions
-- ==========================================================
function M.sessions_menu()
  local ok, sessions = pcall(require, "mini.sessions")
  if not ok then
    vim.notify("mini.sessions not found", vim.log.levels.WARN)
    return
  end

  local default_name = session_prefix()

  local actions = {
    "Quit (no save)",
    "Quit and save (auto name)",
    "Save as new…",
    "Save (auto name)",
    "Load latest for cwd (auto)",
    "Load session…",
    "Delete session…",
  }

  vim.ui.select(actions, { prompt = "Sessions" }, function(choice)
    if not choice then return end

    if choice == "Quit (no save)" then
      vim.g._mini_sessions_skip_autowrite = true
      vim.cmd("qa")
      return
    end

    if choice == "Quit and save (auto name)" then
      sessions.write(default_name)
      vim.cmd("qa")
      return
    end

    if choice == "Save as new…" then
      vim.ui.input({ prompt = "Session name:", default = default_name }, function(input)
        if not input or input == "" then return end
        sessions.write(input)
        vim.notify(("Saved session: %s"):format(input), vim.log.levels.INFO, { title = "Sessions" })
      end)
      return
    end

    if choice == "Save (auto name)" then
      sessions.write(default_name)
      vim.notify(("Saved session: %s"):format(default_name), vim.log.levels.INFO, { title = "Sessions" })
      return
    end

    if choice == "Load latest for cwd (auto)" then
      local name = find_latest_session_with_prefix(default_name)
      if name then
        sessions.read(name)
      else
        vim.notify("No matching session found", vim.log.levels.INFO, { title = "Sessions" })
      end
      return
    end

    if choice == "Load session…" then
      sessions.select("read")
      return
    end

    if choice == "Delete session…" then
      sessions.select("delete")
      return
    end
  end)
end

-- ==========================================================
-- Public: setup (NO autoload; safe autosave on exit)
-- ==========================================================
function M.setup()
  local ok, sessions = pcall(require, "mini.sessions")
  if not ok then
    vim.notify("mini.sessions not found", vim.log.levels.WARN)
    return
  end

  sessions.setup({
    directory = vim.fn.stdpath("state") .. "/sessions",
    autoread = false,
    autowrite = false,
  })

  local grp = vim.api.nvim_create_augroup("MiniSessionsPolicy", { clear = true })

  -- Autosave on exit (safe): only if there are real file buffers
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = grp,
    callback = function()
      if vim.g._mini_sessions_skip_autowrite then return end
      if not has_real_file_buffers() then return end
      pcall(sessions.write, session_prefix())
    end,
  })
end

return M
