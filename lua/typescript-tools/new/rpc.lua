local api = vim.api
local util = require "lspconfig.util"
local configs = require "lspconfig.configs"
local plugin_config = require "typescript-tools.new.config"
local Path = require "plenary.path"

local Tsserver = require "typescript-tools.new.tsserver"
local autocommands = require "typescript-tools.new.autocommands"
local custom_handlers = require "typescript-tools.new.custom_handlers"
local request_router = require "typescript-tools.new.request_router"

local M = {}

---@param dispatchers Dispatchers
---@return LspInterface
function M.start(dispatchers)
  local config = configs[plugin_config.plugin_name]
  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)

  assert(util.bufname_valid(bufname), "Invalid buffer name!")

  local root_dir = config.get_root_dir(util.path.sanitize(bufname), bufnr)
  local tsserver_path = Path:new(root_dir, "node_modules", "typescript", "lib", "tsserver.js")

  local npm_global_path = vim.fn
    .system([[node -p "require('path').resolve(process.execPath, '../..')"]])
    :match "^%s*(.-)%s*$"

  -- INFO: if we can't find local tsserver try to use global installed one
  if not tsserver_path:exists() then
    tsserver_path = Path:new(npm_global_path, "bin", "tsserver")
  end

  -- INFO: if there is no local or global tsserver just error out
  assert(
    tsserver_path:exists(),
    "Cannot find tsserver executable in local project nor global npm installation."
  )

  local tsserver_syntax = Tsserver:new(tsserver_path, "syntax", dispatchers)
  local tsserver_diagnostic = nil
  if plugin_config.separate_diagnostic_server then
    tsserver_diagnostic = Tsserver:new(tsserver_path, "diagnostic", dispatchers)
  end

  autocommands.setup_autocommands()
  custom_handlers.setup_lsp_handlers(dispatchers)

  return {
    request = function(...)
      return request_router.route_request(tsserver_syntax, tsserver_diagnostic, ...)
    end,
    notify = function(...)
      request_router.route_request(tsserver_syntax, tsserver_diagnostic, ...)
    end,
    terminate = function()
      tsserver_syntax:terminate()
      if tsserver_diagnostic then
        tsserver_diagnostic:terminate()
      end
    end,
    is_closing = function()
      local ret = tsserver_syntax:is_closing()
      if tsserver_diagnostic then
        ret = ret and tsserver_diagnostic:is_closing()
      end

      return ret
    end,
  }
end

return M
