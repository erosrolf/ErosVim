require("eros_build_tool").setup({
  log = {
    height = 50,
    position = "botright",
    open_cmd = "split",
    replace_mode = true,
  },
  state = {
    enabled = true,
    -- file = "/tmp/nvim_build_root.txt", -- если хочешь своё место
  },
})
