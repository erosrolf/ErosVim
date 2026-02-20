local M = {}

M.capabilities = vim.lsp.protocol.make_client_capabilities()
do
  local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
  if ok then
    M.capabilities = cmp_lsp.default_capabilities(M.capabilities)
  end
  -- полезно для clangd, но не мешает и другим
  M.capabilities.offsetEncoding = { "utf-16" }
end

function M.on_attach(client, bufnr)
  if vim.lsp.inlay_hint and client.supports_method("textDocument/inlayHint") then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end
end

-- Аналог lspconfig.util.root_pattern(...)
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
