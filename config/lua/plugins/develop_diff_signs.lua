-- Подсветка "закоммиченных" отличий текущей ветки от develop:
-- git diff develop...HEAD -- <file>
-- Знаки рисуем в signcolumn фиолетовыми группами.

local M = {}

local ns = vim.api.nvim_create_namespace("DevelopDiffSigns")
local group = vim.api.nvim_create_augroup("DevelopDiffSigns", { clear = true })

-- ====== Настройки ======
M.config = {
  base = "develop",          -- с чем сравниваем
  priority = 180,            -- приоритет знаков (мини.дифф обычно выше/ниже — подстроишь)
  debounce_ms = 200,
  enabled = true,
  -- Если хочешь только в некоторых репах — сюда можно добавить фильтр позже.
}

-- ====== HL + signs ======
local function setup_hl_and_signs()
  -- Подстрой под твою тему: сейчас это "фиолетовые" акценты.
  -- Можно сделать link на существующие группы (например, Purple/DiagnosticHint), если есть.
  vim.api.nvim_set_hl(0, "DevelopDiffAdd",    { fg = "#a855f7" })
  vim.api.nvim_set_hl(0, "DevelopDiffChange", { fg = "#a855f7" })
  vim.api.nvim_set_hl(0, "DevelopDiffDelete", { fg = "#a855f7" })

  vim.fn.sign_define("DevelopDiffAddSign",    { text = '▒', texthl = "DevelopDiffAdd" })
  vim.fn.sign_define("DevelopDiffChangeSign", { text = '▒', texthl = "DevelopDiffChange" })
  vim.fn.sign_define("DevelopDiffDeleteSign", { text = '▒', texthl = "DevelopDiffDelete" })
end

-- ====== Utils ======
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function buf_is_real_file(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  if vim.bo[buf].buftype ~= "" then return false end
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= nil and name ~= ""
end

local function system_text(cmd, cwd)
  local obj = vim.system(cmd, { text = true, cwd = cwd }):wait()
  return obj.code, obj.stdout or "", obj.stderr or ""
end

local function get_repo_root(abs_path)
  local dir = vim.fn.fnamemodify(abs_path, ":h")
  local code, out = system_text({ "git", "rev-parse", "--show-toplevel" }, dir)
  if code ~= 0 then return nil end
  out = trim(out)
  if out == "" then return nil end
  return out
end

local function relpath_from_root(root, abs_path)
  root = root:gsub("/+$", "")
  if abs_path:sub(1, #root + 1) ~= root .. "/" then return nil end
  return abs_path:sub(#root + 2)
end

local function clear_signs(buf)
  vim.fn.sign_unplace("DevelopDiffSigns", { buffer = buf })
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

-- Парсим "git diff --unified=0" и превращаем в три множества строк:
-- add/change/delete (по строкам новой версии файла)
local function parse_unified0(diff_text)
  local add, change, del = {}, {}, {}

  -- В unified diff заголовки: @@ -a,b +c,d @@
  for line in diff_text:gmatch("[^\n]+") do
    local a1, a2, b1, b2 = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
    if b1 then
      a1 = tonumber(a1)
      a2 = tonumber(a2) or 1
      b1 = tonumber(b1)
      b2 = tonumber(b2) or 1

      -- Эвристика:
      -- - чистое добавление: a2==0 && b2>0
      -- - чистое удаление:  b2==0 && a2>0 (подсветим строку "на месте" b1)
      -- - замена/изменение: a2>0 && b2>0 (подсветим диапазон как change)
      if a2 == 0 and b2 > 0 then
        for l = b1, (b1 + b2 - 1) do add[l] = true end
      elseif b2 == 0 and a2 > 0 then
        del[b1] = true
      else
        for l = b1, (b1 + b2 - 1) do change[l] = true end
      end
    end
  end

  return add, change, del
end

local function place_sign(buf, lnum, kind)
  local name = (kind == "add" and "DevelopDiffAddSign")
            or (kind == "change" and "DevelopDiffChangeSign")
            or "DevelopDiffDeleteSign"

  vim.fn.sign_place(0, "DevelopDiffSigns", name, buf, {
    lnum = lnum,
    priority = M.config.priority,
  })
end

-- ====== Core update ======
local pending = {}

local function update_now(buf)
  if not M.config.enabled then
    clear_signs(buf)
    return
  end
  if not buf_is_real_file(buf) then return end

  local abs = vim.api.nvim_buf_get_name(buf)
  local root = get_repo_root(abs)
  if not root then
    clear_signs(buf)
    return
  end

  local rel = relpath_from_root(root, abs)
  if not rel then
    clear_signs(buf)
    return
  end

  -- Проверим, что base-ветка существует (локально). Если нет — тихо отключим слой.
  local code_ref = ({ system_text({ "git", "rev-parse", "--verify", M.config.base }, root) })[1]
  if code_ref ~= 0 then
    clear_signs(buf)
    return
  end

  -- Считаем diff текущей ветки относительно develop (трёхточечное сравнение)
  local code, out = system_text(
    { "git", "diff", "--no-color", "--unified=0", (M.config.base .. "...HEAD"), "--", rel },
    root
  )

  clear_signs(buf)

  if code ~= 0 then return end
  out = out or ""
  if out == "" then return end

  local add, change, del = parse_unified0(out)

  -- ставим delete первым, чтобы add/change могли "перебить" (если совпадёт lnum)
  for lnum, _ in pairs(del) do place_sign(buf, lnum, "delete") end
  for lnum, _ in pairs(change) do place_sign(buf, lnum, "change") end
  for lnum, _ in pairs(add) do place_sign(buf, lnum, "add") end
end

local function schedule_update(buf)
  if pending[buf] then pending[buf]:stop(); pending[buf]:close() end
  local t = vim.uv.new_timer()
  pending[buf] = t
  t:start(M.config.debounce_ms, 0, function()
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then return end
      update_now(buf)
    end)
  end)
end

-- ====== Public API ======
function M.refresh(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  schedule_update(buf)
end

function M.toggle()
  M.config.enabled = not M.config.enabled
  vim.notify(("Develop diff signs: %s"):format(M.config.enabled and "ON" or "OFF"))
  -- Обновим текущий буфер сразу
  M.refresh()
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  setup_hl_and_signs()

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "CursorHold" }, {
    group = group,
    callback = function(args)
      schedule_update(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      pending[args.buf] = nil
    end,
  })
end

return M
