local lspconfig = require("lspconfig")
local util = require("lspconfig.util")
local navic = require("nvim-navic")
local capabilities = require("cmp_nvim_lsp").default_capabilities()
local functions = require("core.functions")
local formatter = require("core.formatter")

local fallbackFlagsList = {
  "-std=c++11", -- лучше совпадать с тем, что реально в compile_commands (у тебя c++11)
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

local on_attach = function(client, bufnr)
  -- winbar breadcrumbs: attach only once, only for selected servers
  if (client.name == "clangd" or client.name == "jsonls")
      and client.server_capabilities.documentSymbolProvider then
    navic.attach(client, bufnr)
  end

  -- format on save (только если сервер поддерживает)
  if client.server_capabilities.documentFormattingProvider then
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

lspconfig.clangd.setup({

  filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "cc", "h" },
  -- ВАЖНО:
  -- 1) Не используем --extra-arg (Apple clangd их не знает)
  -- 2) Не используем --clang-tidy=false (такого флага нет). Просто не включаем clang-tidy.
  cmd = {
    "clangd",
    "--background-index",
    "--header-insertion=never",
    "--completion-style=detailed",
    -- Можно добавить логирование clangd при отладке:
    -- "--log=verbose",
  },

  root_dir = util.root_pattern(".git"),
  capabilities = capabilities,
  on_attach = on_attach,

  init_options = {
    fallbackFlags = fallbackFlagsList,
  },

  -- Подмешиваем compile_commands-dir, но НЕ ломаем cmd.
  on_new_config = function(new_config, _root_dir)
    local cc_path = functions.get_clangd_compile_commands_path()
    if not cc_path or cc_path == "" then
      return
    end

    local cc_dir = vim.functions.fnamemodify(cc_path, ":h")

    -- clangd setup мог дать cmd строкой (редко, но бывает) — нормализуем
    if type(new_config.cmd) == "string" then
      new_config.cmd = { new_config.cmd }
    end

    -- Убираем старые --compile-commands-dir=..., чтобы не копились
    local filtered = {}
    for _, a in ipairs(new_config.cmd or {}) do
      if type(a) == "string" and not a:match("^%-%-compile%-commands%-dir=") then
        table.insert(filtered, a)
      end
    end

    -- Если вдруг cmd пустой — безопасно восстановим базовый
    if #filtered == 0 then
      filtered = {
        "clangd",
        "--background-index",
        "--header-insertion=never",
        "--completion-style=detailed",
      }
    end

    table.insert(filtered, "--compile-commands-dir=" .. cc_dir)
    new_config.cmd = filtered

    -- Страховка: init_options могли затереться
    new_config.init_options = new_config.init_options or {}
    new_config.init_options.fallbackFlags = fallbackFlagsList
  end,
})

lspconfig.jsonls.setup({
  capabilities = capabilities,
  on_attach = on_attach,
})

lspconfig.buf_ls.setup({
  cmd = { "buf", "lsp", "serve" },
  filetypes = { "proto" },
  root_dir = util.root_pattern("buf.work.yaml", "buf.yaml", ".git"),
  capabilities = capabilities,

  on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
    on_attach(client, bufnr)
  end,
})
