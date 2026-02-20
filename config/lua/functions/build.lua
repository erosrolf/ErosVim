local M = {}

local function _build_tool()
  local ok, bt = pcall(require, "eros_build_tool")
  if not ok then return nil end
  return bt
end

function M.setup()
  vim.api.nvim_create_user_command("PickCwdBuild", function(opts)
    local bt = _build_tool()
    if not bt then
      vim.notify("plugins.eros_build_tool is not available", vim.log.levels.ERROR)
      return
    end
    bt.pick_cwd_build(opts.args)
  end, {
    nargs = 1,
    desc = "Set build CWD to <repo_root>/<arg> and load .nvim-build.lua there",
    complete = function(_, line)
      local bt = _build_tool()
      if bt and bt.complete_pick_cwd_build then
        return bt.complete_pick_cwd_build(line)
      end
      return {}
    end,
  })

  vim.api.nvim_create_user_command("PickCwdBuildShow", function()
    local bt = _build_tool()
    if not bt or not bt.show_cwd_build then
      vim.notify("plugins.eros_build_tool is not available", vim.log.levels.ERROR)
      return
    end
    bt.show_cwd_build()
  end, { desc = "Show current build CWD" })

  vim.api.nvim_create_user_command("PickCwdBuildClear", function()
    local bt = _build_tool()
    if not bt or not bt.clear_cwd_build then
      vim.notify("plugins.eros_build_tool is not available", vim.log.levels.ERROR)
      return
    end
    bt.clear_cwd_build()
  end, { desc = "Clear saved build CWD" })

  vim.api.nvim_create_user_command("BuildTarget", function(cmdopts)
    local bt = _build_tool()
    if not bt or not bt.build_target then
      vim.notify("plugins.eros_build_tool is not available", vim.log.levels.ERROR)
      return
    end
    bt.build_target({ target = cmdopts.args })
  end, {
    nargs = "?",
    desc = "Build target (infer from current file via build.ninja, or provide explicit target)",
  })

  vim.api.nvim_create_user_command("BuildLog", function()
    local bt = _build_tool()
    if not bt or not bt.show_build_log then
      vim.notify("plugins.eros_build_tool is not available", vim.log.levels.ERROR)
      return
    end
    bt.show_build_log()
  end, { desc = "Reopen last build/test log window" })
end

return M
