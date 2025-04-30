vim.g.mapleader = " "

local keymap = vim.keymap.set
local telescope = require("telescope")
local fb = telescope.extensions.file_browser
local builtin = require("telescope.builtin")

-- открыть легковестный браузер
vim.keymap.set("n", "<leader>e", function()
  require("mini.files").open(vim.loop.cwd(), true)
end, { desc = "Mini Files" })

-- открыть детальный браузер
keymap("n", "<leader>fb", function()
  require("telescope").extensions.file_browser.file_browser()
end, { desc = "File browser (detailed)" })

keymap("n", "<leader>w", ":w<CR>")

vim.keymap.set('n', '<leader>q', function()
  if vim.bo.modified then
    vim.ui.select({ "Выйти без сохранения", "Сохранить и выйти", "Отмена" }, {
      prompt = "Файл изменён. Что сделать?",
    }, function(choice)
      if choice == "Сохранить и выйти" then
        vim.cmd("wq")
      elseif choice == "Выйти без сохранения" then
        vim.cmd("q!")
      end
      -- если "Отмена" — ничего не делаем
    end)
  else
    vim.cmd("q")
  end
end, { desc = "Умный выход" })

keymap("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
keymap("n", "<leader>fw", builtin.live_grep, { desc = "Live grep" })
keymap("n", "<leader>fb", builtin.current_buffer_fuzzy_find, { desc = "Fuzzy find in buffer" })

