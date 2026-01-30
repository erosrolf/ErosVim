require("plugins.treesitter")
require("plugins.comment")
require("plugins.lsp")
require("plugins.lsp_signature")
require("plugins.illuminate")
require("plugins.cmp")
require("plugins.nvim-navic")

-- aerial
require("plugins.aerial")

-- mini
require("plugins.mini_icons")
require("plugins.mini_files")
require("plugins.mini_pick")
require("plugins.mini_extra")

-- ui
require("plugins.ui")
require("plugins.bufferline")
require("plugins.winbar")

-- colorscheme
vim.cmd.colorscheme("eros-light")

-- git
require("plugins.gitsigns")
require("plugins.diffview")
require("plugins.blame")

require("plugins.git_ranges_jump").setup({
  develop_ref = "develop",
  keymaps = { next = "]d", prev = "[d" },
  enable = { red = true, green = true, orange = true },
})

-- custom
require("plugins.eros_build_tool")
