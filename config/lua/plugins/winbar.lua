local ok, navic = pcall(require, "nvim-navic")
if not ok then
  return
end

navic.setup({
  highlight = true,
  separator = " > ",
  depth_limit = 0,
  safe_output = true,
})

-- показываем breadcrumbs в winbar
vim.o.winbar = "%{%v:lua.require('nvim-navic').get_location()%}%="

-- выключаем winbar там, где он мешает
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "minifiles", "mini.files", "help", "qf", "Trouble", "NvimTree", "toggleterm" },
  callback = function()
    vim.opt_local.winbar = ""
  end,
})
