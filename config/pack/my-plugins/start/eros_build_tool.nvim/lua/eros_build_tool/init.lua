-- file: /Users/aiunikitin/erosrolf/ErosVim/config/pack/my-plugins/start/eros_build_tool.nvim/lua/eros_build_tool/init.lua

local M = {}

-- =========================================================
-- Configuration with defaults
-- =========================================================
M.cfg = {
  log = {
    height = 15,
    position = "botright",
    open_cmd = "split",
    bufname_prefix = "term://build:",
    q_close = true,
    replace_mode = true,
  },
  state = {
    enabled = true,
    file = nil,
  },
  keys = {
    buildcfg = "buildcfg",
    build_root = "nvim_build_root",
  },
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
      build_and_test_nearest = "BuildAndTestNearest",
      build_and_test_file = "BuildAndTestFile",
    },
  },
  debug = false,  -- по умолчанию выключено
}

-- =========================================================
-- Utils
-- =========================================================
local utils = {}

function utils.merge(a, b)
  return vim.tbl_deep_extend("force", a, b or {})
end

function utils.find_repo_root()
  local buf = vim.api.nvim_buf_get_name(0)
  local start = (buf ~= "" and vim.fs.dirname(buf)) or vim.uv.cwd()
  local git = vim.fs.find(".git", { path = start, upward = true })[1]
  return git and vim.fs.dirname(git) or nil
end

function utils.normalize_subdir(s)
  s = s or ""
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  s = s:gsub("^/*", ""):gsub("/*$", "")
  return s
end

function utils.path_join(a, b)
  if not a or a == "" then return b end
  if not b or b == "" then return a end
  return (a:gsub("/+$", "") .. "/" .. b:gsub("^/+", ""))
end

function utils.shell_escape(s)
  return vim.fn.shellescape(s)
end

function utils.trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Функция для поиска директории с .nvim-build.lua
function utils.find_build_root_dir(start_path)
  local function search_dir(path, depth)
    if depth > 2 then return nil end -- не глубже 2 уровней
    
    -- Проверяем текущую директорию
    if vim.fn.filereadable(path .. "/.nvim-build.lua") == 1 then
      return path
    end
    
    -- Проверяем поддиректории (кроме служебных)
    for name, type in vim.fs.dir(path) do
      if type == "directory" 
          and name ~= ".git" 
          and name ~= "build" 
          and name ~= "node_modules"
          and name ~= "Debug"
          and name ~= "Release"
          and name ~= "cmake-build-debug" then
        local subdir = path .. "/" .. name
        local result = search_dir(subdir, depth + 1)
        if result then return result end
      end
    end
    
    return nil
  end
  
  return search_dir(start_path, 0)
end

-- =========================================================
-- debug function
-- =========================================================
local function debug_log(msg, level)
  if not M.cfg.debug then return end
  level = level or vim.log.levels.DEBUG
  vim.schedule(function()
    vim.notify(msg, level)
  end)
end

-- =========================================================
-- State Management
-- =========================================================
local State = {}

function State:new()
  local state = {
    build_root = nil,
    build_cfg = nil,
  }
  setmetatable(state, self)
  self.__index = self
  return state
end

function State:get_file()
  if M.cfg.state.file and M.cfg.state.file ~= "" then
    return M.cfg.state.file
  end
  return vim.fn.stdpath("state") .. "/nvim_build_root.txt"
end

function State:load()
  if not M.cfg.state.enabled then return nil end
  local f = self:get_file()
  if vim.fn.filereadable(f) ~= 1 then return nil end
  local lines = vim.fn.readfile(f)
  local p = lines and lines[1] or nil
  if p and p ~= "" then return p end
  return nil
end

function State:save(path)
  if not M.cfg.state.enabled then return end
  vim.fn.writefile({ path }, self:get_file())
end

function State:clear()
  local f = self:get_file()
  if vim.fn.filereadable(f) == 1 then
    pcall(vim.fn.delete, f)
  end
