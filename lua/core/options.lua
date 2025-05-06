vim.cmd("colorscheme dayfox")

vim.o.termguicolors = true
vim.o.lazyredraw = false
vim.o.ttyfast = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.swapfile = true
vim.opt.undofile = true

vim.o.winbar = "%{%v:lua.require'nvim-navic'.get_location()%}"
vim.g.silent_swap_clean = true

-- отступы
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.scrolloff = 5

local two_space_languages = { "lua", "json", "jsonc", "yaml", "html" }
vim.api.nvim_create_autocmd("FileType", {
  pattern = two_space_languages,
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
  end,
})

