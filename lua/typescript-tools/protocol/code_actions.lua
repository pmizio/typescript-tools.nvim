local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

--- @class CodeActionsService
--- @field server_type string
--- @field tsserver TsserverInstance
--- @field request_id number|nil
--- @field request_range table|nil
--- @field refactors table
--- @field callback function|nil
--- @field notify_reply_callback function|nil

--- @class CodeActionsService
local CodeActionsService = {}

--- @param server_type string
--- @param tsserver TsserverInstance
function CodeActionsService:new(server_type, tsserver)
  local obj = {
    server_type = server_type,
    tsserver = tsserver,
    request_id = nil,
    refactors = {},
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

--- TODO: collect all code fixes from range/line
--- @param params table
--- @param callback function
--- @param notify_reply_callback function
function CodeActionsService:request(params, callback, notify_reply_callback)
  if self.server_type == constants.ServerCompositeType.Diagnostics then
    return
  end

  self.callback = vim.schedule_wrap(callback)
  self.notify_reply_callback = notify_reply_callback and vim.schedule_wrap(notify_reply_callback)
    or nil

  local text_document = params.textDocument
  local range = utils.convert_lsp_range_to_tsserver(params.range)

  self.request_range = {
    file = vim.uri_to_fname(text_document.uri),
    startLine = range.start.line,
    startOffset = range.start.offset,
    endLine = range["end"].line,
    endOffset = range["end"].offset,
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/4635a5cef9aefa9aa847ef7ce2e6767ddf4f54c2/lib/protocol.d.ts#L409
  self.request_id = self.tsserver.request_queue:enqueue {
    message = {
      command = constants.CommandTypes.GetApplicableRefactors,
      arguments = self.request_range,
    },
  }

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/4635a5cef9aefa9aa847ef7ce2e6767ddf4f54c2/lib/protocol.d.ts#L526
  self.tsserver.request_queue:enqueue {
    message = {
      command = constants.CommandTypes.GetCodeFixes,
      arguments = vim.tbl_extend("force", self.request_range, {
        errorCodes = vim.tbl_map(function(diag)
          return diag.code
        end, params.context.diagnostics),
      }),
    },
  }

  return self.request_id
end

--- @private
--- @param kind string
--- @return string|nil
local make_lsp_code_action_kind = function(kind)
  if kind:find("extract", 1, true) then
    return constants.CodeActionKind.RefactorExtract
  elseif kind:find("rewrite", 1, true) then
    return constants.CodeActionKind.RefactorRewrite
  end

  -- TODO: maybe we want add other kinds but for now it is ok
  return nil
end

--- @param title string
--- @param destructive boolean
--- @return table
function CodeActionsService:make_imports_action(title, destructive)
  return {
    title = title,
    kind = constants.CodeActionKind.SourceOrganizeImports,
    data = {
      scope = {
        type = "file",
        args = { file = self.request_range.file },
      },
      skipDestructiveCodeActions = destructive,
    },
  }
end

--- @param response table
function CodeActionsService:handle_response(response)
  if not response.success then
    return
  end

  local command = response.command

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/4635a5cef9aefa9aa847ef7ce2e6767ddf4f54c2/lib/protocol.d.ts#L418
  -- TODO: handle refactors response
  if command == constants.CommandTypes.GetApplicableRefactors then
    self.refactors = {}

    for _, refactor in ipairs(response.body) do
      for _, action in ipairs(refactor.actions) do
        local kind = make_lsp_code_action_kind(action.kind or "")

        if kind and not action.notApplicableReason then
          table.insert(self.refactors, {
            title = action.description,
            kind = kind,
            data = vim.tbl_extend("force", self.request_range, {
              action = action.name,
              kind = kind,
              refactor = refactor.name,
            }),
          })
        end
      end
    end
  end

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/4635a5cef9aefa9aa847ef7ce2e6767ddf4f54c2/lib/protocol.d.ts#L585
  if command == constants.CommandTypes.GetCodeFixes then
    if self.notify_reply_callback then
      self.notify_reply_callback(self.request_id)
    end

    local code_actions = #self.refactors == 0
        and {
          self:make_imports_action("Organize imports", false),
          self:make_imports_action("Sort imports", true),
        }
      or {}

    for _, fix in ipairs(response.body) do
      table.insert(code_actions, {
        title = fix.description,
        kind = constants.CodeActionKind.QuickFix,
        edit = {
          changes = utils.convert_tsserver_edits_to_lsp(fix.changes),
        },
      })
    end

    if self.callback then
      self.callback(nil, vim.list_extend(code_actions, self.refactors))
    end
  end
end

return CodeActionsService
