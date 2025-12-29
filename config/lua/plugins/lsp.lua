local lspconfig = require("lspconfig")
local navic = require("nvim-navic")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

local on_attach = function(client, bufnr)
  -- Навигация по символам
  if client.server_capabilities.documentSymbolProvider then
    navic.attach(client, bufnr)
  end

  -- Форматирование при сохранении
  if client.server_capabilities.documentFormattingProvider then
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = function()
        vim.lsp.buf.format({ async = false })
      end,
    })
  end
end

lspconfig.clangd.setup({
  cmd = { "clangd", "--clang-tidy" }, -- добавим поддержку clang-tidy
  root_dir = lspconfig.util.root_pattern("compile_commands.json", ".git"),
  capabilities = capabilities,
  on_attach = on_attach,
})
