require("plugins.treesitter")
require("plugins.comment")
require("plugins.lsp")
require("plugins.lsp_signature")
require("plugins.cmp")
require("plugins.nvim-navic")
require("plugins.gitsigns")
require("plugins.trouble")

-- telescope
require("plugins.telescope")

-- notes and aerial
require("plugins.aerial")
require("plugins.notes").setup({
  -- при желании можно изменить корень для заметок
  notes_root = "~/obsidian/notes",
})

-- tests
require("plugins.neotest")
require("plugins.neotest-gtest")

-- ui
require("plugins.ui")
require("plugins.miniicons")
require("plugins.bufferline")
require("plugins.mini_files")
require("plugins.neo-tree")
require("plugins.lualine")
require("plugins.alpha")

-- colorschemes
require("plugins.catpuccin")
require("plugins.github-nvim-theme")
