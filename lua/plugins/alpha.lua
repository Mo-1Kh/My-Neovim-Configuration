return {
  {
    "nvimdev/dashboard-nvim",
    event = "VimEnter",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("dashboard").setup({
        theme = "hyper",

        config = {
          week_header = {
            enable = true,
          },

          shortcut = {
            {
              desc = "󰈞 Find Files",
              group = "Label",
              action = "Telescope find_files",
              key = "f",
            },
            {
              desc = "󰱼 Live Grep",
              group = "DiagnosticHint",
              action = "Telescope live_grep",
              key = "g",
            },
            {
              desc = "󰋚 Recent Files",
              group = "Number",
              action = "Telescope oldfiles",
              key = "r",
            },
            {
              desc = "󰒲 Lazy",
              group = "@property",
              action = "Lazy",
              key = "l",
            },
            {
              desc = "󰅚 Quit",
              group = "Error",
              action = "qa",
              key = "q",
            },
          },

          project = {
            enable = true,
            limit = 8,
            icon = "󰉋 ",
            label = " Recent Projects",
            action = "Telescope find_files cwd=",
          },

          mru = {
            enable = true,
            limit = 10,
            icon = "󰋚 ",
            label = " Recent Files",
            cwd_only = false,
          },

          packages = {
            enable = true,
          },

          footer = {
            "",
            "⚡ Happy coding with Neovim",
          },
        },
      })
    end,
  },
}
