local ok, navic = pcall(require, "nvim-navic")
if not ok then
  return
end

navic.setup({
  highlight = true,
  separator = " > ",
  depth_limit = 0,
  safe_output = true,
  lazy_update_context = false,
})

_G.navic_winbar = function()
  local ok2, navic2 = pcall(require, "nvim-navic")
  if not ok2 then
    return ""
  end

  if not navic2.is_available() then
    return ""
  end

  return navic2.get_location()
end

vim.o.winbar = "%{%v:lua.navic_winbar()%}"
