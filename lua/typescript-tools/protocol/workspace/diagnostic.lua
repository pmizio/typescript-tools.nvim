local c = require "typescript-tools.protocol.constants"
local document_diagnostic = require "typescript-tools.protocol.text_document.custom_diagnostic"

local M = {}

M.workspace_diagnostic_token_prefix = "workspace_diagnostic_"

---@class WorkspaceDiagnosticNotification
---@field dispatchers Dispatchers
---@field token string
---@field items table

---@param kind "begin"|"report"|"end"
---@param opts WorkspaceDiagnosticNotification
local send_progress_notification = vim.schedule_wrap(function(kind, opts)
  opts.dispatchers.notification(c.LspMethods.Progress, {
    token = opts.token,
    value = {
      kind = kind,
      title = "Calculating workspace diagnostics...",
      items = opts.items,
    },
  })
end)

---@type TsserverProtocolHandler
function M.handler(request, response, _, ctx)
  local buf_name = vim.api.nvim_buf_get_name(0)

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/94f03cf0c6eb5cb3a391e817db9c9a7bb9f1de6c/src/server/protocol.ts#L2756
  local seq = request {
    command = c.CommandTypes.GeterrForProject,
    arguments = {
      file = buf_name,
      delay = 0,
    },
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/2da62a784bbba237b8239e84c8629cfafb0f595e/lib/protocol.d.ts#L2171
  local body, command = coroutine.yield()
  local init = false

  local opts = {
    token = M.workspace_diagnostic_token_prefix .. seq,
    dispatchers = ctx.dispatchers,
  }

  send_progress_notification("begin", opts)

  repeat
    send_progress_notification("report", opts)

    if body.file and not body.file:find("node_modules", 1, true) then
      local items = {}
      local file = vim.uri_from_fname(body.file)

      for _, diagnostic in pairs(body.diagnostics or {}) do
        table.insert(items, document_diagnostic.tsserver_diagnostic_to_lsp(diagnostic))
      end

      if #items > 0 then
        local diagnostic_response = {
          uri = file,
          kind = c.DocumentDiagnosticReportKind.Full,
          items = items,
        }

        if not init then
          init = true
          response(diagnostic_response)
        else
          send_progress_notification(
            "report",
            vim.tbl_extend("force", {
              items = { diagnostic_response },
            }, opts)
          )
        end
      end
    end

    body, command = coroutine.yield()
  until command == c.DiagnosticEventKind.RequestCompleted

  if not init then
    response {}
  end

  send_progress_notification("end", opts)
end

return M
