local lsp = require("core.lsp")

local M = {}

function M.setup(opts)
  vim.lsp.config("clangd", vim.tbl_deep_extend("force", {
    cmd = {
      "clangd",
      "--background-index",
      "--completion-style=detailed",
      "--header-insertion=never",
      "--function-arg-placeholders",
      "--fallback-style=LLVM",
      "--pch-storage=memory",
      "--limit-results=200",
      "--limit-references=200",
    },
    filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
    capabilities = lsp.capabilities,
    on_attach = lsp.on_attach,
  }, opts or {}))
end

return M
