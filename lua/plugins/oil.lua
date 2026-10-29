return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local oil = require("oil")
    oil.setup({
      columns = {
        "icon",
      },
      view_options = {
        show_hidden = true,
      },
    })
    vim.keymap.set("n", "-", oil.toggle_float, { desc = "Open parent directory (Oil)" })
  end,
}
