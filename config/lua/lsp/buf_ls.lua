local lsp = require("core.lsp")

local M = {}

function M.setup()
  vim.lsp.config("buf_ls", {
    cmd = { "buf", "lsp", "serve" },
    filetypes = { "proto" },
    root_dir = lsp.root_pattern("buf.work.yaml", "buf.yaml", ".git"),
    capabilities = lsp.capabilities,

    on_attach = function(client, bufnr)
      -- disable formatting from buf_ls
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
      lsp.on_attach(client, bufnr)
    end,
  })
end

return M
