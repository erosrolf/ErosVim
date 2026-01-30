local M = {}

M.cfg = {
  -- окно лога
  log = {
    height = 15,
    position = "botright",      -- "botright" | "topleft" | "belowright" и т.п.
    open_cmd = "split",         -- "split" (горизонтально) / "vsplit" (вертикально)
    bufname_prefix = "term://build:",
    q_close = true,             -- q закрывает только окно
    replace_mode = true,        -- true = пересоздаём буфер на каждый запуск (как у тебя сейчас)
  },

  -- состояние (persist build root)
  state = {
    enabled = true,
    file = nil,                 -- nil => stdpath("state").."/nvim_build_root.txt"
  },

  -- build config keys that are expected from .nvim-build.lua
  keys = {
    buildcfg = "buildcfg",      -- vim.g.buildcfg
    build_root = "nvim_build_root",
  },

  -- команды
  commands = {
    enabled = true,
    names = {
      pick_cwd = "PickCwdBuild",
      show_cwd = "ShowCwdBuild",
      clear_cwd = "ClearCwdBuild",
      build_target = "BuildTarget",
      build_log = "BuildLog",
      test_nearest = "TestNearest",
      test_file = "TestFile",
    },
  },
}

local function merge(a, b)
  return vim.tbl_deep_extend("force", a, b or {})
end

-- =========================================================
-- utils
-- =========================================================
local function find_repo_root()
  local buf = vim.api.nvim_buf_get_name(0)
  local start = (buf ~= "" and vim.fs.dirname(buf)) or vim.uv.cwd()
  local git = vim.fs.find(".git", { path = start, upward = true })[1]
  return git and vim.fs.dirname(git) or nil
end

local function normalize_subdir(s)
  s = s or ""
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  s = s:gsub("^/*", ""):gsub("/*$", "")
  return s
end

local function path_join(a, b)
  if not a or a == "" then return b end
  if not b or b == "" then return a end
  return (a:gsub("/+$", "") .. "/" .. b:gsub("^/+", ""))
end

local function shell_escape(s)
  return vim.fn.shellescape(s)
end

-- =========================================================
-- state
-- =========================================================
local function state_file()
  if M.cfg.state.file and M.cfg.state.file ~= "" then
    return M.cfg.state.file
  end
  return vim.fn.stdpath("state") .. "/nvim_build_root.txt"
end

local function state_load()
  if not M.cfg.state.enabled then return nil end
  local f = state_file()
  if vim.fn.filereadable(f) ~= 1 then return nil end
  local lines = vim.fn.readfile(f)
  local p = lines and lines[1] or nil
  if p and p ~= "" then return p end
  return nil
end

local function state_save(path)
  if not M.cfg.state.enabled then return end
  vim.fn.writefile({ path }, state_file())
end

local function state_clear()
  local f = state_file()
  if vim.fn.filereadable(f) == 1 then
    pcall(vim.fn.delete, f)
  end
end

-- =========================================================
-- globals helpers
-- =========================================================
local function set_build_root(root)
  vim.g[M.cfg.keys.build_root] = root
end

local function get_build_root()
  return vim.g[M.cfg.keys.build_root]
end

local function buildcfg()
  return vim.g[M.cfg.keys.buildcfg] or {}
end

