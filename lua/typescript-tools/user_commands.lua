local constants = require "typescript-tools.protocol.constants"

local M = {}

local function send_organize_import_request(skipDestructiveCodeActions)
  return function()
    vim.lsp.buf_request(
      0,
      constants.CustomMethods.OrganizeImports,
      { file = vim.fn.expand "%p", skipDestructiveCodeActions = skipDestructiveCodeActions },
      function(_, result)
        if not result or not result.changes then
          return
        end

        vim.lsp.util.apply_workspace_edit(result, "utf-8")
      end
    )
  end
end

M.setup_user_commands = function()
  vim.api.nvim_create_user_command(
    "TSToolsOrganizeImports",
    send_organize_import_request(false),
    {}
  )

  vim.api.nvim_create_user_command("TSToolsSortImports", send_organize_import_request(true), {})
end

return M
