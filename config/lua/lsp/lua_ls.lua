local lsp = require("core.lsp")

local M = {}

function M.setup(opts)
  vim.lsp.config("lua_ls", vim.tbl_deep_extend("force", {
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    capabilities = lsp.capabilities,
    on_attach = lsp.on_attach,
    settings = {
      Lua = {
        runtime = {
          version = "LuaJIT",
        },
        diagnostics = {
          globals = { "vim" },
        },
        workspace = {
          checkThirdParty = false,
          library = vim.api.nvim_get_runtime_file("", true),
        },
        telemetry = {
          enable = false,
        },
        codeLens = {
          enable = true,
        },
        hint = {
          enable = true,
          semicolon = "Disable",
        },
      },
    },
  }, opts or {}))
end

return M
