return {
  -- Disable illuminate.vim (highlighting other occurrences of the word under cursor)
  { "RRethy/vim-illuminate", enabled = false },

  -- Disable snacks.nvim words feature (this is likely what's causing the "glowing" now)
  {
    "folke/snacks.nvim",
    opts = {
      words = { enabled = false },
    },
  },
}
