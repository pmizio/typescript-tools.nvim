local c = require "typescript-tools.new.protocol.constants"

local TOKEN = "TSSERVER_LOADING"

---@param event string
---@param message string|nil
---@return table
local function create_message(event, message)
  return {
    token = TOKEN,
    value = {
      kind = event,
      title = message,
    },
  }
end

---@param response table
---@param dispatchers Dispatchers
local function handle_progress(response, dispatchers)
  local notify = vim.schedule_wrap(dispatchers.notification)

  if response.event == c.TsserverEvents.ProjectLoadingStart then
    notify(c.LspMethods.Progress, create_message("begin", "Loading project"))
    notify(c.LspMethods.Progress, create_message "report")
  elseif response.event == c.TsserverEvents.ProjectLoadingFinish then
    notify(c.LspMethods.Progress, create_message "end")
  end
end

return handle_progress
