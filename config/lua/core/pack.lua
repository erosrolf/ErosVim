local M = {}

local function notify(msg, level)
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO)
  end)
end

local function safe_require(mod)
  local ok, err = pcall(require, mod)
  if not ok then
    notify(("Failed to load %s:\n%s"):format(mod, err), vim.log.levels.WARN)
  end
end

local function get_repo_root()
  local config_dir = vim.fn.stdpath("config")
  local out = vim.fn.systemlist({ "git", "-C", config_dir, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 or not out[1] then
    return nil
  end
  return out[1]
end

local function ensure_dir(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
end

function M.setup(plugins)
  -- 1) определить pack root
  local repo_root = get_repo_root()
  local pack_root

  if repo_root then
    pack_root = repo_root .. "/plugins_pack"
  else
    pack_root = vim.fn.fnamemodify(vim.fn.stdpath("config"), ":h") .. "/plugins_pack"
    notify("git repo root not found, using fallback path", vim.log.levels.WARN)
  end

  ensure_dir(pack_root .. "/pack/core/opt")
  vim.opt.packpath:prepend(pack_root)

  local function is_installed(name)
    return vim.fn.isdirectory(pack_root .. "/pack/core/opt/" .. name) == 1
  end

  -- 2) install/update
  local specs = {}
  for _, p in ipairs(plugins) do
    specs[#specs + 1] = { src = p.src, name = p.name }
  end

  vim.pack.add(specs, { confirm = false })

  -- 3) load configs if installed
  for _, p in ipairs(plugins) do
    if is_installed(p.name) and p.config then
      safe_require(p.config)
    end
  end
end

return M
