require("diffview").setup({
  enhanced_diff_hl = true,
  use_icons = false,
  view = {
    default = {
      layout = "diff2_vertical",   -- один экран: слева/справа
      winbar_info = true,
    },
    file_history = { layout = "diff2_vertical" },
    merge_tool = { layout = "diff3_vertical" },
  },
  file_panel = {
    listing_style = "tree",
    tree_options = { flatten_dirs = true, folder_statuses = "only_folded" },
    win_config = { width = 35 }, -- чтоб панель была “как sidebar”
  },
})
