local mini_files = require("mini.files")

mini_files.setup({
  windows = {
    preview = true,
    width_preview = 40,
  },
})

-- Jump to home directory with "~"
vim.api.nvim_create_autocmd("User", {
  pattern = "MiniFilesBufferCreate",
  callback = function(args)
    local buf = args.data.buf_id

    vim.keymap.set("n", "~", function()
      mini_files.open(vim.loop.os_homedir(), false)
    end, {
      buffer = buf,
      desc = "MiniFiles: go to home directory",
    })
  end,
})
