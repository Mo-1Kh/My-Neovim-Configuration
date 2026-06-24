return {
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("bufferline").setup({
        options = {
          mode = "buffers",

          separator_style = "slant",


          always_show_bufferline = true,
          show_buffer_close_icons = false,
          show_close_icon = false,

          numbers = "ordinal",

          offsets = {
            {
              filetype = "neo-tree",
              text = "File Explorer",
              text_align = "center",
              separator = true,
            },
          },
        },
      })

      vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<CR>")
      vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<CR>")
    end,
  },
}
