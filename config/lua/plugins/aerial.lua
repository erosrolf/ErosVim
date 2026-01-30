require("aerial").setup({
  -- Источник символов: сначала LSP, потом treesitter
  backends = { "lsp", "treesitter" },

  -- Показывать только значимые символы
  filter_kind = {
    "Class",
    "Constructor",
    "Enum",
    "Function",
    "Interface",
    "Method",
    "Namespace",
    "Struct",
  },

  -- Расположение окна
  layout = {
    min_width = 40,
    max_width = 60,
    default_direction = "right",
  },

  -- Поведение
  close_automatic_events = { "unsupported" },
  highlight_on_hover = true,
  show_guides = true,
  autojump = true,
})
