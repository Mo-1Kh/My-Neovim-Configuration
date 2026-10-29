return {
  {
    "nvim-tree/nvim-web-devicons",
    lazy = false,
    config = function()
      require("nvim-web-devicons").setup({
        color_icons = true,
        default = true,
        strict = true,
        override_by_filename = {
          [".gitignore"] = {
            icon = "󰊢",
            color = "#f1502f",
            name = "GitIgnore",
          },
          [".env"] = {
            icon = "",
            color = "#faf743",
            name = "Env",
          },
          ["lazy-lock.json"] = {
            icon = "󰒲",
            color = "#83a598",
            name = "LazyLock",
          },
          ["Dockerfile"] = {
            icon = "󰡨",
            color = "#458ee6",
            name = "Dockerfile",
          },
          ["docker-compose.yml"] = {
            icon = "󰡨",
            color = "#458ee6",
            name = "DockerCompose",
          },
        },
        override_by_extension = {
          ["log"] = {
            icon = "",
            color = "#81e043",
            name = "Log",
          },
        },
      })
    end,
  },
}
