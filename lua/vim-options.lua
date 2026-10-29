-- ========================================================================== --
--                          CORE OPTIONS & KEYMAPS                            --
-- ========================================================================== --

-- Leader keys (must be set before plugins load)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- ------------------------ UI & Appearance --------------------------------- --
vim.opt.termguicolors = true  -- Enable 24-bit RGB color in the TUI
vim.opt.signcolumn = "yes"    -- Always show sign column to prevent text shifting
vim.opt.number = true         -- Show absolute line number on current line
vim.opt.relativenumber = true -- Show relative line numbers for easy jumping
vim.opt.cursorline = true     -- Highlight current cursor line
vim.opt.linebreak = true      -- Wrap long lines cleanly at word boundaries
vim.opt.scrolloff = 10        -- Keep at least 10 lines visible above/below cursor

-- ------------------------ Search & Substitution --------------------------- --
vim.opt.ignorecase = true     -- Case-insensitive searching by default
vim.opt.smartcase = true      -- Case-sensitive if search contains uppercase
vim.opt.inccommand = "split"  -- Live preview of :substitute changes in a split

-- ------------------------ Files & Splits ---------------------------------- --
vim.opt.swapfile = false      -- Disable swap files
vim.opt.splitright = true     -- Open vertical splits to the right
vim.opt.splitbelow = true     -- Open horizontal splits below

-- ------------------------ General Keymaps --------------------------------- --
-- Exit insert mode quickly with JJ
vim.keymap.set("i", "JJ", "<Esc>", { desc = "Exit insert mode" })

-- Clear search highlighting
vim.keymap.set("n", "<leader>h", "<cmd>nohlsearch<CR>", { desc = "Clear search highlights" })

-- Navigate between split panes
vim.keymap.set("n", "<C-k>", "<cmd>wincmd k<CR>", { desc = "Move focus to upper split" })
vim.keymap.set("n", "<C-j>", "<cmd>wincmd j<CR>", { desc = "Move focus to lower split" })
vim.keymap.set("n", "<C-h>", "<cmd>wincmd h<CR>", { desc = "Move focus to left split" })
vim.keymap.set("n", "<C-l>", "<cmd>wincmd l<CR>", { desc = "Move focus to right split" })
