local Formatter = {}

local CoreFunctions = require("core.functions")

-----------------------------------------------------------------------
-- Utility: get buffer filename
-----------------------------------------------------------------------
local function get_buffer_filename(buffer_number)
    local filename = vim.api.nvim_buf_get_name(buffer_number)

    if filename == nil or filename == "" then
        return nil
    end

    return filename
end

-----------------------------------------------------------------------
-- Format current buffer using clang-format
-- Used for .proto files to match pre-commit hook
-----------------------------------------------------------------------
function Formatter.format_buffer_with_clang_format(buffer_number)
    if buffer_number == nil then
        buffer_number = vim.api.nvim_get_current_buf()
    end

    local filename = get_buffer_filename(buffer_number)
    if filename == nil then
        return
    end

    -- Read entire buffer
    local buffer_lines = vim.api.nvim_buf_get_lines(
        buffer_number,
        0,
        -1,
        false
    )

    local buffer_content = table.concat(buffer_lines, "\n") .. "\n"

    -- Important:
    -- --assume-filename makes clang-format:
    -- 1) detect language (Proto)
    -- 2) apply project .clang-format rules
    local command = {
        "clang-format",
        "--assume-filename=" .. filename
    }

    local formatted_output = vim.fn.system(command, buffer_content)

    if vim.v.shell_error ~= 0 then
        vim.notify(
            "clang-format failed:\n" .. formatted_output,
            vim.log.levels.ERROR
        )
        return
    end

    -- Preserve cursor position
    local current_row, current_col = unpack(
        vim.api.nvim_win_get_cursor(0)
    )

    local formatted_lines = vim.split(
        formatted_output,
        "\n",
        { plain = true }
    )

    -- Remove trailing empty line if present
    if #formatted_lines > 0 and formatted_lines[#formatted_lines] == "" then
        table.remove(formatted_lines, #formatted_lines)
    end

    vim.api.nvim_buf_set_lines(
        buffer_number,
        0,
        -1,
        false,
        formatted_lines
    )

    pcall(
        vim.api.nvim_win_set_cursor,
        0,
        { current_row, current_col }
    )
end

-----------------------------------------------------------------------
-- Format buffer on save
-- Central entry point for all formatting logic
-----------------------------------------------------------------------
function Formatter.format_buffer_on_save(buffer_number, lsp_client)
    if buffer_number == nil then
        buffer_number = vim.api.nvim_get_current_buf()
    end

    local filetype = vim.bo[buffer_number].filetype

    -------------------------------------------------------------------
    -- 1. Proto files → use clang-format (same as pre-commit hook)
    -------------------------------------------------------------------
    if filetype == "proto" then
        Formatter.format_buffer_with_clang_format(buffer_number)
        return true
    end

    -------------------------------------------------------------------
    -- 2. JSON files → use custom JSON hook
    -------------------------------------------------------------------
    if filetype == "json" then
        CoreFunctions.format_json_like_hook(buffer_number)
        return true
    end

    -------------------------------------------------------------------
    -- 3. Other files → use attached LSP formatting
    -------------------------------------------------------------------
    if lsp_client ~= nil then
        if lsp_client.server_capabilities.documentFormattingProvider then
            vim.lsp.buf.format({
                async = false,
                filter = function(client)
                    return client.id == lsp_client.id
                end,
            })
            return true
        end
    end

    return false
end

return Formatter
