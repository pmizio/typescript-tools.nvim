-- this file create separate XDG path
-- thus Lazy.nvim doesnt takes control over the loading

local function get_root(root)
  local f = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(f, ":p:h:h") .. "/" .. (root or "")
end

local function load(plugin)
  local name = plugin:match ".*/(.*)"
  local package_root = get_root ".tests/site/pack/deps/start/"
  if not vim.loop.fs_stat(package_root .. name) then
    print("Installing " .. plugin)
    vim.fn.mkdir(package_root, "p")
    vim.fn.system {
      "git",
      "clone",
      "--depth=1",
      "https://github.com/" .. plugin .. ".git",
      package_root .. "/" .. name,
    }
  end
end

vim.cmd [[set runtimepath=$VIMRUNTIME]]
vim.opt.runtimepath:append(get_root())
vim.opt.packpath = { get_root ".tests/site" }
load "nvim-lua/plenary.nvim"
load "neovim/nvim-lspconfig"
load "nvim-treesitter/nvim-treesitter"
vim.env.XDG_CONFIG_HOME = get_root ".tests/config"
vim.env.XDG_DATA_HOME = get_root ".tests/data"
vim.env.XDG_STATE_HOME = get_root ".tests/state"
vim.env.XDG_CACHE_HOME = get_root ".tests/cache"
vim.opt.swapfile = false
vim.cmd.packloadall { bang = true }

_G.initialized = false
_G.file_opened = false
_G.file_closed = false
_G.initial_diagnostics_emitted = false

local c = require "typescript-tools.protocol.constants"
local old_diagnostic_handler = vim.lsp.handlers[c.CustomMethods.Diagnostic]

vim.lsp.handlers[c.CustomMethods.Diagnostic] = function(...)
  _G.initial_diagnostics_emitted = true
  old_diagnostic_handler(...)
end

local old_handler = vim.lsp.handlers["$/progress"]
vim.lsp.handlers["$/progress"] = function(err, result, ...)
  local value = result.value or {}
  _G.initialized = value.kind == "end"
  old_handler(err, result, ...)
end

local augroup = vim.api.nvim_create_augroup("TypescriptToolsTestsGroup", { clear = true })

vim.api.nvim_create_autocmd("User", {
  pattern = "TypescriptTools_textDocument/didOpen",
  callback = function(e)
    _G.file_opened = e.data.command == "updateOpen" or e.data.command == "configure"
  end,
  group = augroup,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "TypescriptTools_textDocument/didClose",
  callback = function()
    _G.file_closed = true
  end,
  group = augroup,
})

require("nvim-treesitter.configs").setup {
  ensure_installed = { "typescript" },
  sync_install = true,
}

require("typescript-tools").setup {
  settings = {
    separate_diagnostic_server = false,
    tsserver_file_preferences = {
      includeInlayEnumMemberValueHints = true,
      includeInlayFunctionLikeReturnTypeHints = true,
      includeInlayVariableTypeHints = true,
    },
    code_lens = "all",
  },
}

function P(arg)
  print(vim.inspect(arg))
end
