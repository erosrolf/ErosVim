local M = {}

local capabilities = vim.lsp.protocol.make_client_capabilities()

local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if ok_cmp then
  capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
end

vim.diagnostic.config({
  severity_sort = true,
  float = {
    border = "rounded",
    source = "always",
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  virtual_text = false,
})

local function on_attach(client, bufnr)
  pcall(function()
    vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
  end)
end

M.capabilities = capabilities
M.on_attach = on_attach

return M
