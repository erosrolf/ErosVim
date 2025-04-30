local ts = require("nvim-treesitter.configs")

ts.setup {
  ensure_installed = { "lua", "vim", "c", "cpp", "proto",  },
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
}
