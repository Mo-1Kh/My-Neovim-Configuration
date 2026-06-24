
-- Shows number lines on the left
vim.opt.number = true

-- Shows relative number lines, based on where you are
vim.opt.relativenumber = true

-- Only works when wrap is on, makes the break nicer around words
vim.opt.linebreak = true

-- Show which line your cursor is on
vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor
vim.opt.scrolloff = 10

-- Enter normal mode with jk
vim.keymap.set('i', 'JJ', '<Esc>')

-- Make search case sensitive or insensitive
vim.opt.ignorecase = true

-- Only works if ignorecase is enabled
vim.opt.smartcase = true

-- Preview substitutions live, as you type
vim.opt.inccommand = 'split'

vim.g.mapleader = " "

vim.opt.swapfile = false

-- Navigate vim panes better
vim.keymap.set('n', '<c-k>', ':wincmd k<CR>')
vim.keymap.set('n', '<c-j>', ':wincmd j<CR>')
vim.keymap.set('n', '<c-h>', ':wincmd h<CR>')
vim.keymap.set('n', '<c-l>', ':wincmd l<CR>')

vim.keymap.set('n', '<leader>h', ':nohlsearch<CR>')
