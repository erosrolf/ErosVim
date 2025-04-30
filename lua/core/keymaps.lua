vim.g.mapleader = " "

local keymap = vim.keymap.set
local builtin = require("telescope.builtin")

keymap("n", "<leader>w", ":w<CR>")
keymap("n", "<leader>q", ":q<CR>")

keymap("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
keymap("n", "<leader>fw", builtin.live_grep, { desc = "Live grep" })
keymap("n", "<leader>fb", builtin.current_buffer_fuzzy_find, { desc = "Fuzzy find in buffer" })

