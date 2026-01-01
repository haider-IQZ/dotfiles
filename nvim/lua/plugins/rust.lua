return {
  -- Add rust-analyzer to lspconfig
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              inlayHints = {
                bindingModeHints = { enable = false },
                chainingHints = { enable = false },
                closingBraceHints = { enable = false },
                closureReturnTypeHints = { enable = false },
                parameterHints = { enable = false },
                reborrowHints = { enable = false },
                renderColons = { enable = false },
                typeHints = { enable = false },
              },
            },
          },
        },
      },
    },
  },
}
