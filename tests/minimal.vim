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

local tests_augroup = vim.api.nvim_create_augroup("TsserverTestsGroup", { clear = true })

vim.api.nvim_create_autocmd("User", {
  pattern = { "tsserver_response_updateOpen" },
  callback = function(event)
    if #event.data.arguments.openFiles > 0 then
      _G.opened = true
    end
  end,
  group = diag_augroup,
})


require("typescript-tools").setup {
  on_attach = function() end,
  settings = {
    enable_formatting = true,
  },
}

function P(arg)
  print(vim.inspect(arg))
end
EOF
