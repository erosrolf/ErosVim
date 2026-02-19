require("mole").setup({
  -- where session files are saved
  session_dir = vim.fn.stdpath("data") .. "/mole", -- ~/.local/share/nvim/mole

  -- "location" = file path + line range
  -- "snippet" = file path + line range + selected text in a fenced code block
  capture_mode = "snippet",

  -- open the side panel automatically when starting a session
  auto_open_panel = true,

  -- custom session name: nil = timestamp, string = fixed name, function = called to get name
  session_name = nil,

  -- show vim.notify messages
  notify = true,

  -- picker for resume: "auto" (telescope → snacks → vim.ui.select), "telescope", "snacks", or "select"
  picker = "auto",

  -- keybindings
  -- keys = {
  --   annotate = "<leader>ma",        -- visual mode
  --   start_session = "<leader>ms",   -- normal mode
  --   stop_session = "<leader>mq",    -- normal mode
  --   resume_session = "<leader>mr",  -- normal mode
  --   toggle_window = "<leader>mw",   -- normal mode
  --   jump_to_location = { "<CR>", "gd" }, -- in side panel
  --   next_annotation = "]a",              -- in side panel
  --   prev_annotation = "[a",              -- in side panel
  -- },

  -- side panel
  window = {
    width = 0.3, -- fraction of editor width
  },

  -- inline input popup
  input = {
    width = 50,
    border = "rounded",
  },

  -- callbacks that return lines written to the session file
  -- each receives an info table and must return a table of strings (lines)
  -- return {} to skip a section entirely
  format = {
    -- info: { title, file_path, cwd, timestamp }
    header = function(info)
      return {
        "# " .. info.title,
        "",
        "**File:** " .. info.file_path,
        "**Started:** " .. info.timestamp,
        "**Project:** " .. info.cwd, -- used to resolve file paths when jumping to locations from a different project
        "",
        "---",
      }
    end,
    -- info: { timestamp }
    footer = function(info)
      return {
        "",
        "---",
        "",
        "**Ended:** " .. info.timestamp,
      }
    end,
    -- info: { timestamp }
    resumed = function(info)
      return {
        "",
        "---",
        "",
        "**Resumed:** " .. info.timestamp,
        "",
        "---",
        "",
      }
    end,
  },
})
