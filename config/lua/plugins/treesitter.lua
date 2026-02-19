local ok, ts = pcall(require, "nvim-treesitter")
if not ok then
  return
end

ts.setup({
  ensure_installed = { "lua", "vim", "c", "cpp", "proto" },
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
})
