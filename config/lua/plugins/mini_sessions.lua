local sessions = require("mini.sessions")

sessions.setup({
  directory = vim.fn.stdpath("state") .. "/sessions",
  autoread = false,
  autowrite = false,
})
