local M = {}

function M.goto_menu()
  local choices = {
    { label = "Definition",      action = vim.lsp.buf.definition },
    { label = "Declaration",     action = vim.lsp.buf.declaration },
    { label = "Implementation",  action = vim.lsp.buf.implementation },
    { label = "Type Definition", action = vim.lsp.buf.type_definition },
    { label = "References",      action = vim.lsp.buf.references },
    { label = "Hover (Doc)",     action = vim.lsp.buf.hover },
  }

  vim.ui.select(choices, {
    prompt = "Go to...",
    format_item = function(item) return item.label end,
  }, function(choice)
    if choice then choice.action() end
  end)
end

function M.show_diagnostics_list()
  vim.diagnostic.setloclist({ open = true })
  vim.cmd("botright lopen | resize 15")
end

------ smart close buffer ------
function M.smart_close_buffer()
  local modified = vim.bo.modified
  local bufs = #vim.fn.getbufinfo({ buflisted = 1 })
  local curbuf = vim.api.nvim_get_current_buf()

  local function close(force)
    -- Закрываем aerial, если открыт
    local ok_aerial, aerial = pcall(require, "aerial")
    if ok_aerial and aerial.is_open() then
      aerial.close()
    end

    -- Если это последний listed-буфер — логично закрыть Neovim
    if bufs <= 1 then
      vim.cmd(force and "q!" or "confirm q")
      return
    end

    -- Аккуратно удалить буфер, не ломая layout
    local ok_br, bufremove = pcall(require, "mini.bufremove")
    if ok_br then
      bufremove.delete(curbuf, force)
      return
    end

    -- Фоллбек, если mini.bufremove по какой-то причине недоступен
    vim.cmd(force and "bdelete!" or "bdelete")
  end

  if not modified then
    close(false)
    return
  end

  vim.ui.select(
    { "Выйти без сохранения", "Сохранить и закрыть", "Отмена" },
    { prompt = "Буфер изменён. Что сделать?" },
    function(choice)
      if choice == "Сохранить и закрыть" then
        vim.cmd("write")
        close(false)
      elseif choice == "Выйти без сохранения" then
        close(true)
      end
    end
  )
end

function M.preview_hunk_popup()
  local width = vim.api.nvim_win_get_width(0)
  local ok, gs = pcall(require, "gitsigns")
  if not ok or not gs then return end

  local hunks = gs.get_hunks(vim.api.nvim_get_current_buf())
  if not hunks then return end

  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local target = nil

  for _, h in ipairs(hunks) do
    local start_line = h.added.start
    local end_line = h.added.start + h.added.count
    if cursor >= start_line and cursor <= end_line then
      target = h
      break
    end
  end

  if not target then
    vim.notify("Нет изменений в текущей строке", vim.log.levels.INFO)
    return
  end

  local lines = {}
  for _, l in ipairs(target.removed.lines or {}) do table.insert(lines, "- " .. l) end
  if #(target.removed.lines or {}) > 0 and #(target.added.lines or {}) > 0 then table.insert(lines, "") end
  for _, l in ipairs(target.added.lines or {}) do table.insert(lines, "+ " .. l) end

  vim.lsp.util.open_floating_preview(lines, "diff", {
    border = "rounded",
    width = width,
    title = "Git Hunk",
    title_pos = "center",
    focusable = false,
    close_events = { "CursorMoved", "InsertEnter" },
  })
end

return M
