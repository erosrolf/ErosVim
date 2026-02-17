-- config/lua/core/keymaps.lua
-- ============================================================
-- Один файл, но структурировано по "группам" (core / plugins).
-- Не падает, если плагин не установлен/удалён (vim.pack + opt).
-- ============================================================

vim.g.mapleader = " "

local map  = vim.keymap.set
local func = require("core.functions")

-- pack.lua у тебя живёт как "инфра". Мы не добавляем новые API,
-- поэтому проверяем установку по пути, исходя из packpath.
local function is_pack_installed(pack_name)
  -- Ищем в любом packpath: <packpath>/pack/*/opt/<pack_name>
  for _, root in ipairs(vim.opt.packpath:get()) do
    local glob = root .. "/pack/*/opt/" .. pack_name
    if vim.fn.empty(vim.fn.glob(glob)) == 0 then
      return true
    end
  end
  return false
end

local function safe_call(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then
      vim.schedule(function()
        vim.notify(err, vim.log.levels.WARN)
      end)
    end
  end
end

local function req(mod)
  local ok, m = pcall(require, mod)
  if not ok then return nil end
  return m
end

-- Универсальный раннер групп
local groups = {
  -- ==========================================================
  -- CORE (без внешних плагинов)
  -- ==========================================================
  {
    name = "core / lsp",
    maps = {
      { "<leader>a", vim.lsp.buf.code_action, "Code Action", { "n", "v" } },
      { "<leader>rn", vim.lsp.buf.rename, "Rename symbol" },
      { "<leader>f", function() vim.lsp.buf.format({ async = true }) end, "Format file" },
    },
  },

  {
    name = "core / splits",
    maps = {
      { "<leader>h", "<C-w>h", "Go to left split" },
      { "<leader>j", "<C-w>j", "Go to below split" },
      { "<leader>k", "<C-w>k", "Go to upper split" },
      { "<leader>l", "<C-w>l", "Go to right split" },
      { "<leader>sh", "<cmd>split<CR>", "Horizontal split" },
      { "<leader>sv", "<cmd>vsplit<CR>", "Vertical split" },
      { "<leader>sc", "<cmd>close<CR>", "Close current split" },
      { "<leader>sx", "<cmd>only<CR>", "Close other splits" },
    },
  },

  {
    name = "core / misc",
    maps = {
      { "<leader>go", func.goto_menu, "Go to (definition, ref, ...)" },
      { "<leader>bo", func.open_buffer_in_finder, "Open buffer in Finder" },

      { "<leader>w", function()
          local ft = vim.bo.filetype
          if ft == "minifiles" then
            local mf = req("mini.files")
            if mf and mf.synchronize then mf.synchronize() end
            return
          end
          vim.lsp.buf.format({ async = false })
          vim.cmd("write")
        end,
        "Format & Save / MiniFiles Sync"
      },

      { "<leader>q", func.smart_close_buffer, "Smart close" },
    },
  },

  -- ==========================================================
  -- TROUBLE (если установлен)
  -- ==========================================================
  {
    name = "trouble.nvim",
    dep = { pack = "trouble.nvim", mod = "trouble" }, -- если у тебя нет trouble в списке плагинов — блок просто не активируется
    maps = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", "Diagnostics (workspace)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", "Diagnostics (current buffer)" },
      { "<leader>xr", "<cmd>Trouble lsp toggle<cr>", "LSP (defs/refs/impl/...)" },
      { "<leader>xs", "<cmd>Trouble symbols toggle pinned=true win.position=bottom<cr>", "Symbols (right)" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", "Quickfix list" },
      { "<leader>xl", "<cmd>Trouble loclist toggle<cr>", "Location list" },
    },
  },

  -- ==========================================================
  -- MINI.EXTRA
  -- ==========================================================
  {
    name = "mini.extra",
    dep = { pack = "mini.extra", mod = "mini.extra" },
    maps = {
      { "<leader>:", function()
          require("mini.extra").pickers.history({ scope = ":" })
        end,
        "Command history (mini.extra)"
      },
      { "<leader>;", function()
          require("mini.extra").pickers.commands()
        end,
        "Commands (mini.extra)"
      },
      { "<leader>fo", function()
          require("mini.extra").pickers.oldfiles()
        end,
        "Recent files (mini.extra)"
      },
    },
  },

  -- ==========================================================
  -- MINI.PICK
  -- ==========================================================
  {
    name = "mini.pick",
    dep = { pack = "mini.pick", mod = "mini.pick" },
    maps = {
      { "<leader>ff", function()
          require("mini.pick").builtin.files()
        end,
        "Find files (mini.pick)"
      },
    },
  },

  -- ==========================================================
  -- MINI.FILES
  -- ==========================================================
  {
    name = "mini.files",
    dep = { pack = "mini.files", mod = "mini.files" },
    maps = {
      { "<leader>e", function()
          local path = vim.fn.expand("%:p")
          local stat = vim.loop.fs_stat(path)
          local dir = (stat and stat.type == "file")
            and vim.fn.fnamemodify(path, ":h")
            or vim.loop.cwd()
          require("mini.files").open(dir, true)
        end,
        "Explorer (mini.files)"
      },
    },
  },

  -- ==========================================================
  -- GITSIGNS
  -- ==========================================================
  {
    name = "gitsigns.nvim",
    dep = { pack = "gitsigns.nvim", mod = "gitsigns" },
    maps = {
      { "<leader>gd", func.preview_hunk_popup, "Show Git hunk under cursor" },
      { "<leader>gu", function()
          local gs = req("gitsigns"); if gs and gs.reset_hunk then gs.reset_hunk() end
        end,
        "Undo Git hunk"
      },
      { "<leader>gp", function()
          local gs = req("gitsigns"); if gs and gs.preview_hunk then gs.preview_hunk() end
        end,
        "Preview hunk"
      },
      { "<leader>gr", function()
          local gs = req("gitsigns"); if gs and gs.reset_hunk then gs.reset_hunk() end
        end,
        "Reset hunk"
      },
    },
  },

  -- ==========================================================
  -- DIFFVIEW
  -- ==========================================================
  {
    name = "diffview.nvim",
    dep = { pack = "diffview.nvim", mod = "diffview.lib" },
    maps = {
      { "<leader>dif", function()
          local ok, lib = pcall(require, "diffview.lib")
          if not ok then
            vim.notify("diffview.nvim not found", vim.log.levels.WARN)
            return
          end

          local view = lib.get_current_view()
          if view then
            vim.cmd("DiffviewClose")
          else
            vim.cmd("DiffviewOpen HEAD~1")
          end
        end,
        "Toggle Git Diff (HEAD~1)"
      },

      { "<leader>diF", function()
          local commits = vim.fn.systemlist("git log --oneline --max-count=30")
          if not commits or #commits == 0 then
            vim.notify("No git commits found (are you in a git repo?)", vim.log.levels.WARN)
            return
          end

          vim.ui.select(commits, { prompt = "Diff against commit:" }, function(choice)
            if not choice then return end
            local sha = choice:match("^(%S+)")
            if not sha then return end
            vim.cmd("DiffviewOpen " .. sha)
          end)
        end,
        "Diff: choose commit"
      },
    },
  },

  -- ==========================================================
  -- BLAME.NVIM
  -- ==========================================================
  {
    name = "blame.nvim",
    dep = { pack = "blame.nvim", mod = "blame" },
    maps = {
      { "<leader>gb", "<cmd>BlameToggle<CR>", "Git Blame toggle file" },
    },
  },

  -- ==========================================================
  -- ILLUMINATE
  -- ==========================================================
  {
    name = "vim-illuminate",
    dep = { pack = "vim-illuminate", mod = "illuminate" },
    maps = {
      { "]r", function()
          local ill = req("illuminate"); if ill and ill.goto_next_reference then ill.goto_next_reference(false) end
        end,
        "Next ref"
      },
      { "[r", function()
          local ill = req("illuminate"); if ill and ill.goto_prev_reference then ill.goto_prev_reference(false) end
        end,
        "Prev ref"
      },
    },
  },

  -- ==========================================================
  -- AERIAL
  -- ==========================================================
  {
    name = "aerial.nvim",
    dep = { pack = "aerial.nvim", mod = "aerial" },
    maps = {
      { "<leader>ot", "<cmd>AerialToggle<CR>", "Toggle Aerial Outline" },
    },
  },

  -- ==========================================================
  -- BUFFERLINE
  -- ==========================================================
  {
    name = "bufferline.nvim",
    dep = { pack = "bufferline.nvim", mod = "bufferline" },
    maps = {
      { "<leader>bh", "<cmd>BufferLineCyclePrev<CR>", "Prev buffer" },
      { "<leader>bl", "<cmd>BufferLineCycleNext<CR>", "Next buffer" },
      { "<leader>bb", "<cmd>BufferLinePick<CR>", "Pick buffer" },
      { "<leader>bx", "<cmd>bufdo bd<CR>", "Close all buffers" },
      { "<leader>bc", "<cmd>%bd|e#|bd#<CR>", "Close others buffers" },
    },
  },

  -- ==========================================================
  -- Custom: git hunks outline (твой модуль)
  -- (если удалишь файл — не упадём)
  -- ==========================================================
  {
    name = "custom / git hunks outline",
    maps = {
      { "<leader>oh", function()
          local ok, mod = pcall(require, "plugins.git_hunks_outline")
          if ok and mod and mod.open then mod.open() end
        end,
        "Open Git Hunks (develop)"
      },
    },
  },

  -- ==========================================================
  -- Grep helpers (без плагинов)
  -- ==========================================================
  {
    name = "core / grep",
    maps = {
      {
        "<leader>fw",
        function()
          local q = vim.fn.input("Grep C/C++: ")
          if q == "" then return end
          vim.cmd("silent! grep! " ..
            "-g'*.cc' -g'*.h' -g'*.cpp' -g'*.hpp' -g'*.proto' " ..
            vim.fn.shellescape(q)
          )
          vim.cmd("copen")
        end,
        "Grep C/C++ (quickfix)",
      },
      {
        "<leader>fj",
        function()
          local q = vim.fn.input("Grep JSON: ")
          if q == "" then return end
          vim.cmd("silent! grep! " .. "-g'*.json' " .. vim.fn.shellescape(q))
          vim.cmd("copen")
        end,
        "Grep JSON (quickfix)",
      },
    },
  },

  -- ==========================================================
  -- clangd command (если команда существует — работает)
  -- ==========================================================
  {
    name = "clangd",
    maps = {
      { "<leader>/", "<cmd>ClangdSwitchSourceHeader<CR>", "Switch header/source" },
    },
  },
}

-- ============================================================
-- Apply keymaps
-- ============================================================
for _, g in ipairs(groups) do
  local enabled = true
  if g.dep and g.dep.pack then
    enabled = is_pack_installed(g.dep.pack)
  end

  if enabled then
    for _, m in ipairs(g.maps) do
      local lhs, rhs, desc, mode = m[1], m[2], m[3], m[4] or "n"
      map(mode, lhs, safe_call(rhs), { desc = desc, silent = true })
    end
  end
end
