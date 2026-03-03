vim.o.termguicolors = true
vim.o.lazyredraw = false
vim.o.ttyfast = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.swapfile = false
vim.opt.undofile = true

-- colorscheme
vim.cmd.colorscheme("eros-light")

vim.g.silent_swap_clean = true

-- отключаем q:
vim.keymap.set("n", "q:", "<nop>")
vim.keymap.set("n", "q/", "<nop>")
vim.keymap.set("n", "q?", "<nop>")

-- отступы
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.scrolloff = 5
vim.opt.signcolumn = "yes:1"

vim.api.nvim_set_hl(0, "GitHunksOutlinePreview", { link = "Visual" })

-- поиск grep
vim.o.grepprg = "rg --vimgrep --smart-case"
vim.o.grepformat = "%f:%l:%c:%m"

local two_space_languages = { "lua", "yaml", "html" }
local four_space_languages = { "json", "jsonc" }

vim.api.nvim_create_autocmd("FileType", {
  pattern = two_space_languages,
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = four_space_languages,
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.expandtab = true
  end,
})

vim.api.nvim_create_user_command(
  "CopyFileWithPath",
  function()
    require("core.functions").copy_file_path_and_content()
  end,
  {}
)
