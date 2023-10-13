local api = vim.api
local plugin_config = require "typescript-tools.config"

local M = {}

M.extensions_pattern = { "*.js", "*.mjs", "*.jsx", "*.ts", "*.tsx", "*.mts" }

---@param callback function
---@param augroup number
function M.create_lsp_attach_augcmd(callback, augroup)
  local initialized = false

  api.nvim_create_autocmd("LspAttach", {
    pattern = M.extensions_pattern,
    callback = function(e)
      local client = vim.lsp.get_client_by_id(e.data.client_id)

      if (client and client.name ~= plugin_config.plugin_name) or initialized then
        return
      end

      initialized = true

      callback(e)
    end,
    group = augroup,
  })
end

return M
