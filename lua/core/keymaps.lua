vim.g.mapleader = " "

local telescope  = require("telescope")
local builtin    = require("telescope.builtin")
local fb         = telescope.extensions.file_browser
local map        = vim.keymap.set

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
    ------ gitsigns (hunks) ------
  { "<leader>gp", function() require("gitsigns").preview_hunk() end, "Preview hunk" },
  { "<leader>gr", function() require("gitsigns").reset_hunk() end, "Reset hunk" },
  { "<leader>gb", function() require("gitsigns").blame_line({ full = true }) end, "Blame line" },

  { ------ fine files ------
    "<leader>ff",
    builtin.find_files,
    "Find files"
  },
  { ------ find word ------
    "<leader>fw", 
    builtin.live_grep,                           
    "Find word"
  },
  { ------ file browser ------
    "<leader>fb", 
    fb.file_browser,                             
    "File browser"
  },
  { ------ mini files ------
    "<leader>e", 
    function() require("mini.files").open(vim.fn.expand("%:p:h"), true) end,
    "Mini Files" 
  },
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
    "<cmd>w<CR>",
    "Save buffer"
  },
  { ------ smart close -------
    "<leader>q",
    function()
      local modified  = vim.bo.modified
      local bufs      = #vim.fn.getbufinfo({ buflisted = 1 })
      local function close(force)
        vim.cmd((bufs<=1) and (force and "q!" or "confirm q")
                           or (force and "bdelete!" or "bdelete"))
      end
      if not modified then close(false) return end
      vim.ui.select({ "Выйти без сохранения", "Сохранить и закрыть", "Отмена" },
        { prompt = "Буфер изменён. Что сделать?" },
        function(choice)
          if choice=="Сохранить и закрыть" then vim.cmd("write") close(false)
          elseif choice=="Выйти без сохранения" then close(true)
          end
        end)
    end,
    "Smart close"
  },
}

-- применение
for _, m in ipairs(M) do
  local lhs, rhs, desc, mode = m[1], m[2], m[3], m[4] or "n"
  map(mode, lhs, rhs, { desc = desc })
end
