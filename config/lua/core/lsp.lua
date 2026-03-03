local M = {}

vim.diagnostic.config({
  update_in_insert = false,
  severity_sort = true,
})

M.capabilities = vim.lsp.protocol.make_client_capabilities()
do
  local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
  if ok then
    M.capabilities = cmp_lsp.default_capabilities(M.capabilities)
  end
  M.capabilities.offsetEncoding = { "utf-16" }
end

function M.on_attach(client, bufnr)
  if vim.lsp.inlay_hint and client.supports_method("textDocument/inlayHint") then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end

  local ok, navic = pcall(require, "nvim-navic")
  if ok and client.server_capabilities and client.server_capabilities.documentSymbolProvider then
    navic.attach(client, bufnr)
  end
end

function M.root_pattern(...)
  local markers = { ... }
  return function(bufnr)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    if fname == "" then
      return vim.uv.cwd()
    end
    return vim.fs.root(fname, markers) or vim.uv.cwd()
  end
end

return M
