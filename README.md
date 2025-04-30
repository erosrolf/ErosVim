# My Neovim Configuration

This is my personal Neovim setup.
Plugins are included as git submodules inside `pack/my-plugins/start`
This ensures long-term reproducibility, even if plugins disappear or change upstream.

## 🔌 Installed Plugins

- **Syntax and Treesitter**
  - [`nvim-treesitter/nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter)

- **Fuzzy Finder & UI**
  - [`nvim-telescope/telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim)
  - [`nvim-telescope/telescope-file-browser.nvim`](https://github.com/nvim-telescope/telescope-file-browser.nvim)
  - [`stevearc/dressing.nvim`](https://github.com/stevearc/dressing.nvim) – improves UI prompts
  - [`nvim-lua/plenary.nvim`](https://github.com/nvim-lua/plenary.nvim) – required by telescope

- **LSP & Autocompletion**
  - [`neovim/nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig)
  - [`hrsh7th/nvim-cmp`](https://github.com/hrsh7th/nvim-cmp)
  - [`hrsh7th/cmp-nvim-lsp`](https://github.com/hrsh7th/cmp-nvim-lsp)
  - [`hrsh7th/cmp-buffer`](https://github.com/hrsh7th/cmp-buffer)
  - [`hrsh7th/cmp-path`](https://github.com/hrsh7th/cmp-path)
  - [`hrsh7th/cmp-cmdline`](https://github.com/hrsh7th/cmp-cmdline)

- **Editing Enhancements**
  - [`numToStr/Comment.nvim`](https://github.com/numToStr/Comment.nvim)
  - [`echasnovski/mini.files`](https://github.com/echasnovski/mini.files) – fast file browser

---

## 🚀 Installation

```Bash
git clone --recursive https://github.com/erosrolf/nvim.git ~/.config/nvim
```

## 🔄 Updating Plugins

```Bash
git submodule update --remote --merge
git commit -am "Update plugin submodules"
```

## 🧠 Philosophy

1. No plugin manager required — only Git and submodules
2. Manual control over versions and updates
3. Fast startup, minimal overhead
4. Easy to reproduce on any machine
