local lsp = require("core.lsp")

local M = {}

function M.setup()
  vim.lsp.config("jsonls", {
    root_dir = lsp.root_pattern(".git"),
    capabilities = lsp.capabilities,
    on_attach = lsp.on_attach,
  })
end

return M
