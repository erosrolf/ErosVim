-- ВАЖНО:
-- nvim-lspconfig предоставляет дефолтные конфиги в lsp/*.lua
-- Neovim (0.11+) автоматически подхватывает:
-- 1) дефолтные конфиги из nvim-lspconfig
-- 2) локальные override-конфиги из lua/lsp/*.lua

-- ключаем сервера.
vim.lsp.enable({
  "clangd",
  "jsonls",
  "buf_ls",
})
