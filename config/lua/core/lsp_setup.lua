-- конфиги серверов
require("lsp.clangd").setup()
require("lsp.lua_ls").setup()
require("lsp.jsonls").setup()
require("lsp.buf_ls").setup()

vim.lsp.enable({
  "clangd",
  "lua_ls",
  "jsonls",
  "buf_ls",
})
