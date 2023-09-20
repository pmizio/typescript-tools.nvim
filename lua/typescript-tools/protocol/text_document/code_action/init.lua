local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"
local plugin_config = require "typescript-tools.config"

local M = {}

local ALL_CODE_ACTIONS_KEY = "all"

local internal_commands_map = {
  fix_all = { name = "Fix all problems" },
  remove_unused = { name = "Remove unused" },
  add_missing_imports = { name = "Add all missing imports" },
  remove_unused_imports = { name = "Remove unused imports" },
  organize_imports = { name = "Organize imports" },
}

--- @param kind string
--- @return CodeActionKind|nil
local function make_lsp_code_action_kind(kind)
  if
    kind:find("extract", 1, true)
    or kind:find("move", 1, true)
    or kind:find("inline", 1, true)
  then
    return c.CodeActionKind.RefactorExtract
  elseif kind:find("rewrite", 1, true) then
    return c.CodeActionKind.RefactorRewrite
  end

  -- TODO: maybe we want add other kinds but for now it is ok
  return nil
end

---@type TsserverProtocolHandler
function M.handler(request, response, params, ctx)
  local text_document = params.textDocument

  local range = utils.convert_lsp_range_to_tsserver(params.range)

  local request_range = {
    file = vim.uri_to_fname(text_document.uri),
    startLine = range.start.line,
    startOffset = range.start.offset,
    endLine = range["end"].line,
    endOffset = range["end"].offset,
  }

  ctx.dependent_seq = {
    -- tsserver protocol reference:
    -- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L405
    request {
      command = c.CommandTypes.GetApplicableRefactors,
      arguments = request_range,
    },
    -- tsserver protocol reference:
    -- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L526
    request {
      command = c.CommandTypes.GetCodeFixes,
      arguments = vim.tbl_extend("force", request_range, {
        errorCodes = vim.tbl_map(function(diag)
          return diag.code
        end, params.context.diagnostics),
      }),
    },
  }

  local body = coroutine.yield()
  local code_actions = {}

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L418
  for _, refactor in ipairs(body) do
    for _, action in ipairs(refactor.actions or {}) do
      local kind = make_lsp_code_action_kind(action.kind or "")

      if kind and not action.notApplicableReason then
        table.insert(code_actions, {
          title = action.description,
          kind = kind,
          data = vim.tbl_extend("force", request_range, {
            action = action.name,
            kind = kind,
            refactor = refactor.name,
          }),
        })
      end
    end
  end

  body = coroutine.yield()

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L585
  for _, fix in ipairs(body) do
    table.insert(code_actions, {
      title = fix.description,
      kind = c.CodeActionKind.QuickFix,
      edit = {
        changes = utils.convert_tsserver_edits_to_lsp(fix.changes),
      },
    })
  end

  local exposed_code_actions = type(plugin_config.expose_as_code_action) == "string"
      and plugin_config.expose_as_code_action == ALL_CODE_ACTIONS_KEY
      and vim.tbl_keys(internal_commands_map)
    or plugin_config.expose_as_code_action

  for _, cmd in ipairs(exposed_code_actions) do
    local action_config = internal_commands_map[cmd]

    table.insert(code_actions, {
      title = action_config.name,
      kind = c.CodeActionKind.QuickFix,
      command = {
        title = action_config.name,
        command = c.InternalCommands.CallApiFunction,
        arguments = { cmd },
      },
    })
  end

  response(code_actions)
end

return M