-- =========================================================
-- load .nvim-build.lua
-- =========================================================
local function load_nvim_build(project_root, opts)
  opts = opts or {}
  local cfg_path = project_root .. "/.nvim-build.lua"

  set_build_root(project_root)
  vim.g.nvim_build_cfg = cfg_path

  if opts.persist ~= false then
    state_save(project_root)
  end

  if vim.fn.filereadable(cfg_path) ~= 1 then
    if opts.silent ~= true then
      vim.notify("Build CWD set to:\n" .. project_root .. "\n(no .nvim-build.lua found)", vim.log.levels.INFO)
    end
    return true
  end

  local ok, err = pcall(dofile, cfg_path)
  if not ok then
    vim.notify("Failed to load:\n" .. cfg_path .. "\n\n" .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  if opts.silent ~= true then
    vim.notify("Build CWD set to:\n" .. project_root, vim.log.levels.INFO)
  end
  return true
end

-- =========================================================
-- public: PickCwdBuild
-- =========================================================
function M.pick_cwd_build(subdir)
  local repo_root = find_repo_root()
  if not repo_root then
    vim.notify("Repo root (.git) not found", vim.log.levels.ERROR)
    return
  end

  local sub = normalize_subdir(subdir)
  if sub == "" then
    vim.notify("Usage: :PickCwdBuild <path_from_repo_root>\nExample: :PickCwdBuild StarOS", vim.log.levels.WARN)
    return
  end

  local project_root = repo_root .. "/" .. sub
  if vim.fn.isdirectory(project_root) ~= 1 then
    vim.notify("Directory not found:\n" .. project_root, vim.log.levels.ERROR)
    return
  end

  load_nvim_build(project_root, { persist = true, silent = false })
end

function M.show_cwd_build()
  local root = get_build_root()
  if root and root ~= "" then
    vim.notify("Build CWD:\n" .. root, vim.log.levels.INFO)
  else
    vim.notify("Build CWD is not set", vim.log.levels.WARN)
  end
end

function M.clear_cwd_build()
  state_clear()
  set_build_root(nil)
  vim.g.nvim_build_cfg = nil
  vim.notify("Build CWD cleared (state removed)", vim.log.levels.INFO)
end

function M.complete_pick_cwd_build(line)
  local repo_root = find_repo_root()
  if not repo_root then return {} end

  local arg = line:match("^%s*PickCwdBuild%s+(.*)$") or ""
  arg = normalize_subdir(arg)

  local base = repo_root
  local prefix = ""

  local slash = arg:match("^(.*)/[^/]*$")
  if slash then
    base = repo_root .. "/" .. slash
    prefix = slash .. "/"
  end

  if vim.fn.isdirectory(base) ~= 1 then return {} end

  local res = {}
  for name, t in vim.fs.dir(base) do
    if t == "directory" then
      table.insert(res, prefix .. name)
    end
  end
  table.sort(res)
  return res
end

-- =========================================================
-- init once
-- =========================================================
function M.init_once()
  if vim.g.__eros_build_tools_inited then return end
  vim.g.__eros_build_tools_inited = true

  local saved = state_load()
  if saved and saved ~= "" and vim.fn.isdirectory(saved) == 1 then
    load_nvim_build(saved, { persist = false, silent = true })
  end
end

-- =========================================================
-- log terminal
-- =========================================================
local function ensure_log_buf(title, recreate)
  local buf = vim.g._build_term_buf
  if recreate and buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    buf = nil
  end

  if buf and vim.api.nvim_buf_is_valid(buf) then
    if title and title ~= "" then
      pcall(vim.api.nvim_buf_set_name, buf, M.cfg.log.bufname_prefix .. title)
    end
    return buf
  end

  buf = vim.api.nvim_create_buf(false, true)
  vim.g._build_term_buf = buf

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "terminal"

  pcall(vim.api.nvim_buf_set_name, buf, M.cfg.log.bufname_prefix .. (title or "log"))
  return buf
end

local function open_log_window(title)
  local buf = ensure_log_buf(title, false)

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_set_current_win(win)
      return buf, win
    end
  end

  local cmd = ("%s %s | resize %d"):format(M.cfg.log.position, M.cfg.log.open_cmd, M.cfg.log.height)
  vim.cmd(cmd)

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  if M.cfg.log.q_close then
    vim.keymap.set("n", "q", function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, silent = true, nowait = true })
  end

  return buf, win
end

function M.show_build_log()
  open_log_window("log")
end

