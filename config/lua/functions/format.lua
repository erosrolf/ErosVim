local M = {}

function M.copy_file_path_and_content()
  local path = vim.fn.expand("%:p")
  if path == "" then
    vim.notify("No file path for current buffer", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, "\n")
  vim.fn.setreg("+", path .. "\n\n" .. text)
  vim.notify("Copied file path + content to clipboard", vim.log.levels.INFO)
end

function M.format_json_like_hook(bufnr)
  bufnr = bufnr or 0
  if vim.bo[bufnr].filetype ~= "json" then return false end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines == 0 then return false end

  if vim.fn.executable("jq") ~= 1 then
    vim.notify("jq not found in PATH", vim.log.levels.WARN)
    return false
  end

  local input = table.concat(lines, "\n")
  local output = vim.fn.system({ "jq", "-M", "-S", "--indent", "4", "." }, input)

  if vim.v.shell_error ~= 0 then
    vim.notify("jq failed: buffer is not valid JSON", vim.log.levels.WARN)
    return false
  end

  local out_lines = vim.split(output, "\n", { plain = true })
  if out_lines[#out_lines] == "" then table.remove(out_lines, #out_lines) end

  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, out_lines)
  vim.fn.winrestview(view)
  return true
end

return M
