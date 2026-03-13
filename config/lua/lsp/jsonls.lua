local lsp = require("core.lsp")

local M = {}

function M.setup(opts)
  vim.lsp.config("jsonls", vim.tbl_deep_extend("force", {
    cmd = { "vscode-json-language-server", "--stdio" },
    filetypes = { "json", "jsonc" },
    init_options = {
      provideFormatter = true,
    },
    capabilities = lsp.capabilities,
    on_attach = lsp.on_attach,
  }, opts or {}))
end

return M
