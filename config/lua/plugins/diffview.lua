require("diffview").setup({
  enhanced_diff_hl = true, -- красивые подсветки
  use_icons = true,
  view = {
    default = {
      layout = "diff2_horizontal", -- side-by-side
    },
    merge_tool = {
      layout = "diff3_horizontal",
    },
    file_history = {
      layout = "diff2_vertical",
    },
  },
  file_panel = {
    listing_style = "tree", -- как файловое дерево
    tree_options = {
      flatten_dirs = true,
      folder_statuses = "only_folded",
    },
  },
})
