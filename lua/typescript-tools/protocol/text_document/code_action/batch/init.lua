local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

---@param all_changes table - table to add new changes to
---@param response table - code_action response from tsserver
---@param file_uri string - uri of the file that code action will be run
local function add_changes_from_response(all_changes, response, file_uri)
  if not response.changes then
    return
  end

  local lsp_response = utils.convert_tsserver_edits_to_lsp(response.changes)[file_uri]

  if not lsp_response then
    return
  end

  for _, change in ipairs(lsp_response) do
    table.insert(all_changes, change)
  end
end

---@param diagnostics table - table of all file diagnostics
---@param diagnostics_error_codes table - all of the error codes that are allowed to be fixed
---@returns table - list of diagnostics from tsserver with given error codes
local function get_diagnostics_to_fix(diagnostics, diagnostics_error_codes)
  return vim.tbl_filter(function(diagnostic)
    return diagnostic.source == c.DiagnosticSource
      and vim.tbl_contains(diagnostics_error_codes, diagnostic.code)
  end, diagnostics)
end

---@param diagnostic table - diagnostic to make a code action for
---@param fname string - file name of the file that code action will be run
---@returns table - parameters for 'GetCodeFixes' request
local function make_code_action_params(diagnostic, fname)
  return {
    file = fname,
    startLine = diagnostic.lnum + 1,
    startOffset = diagnostic.col + 1,
    endLine = diagnostic.end_lnum + 1,
    endOffset = diagnostic.end_col,
    errorCodes = { diagnostic.code },
  }
end

---@type TsserverProtocolHandler
function M.handler(request, response, params, ctx)
  local bufnr = params.bufnr
  local uri = vim.uri_from_bufnr(bufnr)
  local fname = vim.uri_to_fname(uri)

  local diagnostics = get_diagnostics_to_fix(params.diagnostics, params.error_codes)

  if #diagnostics == 0 then
    request {
      response = { edit = {} },
    }
    return
  end

  ctx.dependent_seq = vim.tbl_map(function(diagnostic)
    return request {
      command = c.CommandTypes.GetCodeFixes,
      arguments = make_code_action_params(diagnostic, fname),
    }
  end, diagnostics)

  local final_changes = {}

  local fixes_ids_to_combine = {}

  for _ in ipairs(diagnostics) do
    -- tsserver protocol reference:
    -- https://github.com/microsoft/TypeScript/blob/c18791ccf165672df3b55f5bdd4a8655f33be26c/lib/protocol.d.ts#L585
    local body = coroutine.yield()

    for _, fix in ipairs(body) do
      if fix and vim.tbl_contains(params.fix_names, fix.fixName) then
        -- if `fixId` is present we only ask one time for `getCombinedCodeFix` that returns all of the fixes
        -- for given id
        if fix.fixId then
          fixes_ids_to_combine[fix.fixId] = true
        -- if `fixId` is not present we just apply the changes from this fix, because it cannot be applied in the group
        else
          add_changes_from_response(final_changes, fix, uri)
          goto continue
        end
      end
    end
    ::continue::
  end

  for fix_id in pairs(fixes_ids_to_combine) do
    -- tsserver protocol reference:
    -- https://github.com/microsoft/TypeScript/blob/v5.1.3/src/server/protocol.ts#L780
    request {
      command = c.CommandTypes.GetCombinedCodeFix,
      arguments = {
        scope = {
          type = "file",
          args = {
            file = fname,
          },
        },
        fixId = fix_id,
      },
    }
  end

  for _ in pairs(fixes_ids_to_combine) do
    -- tsserver protocol reference:
    -- https://github.com/microsoft/TypeScript/blob/v5.1.5/src/server/protocol.ts#L785
    local body = coroutine.yield()

    add_changes_from_response(final_changes, body, uri)
  end

  response {
    edit = { changes = { [uri] = final_changes } },
    kind = c.CodeActionKind.QuickFix,
    title = "Batch code fix",
  }
end

return M
