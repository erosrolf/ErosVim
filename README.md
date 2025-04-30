# My Neovim Configuration

This is my personal Neovim setup.
Plugins are included as git submodules inside `pack/my-plugins/start`

Plugins:
nvim-treesitter/nvim-treesitter

nvim-telescope/telescope.nvim
nvim-lua/plenary.nvim (dependency of telescope)

numToStr/Comment.nvim

# Install

```bash
git clone --recursive https://github.com/erosrolf/nvim.git ~/.config/nvim
```

# Update Plugins
```bash
git submodule update --remote --merge
git commit -am "Update plugin submodules"
```
