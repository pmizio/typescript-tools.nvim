---@class Settings
---@field plugin_name string
---@field separate_diagnostic_server boolean
---@field tsserver_logs string
local M = {}
local __store = {}

---@enum tsserver_log_level
M.tsserver_log_level = {
  normal = "normal",
  terse = "terse",
  verbose = "verbose",
  off = "off",
}

M.plugin_name = "typescript-tools"

---@param settings table
function M.load_settings(settings)
  vim.validate {
    settings = { settings, "table", true },
    ["settings.separate_diagnostic_server"] = {
      settings.separate_diagnostic_server,
      "boolean",
      true,
    },
    ["settings.tsserver_logs"] = { settings.tsserver_logs, "string", true },
  }

  __store = vim.tbl_deep_extend("force", __store, settings)

  if not M.tsserver_log_level[settings.tsserver_logs] then
    __store.tsserver_logs = "off"
  end
end

setmetatable(M, {
  __index = function(_, key)
    return __store[key]
  end,
})

return M
