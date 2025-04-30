vim.g.mapleader = " "

local keymap = vim.keymap.set
keymap("n", "<leader>w", ":w<CR>")
keymap("n", "<leader>q", ":q<CR>")
