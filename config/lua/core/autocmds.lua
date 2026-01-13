----- auto show diagnostic window -----
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.diagnostic.open_float(nil, {
      focus = false,
      border = "rounded",
      source = "always",
      prefix = "👁 ",
    })
  end,
})

----- kill old swap file -----
vim.api.nvim_create_autocmd("BufWritePost", {
  callback = function()
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

----- disable winbar for mini.files windows -----
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "minifiles", "mini.files" },
  callback = function()
    vim.opt_local.winbar = ""
  end,
})
