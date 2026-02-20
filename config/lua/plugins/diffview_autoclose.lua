-- Auto-close Diffview when you jump to a real file buffer.
-- Keeps Diffview as a single "session": open -> navigate -> jump -> auto close.

local function is_diffview_buffer(buf)
  local ft = vim.bo[buf].filetype
  if ft == "DiffviewFiles" or ft == "DiffviewFileHistory" then
    return true
  end

  local name = vim.api.nvim_buf_get_name(buf)
  if name:match("^diffview://") then
    return true
  end

  -- Diffview diff buffers are often nofile+diff
  if vim.bo[buf].buftype == "nofile" and vim.wo.diff then
    return true
  end

  return false
end

local function is_real_file_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  if vim.bo[buf].buftype ~= "" then return false end
  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= nil and name ~= ""
end

vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("DiffviewAutoClose", { clear = true }),
  callback = function(args)
    local ok, lib = pcall(require, "diffview.lib")
    if not ok then return end
    if not lib.get_current_view() then return end

    local buf = args.buf
    if is_diffview_buffer(buf) then return end

    if is_real_file_buffer(buf) then
      vim.schedule(function()
        if lib.get_current_view() then
          vim.cmd("DiffviewClose")
        end
      end)
    end
  end,
})
