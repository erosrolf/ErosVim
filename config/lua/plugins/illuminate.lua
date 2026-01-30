local ok, illuminate = pcall(require, "illuminate")
if not ok then return end

illuminate.configure({
  -- задержка перед подсветкой (меньше = быстрее/агрессивнее)
  delay = 10,

  -- какие источники использовать (обычно лучший порядок)
  providers = { "lsp", "treesitter", "regex" },

  -- подсвечивать слово под курсором
  under_cursor = true,

  -- не включать на очень больших файлах
  large_file_cutoff = 5000,
  large_file_overrides = nil,

  -- где не нужно
  filetypes_denylist = {
    "NvimTree",
    "TelescopePrompt",
    "DiffviewFiles",
    "DiffviewFileHistory",
    "help",
    "alpha",
    "dashboard",
  },
})

-- Сделаем подсветку в стиле LSP (если цвета уже настроены темой)
vim.api.nvim_set_hl(0, "IlluminatedWordText",  { link = "LspReferenceText" })
vim.api.nvim_set_hl(0, "IlluminatedWordRead",  { link = "LspReferenceRead" })
vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { link = "LspReferenceWrite" })
