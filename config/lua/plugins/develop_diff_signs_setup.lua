local ok, mod = pcall(require, "plugins.develop_diff_signs")
if not ok then return end

mod.setup({
  base = "develop",
  priority = 10,
})
