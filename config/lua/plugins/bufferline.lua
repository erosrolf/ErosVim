require("bufferline").setup({
  options = {
    mode = "buffers",
    diagnostics = "nvim_lsp",
    separator_style = "slant", -- или "thin"
    show_buffer_close_icons = false,
    show_close_icon = false,
    always_show_bufferline = true,
  }
})

