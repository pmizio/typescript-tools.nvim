local api = vim.api
local common = require "typescript-tools.autocommands.common"

local M = {}

function M.autosetup_user_commands()
  local augroup = api.nvim_create_augroup("TypescriptToolsUserCommandsGroup", { clear = true })

  common.create_lsp_attach_augcmd(function()
    require("typescript-tools.user_commands").setup_user_commands()
  end, augroup)
end

return M
