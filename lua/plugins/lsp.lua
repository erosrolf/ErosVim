local lspconfig = require("lspconfig")

lspconfig.clangd.setup({
  cmd = { "clangd" },
  root_dir = lspconfig.util.root_pattern("complete_commangs.json", ".git"),
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
})