local function term_run(cmd, cwd, title)
  local recreate = M.cfg.log.replace_mode

  local old_win = nil
  local old_buf = vim.g._build_term_buf
  if old_buf and vim.api.nvim_buf_is_valid(old_buf) then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == old_buf then
        old_win = win
        break
      end
    end
  end

  local buf = ensure_log_buf(title, recreate)

  if old_win and vim.api.nvim_win_is_valid(old_win) then
    vim.api.nvim_win_set_buf(old_win, buf)
    vim.api.nvim_set_current_win(old_win)
  else
    open_log_window(title)
  end

  vim.api.nvim_set_current_buf(buf)
  vim.fn.termopen({ vim.o.shell, "-lc", cmd }, { cwd = cwd })
  vim.cmd("startinsert")
end

-- =========================================================
-- build target infer
-- =========================================================
local function get_build_dir_abs()
  local root = get_build_root()
  if not root or root == "" then return nil end
  local cfg = buildcfg()
  local rel = cfg.build_dir or ""
  return path_join(root, rel)
end

local function infer_target_from_build_ninja(src_abs)
  local build_dir = get_build_dir_abs()
  if not build_dir then
    return nil, "nvim_build_root is not set (run :PickCwdBuild ...)"
  end

  local ninja_path = path_join(build_dir, "build.ninja")
  if vim.fn.filereadable(ninja_path) ~= 1 then
    return nil, "build.ninja not found: " .. ninja_path
  end

  local root = get_build_root()
  local src_rel = src_abs
  if root and src_abs:sub(1, #root) == root then
    src_rel = src_abs:sub(#root + 2)
  end

  local function try_rg(needle)
    local cmd = ("rg -n --fixed-strings %s %s"):format(shell_escape(needle), shell_escape(ninja_path))
    local out = vim.fn.systemlist(cmd)
    if vim.v.shell_error == 0 and out and #out > 0 then
      return out[1]
    end
    return nil
  end

  local line = try_rg(src_rel) or try_rg(src_abs)
  if not line then
    return nil, "Source not found in build.ninja (maybe not configured/built yet)"
  end

  local target = line:match("CMakeFiles/([^/]+)%.dir/")
  if not target then
    return nil, "Failed to parse target from build.ninja line:\n" .. line
  end

  return target, nil
end

local function run_build_cmd(target)
  local root = get_build_root()
  if not root or root == "" then
    vim.notify("nvim_build_root is not set. Run :PickCwdBuild <dir>", vim.log.levels.ERROR)
    return
  end

  local cfg = buildcfg()
  local preset = cfg.preset or "user-conan-debug"
  local cmd = ("cmake --build --preset %s --target %s"):format(preset, target)

  term_run(cmd, root, "build:" .. target)
end

function M.build_target(opts)
  opts = opts or {}
  local explicit = opts.target

  if explicit and explicit ~= "" then
    run_build_cmd(explicit)
    return
  end

  local src = vim.api.nvim_buf_get_name(0)
  if not src or src == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end
  src = vim.fn.fnamemodify(src, ":p")

  local target, err = infer_target_from_build_ninja(src)
  if not target then
    vim.notify("Can't infer target.\n" .. err .. "\n\nUse :BuildTarget <target>", vim.log.levels.WARN)
    return
  end

  run_build_cmd(target)
end

-- =========================================================
-- gtest helpers (оставил как у тебя, только запускаем через term_run)
-- =========================================================
local function _trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function _parse_gtest_at_line(line)
  local macro, inside = line:match("^%s*(TEST[_%w]*)%s*%((.*)%)")
  if not macro or not inside then return nil end
  inside = inside:gsub("%)%s*%b{}", "")
  local a, b = inside:match("^%s*([^,]+)%s*,%s*([^,%)]+)")
  if not a or not b then return nil end
  a = _trim(a:gsub("[\"']", ""))
  b = _trim(b:gsub("[\"']", ""))
  if a == "" or b == "" then return nil end
  return a .. "." .. b
end

local function _nearest_gtest_name(bufnr, from_lnum)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, from_lnum, false)
  for i = #lines, 1, -1 do
    local name = _parse_gtest_at_line(lines[i])
    if name then return name end
  end
  return nil
end

local function _all_gtest_names_in_file(bufnr)
  local names = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, line in ipairs(lines) do
    local name = _parse_gtest_at_line(line)
    if name then table.insert(names, name) end
  end
  return names
end

local function _tests_dir_abs()
  local root = get_build_root()
  if not root or root == "" then return nil end
  local cfg = buildcfg()
  local rel = cfg.tests_dir or ""
  if rel == "" then return nil end
  return (root:gsub("/+$", "") .. "/" .. rel:gsub("^/+", ""))
end

local function _resolve_test_binary(target)
  local dir = _tests_dir_abs()
  if not dir then
    return nil, "vim.g.buildcfg.tests_dir is not set in .nvim-build.lua"
  end
  local bin = dir .. "/" .. target
  if vim.fn.filereadable(bin) ~= 1 then
    return nil, "Test binary not found:\n" .. bin
  end
  return bin, nil
end

local function _run_gtest(target, filter, title)
  local dir = _tests_dir_abs()
  if not dir then
    vim.notify("vim.g.buildcfg.tests_dir is not set in .nvim-build.lua", vim.log.levels.ERROR)
    return
  end

  local bin, err = _resolve_test_binary(target)
  if not bin then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local cmd = bin
  if filter and filter ~= "" then
    cmd = cmd .. " --gtest_filter=" .. vim.fn.shellescape(filter)
  end

  term_run(cmd, dir, title or ("test:" .. target))
end

function M.test_nearest()
  M.init_once()

  local src = vim.api.nvim_buf_get_name(0)
  if not src or src == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  local target, terr = infer_target_from_build_ninja(vim.fn.fnamemodify(src, ":p"))
  if not target then
    vim.notify("Can't infer target for this file.\n" .. terr .. "\n\nUse :BuildTarget <target> first or build once.", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local name = _nearest_gtest_name(bufnr, lnum)
  if not name then
    vim.notify("No TEST/TEST_F/TEST_P found above cursor", vim.log.levels.WARN)
    return
  end

  _run_gtest(target, name, "gtest:" .. name)
end

function M.test_file()
  M.init_once()

  local src = vim.api.nvim_buf_get_name(0)
  if not src or src == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  local target, terr = infer_target_from_build_ninja(vim.fn.fnamemodify(src, ":p"))
  if not target then
    vim.notify("Can't infer target for this file.\n" .. terr, vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local names = _all_gtest_names_in_file(bufnr)
  if #names == 0 then
    vim.notify("No TEST/TEST_F/TEST_P macros found in this file", vim.log.levels.WARN)
    return
  end

  _run_gtest(target, table.concat(names, ":"), "gtest:file")
end

-- =========================================================
-- setup + (опционально) регистрация команд
-- =========================================================
local function create_commands()
  local c = M.cfg.commands.names

  vim.api.nvim_create_user_command(c.pick_cwd, function(opts)
    M.pick_cwd_build(opts.args)
  end, {
    nargs = 1,
    complete = function(line) return M.complete_pick_cwd_build(line) end,
  })

  vim.api.nvim_create_user_command(c.show_cwd, function() M.show_cwd_build() end, {})
  vim.api.nvim_create_user_command(c.clear_cwd, function() M.clear_cwd_build() end, {})

  vim.api.nvim_create_user_command(c.build_log, function() M.show_build_log() end, {})

  vim.api.nvim_create_user_command(c.build_target, function(opts)
    M.build_target({ target = opts.args ~= "" and opts.args or nil })
  end, { nargs = "?" })

  vim.api.nvim_create_user_command(c.test_nearest, function() M.test_nearest() end, {})
  vim.api.nvim_create_user_command(c.test_file, function() M.test_file() end, {})
end

function M.setup(opts)
  M.cfg = merge(M.cfg, opts)

  -- restore saved cwd (тихо)
  M.init_once()

  if M.cfg.commands.enabled then
    create_commands()
  end

  return M
end

return M
