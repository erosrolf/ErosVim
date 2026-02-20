local ok, gs = pcall(require, "gitsigns")
if not ok then return end

gs.setup({
  -- ВАЖНО: чтобы не конфликтовать с mini.diff и develop-layer
  signcolumn = false,
  numhl = false,
  linehl = false,
  word_diff = false,

  -- оставляем полезное
  current_line_blame = false,

  preview_config = {
    border = "rounded",
  },
})
