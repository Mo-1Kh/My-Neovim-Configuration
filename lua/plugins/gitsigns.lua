return {
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "G", "Gdiffsplit", "Gvdiffsplit", "Gwrite", "Gread" },
    keys = {
      { "<leader>gg", "<cmd>Git<CR>", desc = "Open Git status (Fugitive)" },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local gs = require("gitsigns")

      gs.setup({
        signs = {
          add          = { text = "▎" },
          change       = { text = "▎" },
          delete       = { text = "" },
          topdelete    = { text = "" },
          changedelete = { text = "▎" },
          untracked    = { text = "┆" },
        },
        signs_staged = {
          add          = { text = "▎" },
          change       = { text = "▎" },
          delete       = { text = "" },
          topdelete    = { text = "" },
          changedelete = { text = "▎" },
        },
        signs_staged_enable = true,
        signcolumn = true,
        numhl = false,
        linehl = false,
        word_diff = false,
        current_line_blame = false, -- toggle with <leader>gt
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = "eol",
          delay = 300,
        },
        current_line_blame_formatter = "  󰊢 <author>, <author_time:%R> • <summary>",
        preview_config = {
          border = "rounded",
          style = "minimal",
          relative = "cursor",
          row = 0,
          col = 1,
        },
        on_attach = function(bufnr)
          local function map(mode, l, r, desc)
            vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
          end

          -- Navigate between git hunks
          map("n", "]h", function()
            if vim.wo.diff then
              vim.cmd.normal({ "]c", bang = true })
            else
              gs.nav_hunk("next")
            end
          end, "Next Git hunk")

          map("n", "[h", function()
            if vim.wo.diff then
              vim.cmd.normal({ "[c", bang = true })
            else
              gs.nav_hunk("prev")
            end
          end, "Previous Git hunk")

          -- Hunk actions
          map("n", "<leader>gp", gs.preview_hunk, "Preview Git hunk")
          map("n", "<leader>gi", gs.preview_hunk_inline, "Preview Git hunk inline")
          map("n", "<leader>gs", gs.stage_hunk, "Stage Git hunk")
          map("n", "<leader>gr", gs.reset_hunk, "Reset Git hunk")
          map("v", "<leader>gs", function()
            gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, "Stage selected Git hunk")
          map("v", "<leader>gr", function()
            gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, "Reset selected Git hunk")

          -- Buffer-wide Git actions
          map("n", "<leader>gS", gs.stage_buffer, "Stage entire buffer")
          map("n", "<leader>gR", gs.reset_buffer, "Reset entire buffer")
          map("n", "<leader>gu", gs.undo_stage_hunk, "Undo stage hunk")

          -- Blame & Diff
          map("n", "<leader>gt", gs.toggle_current_line_blame, "Toggle inline Git blame")
          map("n", "<leader>gb", function()
            gs.blame_line({ full = true })
          end, "Show full Git blame popup")
          map("n", "<leader>gd", gs.diffthis, "Git diff current file")
        end,
      })
    end,
  },
  {
    "sindrets/diffview.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewFileHistory",
    },
    keys = {
      {
        "<leader>gv",
        function()
          local lib = require("diffview.lib")
          if lib.get_current_view() then
            vim.cmd("DiffviewClose")
          else
            vim.cmd("DiffviewOpen")
          end
        end,
        desc = "Toggle Git Diffview",
      },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "Git history of current file" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<CR>", desc = "Git history of entire repo" },
      { "<leader>gx", "<cmd>DiffviewClose<CR>", desc = "Close Git Diffview" },
    },
    config = function()
      local actions = require("diffview.actions")
      require("diffview").setup({
        enhanced_diff_hl = true,
        use_icons = true,
        show_help_hints = true,
        icons = {
          folder_closed = "󰉋",
          folder_open = "󰝰",
        },
        signs = {
          fold_closed = "",
          fold_open = "",
          done = "✓",
        },
        view = {
          default = {
            layout = "diff2_horizontal",
          },
          merge_tool = {
            layout = "diff3_mixed",
            disable_diagnostics = true,
          },
        },
        keymaps = {
          view = {
            { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close Diffview" } },
          },
          file_panel = {
            { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close Diffview" } },
            { "n", "s", actions.toggle_stage_entry, { desc = "Stage / unstage file" } },
          },
          file_history_panel = {
            { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close Diffview" } },
          },
        },
      })
    end,
  },
}
