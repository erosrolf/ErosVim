local ok, diff = pcall(require, "mini.diff")
if not ok then return end

diff.setup(
{
  -- Options for how hunks are visualized
  view = {
    -- Visualization style. Possible values are 'sign' and 'number'.
    -- Default: 'number' if line numbers are enabled, 'sign' otherwise.
    -- style = vim.go.number and 'number' or 'sign',
    style = 'sign',

    -- Signs used for hunks with 'sign' view
    signs = { add = '▒', change = '▒', delete = '▒' },

    -- Priority of used visualization extmarks
    priority = 199,
  },

  -- Source(s) for how reference text is computed/updated/etc
  -- Uses content from Git index by default
  source = nil,

  -- Delays (in ms) defining asynchronous processes
  delay = {
    -- How much to wait before update following every text change
    text_change = 200,
  },

  -- Mappings in core/keymps.lua
  mappings = {
    apply = '',
    reset = '',
    textobject = '',
    goto_first = '',
    goto_prev = '',
    goto_next = '',
    goto_last = '',
  },

  -- Various options
  options = {
    -- Diff algorithm. See `:h vim.diff()`.
    algorithm = 'histogram',

    -- Whether to use "indent heuristic". See `:h vim.diff()`.
    indent_heuristic = true,

    -- The amount of second-stage diff to align lines
    linematch = 60,

    -- Whether to wrap around edges during hunk navigation
    wrap_goto = false,
  },
})

-- Опционально: красивее цвета
-- vim.api.nvim_set_hl(0, "MiniDiffSignAdd",    { link = "DiffAdd" })
-- vim.api.nvim_set_hl(0, "MiniDiffSignChange", { link = "DiffChange" })
-- vim.api.nvim_set_hl(0, "MiniDiffSignDelete", { link = "DiffDelete" })
