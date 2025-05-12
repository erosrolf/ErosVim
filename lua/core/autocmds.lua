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

----- oldfiles on open empty nvim ------
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() == 0 then
      require("telescope.builtin").oldfiles({ only_cwd = true })
    end
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
