local c = require "typescript-tools.protocol.constants"
local plugin_config = require "typescript-tools.config"

local M = {}

local TIMEOUT = 1000

local function get_diagnostics_to_fix(diagnostics_error_codes, bufnr)
  local diagnostics = vim.diagnostic.get(bufnr)

  return vim.tbl_filter(function(diagnostic)
    return diagnostic.source == "tsserver"
      and vim.tbl_contains(diagnostics_error_codes, diagnostic.code)
  end, diagnostics)
end

local function make_code_action_params(diagnostic, bufnr)
  local params = vim.lsp.util.make_given_range_params(
    { diagnostic.lnum + 1, diagnostic.col },
    { diagnostic.end_lnum + 1, diagnostic.end_col - 2 },
    bufnr
  )
  params.context = { diagnostics = { diagnostic } }

  return params
end

function M.get_batch_code_fix_updates(diagnostics_error_codes, fix_names)
  local bufnr = 0

  local tsserver_diagnostics_unused = get_diagnostics_to_fix(diagnostics_error_codes, bufnr)

  if #tsserver_diagnostics_unused == 0 then
    return
  end

  local changes = {}

  local buffer_uri = vim.uri_from_bufnr(bufnr)
  local typescript_client = vim.lsp.get_active_clients({ name = plugin_config.plugin_name })[1]

  for _, diagnostic in ipairs(tsserver_diagnostics_unused) do
    local params = make_code_action_params(diagnostic, bufnr)
    -- TODO: handle error
    local results =
      typescript_client.request_sync(c.LspMethods.CodeAction, params, TIMEOUT, bufnr).result

    local actions = vim.tbl_filter(function(result)
      return vim.tbl_contains(fix_names, result.fixName)
    end, results)

    if #actions == 0 then
      return
    end

    for _, action in ipairs(actions) do
      local resolved_action = action

      if not action.edit then
        -- TODO: handle error
        resolved_action =
          typescript_client.request_sync("codeAction/resolve", action, TIMEOUT, bufnr).result
      end

      -- TODO: handle empty or non existent changes
      for _, change in ipairs(resolved_action.edit.changes[buffer_uri]) do
        changes[#changes + 1] = change
      end
    end
  end

  local workspace_edit = {
    changes = {
      [buffer_uri] = changes,
    },
  }

  return workspace_edit
end

return M
