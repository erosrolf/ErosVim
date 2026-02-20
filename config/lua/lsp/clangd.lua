local M = {}

function M.setup(opts)
  vim.lsp.config("clangd", vim.tbl_deep_extend("force", {
    cmd = {
      "clangd",
      "--background-index",
      "--clang-tidy",
      "--completion-style=detailed",
      "--header-insertion=iwyu",
      "--header-insertion-decorators",
      "--function-arg-placeholders",
      "--fallback-style=LLVM",
    },

    -- если когда-то будут проблемы с root:
    -- root_markers = {
    --   ".git",
    --   "compile_commands.json",
    --   "compile_flags.txt",
    --   "CMakeLists.txt",
    -- },

  }, opts or {}))
end

return M
