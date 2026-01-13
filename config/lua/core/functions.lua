local M = {}

-- Меню "Go to..."
function M.goto_menu()
  local choices = {
    { label = "Definition",       action = vim.lsp.buf.definition },
    { label = "Declaration",      action = vim.lsp.buf.declaration },
    { label = "Implementation",   action = vim.lsp.buf.implementation },
    { label = "Type Definition",  action = vim.lsp.buf.type_definition },
    { label = "References",       action = vim.lsp.buf.references },
    { label = "Hover (Doc)",      action = vim.lsp.buf.hover },
  }

  vim.ui.select(choices, {
    prompt = "Go to...",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice then choice.action() end
  end)
end

------ diagnostic split ------
function M.show_diagnostics_list()
  vim.diagnostic.setloclist({ open = true })
  vim.cmd("botright lopen | resize 15")
end

------ smart close buffer ------
function M.smart_close_buffer()
  local modified  = vim.bo.modified
  local bufs      = #vim.fn.getbufinfo({ buflisted = 1 })

  local function close(force)
    -- Закрываем aerial, если открыт
    local aerial = require("aerial")
    if aerial.is_open() then
      aerial.close()
    end

    vim.cmd((bufs <= 1) and (force and "q!" or "confirm q")
                        or (force and "bdelete!" or "bdelete"))
  end

  if not modified then close(false) return end

  vim.ui.select({ "Выйти без сохранения", "Сохранить и закрыть", "Отмена" },
    { prompt = "Буфер изменён. Что сделать?" },
    function(choice)
      if choice == "Сохранить и закрыть" then
        vim.cmd("write")
        close(false)
      elseif choice == "Выйти без сохранения" then
        close(true)
      end
    end)
end

------ git diff preview window ------
function M.preview_hunk_popup()
  local width = vim.api.nvim_win_get_width(0)
  local gs = require("gitsigns")
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

  -- Удалённые строки (то, что было)
  for _, l in ipairs(target.removed.lines or {}) do
    table.insert(lines, "- " .. l)
  end

  -- Разделитель
  if #target.removed.lines > 0 and #target.added.lines > 0 then
    table.insert(lines, "")
  end

  -- Добавленные строки (то, что стало)
  for _, l in ipairs(target.added.lines or {}) do
    table.insert(lines, "+ " .. l)
  end

  vim.lsp.util.open_floating_preview(
    lines,
    "diff",
    {
      border = "rounded",
      width = width,
      title = "Git Hunk",
      title_pos = "center",
      focusable = false,
      close_events = { "CursorMoved", "InsertEnter" },
    }
  )
end



-- Пересборка проекта и перезапуск LSP
function M.staros_rebuild()
  vim.cmd("botright split | resize 15 | terminal")
  local term_buf = vim.api.nvim_get_current_buf()
  local term_chan = vim.b.terminal_job_id

  vim.fn.chansend(term_chan, "staros-rebuild --configure-only\n")

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = term_buf,
    once = true,
    callback = function()
      vim.cmd("bd!")
      vim.lsp.stop_client(vim.lsp.get_active_clients())
      vim.cmd("edit")
      vim.cmd("LspStart")
      vim.notify("Rebuild complete and LSP restarted", vim.log.levels.INFO)
    end,
  })
end



-- Copy absolute path + whole buffer content to system clipboard (+)
function M.copy_file_path_and_content()
  local path = vim.fn.expand("%:p")
  if path == "" then
    vim.notify("No file path for current buffer", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, "\n")

  local result = path .. "\n\n" .. text
  vim.fn.setreg("+", result)
  vim.notify("Copied file path + content to clipboard", vim.log.levels.INFO)
end



-- Format JSON exactly like project hook: jq -M -S --indent 4 .
-- Returns true if buffer was changed, false otherwise.
function M.format_json_like_hook(bufnr)
  bufnr = bufnr or 0

  -- jq can't handle jsonc (comments / trailing commas). Keep it strict.
  local ft = vim.bo[bufnr].filetype
  if ft ~= "json" then
    return false
  end

  -- If buffer is empty, do nothing
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines == 0 then
    return false
  end

  -- Ensure jq exists
  if vim.fn.executable("jq") ~= 1 then
    vim.notify("jq not found in PATH", vim.log.levels.WARN)
    return false
  end

  local input = table.concat(lines, "\n")

  -- Run jq with exact project flags
  local cmd = { "jq", "-M", "-S", "--indent", "4", "." }
  local output = vim.fn.system(cmd, input)

  if vim.v.shell_error ~= 0 then
    -- invalid JSON; don't block save, just notify
    vim.notify("jq failed: buffer is not valid JSON", vim.log.levels.WARN)
    return false
  end

  local out_lines = vim.split(output, "\n", { plain = true })
  if out_lines[#out_lines] == "" then
    table.remove(out_lines, #out_lines)
  end

  -- No changes -> do nothing
  if #out_lines == #lines then
    local same = true
    for i = 1, #lines do
      if lines[i] ~= out_lines[i] then
        same = false
        break
      end
    end
    if same then
      return false
    end
  end

  local view = vim.fn.winsaveview()

  -- One undo step
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, out_lines)

  vim.fn.winrestview(view)
  return true
end

return M
