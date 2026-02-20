local lsp = require("core.lsp")

local M = {}

function M.setup()
  vim.lsp.config("lua_ls", {
    filetypes = { "lua" },
    root_dir = lsp.root_pattern(".luarc.json", ".luarc.jsonc", ".git"),

    settings = {
      Lua = {
        runtime = { version = "LuaJIT" },
        diagnostics = { globals = { "vim" } },
        workspace = {
          checkThirdParty = false,
          library = vim.api.nvim_get_runtime_file("", true),
        },
        telemetry = { enable = false },
      },
    },

    capabilities = lsp.capabilities,
    on_attach = lsp.on_attach,
  })
end

return M
