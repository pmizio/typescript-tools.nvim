local api = vim.api
local util = require "lspconfig.util"
local configs = require "lspconfig.configs"
local plugin_config = require "typescript-tools.config"
local Path = require "plenary.path"

local TsserverInstance = require "typescript-tools.tsserver_instance"
local internal_commands = require "typescript-tools.internal_commands"
local constants = require "typescript-tools.protocol.constants"

local DIAGNOSTICS_ALLOWED = {
  constants.LspMethods.Initialize,
  constants.LspMethods.DidOpen,
  constants.LspMethods.DidChange,
  constants.LspMethods.DidClose,
  constants.LspMethods.Shutdown,
}

vim.tbl_add_reverse_lookup(DIAGNOSTICS_ALLOWED)

local M = {}

--- @param server_name string
--- @returns Methods:
--- - `notify()` |vim.lsp.rpc.notify()|
--- - `request()` |vim.lsp.rpc.request()|
--- - `is_closing()` returns a boolean indicating if the RPC is closing.
--- - `terminate()` terminates the RPC client.
M.start = function(server_name, dispatchers)
  local config = configs[server_name]
  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)
  if not util.bufname_valid(bufname) then
    return
  end

  local root_dir = config.get_root_dir(util.path.sanitize(bufname), bufnr)
  local tsserver_path = Path:new(root_dir, "node_modules", "typescript", "lib", "tsserver.js")

  local npm_global_path = vim.fn.system(
    [[node -p "require('path').resolve(process.execPath, '../..')"]]
  ):match "^%s*(.-)%s*$"
  plugin_config.set_global_npm_path(npm_global_path)

  -- INFO: if we can't find local tsserver try to use global installed one
  if not tsserver_path:exists() then
    tsserver_path = Path:new(npm_global_path, "bin", "tsserver")
  end

  -- INFO: if there is no local or global tsserver just error out
  assert(
    tsserver_path:exists(),
    "Cannot find tsserver executable in local project nor global npm installation."
  )

  local has_separate_diagonstic = plugin_config.composite_mode
    == plugin_config.COMPOSITE_MODES.SEPARATE_DIAGNOSTIC

  local primary_server = TsserverInstance
    :new(
      tsserver_path,
      has_separate_diagonstic and constants.ServerCompositeType.Primary
        or constants.ServerCompositeType.Single,
      dispatchers
    )
    :get_lsp_interface()
  local diagnostics_server = nil

  if has_separate_diagonstic then
    diagnostics_server = TsserverInstance
      :new(tsserver_path, constants.ServerCompositeType.Diagnostics, dispatchers)
      :get_lsp_interface()
  end

  --- @param fn 'request'|'notify'|'terminate'
  --- @param without_request_check boolean|nil
  --- @return function
  local diapatch_to_servers = function(fn, without_request_check)
    return function(method, ...)
      -- INFO: tsserver don't have any commans we can capture them and use for internal features eg. rename after refactors
      if method == constants.LspMethods.ExecuteCommand then
        internal_commands.handle_command(...)
        return
      end

      if diagnostics_server and (DIAGNOSTICS_ALLOWED[method] or without_request_check) then
        diagnostics_server[fn](method, ...)
      end

      return primary_server[fn](method, ...)
    end
  end

  return {
    request = diapatch_to_servers "request",
    notify = diapatch_to_servers "notify",
    terminate = diapatch_to_servers("terminate", true),
    is_closing = function()
      local ret = primary_server.is_closing()

      if diagnostics_server then
        ret = ret and diagnostics_server.is_closing()
      end

      return ret
    end,
  }
end

return M
