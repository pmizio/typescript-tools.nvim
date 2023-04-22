local c = require "typescript-tools.new.protocol.constants"
local utils = require "typescript-tools.new.protocol.utils"
local protocol = require "typescript-tools.new.protocol"

--- @param kind string
--- @return CodeActionKind|nil
local make_lsp_code_action_kind = function(kind)
  if kind:find("extract", 1, true) then
    return c.CodeActionKind.RefactorExtract
  elseif kind:find("rewrite", 1, true) then
    return c.CodeActionKind.RefactorRewrite
  end

  -- TODO: maybe we want add other kinds but for now it is ok
  return nil
end

--- @param title string
--- @param destructive boolean
--- @return table
local function make_imports_action(file, title, destructive)
  return {
    title = title,
    kind = c.CodeActionKind.SourceOrganizeImports,
    data = {
      scope = {
        type = "file",
        args = { file = file },
      },
      skipDestructiveCodeActions = destructive,
    },
  }
end

---@param _ string
---@param params table
---@return TsserverRequest | TsserverRequest[], function|nil, RequestOptions
local function code_action_creator(_, params)
  local text_document = params.textDocument

  local range = utils.convert_lsp_range_to_tsserver(params.range)
  local request_range = {
    file = vim.uri_to_fname(text_document.uri),
    startLine = range.start.line,
    startOffset = range.start.offset,
    endLine = range["end"].line,
    endOffset = range["end"].offset,
  }

  ---@type TsserverRequest[]
  local requests = {
    -- tsserver protocol reference:
    -- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L405
    {
      command = c.CommandTypes.GetApplicableRefactors,
      arguments = request_range,
    },
    -- tsserver protocol reference:
    -- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L526
    {
      command = c.CommandTypes.GetCodeFixes,
      arguments = vim.tbl_extend("force", request_range, {
        errorCodes = vim.tbl_map(function(diag)
          return diag.code
        end, params.context.diagnostics),
      }),
    },
  }

  ---@param body table
  ---@return table
  local function handler(body)
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

    body = coroutine.yield(protocol.multi_response)

    -- tsserver protocol reference:
    -- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L585
    if #code_actions == 0 then
      table.insert(code_actions, make_imports_action(request_range.file, "Organize imports", false))
      table.insert(code_actions, make_imports_action(request_range.file, "Sort imports", true))
    end

    for _, fix in ipairs(body) do
      table.insert(code_actions, {
        title = fix.description,
        kind = c.CodeActionKind.QuickFix,
        edit = {
          changes = utils.convert_tsserver_edits_to_lsp(fix.changes),
        },
      })
    end

    return code_actions
  end

  return requests, handler, { collect_all = true }
end

return code_action_creator
