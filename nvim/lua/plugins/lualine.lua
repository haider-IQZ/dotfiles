return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      local colors = {
        bg = "#000000",
        fg = "#ebdbb2",
        yellow = "#fabd2f",
        cyan = "#8ec07c",
        darkgray = "#282828",
        gray = "#928374",
        black = "#000000",
        white = "#ebdbb2",
        red = "#fb4934",
        green = "#b8bb26",
        blue = "#83a598",
        orange = "#fe8019",
      }

      local theme = {
        normal = {
          a = { fg = colors.black, bg = colors.blue, gui = "bold" },
          b = { fg = colors.white, bg = colors.darkgray },
          c = { fg = colors.white, bg = colors.black },
        },
        insert = {
          a = { fg = colors.black, bg = colors.yellow, gui = "bold" },
          b = { fg = colors.white, bg = colors.darkgray },
          c = { fg = colors.white, bg = colors.black },
        },
        visual = {
          a = { fg = colors.black, bg = colors.orange, gui = "bold" },
          b = { fg = colors.white, bg = colors.darkgray },
          c = { fg = colors.white, bg = colors.black },
        },
        replace = {
          a = { fg = colors.black, bg = colors.red, gui = "bold" },
          b = { fg = colors.white, bg = colors.darkgray },
          c = { fg = colors.white, bg = colors.black },
        },
        command = {
          a = { fg = colors.black, bg = colors.cyan, gui = "bold" },
          b = { fg = colors.white, bg = colors.darkgray },
          c = { fg = colors.white, bg = colors.black },
        },
        inactive = {
          a = { fg = colors.white, bg = colors.black, gui = "bold" },
          b = { fg = colors.white, bg = colors.black },
          c = { fg = colors.white, bg = colors.black },
        },
      }

      opts.options.theme = theme
    end,
  },
}

