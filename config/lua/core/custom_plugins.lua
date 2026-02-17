-- custom
require("plugins.git_ranges_jump").setup({
  develop_ref = "develop",
  keymaps = { next = "]d", prev = "[d" },
  enable = { red = true, green = true, orange = true },
})
require("plugins.eros_build_tool")
