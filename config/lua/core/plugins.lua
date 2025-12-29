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

safe_require("plugins.treesitter")
safe_require("plugins.comment")
safe_require("plugins.lsp")
safe_require("plugins.lsp_signature")
safe_require("plugins.cmp")
safe_require("plugins.nvim-navic")
safe_require("plugins.gitsigns")
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
safe_require("plugins.lualine")

-- colorschemes
safe_require("plugins.catpuccin")
safe_require("plugins.github-nvim-theme")
