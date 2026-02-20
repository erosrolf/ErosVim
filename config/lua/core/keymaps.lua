-- core/keymaps.lua
-- ============================================================
-- Здесь живут все хоткеи.
-- Формат записи:
-- { "<lhs>", <rhs>, "Description", {modes} }
-- modes опционален, по умолчанию "n" (normal).
--
-- Как настраивать:
-- 1) Меняешь хоткеи прямо в таблице M
-- 2) Описание (desc) полезно для which-key/подсказок (и для тебя)
-- 3) Для Diffview смотри секцию GIT ниже
-- ============================================================

vim.g.mapleader = " "

local map         = vim.keymap.set
local func        = require("core.functions")
local extra       = require("mini.extra")
local mole        = require("mole")
local formatter   = require("core.formatter")

  -- ==========================================================
  -- MOLE
  -- ==========================================================
  vim.keymap.set("v", "<leader>ma", mole.annotate, { desc = "Mole: annotate" })
  vim.keymap.set("n", "<leader>ms", mole.start_session, { desc = "Mole: start session" })
  vim.keymap.set("n", "<leader>mq", mole.stop_session, { desc = "Mole: stop session" })
  vim.keymap.set("n", "<leader>mr", mole.resume_session, { desc = "Mole: resume session" })
  vim.keymap.set("n", "<leader>mw", mole.toggle_window, { desc = "Mole: toggle panel" })

