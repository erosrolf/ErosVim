-- core/functions.lua
-- Central loader, similar to core/plugins.lua
-- Loads modules from lua/functions/*.lua and merges exports into one table M.

local M = {}

local function merge(dst, src)
  for k, v in pairs(src) do
    if k ~= "setup" then
      dst[k] = v
    end
  end
end

local modules = {
  "functions.ui",
  "functions.format",
  "functions.git",
  "functions.build",
  "functions.open_in_finder",
}

local did_setup = vim.g.__core_functions_setups_done
if not did_setup then
  vim.g.__core_functions_setups_done = true
end

for _, name in ipairs(modules) do
  local ok, mod = pcall(require, name)
  if ok and type(mod) == "table" then
    merge(M, mod)

    if not did_setup and type(mod.setup) == "function" then
      pcall(mod.setup)
    end
  else
    vim.notify(("Failed to load %s"):format(name), vim.log.levels.WARN)
  end
end

return M
