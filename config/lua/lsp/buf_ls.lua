local lsp = require("core.lsp")

local M = {}

function M.setup(opts)
  vim.lsp.config("buf_ls", vim.tbl_deep_extend("force", {
    cmd = { "buf", "lsp", "serve" },
    filetypes = { "proto" },
    capabilities = lsp.capabilities,
    on_attach = function(client, bufnr)
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
      lsp.on_attach(client, bufnr)
    end,
  }, opts or {}))
end

return M
