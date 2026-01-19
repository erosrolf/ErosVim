vim.g.mapleader = " "

local telescope  = require("telescope")
local builtin    = require("telescope.builtin")
local fb         = telescope.extensions.file_browser
local map        = vim.keymap.set
local func       = require("core.functions")

local M = {
  { ----- code_action -----
    "<leader>a",
    vim.lsp.buf.code_action,
    "Code Action",
    { "n", "v" } 
  },
  { ----- format file ------
    "<leader>f",
    function() 
      vim.lsp.buf.format({ async = true })
    end,
    "Format file"
  },

  ------ diagnostics ------
  -- Trouble.nvim v2 mappings
  { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", "Diagnostics (workspace)" },
  { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", "Diagnostics (current buffer)" },
  { "<leader>xr", "<cmd>Trouble lsp toggle<cr>", "LSP (defs/refs/impl/...)" },
  { "<leader>xs", "<cmd>Trouble symbols toggle pinned=true win.position=bottom<cr>", "Symbols (right)" },
  { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", "Quickfix list" },
  { "<leader>xl", "<cmd>Trouble loclist toggle<cr>", "Location list" },

  { "<leader>rn", vim.lsp.buf.rename, "Rename symbol" },

  ----- GIT ------
  {
    ------ git diffview ------
    "<leader>dif",
    function()
      local view = require("diffview.lib").get_current_view()
      if view then
        vim.cmd("DiffviewClose")
      else
        vim.cmd("DiffviewOpen")
      end
    end,
    "Toggle Git Diffview"
  },
  { "<leader>gd", func.preview_hunk_popup, "Show Git hunk under cursor" },
  { "<leader>gu", function() require("gitsigns").reset_hunk() end, "Undo Git hunk" },

  { ----- goto_menu ------
    "<leader>go",
    func.goto_menu,
    "Go to (definition, ref, ...)"
  },

    ------ gitsigns (hunks) ------
  { "<leader>gp", function() require("gitsigns").preview_hunk() end, "Preview hunk" },
  { "<leader>gr", function() require("gitsigns").reset_hunk() end, "Reset hunk" },
  { "<leader>gb", function() require("gitsigns").blame_line({ full = true }) end, "Blame line" },

  ------ telescope ------
  { "<leader>ff", builtin.find_files, "Find files" },
  { "<leader>fw", telescope.extensions.live_grep_args.live_grep_args, "Find word" },
  { ------ file browser ------
    "<leader>fb", 
    fb.file_browser,                             
    "File browser"
  },

------ explorer ------
{
  "<leader>e",
  function()
    local path = vim.fn.expand("%:p")
    local stat = vim.loop.fs_stat(path)
    local dir = (stat and stat.type == "file")
      and vim.fn.fnamemodify(path, ":h")
      or vim.loop.cwd()

    require("mini.files").open(dir, true)
  end,
  "Mini Files",
},

  { ------ mini files ------
    "<leader>mf",
    function()
      local path = vim.fn.expand("%:p")
      local stat = vim.loop.fs_stat(path)
      local cwd = (stat and stat.type == "file")
        and vim.fn.fnamemodify(path, ":h")
        or vim.loop.cwd()

      require("mini.files").open(cwd, true)
    end,
    "Mini Files"
  },
  ------ aerial toggle outline ------
  { "<leader>ot", "<cmd>AerialToggle<CR>", "Toggle Aerial Outline" },
  { ------ switch header/source ------
    "<leader>/", 
    "<cmd>ClangdSwitchSourceHeader<CR>",
    "Switch header/source" 
  },
  ----- SPLITS ------
  { "<leader>h", "<C-w>h", "Go to left split" },
  { "<leader>j", "<C-w>j", "Go to below split" },
  { "<leader>k", "<C-w>k", "Go to upper split" },
  { "<leader>l", "<C-w>l", "Go to right split" },
  { "<leader>sh", "<cmd>split<CR>", "Horizontal split" },
  { "<leader>sv", "<cmd>vsplit<CR>", "Vertical split" },
  { "<leader>sc", "<cmd>close<CR>", "Close current split" },
  { "<leader>sx", "<cmd>only<CR>", "Close other splits" },

  { ------ previous buffer ------
    "<leader>bh", 
    "<cmd>BufferLineCyclePrev<CR>",
    "Prev buffer" 
  },
  { ------ next buffer ------
    "<leader>bl",
    "<cmd>BufferLineCycleNext<CR>",
    "Next buffer"
  },
  { ------ pick buffer ------
    "<leader>bb",
    "<cmd>BufferLinePick<CR>",
    "Pick buffer" 
  },
  { ------ close all buffers ------
    "<leader>bx",
    "<cmd>bufdo bd<CR>",
    "Close all buffers"   
  },
  { ------ close others buffers ------
    "<leader>bc",
    "<cmd>%bd|e#|bd#<CR>",
    "Close others buffers"
  },
  { ------ save buffer ------
    "<leader>w",
    function()
      local ft = vim.bo.filetype
  
      -- Если фокус в mini.files → синхронизация FS
      if ft == "minifiles" then
        require("mini.files").synchronize()
        return
      end
  
      -- Обычное поведение
      vim.lsp.buf.format({ async = false })
      vim.cmd("write")
    end,
    "Format & Save / MiniFiles Sync"
  },
  { ------ smart close -------
    "<leader>q",
    func.smart_close_buffer,
    "Smart close"
  },
}

-- применение
for _, m in ipairs(M) do
  local lhs, rhs, desc, mode = m[1], m[2], m[3], m[4] or "n"
  map(mode, lhs, rhs, { desc = desc })
end
