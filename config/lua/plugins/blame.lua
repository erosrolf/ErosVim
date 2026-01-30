require("blame").setup({
  enabled = false,        -- включаем только через toggle
  date_format = "%d.%m.%Y",
  virtual_style = "left", -- blame слева от кода
  merge_consecutive = true,
  max_summary_width = 30,
  highlight_group = "Comment",
})
