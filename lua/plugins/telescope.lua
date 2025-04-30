local actions = require("telescope.actions")

require("telescope").setup {
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
      hidden = true, -- искать и скрытые файлы, если хочешь
    },
  },

  extensions = {
    file_browser = {
      theme = "dropdown", -- можно заменить на "ivy" или "cursor"
      hijack_netrw = true,-- заменяет стандартный netrw
      hidden = true       -- показывать скрытые файлы
    }
  }
}

require("telescope").load_extension("file_browser")
