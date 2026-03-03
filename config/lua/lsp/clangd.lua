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

      -- perf
      "--pch-storage=memory",
      "--limit-results=200",
      "--limit-references=200",
    }

  }, opts or {}))
end

return M
