local constants = require "typescript-tools.protocol.constants"

local TOKEN = "TSSERVER_LOADING"

--- @class ProjectLoadService
--- @field instance table|nil - static
--- @field loadings_in_progress number - static
--- @field dispatchers table

--- @class ProjectLoadService
local ProjectLoadService = {
  instance = nil,
}

--- @param dispatchers table
function ProjectLoadService:new(dispatchers)
  if not self.instance then
    self.instance = {}
    self.loadings_in_progress = 0
    self.dispatchers = dispatchers

    setmetatable(self.instance, self)
    self.__index = self
  end

  return self.instance
end

--- @private
--- @param event "begin"|"report"|"end"
--- @param message string|nil
function ProjectLoadService:send_progress(event, message)
  vim.schedule(function()
    self.dispatchers.notification(constants.LspMethods.Progress, {
      token = TOKEN,
      value = {
        kind = event,
        title = message,
      },
    })
  end)
end

--- @param response table
function ProjectLoadService:handle_event(response)
  local event = response.event

  if event == constants.TsserverEvents.ProjectLoadingStart then
    self.loadings_in_progress = self.loadings_in_progress + 1
    self:send_progress("begin", "Loading project")
    self:send_progress "report"
  elseif event == constants.TsserverEvents.ProjectLoadingFinish then
    self.loadings_in_progress = self.loadings_in_progress - 1

    if self.loadings_in_progress <= 0 then
      self:send_progress "end"
    end
  end
end

function ProjectLoadService:dispose()
  ProjectLoadService.instance = nil

  if self.loadings_in_progress > 0 then
    self:send_progress "end"
  end
end

return ProjectLoadService
