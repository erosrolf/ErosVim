vim.opt.runtimepath:append(vim.fn.stdpath("config") .. "/pack/my-plugins/start")

require("core.options")
require("core.keymaps")
require("core.plugins")
