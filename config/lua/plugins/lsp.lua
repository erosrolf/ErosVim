local lspconfig = require("lspconfig")
local util = require("lspconfig.util")
local navic = require("nvim-navic")
local capabilities = require("cmp_nvim_lsp").default_capabilities()
local fn = require("core.functions")

local augroup = vim.api.nvim_create_augroup("LspFormatOnSave", { clear = false })

local on_attach = function(client, bufnr)
  if client.server_capabilities.documentSymbolProvider then
    navic.attach(client, bufnr)
  end

  if client.server_capabilities.documentFormattingProvider then
    vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })

    vim.api.nvim_create_autocmd("BufWritePre", {
      group = augroup,
      buffer = bufnr,
      callback = function()
        if vim.bo[bufnr].filetype == "json" then
          fn.format_json_like_hook(bufnr)
          return
        end

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
  root_dir = util.root_pattern(".git"),
  capabilities = capabilities,
  on_attach = on_attach,

  on_new_config = function(new_config, _root_dir)
    local cc_path = fn.get_clangd_compile_commands_path()
    if not cc_path or cc_path == "" then
      return
    end

    local cc_dir = vim.fn.fnamemodify(cc_path, ":h")

    if type(new_config.cmd) == "string" then
      new_config.cmd = { new_config.cmd }
    end
    new_config.cmd = new_config.cmd or { "clangd", "--clang-tidy" }

    local filtered = {}
    for _, a in ipairs(new_config.cmd) do
      if type(a) == "string" and not a:match("^%-%-compile%-commands%-dir=") then
        table.insert(filtered, a)
      end
    end

    table.insert(filtered, "--compile-commands-dir=" .. cc_dir)
    new_config.cmd = filtered
  end,
})

lspconfig.jsonls.setup({
  capabilities = capabilities,
  on_attach = on_attach,
})
