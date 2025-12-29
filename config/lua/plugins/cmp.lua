local cmp = require("cmp")

cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ["<Tab>"] = cmp.mapping.confirm({ select = true }),
    ["<Down>"] = cmp.mapping.select_next_item(),
    ["<Up>"] = cmp.mapping.select_prev_item()
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp" },  -- подсказки от LSP
    { name = "buffer" },    -- слова из текущего файла
    { name = "path" }       -- пути к файлам
  }),
  experimental = {
    ghost_text = true,
  },
})

cmp.setup.cmdline(":", {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = "path" },
    { name = "cmdline" },
  },
})