end

-- =========================================================
-- Build Context
-- =========================================================
local BuildContext = {}

function BuildContext:new()
  local ctx = {
    root = nil,
    cfg = {},
    cfg_path = nil,
  }
  setmetatable(ctx, self)
  self.__index = self
  return ctx
end

function BuildContext:set_root(root)
  self.root = root
  vim.g[M.cfg.keys.build_root] = root
  return self
end

function BuildContext:get_root()
  return self.root or vim.g[M.cfg.keys.build_root]
end

function BuildContext:get_cfg()
  return vim.g[M.cfg.keys.buildcfg] or {}
end

function BuildContext:get_build_dir_abs()
  local root = self:get_root()
  if not root or root == "" then return nil end
  local cfg = self:get_cfg()
  local rel = cfg.build_dir or ""
  return utils.path_join(root, rel)
end

function BuildContext:get_tests_dir_abs()
  local root = self:get_root()
  if not root or root == "" then return nil end
  local cfg = self:get_cfg()
  local rel = cfg.tests_dir or ""
  if rel == "" then return nil end
  return utils.path_join(root, rel)
end

function BuildContext:load_from_project(project_root, opts)
  opts = opts or {}
  local cfg_path = project_root .. "/.nvim-build.lua"

  self:set_root(project_root)
  self.cfg_path = cfg_path
  vim.g.nvim_build_cfg = cfg_path

  if opts.persist ~= false then
    State:save(project_root)
  end

  if vim.fn.filereadable(cfg_path) ~= 1 then
    if opts.silent ~= true then
      debug_log("Build CWD set to:\n" .. project_root .. "\n(no .nvim-build.lua found)", vim.log.levels.INFO)
    end
    return true
  end

  local ok, err = pcall(dofile, cfg_path)
  if not ok then
    debug_log("Failed to load:\n" .. cfg_path .. "\n\n" .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  if opts.silent ~= true then
    debug_log("Build CWD set to:\n" .. project_root, vim.log.levels.INFO)
  end
  return true
end

-- Глобальный экземпляр контекста
local current_context = BuildContext:new()

-- =========================================================
-- Target Inference
-- =========================================================
local TargetInference = {}

function TargetInference:from_build_ninja(src_abs)
  local build_dir = current_context:get_build_dir_abs()
  if not build_dir then
    return nil, "nvim_build_root is not set (run :PickCwdBuild ...)"
  end

  build_dir = vim.fn.fnamemodify(build_dir, ":p")
  local ninja_path = utils.path_join(build_dir, "build.ninja")
  ninja_path = vim.fn.fnamemodify(ninja_path, ":p")
  
  debug_log("Looking for ninja at: " .. ninja_path)
  
  if vim.fn.filereadable(ninja_path) ~= 1 then
    return nil, "build.ninja not found: " .. ninja_path
  end

  local root = current_context:get_root()
  root = vim.fn.fnamemodify(root, ":p")
  src_abs = vim.fn.fnamemodify(src_abs, ":p")
  
  debug_log("Root: " .. root)
  debug_log("Source absolute: " .. src_abs)
  
  local src_rel = src_abs
  if root and src_abs:sub(1, #root) == root then
    src_rel = src_abs:sub(#root + 1)
    src_rel = src_rel:gsub("^/+", "")
    debug_log("Source relative: " .. src_rel)
  end

  local function try_rg(needle)
    local cmd = ("rg -n --fixed-strings %s %s"):format(utils.shell_escape(needle), utils.shell_escape(ninja_path))
    debug_log("Running rg: " .. cmd)
    local out = vim.fn.systemlist(cmd)
    if vim.v.shell_error == 0 and out and #out > 0 then
      debug_log("Found with rg: " .. out[1])
      return out[1]
    end
    return nil
  end

  local function try_grep(needle)
    local cmd = ("grep -n -F %s %s 2>/dev/null | head -1"):format(utils.shell_escape(needle), utils.shell_escape(ninja_path))
    local out = vim.fn.systemlist(cmd)
    if vim.v.shell_error == 0 and out and #out > 0 then
      debug_log("Found with grep: " .. out[1])
      return out[1]
    end
    return nil
  end

  local line = try_rg(src_rel) or try_rg(src_abs) or try_grep(src_rel) or try_grep(src_abs)
  if not line then
    return nil, "Source not found in build.ninja (maybe not configured/built yet)"
  end

  local target = line:match("CMakeFiles/([^/]+)%.dir/")
  if not target then
    return nil, "Failed to parse target from build.ninja line:\n" .. line
  end

  debug_log("Found target: " .. target)
  return target, nil
end

-- =========================================================
-- Test Parser
-- =========================================================
local TestParser = {}

function TestParser:_parse_gtest_at_line(line)
  local macro, inside = line:match("^%s*(TEST[_%w]*)%s*%((.*)%)")
  if not macro or not inside then return nil end
  inside = inside:gsub("%)%s*%b{}", "")
  local a, b = inside:match("^%s*([^,]+)%s*,%s*([^,%)]+)")
  if not a or not b then return nil end
  a = utils.trim(a:gsub("[\"']", ""))
  b = utils.trim(b:gsub("[\"']", ""))
  if a == "" or b == "" then return nil end
  return a .. "." .. b
end

function TestParser:nearest(bufnr, from_lnum)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, from_lnum, false)
  for i = #lines, 1, -1 do
    local name = self:_parse_gtest_at_line(lines[i])
    if name then return name end
  end
  return nil
end

function TestParser:all_in_file(bufnr)
  local names = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, line in ipairs(lines) do
    local name = self:_parse_gtest_at_line(line)
    if name then table.insert(names, name) end
  end
  return names
end

-- =========================================================
-- Terminal Manager
-- =========================================================
local TerminalManager = {
  current_buf = nil,
  current_job_id = nil,
  callbacks = {},
  auto_close_windows = {},
}

function TerminalManager:ensure_buf(title, recreate)
  if recreate and self.current_buf and vim.api.nvim_buf_is_valid(self.current_buf) then
    pcall(vim.api.nvim_buf_delete, self.current_buf, { force = true })
    self.current_buf = nil
  end

  if self.current_buf and vim.api.nvim_buf_is_valid(self.current_buf) then
    if title and title ~= "" then
      pcall(vim.api.nvim_buf_set_name, self.current_buf, M.cfg.log.bufname_prefix .. title)
    end
    return self.current_buf
  end

  local buf = vim.api.nvim_create_buf(false, true)
  self.current_buf = buf

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "terminal"

  pcall(vim.api.nvim_buf_set_name, buf, M.cfg.log.bufname_prefix .. (title or "log"))
  return buf
end

function TerminalManager:open_window(title)
  local buf = self:ensure_buf(title, false)

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

function TerminalManager:run(cmd, cwd, title, callback, opts)
  opts = opts or {}
  local recreate = M.cfg.log.replace_mode
  local auto_close_on_success = opts.auto_close_on_success or false

  local old_win = nil
  local old_buf = self.current_buf
  if old_buf and vim.api.nvim_buf_is_valid(old_buf) then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == old_buf then
        old_win = win
        break
      end
    end
  end

  local buf = self:ensure_buf(title, recreate)
  local win = nil

  if old_win and vim.api.nvim_win_is_valid(old_win) then
    vim.api.nvim_win_set_buf(old_win, buf)
    win = old_win
    vim.api.nvim_set_current_win(old_win)
  else
    win = self:open_window(title)
  end

  vim.api.nvim_set_current_buf(buf)
  
  self.callbacks[buf] = callback
  self.auto_close_windows[buf] = auto_close_on_success and win or nil
  
  self.current_job_id = vim.fn.termopen({ vim.o.shell, "-lc", cmd }, {
    cwd = cwd,
    on_exit = function(_, exit_code, _)
      local cb = self.callbacks[buf]
      if cb then
        cb(exit_code == 0)
        self.callbacks[buf] = nil
      end
      
      local close_win = self.auto_close_windows[buf]
      if close_win and exit_code == 0 and vim.api.nvim_win_is_valid(close_win) then
        vim.cmd("wincmd p")
        vim.api.nvim_win_close(close_win, true)
      end
      self.auto_close_windows[buf] = nil
    end
  })
  
  vim.cmd("startinsert")
end

local terminal = TerminalManager

-- =========================================================
-- Build Actions
-- =========================================================
local BuildActions = {}

function BuildActions:build_target(opts)
  opts = opts or {}
  local explicit = opts.target
  local callback = opts.callback

  if explicit and explicit ~= "" then
    self:_run_build_cmd(explicit, callback)
    return
  end

  local src = vim.api.nvim_buf_get_name(0)
  if not src or src == "" then
    debug_log("No file in current buffer", vim.log.levels.WARN)
    if callback then callback(false) end
    return
  end
  src = vim.fn.fnamemodify(src, ":p")

  local target, err = TargetInference:from_build_ninja(src)
  if not target then
    debug_log("Can't infer target.\n" .. err .. "\n\nUse :BuildTarget <target>", vim.log.levels.WARN)
    if callback then callback(false) end
    return
  end

  self._last_target = target
  self._last_source = src
  
  self:_run_build_cmd(target, callback)
end

function BuildActions:_run_build_cmd(target, callback)
  local root = current_context:get_root()
  if not root or root == "" then
    debug_log("nvim_build_root is not set. Run :PickCwdBuild <dir>", vim.log.levels.ERROR)
    if callback then callback(false) end
    return
  end

  local build_dir = current_context:get_build_dir_abs()
  if not build_dir or build_dir == "" then
    debug_log("build_dir is not set in .nvim-build.lua", vim.log.levels.ERROR)
    if callback then callback(false) end
    return
  end

  build_dir = vim.fn.fnamemodify(build_dir, ":p")

  if vim.fn.isdirectory(build_dir) ~= 1 then
    debug_log("Build directory not found:\n" .. build_dir, vim.log.levels.ERROR)
    if callback then callback(false) end
    return
  end

  local cmd = ("cmake --build %s --target %s")
    :format(vim.fn.shellescape(build_dir), vim.fn.shellescape(target))

  local is_composite = debug.getinfo(2, "f").func == M.build_and_test_file or
                       debug.getinfo(2, "f").func == M.build_and_test_nearest

  terminal:run(cmd, root, "build:" .. target, callback, {
    auto_close_on_success = is_composite
  })
end

-- =========================================================
-- Test Actions
-- =========================================================
local TestActions = {}

function TestActions:test_file_with_target(target, file_path)
  debug_log("TestActions:test_file_with_target() called with target: " .. target)
  
  local src = file_path or vim.api.nvim_buf_get_name(0)
  if not src or src == "" then
    debug_log("No file specified", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.fn.bufnr(src)
  if bufnr == -1 then
    debug_log("Buffer not found for file: " .. src, vim.log.levels.WARN)
    return
  end

  local names = TestParser:all_in_file(bufnr)
  debug_log("Found " .. #names .. " tests in file")
  
  if #names == 0 then
    debug_log("No TEST/TEST_F/TEST_P macros found in this file", vim.log.levels.WARN)
    return
  end

  self:_run_gtest(target, table.concat(names, ":"), "gtest:file")
end

function TestActions:_resolve_test_binary(target)
  local dir = current_context:get_tests_dir_abs()
  if not dir then
    return nil, "vim.g.buildcfg.tests_dir is not set in .nvim-build.lua"
  end
  local bin = dir .. "/" .. target
  if vim.fn.filereadable(bin) ~= 1 then
    return nil, "Test binary not found:\n" .. bin
  end
  return bin, nil
end

function TestActions:_run_gtest(target, filter, title)
  debug_log("_run_gtest: target=" .. target .. ", filter=" .. filter)
  
  local dir = current_context:get_tests_dir_abs()
  if not dir then
    debug_log("vim.g.buildcfg.tests_dir is not set in .nvim-build.lua", vim.log.levels.ERROR)
    return false
  end

  local bin, err = self:_resolve_test_binary(target)
  if not bin then
    debug_log(err, vim.log.levels.ERROR)
    return false
  end

  local cmd = bin
  if filter and filter ~= "" then
    cmd = cmd .. " --gtest_filter=" .. vim.fn.shellescape(filter)
  end
  
  debug_log("Running command: " .. cmd)
  debug_log("In directory: " .. dir)

  terminal:run(cmd, dir, title or ("test:" .. target))
  return true
end

function TestActions:test_nearest()
  local src = vim.api.nvim_buf_get_name(0)
  if not src or src == "" then
    debug_log("No file in current buffer", vim.log.levels.WARN)
    return
  end

  local target, terr = TargetInference:from_build_ninja(vim.fn.fnamemodify(src, ":p"))
  if not target then
    debug_log("Can't infer target for this file.\n" .. terr .. "\n\nUse :BuildTarget <target> first or build once.", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local name = TestParser:nearest(bufnr, lnum)
  if not name then
    debug_log("No TEST/TEST_F/TEST_P found above cursor", vim.log.levels.WARN)
    return
  end

  self:_run_gtest(target, name, "gtest:" .. name)
end

function TestActions:test_nearest_with_target(target, file_path, line)
  debug_log("TestActions:test_nearest_with_target() called with target: " .. target)
  
  local src = file_path or vim.api.nvim_buf_get_name(0)
  if not src or src == "" then
    debug_log("No file specified", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.fn.bufnr(src)
  if bufnr == -1 then
    debug_log("Buffer not found for file: " .. src, vim.log.levels.WARN)
    return
  end

  local lnum = line or vim.api.nvim_win_get_cursor(0)[1]
  local name = TestParser:nearest(bufnr, lnum)
  if not name then
    debug_log("No TEST/TEST_F/TEST_P found above cursor", vim.log.levels.WARN)
    return
  end

  self:_run_gtest(target, name, "gtest:" .. name)
end

function TestActions:test_file()
  debug_log("TestActions:test_file() called")
  
  local src = vim.api.nvim_buf_get_name(0)
  if not src or src == "" then
    debug_log("No file in current buffer", vim.log.levels.WARN)
    return
  end

  local target, terr = TargetInference:from_build_ninja(vim.fn.fnamemodify(src, ":p"))
  if not target then
    debug_log("Can't infer target for this file.\n" .. terr, vim.log.levels.WARN)
    return
  end
  
  debug_log("Target for tests: " .. target)

  local bufnr = vim.api.nvim_get_current_buf()
  local names = TestParser:all_in_file(bufnr)
  debug_log("Found " .. #names .. " tests in file")
  
  if #names == 0 then
    debug_log("No TEST/TEST_F/TEST_P macros found in this file", vim.log.levels.WARN)
    return
  end

  self:_run_gtest(target, table.concat(names, ":"), "gtest:file")
end

local test_actions = TestActions
local build_actions = BuildActions

-- =========================================================
-- Public API (Commands)
-- =========================================================

function M.pick_cwd_build(subdir)
  local repo_root = utils.find_repo_root()
  if not repo_root then
    debug_log("Repo root (.git) not found", vim.log.levels.ERROR)
    return
  end

  local sub = utils.normalize_subdir(subdir)
  if sub == "" then
    debug_log("Usage: :PickCwdBuild <path_from_repo_root>\nExample: :PickCwdBuild StarOS", vim.log.levels.WARN)
    return
  end

  local project_root = repo_root .. "/" .. sub
  if vim.fn.isdirectory(project_root) ~= 1 then
    debug_log("Directory not found:\n" .. project_root, vim.log.levels.ERROR)
    return
  end

  current_context:load_from_project(project_root, { persist = true, silent = false })
end

function M.show_cwd_build()
  local root = current_context:get_root()
  if root and root ~= "" then
    vim.notify("Build CWD:\n" .. root, vim.log.levels.INFO)
  else
    vim.notify("Build CWD is not set", vim.log.levels.WARN)
  end
end

function M.clear_cwd_build()
  State:clear()
  current_context:set_root(nil)
  vim.g.nvim_build_cfg = nil
  vim.notify("Build CWD cleared (state removed)", vim.log.levels.INFO)
end

function M.complete_pick_cwd_build(line)
  local repo_root = utils.find_repo_root()
  if not repo_root then return {} end

  local arg = line:match("^%s*PickCwdBuild%s+(.*)$") or ""
  arg = utils.normalize_subdir(arg)

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

function M.build_target(opts)
  build_actions:build_target(opts)
end

function M.show_build_log()
  terminal:open_window("log")
end

function M.test_nearest()
  test_actions:test_nearest()
end

function M.test_file()
  test_actions:test_file()
end

function M.build_and_test_nearest()
  debug_log("Starting BuildAndTestNearest")
  
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  local current_win = vim.api.nvim_get_current_win()
  
  build_actions:build_target({
    callback = function(success)
      if success then
        if vim.api.nvim_win_is_valid(current_win) then
          vim.api.nvim_set_current_win(current_win)
        end
        
        debug_log("Build successful, starting tests...")
        local target = build_actions._last_target
        if target then
          test_actions:test_nearest_with_target(target, current_file, current_line)
        else
          test_actions:test_nearest()
        end
      else
        vim.notify("Build failed, tests cancelled", vim.log.levels.ERROR)
      end
    end
  })
end

function M.build_and_test_file()
  debug_log("Starting BuildAndTestFile")
  
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_win = vim.api.nvim_get_current_win()
  
  build_actions:build_target({
    callback = function(success)
      if success then
        if vim.api.nvim_win_is_valid(current_win) then
          vim.api.nvim_set_current_win(current_win)
        end
        
        debug_log("Build successful, starting tests...")
        local target = build_actions._last_target
        if target then
          test_actions:test_file_with_target(target, current_file)
        else
          test_actions:test_file()
        end
      else
        vim.notify("Build failed, tests cancelled", vim.log.levels.ERROR)
      end
    end
  })
end

-- =========================================================
-- Auto-switch context
-- =========================================================
function M.auto_switch_context()
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == "" then return end
  
  local file_repo = utils.find_repo_root()
  if not file_repo then return end
  
  local current_root = current_context:get_root()
  
  if current_root ~= file_repo then
    local build_root = utils.find_build_root_dir(file_repo)
    
    if build_root and vim.fn.filereadable(build_root .. "/.nvim-build.lua") == 1 then
      vim.notify("Auto-switching build context to: " .. build_root, vim.log.levels.INFO)
      current_context:load_from_project(build_root, { persist = true, silent = true })
    end
  end
end

-- =========================================================
-- Initialization
-- =========================================================
function M.init_once()
  if vim.g.__eros_build_tools_inited then return end
  vim.g.__eros_build_tools_inited = true

  local saved = State:load()
  if saved and saved ~= "" and vim.fn.isdirectory(saved) == 1 then
    if vim.fn.filereadable(saved .. "/.nvim-build.lua") == 1 then
      current_context:load_from_project(saved, { persist = false, silent = true })
    else
      State:clear()
    end
  end
  
  if not current_context:get_root() then
    local current_file = vim.api.nvim_buf_get_name(0)
    if current_file ~= "" then
      local file_repo = utils.find_repo_root()
      if file_repo then
        local build_root = utils.find_build_root_dir(file_repo)
        if build_root and vim.fn.filereadable(build_root .. "/.nvim-build.lua") == 1 then
          vim.notify("Auto-detected build context: " .. build_root, vim.log.levels.INFO)
          current_context:load_from_project(build_root, { persist = true, silent = true })
        end
      end
    end
  end
end

-- =========================================================
-- Command registration
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

  vim.api.nvim_create_user_command(c.build_and_test_nearest, function() M.build_and_test_nearest() end, {})
  vim.api.nvim_create_user_command(c.build_and_test_file, function() M.build_and_test_file() end, {})

  vim.api.nvim_create_user_command("DebugBuildContext", function() M.debug_context() end, {})
  vim.api.nvim_create_user_command("DebugState", function() M.debug_state() end, {})
  vim.api.nvim_create_user_command("DebugTestBinary", function() M.debug_test_binary() end, {})
  vim.api.nvim_create_user_command("FindBuildRoot", function() M.find_build_root() end, {})
end

function M.setup(opts)
  M.cfg = utils.merge(M.cfg, opts)

  M.init_once()

  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function()
      M.auto_switch_context()
    end,
    desc = "Auto-switch build context based on current file"
  })

  if M.cfg.commands.enabled then
    create_commands()
  end

  return M
end

-- =========================================================
-- Debug functions
-- =========================================================
function M.debug_context()
  local root = current_context:get_root()
  local build_dir = current_context:get_build_dir_abs()
  local cfg = current_context:get_cfg()
  
  print("=== CONTEXT ===")
  print("Root:", root or "nil")
  print("Build dir:", build_dir or "nil")
  print("Config:", vim.inspect(cfg))
  print("vim.g.nvim_build_root:", vim.inspect(vim.g.nvim_build_root))
  print("vim.g.buildcfg:", vim.inspect(vim.g.buildcfg))
end

function M.debug_state()
  print("=== GLOBALS ===")
  print("vim.g.nvim_build_root:", vim.inspect(vim.g.nvim_build_root))
  print("vim.g.buildcfg:", vim.inspect(vim.g.buildcfg))
  
  print("=== CONTEXT ===")
  print("current_context.root:", vim.inspect(current_context.root))
  
  print("=== STATE FILE ===")
  local state_file = State:get_file()
  print("State file path:", state_file)
  
  if vim.fn.filereadable(state_file) == 1 then
    local lines = vim.fn.readfile(state_file)
    print("State file content:", lines[1])
  else
    print("State file does not exist")
  end
  
  print("=== REPO ROOT ===")
  local repo_root = utils.find_repo_root()
  print("Current file repo root:", repo_root or "nil")
end

function M.debug_test_binary()
  local src = vim.api.nvim_buf_get_name(0)
  if not src or src == "" then
    vim.notify("No file in current buffer", vim.log.levels.ERROR)
    return
  end
  
  local target, err = TargetInference:from_build_ninja(vim.fn.fnamemodify(src, ":p"))
  if not target then
    vim.notify("Can't infer target: " .. err, vim.log.levels.ERROR)
    return
  end
  
  print("Target:", target)
  
  local tests_dir = current_context:get_tests_dir_abs()
  print("Tests dir:", tests_dir or "nil")
  
  if tests_dir then
    local binary = tests_dir .. "/" .. target
    print("Expected binary:", binary)
    print("Binary exists:", vim.fn.filereadable(binary) == 1)
  end
end

function M.find_build_root()
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == "" then
    vim.notify("No file in current buffer", vim.log.levels.ERROR)
    return
  end
  
  local file_repo = utils.find_repo_root()
  if not file_repo then
    vim.notify("No git repository found", vim.log.levels.ERROR)
    return
  end
  
  local build_root = utils.find_build_root_dir(file_repo)
  if build_root then
    vim.notify("Found build root: " .. build_root, vim.log.levels.INFO)
    vim.notify("Config file: " .. build_root .. "/.nvim-build.lua", vim.log.levels.INFO)
  else
    vim.notify("No .nvim-build.lua found in " .. file_repo .. " or its subdirectories", vim.log.levels.WARN)
  end
end

return M
