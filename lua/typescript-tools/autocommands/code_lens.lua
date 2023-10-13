local api = vim.api

local common = require "typescript-tools.autocommands.common"
local utils = require "typescript-tools.utils"

local M = {}

function M.setup_code_lens_autocmds()
  local augroup = vim.api.nvim_create_augroup("TypescriptToolsCodeLensGroup", { clear = true })

  common.create_lsp_attach_augcmd(function()
    pcall(vim.lsp.codelens.refresh)

    api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "CursorHold" }, {
      pattern = common.extensions_pattern,
      callback = function(e)
        if not utils.get_typescript_client(e.buf) then
          return
        end

        ---@type string
        local file = e.file

        if file and file:find "%w+://.*" then
          return
        end

        pcall(vim.lsp.codelens.refresh)
      end,
      group = augroup,
    })
  end, augroup)
end

return M
