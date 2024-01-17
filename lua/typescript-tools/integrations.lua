local M = {}

---@param picker function
---@param callback fun(err: boolean|nil, file: string?)
function M.telescope_picker(picker, callback)
  local ok, actions = pcall(require, "telescope.actions")

  if not ok then
    vim.notify("Telescope need to be installed to call this integration", vim.log.levels.WARN)
    callback(true, nil)
    return
  end

  local action_state = require "telescope.actions.state"
  picker = picker or require("telescope.builtin").find_files

  picker {
    attach_mappings = function(prompt_bufnr)
      local selected = nil

      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        selected = true

        if selection then
          selected = vim.fs.joinpath(vim.loop.cwd(), selection.value)
        end

        actions.close(prompt_bufnr)
      end)
      actions.close:enhance {
        post = function()
          callback(nil, selected)
        end,
      }
      return true
    end,
  }
end

return M
