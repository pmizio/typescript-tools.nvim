local api = vim.api

local M = {}

M.buf_map = {}

function M.setup_on_attach_autocmds()
  local augroup = api.nvim_create_augroup("TypescriptToolsOnAttachGroup", { clear = true })
  api.nvim_create_autocmd("BufDelete", {
    callback = function(args)
      local buf_key = tostring(args.buf)
      M.buf_map[buf_key] = false
    end,
    group = augroup,
  })
end

return M
