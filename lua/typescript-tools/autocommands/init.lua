local diagnostics = require "typescript-tools.autocommands.diagnostics"
local code_lens = require "typescript-tools.autocommands.code_lens"
local config = require "typescript-tools.config"
local jsx_close_tag = require "typescript-tools.autocommands.jsx_close_tag"

local M = {}

---@param dispatchers Dispatchers
function M.setup_autocommands(dispatchers)
  diagnostics.setup_diagnostic_autocmds(dispatchers)

  if config.code_lens ~= config.code_lens_mode.off then
    code_lens.setup_code_lens_autocmds()
  end

  if config.jsx_close_tag.enable then
    jsx_close_tag.setup_jsx_close_tag_autocmds()
  end
end

return M
