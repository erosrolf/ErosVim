local navic = require("nvim-navic")
local functions = require("core.functions")
local formatter = require("core.formatter")

-- capabilities (cmp)
local capabilities = vim.lsp.protocol.make_client_capabilities()
do
  local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
  if ok_cmp then
    capabilities = cmp_lsp.default_capabilities(capabilities)
  end
end

local fallbackFlagsList = {
  "-std=c++11",
  "-Wno-unknown-attributes",
  "-Wno-attributes",
  "-Wno-error=unknown-attributes",
  "-Wno-error=attributes",
  "-DLOCKS_EXCLUDED=",
  "-DABSL_LOCKS_EXCLUDED=",
  "-DABSL_LEGACY_THREAD_ANNOTATIONS",
  "-D_LIBCPP_ENABLE_THREAD_SAFETY_ANNOTATIONS",
}

local augroup = vim.api.nvim_create_augroup("LspFormatOnSave", { clear = false })

local function on_attach(client, bufnr)
  -- winbar breadcrumbs
  if (client.name == "clangd" or client.name == "jsonls")
      and client.server_capabilities
      and client.server_capabilities.documentSymbolProvider
  then
    navic.attach(client, bufnr)
  end

  -- format on save
  if client.server_capabilities and client.server_capabilities.documentFormattingProvider then
    vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = augroup,
      buffer = bufnr,
      callback = function()
        formatter.format_buffer_on_save(bufnr, client)
      end,
    })
  end
end

-- root helpers (replacement for lspconfig.util.root_pattern)
local function root_pattern(...)
  local markers = { ... }
  return function(bufname)
    local start = (bufname and bufname ~= "") and vim.fs.dirname(bufname) or vim.loop.cwd()
    local found = vim.fs.find(markers, { path = start, upward = true })[1]
    return found and vim.fs.dirname(found) or nil
  end
end

local function ensure_list_cmd(cmd)
  if type(cmd) == "string" then
    return { cmd }
  end
  return cmd
end

local function add_compile_commands_dir(cmd, cc_dir)
  cmd = ensure_list_cmd(cmd or {})
  local filtered = {}
  for _, a in ipairs(cmd) do
    if type(a) == "string" and not a:match("^%-%-compile%-commands%-dir=") then
      table.insert(filtered, a)
    end
  end
  if #filtered == 0 then
    filtered = {
      "clangd",
      "--background-index",
      "--header-insertion=never",
      "--completion-style=detailed",
    }
  end
  table.insert(filtered, "--compile-commands-dir=" .. cc_dir)
  return filtered
end

-- small wrapper
local function cfg(server, opts)
  opts = opts or {}
  opts.capabilities = opts.capabilities or capabilities
  opts.on_attach = opts.on_attach or on_attach

  vim.lsp.config(server, opts)
  vim.lsp.enable(server)
end

-- clangd
cfg("clangd", {
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "cc", "h" },
  cmd = {
    "clangd",
    "--background-index",
    "--header-insertion=never",
    "--completion-style=detailed",
  },
  root_dir = root_pattern(".git"),
  init_options = {
    fallbackFlags = fallbackFlagsList,
  },

  -- equivalent of on_new_config
  on_init = function(client)
    -- compute compile_commands dir once on init
    local cc_path = functions.get_clangd_compile_commands_path()
    if not cc_path or cc_path == "" then
      return
    end
    local cc_dir = vim.fn.fnamemodify(cc_path, ":h")

    -- update client config cmd
    local c = client.config
    c.cmd = add_compile_commands_dir(c.cmd, cc_dir)

    -- keep fallbackFlags
    c.init_options = c.init_options or {}
    c.init_options.fallbackFlags = fallbackFlagsList
  end,
})

-- jsonls
cfg("jsonls", {
  root_dir = root_pattern(".git"),
})

-- buf_ls (proto)
cfg("buf_ls", {
  cmd = { "buf", "lsp", "serve" },
  filetypes = { "proto" },
  root_dir = root_pattern("buf.work.yaml", "buf.yaml", ".git"),
  on_attach = function(client, bufnr)
    -- disable formatting from buf_ls
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
    on_attach(client, bufnr)
  end,
})
