--------------------------------------------------------------------
-- Diagnostics float on CursorHold (only if there are diagnostics)
--------------------------------------------------------------------
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    local diagnostics = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
    if #diagnostics == 0 then
      return
    end

    vim.diagnostic.open_float(nil, {
      focus = false,
      border = "rounded",
      source = "always",
      prefix = "👁 ",
    })
  end,
})

--------------------------------------------------------------------
-- Navic winbar cache + (optional) clangd semantic tokens tweak
-- IMPORTANT: navic.attach() should be done ONLY in core/lsp.lua (on_attach)
--------------------------------------------------------------------
vim.g.navic_cached = vim.g.navic_cached or ""

local navic_group = vim.api.nvim_create_augroup("NavicWinbarCache", { clear = true })

local function update_navic_cache()
  local ok, navic = pcall(require, "nvim-navic")
  if not ok or not navic.is_available() then
    vim.g.navic_cached = ""
    return
  end

  vim.g.navic_cached = navic.get_location()
end

-- Debounce to avoid spamming on CursorMoved
local _timer = vim.uv.new_timer()
local function update_navic_cache_debounced()
  _timer:stop()
  _timer:start(60, 0, function()
    vim.schedule(update_navic_cache)
  end)
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = navic_group,
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then return end

    -- Optional: speed up huge C++ TU by disabling semantic tokens only for huge files
    if client.name == "clangd" then
      local line_count = vim.api.nvim_buf_line_count(args.buf)
      if line_count > 5000 then
        client.server_capabilities.semanticTokensProvider = nil
      end
    end

    -- DO NOT navic.attach() here (avoid duplication). It's in core/lsp.lua:on_attach.
    update_navic_cache_debounced()
  end,
})

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufEnter", "InsertLeave" }, {
  group = navic_group,
  callback = update_navic_cache_debounced,
})

--------------------------------------------------------------------
-- Kill old swap file (only if swapfile is enabled)
--------------------------------------------------------------------
vim.api.nvim_create_autocmd("BufWritePost", {
  callback = function()
    if not vim.o.swapfile then
      return
    end

    local filename = vim.fn.expand("%:p")
    local swapdir = vim.fn.stdpath("state") .. "/swap/"
    local swappath = swapdir .. filename:gsub("/", "%%") .. ".swp"

    if vim.loop.fs_stat(swappath) then
      vim.fn.delete(swappath)
      if not vim.g.silent_swap_clean then
        vim.notify("Swap file removed", vim.log.levels.INFO, { title = "Swap Clean", timeout = 1000 })
      end
    end
  end,
})

--------------------------------------------------------------------
-- Disable winbar for some filetypes (where it is annoying)
--------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "minifiles", "mini.files", "help", "qf", "Trouble", "NvimTree", "toggleterm" },
  callback = function()
    vim.opt_local.winbar = ""
  end,
})

--------------------------------------------------------------------
-- Restore last cursor position
--------------------------------------------------------------------
local last_pos_group = vim.api.nvim_create_augroup("LastCursorPosition", { clear = true })

vim.api.nvim_create_autocmd("BufReadPost", {
  group = last_pos_group,
  desc = "Restore last cursor position",
  callback = function(args)
    if vim.bo[args.buf].buftype ~= "" then
      return
    end

    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(args.buf)

    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
