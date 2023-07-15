local c = require "typescript-tools.protocol.constants"
local plugin_config = require "typescript-tools.config"
local workspace_diagnostic = require "typescript-tools.protocol.workspace.diagnostic"

local M = {}

M.cache = {}

local lsp_severity_to_symbol = {
  [c.DiagnosticSeverity.Error] = "E",
  [c.DiagnosticSeverity.Warning] = "W",
  [c.DiagnosticSeverity.Hint] = "N",
  [c.DiagnosticSeverity.Information] = "I",
}

local function set_quickfix_content()
  local items = {}

  for file, diagnostics in pairs(M.cache) do
    for _, diagnostic in pairs(diagnostics) do
      local range = diagnostic.range

      table.insert(items, {
        filename = vim.uri_to_fname(file),
        text = diagnostic.message,
        type = lsp_severity_to_symbol[diagnostic.severity],
        lnum = range.start.line + 1,
        col = range.start.character + 1,
      })
    end
  end

  vim.fn.setqflist({}, " ", { title = "TypeScript workspace diagnostics", items = items })
end

function M.setup()
  local originalProgressHandler = vim.lsp.handlers[c.LspMethods.Progress]
  vim.lsp.handlers[c.LspMethods.Progress] = function(err, result, ctx)
    if
      result and result.token:find(workspace_diagnostic.workspace_diagnostic_token_prefix, 1, true)
    then
      for _, item in ipairs(result.value.items) do
        M.cache[item.uri] = M.cache[item.uri] or {}

        for _, diagnostic in ipairs(item.items) do
          table.insert(M.cache[item.uri], diagnostic)
        end
      end

      set_quickfix_content()
      return
    end

    originalProgressHandler(err, result, ctx)
  end

  vim.lsp.handlers[c.LspMethods.WorkspaceDiagnostic] = function(_, result, ctx)
    local client = vim.lsp.get_client_by_id(ctx.client_id)

    if client and client.name ~= plugin_config.plugin_name then
      return
    end

    M.cache = {}
    M.cache[result.uri] = {}

    for _, diagnostic in ipairs(result.items) do
      table.insert(M.cache[result.uri], diagnostic)
    end

    set_quickfix_content()
    vim.api.nvim_command "botright copen"
  end
end

return M
