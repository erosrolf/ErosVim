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

for _, name in ipairs(modules) do
  local ok, mod = pcall(require, name)
  if ok and type(mod) == "table" then
    merge(M, mod)
  else
    -- не спамим, но оставим след если что-то не загрузилось
    vim.notify(("Failed to load %s"):format(name), vim.log.levels.WARN)
  end
end

-- Define user commands once (modules may provide setup())
if not vim.g.__core_functions_cmds_defined then
  vim.g.__core_functions_cmds_defined = true
  for _, name in ipairs(modules) do
    local ok, mod = pcall(require, name)
    if ok and type(mod) == "table" and type(mod.setup) == "function" then
      pcall(mod.setup)
    end
  end
end

return M
