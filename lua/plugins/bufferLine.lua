return {
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      -- Close a buffer without closing the window (prevents Neo-tree from taking the whole screen)
      local function close_buffer(bufnr)
        bufnr = bufnr or vim.api.nvim_get_current_buf()
        if vim.bo[bufnr].filetype == "neo-tree" then
          return
        end

        local buffers = vim.tbl_filter(function(b)
          return b.buflisted == 1 and b.bufnr ~= bufnr and vim.bo[b.bufnr].filetype ~= "neo-tree"
        end, vim.fn.getbufinfo({ buflisted = 1 }))

        for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
          vim.api.nvim_win_call(win, function()
            if #buffers > 0 then
              vim.cmd("BufferLineCyclePrev")
              if vim.api.nvim_get_current_buf() == bufnr then
                vim.api.nvim_set_current_buf(buffers[1].bufnr)
              end
            else
              vim.cmd("enew")
            end
          end)
        end

        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.cmd("bdelete! " .. bufnr)
        end
      end

      -- Ensure buffer switching happens in an editor window, not inside the Neo-tree sidebar
      local function focus_editor_then(cmd)
        return function()
          if vim.bo.filetype == "neo-tree" then
            local found_editor = false
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              local buf = vim.api.nvim_win_get_buf(win)
              if vim.bo[buf].filetype ~= "neo-tree" then
                vim.api.nvim_set_current_win(win)
                found_editor = true
                break
              end
            end
            if not found_editor then
              vim.cmd("botright vsplit")
            end
          end
          vim.cmd(cmd)
        end
      end

      require("bufferline").setup({
        options = {
          mode = "buffers",

          separator_style = "slant",

          always_show_bufferline = true,
          show_buffer_icons = true,
          color_icons = true,
          show_buffer_close_icons = true,
          show_close_icon = false,
          buffer_close_icon = "󰅖",
          modified_icon = "●",
          left_trunc_marker = "",
          right_trunc_marker = "",

          close_command = close_buffer,
          right_mouse_command = close_buffer,

          numbers = "ordinal",
          diagnostics = "nvim_lsp",
          diagnostics_indicator = function(count, level)
            local icon = level:match("error") and " " or (level:match("warning") and " " or " ")
            return " " .. icon .. count
          end,

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

      -- Navigate between buffers (tabs)
      vim.keymap.set("n", "<S-l>", focus_editor_then("BufferLineCycleNext"), { desc = "Next buffer" })
      vim.keymap.set("n", "<S-h>", focus_editor_then("BufferLineCyclePrev"), { desc = "Previous buffer" })

      -- Reorder buffers left/right
      vim.keymap.set("n", "<A-l>", "<cmd>BufferLineMoveNext<CR>", { desc = "Move buffer right" })
      vim.keymap.set("n", "<A-h>", "<cmd>BufferLineMovePrev<CR>", { desc = "Move buffer left" })

      -- Jump to buffer by number (1-9)
      for i = 1, 9 do
        vim.keymap.set("n", "<leader>" .. i, focus_editor_then("BufferLineGoToBuffer " .. i), { desc = "Go to buffer " .. i })
      end

      -- Pick a buffer interactively by letter
      vim.keymap.set("n", "<leader>bp", focus_editor_then("BufferLinePick"), { desc = "Pick buffer" })
      vim.keymap.set("n", "<leader>P", "<cmd>BufferLineTogglePin<CR>", { desc = "Pin/Unpin buffer" })

      -- Close buffers (tabs)
      vim.keymap.set("n", "<leader>x", function()
        close_buffer()
      end, { desc = "Close current buffer" })
      vim.keymap.set("n", "<leader>bc", "<cmd>BufferLinePickClose<CR>", { desc = "Pick buffer to close" })
      vim.keymap.set("n", "<leader>bo", "<cmd>BufferLineCloseOthers<CR>", { desc = "Close all other buffers" })
      vim.keymap.set("n", "<leader>br", "<cmd>BufferLineCloseRight<CR>", { desc = "Close buffers to the right" })
      vim.keymap.set("n", "<leader>bl", "<cmd>BufferLineCloseLeft<CR>", { desc = "Close buffers to the left" })

      -- Split screen management
      vim.keymap.set("n", "<leader>sv", "<cmd>vsplit<CR>", { desc = "Split window vertically" })
      vim.keymap.set("n", "<leader>sh", "<cmd>split<CR>", { desc = "Split window horizontally" })
      vim.keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
      vim.keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split window" })
    end,
  },
}
