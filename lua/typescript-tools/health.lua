local util = require "typescript-tools.utils"

local M = {}

function M.check()
  local health = vim.health

  health.start "typescript-tools.nvim"

  local version_ok, version_msg = util.check_minimum_nvim_version()
  if version_ok then
    health.ok(version_msg)
  else
    health.error(version_msg, {
      "Please upgrade to Neovim 0.11.2 or later",
      "Visit https://github.com/neovim/neovim/releases",
    })
  end
end

return M
