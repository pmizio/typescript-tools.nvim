local api = vim.api

local common = require "typescript-tools.autocommands.common"

local M = {}

function M.setup_code_lens_autocmds()
  local augroup = vim.api.nvim_create_augroup("TypescriptToolsCodeLensGroup", { clear = true })

  common.create_lsp_attach_augcmd(function()
    pcall(vim.lsp.codelens.refresh)

    api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "CursorHold" }, {
      pattern = M.extensions_pattern,
      callback = function(e)
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
