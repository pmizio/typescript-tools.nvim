set rtp+=.
set rtp+=../plenary.nvim
set rtp+=../nvim-lspconfig
runtime! plugin/plenary.vim
runtime! plugin/nvim-lspconfig
set noswapfile

lua << EOF
_G.initialized = false

local old_handler = vim.lsp.handlers["$/progress"]
vim.lsp.handlers["$/progress"] = function(...)
  _G.initialized = true
  old_handler(...)
end

require("typescript-tools").setup {
  on_attach = on_attach,
}

function P(arg)
  print(vim.inspect(arg))
end
EOF
