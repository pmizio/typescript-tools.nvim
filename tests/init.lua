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
vim.env.XDG_CONFIG_HOME = get_root ".tests/config"
vim.env.XDG_DATA_HOME = get_root ".tests/data"
vim.env.XDG_STATE_HOME = get_root ".tests/state"
vim.env.XDG_CACHE_HOME = get_root ".tests/cache"
vim.o.noswapfile = true
vim.cmd.packloadall { bang = true }

_G.initialized = false

local old_handler = vim.lsp.handlers["$/progress"]
vim.lsp.handlers["$/progress"] = function(...)
  _G.initialized = true
  old_handler(...)
end

require("typescript-tools").setup {
  on_attach = function() end,
}

function P(arg)
  print(vim.inspect(arg))
end
