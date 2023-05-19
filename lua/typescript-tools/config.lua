---@class Settings
---@field plugin_name string
---@field separate_diagnostic_server boolean
---@field tsserver_logs string
---@field publish_diagnostic_on publish_diagnostic_mode
---@field tsserver_plugins string[]
local M = {}
local __store = {}

---@enum tsserver_log_level
M.tsserver_log_level = {
  normal = "normal",
  terse = "terse",
  verbose = "verbose",
  off = "off",
}

---@enum publish_diagnostic_mode
M.publish_diagnostic_mode = {
  insert_leave = "insert_leave",
  change = "change",
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
    ["settings.publish_diagnostic_on"] = { settings.publish_diagnostic_on, "string", true },
    ["settings.tsserver_plugins"] = { settings.tsserver_plugins, "table", true },
  }

  __store = vim.tbl_deep_extend("force", __store, settings)

  if not M.tsserver_log_level[settings.tsserver_logs] then
    __store.tsserver_logs = "off"
  end

  if not M.publish_diagnostic_mode[settings.publish_diagnostic_on] then
    __store.tsserver_logs = "insert_leave"
  end

  if not settings.tsserver_plugins then
    __store.tsserver_plugins = {}
  end
end

setmetatable(M, {
  __index = function(_, key)
    return __store[key]
  end,
})

return M
