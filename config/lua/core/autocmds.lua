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
-- Attach navic on LSP attach
--------------------------------------------------------------------
local navic_group = vim.api.nvim_create_augroup("NavicAttach", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
  group = navic_group,
  callback = function(args)
    local ok, navic = pcall(require, "nvim-navic")
    if not ok then
      return
    end

    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    if client.server_capabilities
      and client.server_capabilities.documentSymbolProvider
    then
      navic.attach(client, args.buf)
      vim.schedule(function()
        vim.cmd("redrawstatus")
      end)
    end
  end,
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
        vim.notify("Swap file removed", vim.log.levels.INFO, {
          title = "Swap Clean",
          timeout = 1000,
        })
      end
    end
  end,
})

--------------------------------------------------------------------
-- Disable winbar for some filetypes
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

--------------------------------------------------------------------
-- Refresh winbar when cursor moves
--------------------------------------------------------------------
local winbar_refresh = vim.api.nvim_create_augroup("WinbarRefresh", { clear = true })

vim.api.nvim_create_autocmd({
  "CursorMoved",
  "CursorMovedI",
  "BufEnter",
  "WinEnter",
  "InsertLeave",
}, {
  group = winbar_refresh,
  callback = function()
    local ok, navic = pcall(require, "nvim-navic")
    if ok and navic.is_available() then
      vim.api.nvim__redraw({ winbar = true, flush = true })
    end
  end,
})
