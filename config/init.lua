-- Ensure "pack/*/start/*" plugins are loaded
vim.cmd("packloadall")
vim.cmd("packadd nvim-treesitter")
vim.cmd("silent! helptags ALL")

require("core.options")
require("core.plugins")
require("core.keymaps")
require("core.autocmds")
require("core.functions")
require("core.formatter")
