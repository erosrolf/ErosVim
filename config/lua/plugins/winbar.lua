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

-- Кеш строки winbar
vim.g.navic_cached = vim.g.navic_cached or ""

-- Локальная Lua-функция для winbar
_G._navic_cached = function()
  return vim.g.navic_cached or ""
end

-- Winbar читает кеш, а не вызывает navic.get_location()
vim.opt.winbar = "%{%v:lua._navic_cached()%}%="

-- Disable winbar for some filetypes
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "minifiles", "mini.files", "help", "qf", "Trouble", "NvimTree", "toggleterm" },
  callback = function()
    vim.opt_local.winbar = ""
  end,
})
