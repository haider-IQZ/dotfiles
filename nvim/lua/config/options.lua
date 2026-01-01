-- Disable line numbers background or cursor line background if needed
-- But usually the issue is the cursorline highlight
vim.opt.cursorline = false 

-- Disable inlay hints (the hard-coded type hints like i32)
vim.g.lazyvim_inlay_hints = false

-- Disable matching paren highlighting (optional, if that's also annoying)
-- vim.g.loaded_matchparen = 1
