local lspconfig = require("lspconfig")
local navic = require("nvim-navic")
local capabilities = require("cmp_nvim_lsp").default_capabilities()
local fn = require("core.functions")

local on_attach = function(client, bufnr)
  -- breadcrumbs
  if client.server_capabilities.documentSymbolProvider then
    navic.attach(client, bufnr)
  end

  -- format on save
  if client.server_capabilities.documentFormattingProvider then
    vim.api.nvim_create_autocmd("BufWritePre", {
      buffer = bufnr,
      callback = function()
        -- JSON: enforce project hook style via jq (sorted keys + indent 4)
        if vim.bo[bufnr].filetype == "json" then
          fn.format_json_like_hook(bufnr)
          return
        end

        -- Other filetypes: format via THIS LSP client only
        vim.lsp.buf.format({
          async = false,
          filter = function(c)
            return c.id == client.id
          end,
        })
      end,
    })
  end
end

lspconfig.clangd.setup({
  cmd = { "clangd", "--clang-tidy" },
  root_dir = lspconfig.util.root_pattern("compile_commands.json", ".git"),
  capabilities = capabilities,
  on_attach = on_attach,
})

lspconfig.jsonls.setup({
  capabilities = capabilities,
  on_attach = on_attach,
})
