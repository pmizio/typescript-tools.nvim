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

---@param opts table|nil Optional picker configuration
---@param callback fun(err: boolean|nil, file: string?)
function M.snacks_picker(opts, callback)
  local ok, Snacks = pcall(require, "snacks")

  if not ok then
    vim.notify(
      "snacks.nvim picker needs to be installed to call this integration",
      vim.log.levels.WARN
    )
    callback(true, nil)
    return
  end

  local picker_opts = {
    title = "Pick a file",
    finder = "files",
    confirm = function(picker, item)
      if item then
        local file_path
        if type(item) == "string" then
          file_path = item
        elseif type(item) == "table" then
          file_path = item._path

          if not file_path then
            file_path = item.filename
              or item.path
              or item.value
              or (item.file and vim.fs.joinpath(item.cwd or vim.loop.cwd(), item.file))
          end
        end

        if file_path then
          file_path = vim.fs.normalize(file_path)
          picker:close()
          callback(nil, file_path)
        else
          picker:close()
          callback(true, nil)
        end
      else
        picker:close()
        callback(true, nil)
      end
    end,
    cancel = function()
      callback(true, nil)
    end,
  }

  if opts then
    for k, v in pairs(opts) do
      picker_opts[k] = v
    end
  end

  Snacks.picker.files(picker_opts)
end

return M
