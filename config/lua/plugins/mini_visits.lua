local ok, visits = pcall(require, "mini.visits")
if not ok then
  return
end

visits.setup(
{
  -- How visit index is converted to list of paths
  list = {
    -- Predicate for which paths to include (all by default)
    filter = nil,

    -- Sort paths based on the visit data (robust frecency by default)
    sort = function(arr)
      table.sort(arr, function(a, b)
        return (a.latest or 0) > (b.latest or 0)
      end)
      return arr
    end,
  },

  -- Whether to disable showing non-error feedback
  silent = false,

  -- How visit index is stored
  store = {
    -- Whether to write all visits before Neovim is closed
    autowrite = true,

    -- Function to ensure that written index is relevant
    normalize = nil,

    -- Path to store visit index
    path = vim.fn.stdpath('data') .. '/mini-visits-index',
  },

  -- How visit tracking is done
  track = {
    -- Start visit register timer at this event
    -- Supply empty string (`''`) to not do this automatically
    event = 'BufEnter',

    -- Debounce delay after event to register a visit
    delay = 1000,
  },
}
)
