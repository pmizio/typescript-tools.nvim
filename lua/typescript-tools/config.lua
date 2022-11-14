local M = {}

--- @private
local __store = {}

M.NAME = "typescript-tools"

M.COMPOSITE_MODES = {
  SINGLE = "single",
  SEPARATE_DIAGNOSTIC = "separate_diagnostic",
}

vim.tbl_add_reverse_lookup(M.COMPOSITE_MODES)

M.PUBLISH_DIAGNOSTIC_ON = {
  CHANGE = "change",
  INSERT_LEAVE = "insert_leave",
}

vim.tbl_add_reverse_lookup(M.PUBLISH_DIAGNOSTIC_ON)

--- @param settings table
M.load_and_validate = function(settings)
  --- @param enum table
  --- @param key string
  --- @param default_value any
  --- @return function, string
  local function validate_enum(enum, key, default_value)
    local modes = table.concat(vim.tbl_values(enum), ", ")

    return function(value)
      if type(value) ~= "nil" and not enum[value] then
        return false
      end

      if type(value) == "nil" and default_value then
        settings[key] = default_value
      end

      return true
    end,
      "one of " .. modes
  end

  vim.validate {
    settings = { settings, "table" },
    ["settings.composite_mode"] = {
      settings.composite_mode,
      validate_enum(M.COMPOSITE_MODES, "composite_mode", M.COMPOSITE_MODES.SINGLE),
    },
    ["settings.publish_diagnostic_on"] = {
      settings.publish_diagnostic_on,
      validate_enum(
        M.PUBLISH_DIAGNOSTIC_ON,
        "publish_diagnostic_on",
        M.PUBLISH_DIAGNOSTIC_ON.INSERT_LEAVE
      ),
    },
    ["settings.debug"] = { settings.debug, "boolean", true },
    ["settings.enable_formatting"] = { settings.enable_formatting, "boolean", true },
    ["settings.enable_styled_components_plugin"] = {
      settings.enable_styled_components_plugin,
      "boolean",
      true,
    },
  }

  local logs = settings.tsserver_logs

  if logs then
    vim.validate {
      ["settings.tsserver_logs"] = { logs, "table" },
      ["settings.tsserver_logs.verbosity"] = { logs.verbosity, "string" },
      ["settings.tsserver_logs.file_basename"] = { logs.file_basename, "string" },
    }
  end

  __store = vim.tbl_deep_extend("force", __store, settings)
end

M.set_global_npm_path = function(path)
  __store.global_npm_path = path
end

setmetatable(M, {
  __index = function(_, key)
    return __store[key]
  end,
})

return M
