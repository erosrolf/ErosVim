-- ============================================================
-- Цели:
--   1) Включать completion ТОЛЬКО в буферах, где реально подключён LSP (через LspAttach)
--   2) Снизить “шум” в списке подсказок (Text вниз, Snippet в конец)
--   3) Держать всё в одном файле: и setup(), и autocmd
-- ============================================================

-- Плагин mini.completion
local MiniCompletion = require("mini.completion")

-- ------------------------------------------------------------
-- Настройка обработки списка айтемов completion.
-- Здесь мы:
--   - "Text" опускаем вниз (часто это мусор в больших проектах)
--   - "Snippet" отправляем в конец (если вдруг прилетает от LSP)
-- ------------------------------------------------------------
local process_items_opts = {
  kind_priority = {
    Text = -1,     -- опустить ниже
    Snippet = 99,  -- поднять "приоритет" => будет дальше/позже (в default_process_items это влияет на сортировку)
  },
}

local process_items = function(items, base)
  return MiniCompletion.default_process_items(items, base, process_items_opts)
end

-- ------------------------------------------------------------
-- Основной setup.
-- Важно: auto_setup = false
-- Это означает: mini.completion НЕ будет сам везде включать omnifunc/completefunc.
-- Мы включим его аккуратно сами на событии LspAttach (ниже).
-- ------------------------------------------------------------
MiniCompletion.setup({
  lsp_completion = {
    -- Варианты: "omnifunc" или "completefunc"
    -- Для большинства конфигов и привычек удобнее "omnifunc".
    source_func = "omnifunc",

    -- ВАЖНО: отключаем авто-настройку, чтобы не трогать буферы без LSP
    auto_setup = false,

    -- Обработка списка кандидатов (сортировка/фильтр)
    process_items = process_items,
  },

  -- Задержки (мс): можешь подстроить под себя
  delay = {
    completion = 120, -- как быстро появляется список
    info = 200,       -- как быстро показывать окно с инфо по айтему
    signature = 120,  -- как быстро показывать сигнатуру
  },
})

-- ------------------------------------------------------------
-- Автокоманда: включать LSP completion только когда LSP реально приаттачился.
-- Это корректно для nvim 0.12 и не ломает буферы без LSP.
-- ------------------------------------------------------------
vim.api.nvim_create_autocmd("LspAttach", {
  desc = "Enable mini.completion omnifunc for LSP-attached buffers",
  callback = function(args)
    -- args.buf — буфер, куда прицепился LSP

    -- Для source_func = "omnifunc" нужно выставить omnifunc:
    vim.bo[args.buf].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"

    -- Если решишь использовать source_func = "completefunc",
    -- то вместо omnifunc нужно выставить completefunc:
    -- vim.bo[args.buf].completefunc = "v:lua.MiniCompletion.completefunc_lsp"
  end,
})

-- ------------------------------------------------------------
-- ЯВНЫЕ МАППИНГИ ДЛЯ НАВИГАЦИИ
-- ------------------------------------------------------------

local function is_completion_active()
  return vim.fn.pumvisible() == 1
end

-- Tab: если меню открыто -> следующий вариант (<C-n>)
--      если закрыто -> обычный Tab (4 пробела или что там у тебя)
vim.keymap.set("i", "<Tab>", function()
  if is_completion_active() then
    return "<C-n>"
  else
    return "<Tab>"
  end
end, { expr = true })

-- Shift-Tab: если меню открыто -> предыдущий вариант (<C-p>)
--           если закрыто -> обычный Shift-Tab
vim.keymap.set("i", "<S-Tab>", function()
  if is_completion_active() then
    return "<C-p>"
  else
    return "<S-Tab>"
  end
end, { expr = true })

-- Ничего не возвращаем намеренно:
-- require("plugins.mini_completion") достаточно, чтобы конфиг применился.
