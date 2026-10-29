-- ========================================================================== --
--                           NEOVIM CONFIGURATION                             --
-- ========================================================================== --

-- Bootstrap lazy.nvim plugin manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop
if not uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load core editor options & keymaps before plugins
require("vim-options")

-- Initialize plugins from lua/plugins/
require("lazy").setup("plugins", {
  change_detection = {
    notify = false,
  },
})
