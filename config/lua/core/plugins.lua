local function safe_require(name)
  local ok, mod = pcall(require, name)
  if not ok then
    vim.schedule(function()
      vim.notify(("Skipped missing module: %s"):format(name), vim.log.levels.WARN)
    end)
    return nil
  end
  return mod
end

require("plugins.treesitter")
require("plugins.comment")
require("plugins.lsp")
require("plugins.lsp_signature")
require("plugins.cmp")
require("plugins.nvim-navic")
require("plugins.gitsigns")
safe_require("plugins.trouble")

-- telescope
safe_require("plugins.telescope")

-- tests
safe_require("plugins.neotest")
safe_require("plugins.neotest-gtest")

-- ui
safe_require("plugins.ui")
safe_require("plugins.miniicons")
safe_require("plugins.bufferline")
safe_require("plugins.mini_files")
safe_require("plugins.winbar")

-- colorscheme
vim.cmd.colorscheme("eros-light")
