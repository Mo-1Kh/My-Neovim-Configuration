return {
  {
    "nvim-telescope/telescope-ui-select.nvim",
  },
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.5",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("telescope").setup({
        extensions = {
          ["ui-select"] = {
            require("telescope.themes").get_dropdown({}),
          },
        },
      })

      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files (Telescope)" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep across project (Telescope)" })
      vim.keymap.set("n", "<leader><leader>", builtin.oldfiles, { desc = "Recent files (Telescope)" })

      require("telescope").load_extension("ui-select")
    end,
  },
}
