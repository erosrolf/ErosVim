require("gitsigns").setup({
  signs = {
    add          = { text = "█" },
    change       = { text = "█" },
    delete       = { text = "█" },
    topdelete    = { text = "█" },
    changedelete = { text = "█" },
    untracked    = { text = "█" },
  },
  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns

    local function map(mode, l, r, desc)
      vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
    end
  end,
})