local M = {
  -- ==========================================================
  -- LSP
  -- ==========================================================
  {
    "<leader>a",
    vim.lsp.buf.code_action,
    "Code Action",
    { "n", "v" }
  },
  {
    "<leader>f",
    function()
      vim.lsp.buf.format({ async = true })
    end,
    "Format file"
  },

  -- ==========================================================
  -- COMMANDS
  -- ==========================================================
  { "<leader>:",
    function() extra.pickers.history({ scope = ":" }) end,
    "Command history (mini.extra)"
  },
  { "<leader>;",
    function() extra.pickers.commands() end,
    "Commands (mini.extra)"
  },

  -- ==========================================================
  -- Diagnostics / Trouble.nvim
  -- ==========================================================
  { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", "Diagnostics (workspace)" },
  { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", "Diagnostics (current buffer)" },
  { "<leader>xr", "<cmd>Trouble lsp toggle<cr>", "LSP (defs/refs/impl/...)" },
  { "<leader>xs", "<cmd>Trouble symbols toggle pinned=true win.position=bottom<cr>", "Symbols (right)" },
  { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", "Quickfix list" },
  { "<leader>xl", "<cmd>Trouble loclist toggle<cr>", "Location list" },

  { "<leader>rn", vim.lsp.buf.rename, "Rename symbol" },

  -- ==========================================================
  -- GIT
  -- ==========================================================
  -- Diffview = "Aerial-like" окно для git diff (список файлов + diff)
  -- Настройка по умолчанию: показывает изменения относительно предыдущего коммита (HEAD~1)
  --   <leader>dif : toggle окно Diffview (HEAD~1)
  --   <leader>diF : выбрать коммит из git log и открыть diff относительно него
  --
  -- Важно:
  -- - Diffview должен быть установлен и подключен как плагин
  -- - Если у тебя нет require("plugins.diffview") в plugins.lua — добавь
  {
    "<leader>dif",
    function()
      local ok, lib = pcall(require, "diffview.lib")
      if not ok then
        vim.notify("diffview.nvim not found", vim.log.levels.WARN)
        return
      end

      local view = lib.get_current_view()
      if view then
        vim.cmd("DiffviewClose")
      else
        vim.cmd("DiffviewOpen develop...HEAD")
      end
    end,
    "Diff vs develop"
  },
  { "<leader>dis", function() func.diffsplit_file_from_develop({ base = "develop", vertical = true }) end, "Diffsplit vs develop" },

  -- Быстрый popup diff hunk под курсором
  { "<leader>gd", function() func.preview_hunk_smart({ base = "origin/develop" }) end, "Show Git hunk under cursor" },
  { "<leader>gu", function() require("gitsigns").reset_hunk() end, "Undo Git hunk" },

  -- ==========================================================
  -- Go to... menu (твоя удобная менюшка)
  -- ==========================================================
  {
    "<leader>go",
    func.goto_menu,
    "Go to (definition, ref, ...)"
  },
  {"]r", function() require("illuminate").goto_next_reference(false) end, "Next ref" },
  {"[r", function() require("illuminate").goto_prev_reference(false) end, "Prev ref" },

  -- ==========================================================
  -- Gitsigns hunks
  -- ==========================================================
  { "<leader>gp", function() require("gitsigns").preview_hunk() end, "Preview hunk" },
  { "<leader>gr", function() require("gitsigns").reset_hunk() end, "Reset hunk" },
  { "<leader>gb", "<cmd>BlameToggle<CR>", "Git Blame toggle file" },

  -- ==========================================================
  -- Finders
  -- ==========================================================
  { "<leader>ff", MiniPick.builtin.files,     "Find files (mini.pick)" },
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
      vim.cmd("silent! grep! " ..
        "-g'*.json' " ..
        vim.fn.shellescape(q)
      )
      vim.cmd("copen")
    end,
    "Grep JSON (quickfix)",
  },
  {
    "<leader>fo",
    function()
      require("mini.visits").select_path()
    end,
    "Recent files (visits)"
  },

  -- ==========================================================
  -- Explorer (mini.files)
  -- ==========================================================
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
    "Mini Files"
  },


  -- ==========================================================
  -- Aerial
  -- ==========================================================
  { "<leader>ot", "<cmd>AerialToggle<CR>", "Toggle Aerial Outline" },
  -- Git hunks outline
  { "<leader>oh", function() require("plugins.git_hunks_outline").open() end, "Open Git Hunks (develop)" },

  -- ==========================================================
  -- C/C++ (clangd)
  -- ==========================================================
  { "<leader>/",
    function()
      local clients = vim.lsp.get_clients({ bufnr = 0, name = "clangd" })
      if #clients == 0 then
        vim.notify("clangd не запущен для этого буфера", vim.log.levels.WARN)
        return
      end

      local params = { uri = vim.uri_from_bufnr(0) }
      vim.lsp.buf_request(0, "textDocument/switchSourceHeader", params, function(err, result)
        if err then
          vim.notify(err.message or tostring(err), vim.log.levels.ERROR)
          return
        end
        if not result then
          vim.notify("clangd не вернул парный файл", vim.log.levels.INFO)
          return
        end
        vim.cmd("edit " .. vim.uri_to_fname(result))
      end)
    end,
    "Switch header/source",
    { "n" },
  },

  -- ==========================================================
  -- Splits navigation
  -- ==========================================================
  { "<leader>h", "<C-w>h", "Go to left split" },
  { "<leader>j", "<C-w>j", "Go to below split" },
  { "<leader>k", "<C-w>k", "Go to upper split" },
  { "<leader>l", "<C-w>l", "Go to right split" },
  { "<leader>sh", "<cmd>split<CR>", "Horizontal split" },
  { "<leader>sv", "<cmd>vsplit<CR>", "Vertical split" },
  { "<leader>sc", "<cmd>close<CR>", "Close current split" },
  { "<leader>sx", "<cmd>only<CR>", "Close other splits" },

  -- ==========================================================
  -- Bufferline
  -- ==========================================================
  { "<leader>bh", "<cmd>BufferLineCyclePrev<CR>", "Prev buffer" },
  { "<leader>bl", "<cmd>BufferLineCycleNext<CR>", "Next buffer" },
  { "<leader>bb", "<cmd>BufferLinePick<CR>", "Pick buffer" },
  { "<leader>bx", "<cmd>bufdo bd<CR>", "Close all buffers" },
  { "<leader>bc", "<cmd>%bd|e#|bd#<CR>", "Close others buffers" },
  { "<leader>bo", func.open_buffer_in_finder, "Open buffer in Finder" },

  -- ==========================================================
  -- Save / Smart close
  -- ==========================================================
  {
    "<leader>w",
    function()
      local filetype = vim.bo.filetype

      if filetype == "minifiles" then
        require("mini.files").synchronize()
        return
      end

      -- Форматируем текущий буфер "правильным" способом.
      -- Для proto будет clang-format (как в pre-commit), для json твой hook,
      -- для остального — LSP (если есть).
      formatter.format_buffer_on_save(vim.api.nvim_get_current_buf(), nil)

      vim.cmd("write")
    end,
    "Format & Save / MiniFiles Sync"
  },
  {
    "<leader>q",
    func.smart_close_buffer,
    "Smart close"
  },
}

-- ============================================================
-- Применение хоткеев
-- ============================================================
for _, m in ipairs(M) do
  local lhs, rhs, desc, mode = m[1], m[2], m[3], m[4] or "n"
  map(mode, lhs, rhs, { desc = desc })
end
