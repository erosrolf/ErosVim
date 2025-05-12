local telescope = require("telescope")
local actions = require("telescope.actions")
local lga_actions = require("telescope-live-grep-args.actions")

telescope.setup {
  defaults = {
    -- Улучшаем поведение по умолчанию
    prompt_prefix = "🔍 ",
    selection_caret = "❯ ",
    path_display = { "smart" },

    -- Игнорируем ненужные папки
    file_ignore_patterns = {
      "node_modules", ".git", "dist", "build", "__pycache__", "%.lock", "%.DS_Store"
    },

    mappings = {
      i = {
        ["<Esc>"] = actions.close -- закрывать окно сразу при Esc в insert режиме
      },
      n = {
        ["<Esc>"] = actions.close -- так же в normal-mode на всякий случай
      }
    }
  },

  pickers = {
    find_files = {
      -- Используем fd с кастомными аргументами
      find_command = { "fd", "--type", "f", "--strip-cwd-prefix" },
      hidden = true,
    },
  },

  extensions = {
    file_browser = {
      theme = "dropdown",
      hijack_netrw = true,
      hidden = true,
    },
    live_grep_args = {
      auto_quoting = true,
      mappings = {
        i = {
          ["<C-k>"] = lga_actions.quote_prompt(),
          ["<C-i>"] = lga_actions.quote_prompt({ postfix = " --iglob " }),
          ["<C-space>"] = lga_actions.to_fuzzy_refine,
        },
      },
    },
  }
}

telescope.load_extension("file_browser")
telescope.load_extension("live_grep_args")
