local M = {}

function M.wait_for_lsp_initialization()
  if not _G.initialized then
    vim.wait(10000, function()
      return _G.initialized
    end, 10)
  end

  if not _G.file_opened then
    vim.wait(10000, function()
      return _G.file_opened
    end, 10)
  end
end

function M.wait_for_lsp_did_close()
  if not _G.file_closed then
    vim.wait(10000, function()
      return _G.file_closed
    end, 10)
  end
end

function M.wait_for_initial_diagnostics()
  if not _G.initial_diagnostics_emitted then
    vim.wait(10000, function()
      return _G.initial_diagnostics_emitted
    end, 10)
  end
end

---@param file string
---@param mode string|nil
function M.open_file(file, mode)
  mode = mode or "e"

  local cwd = vim.fn.getcwd()

  if not string.find(cwd, "ts_project", 1, true) then
    vim.cmd ":cd tests/ts_project"
  end

  _G.file_opened = false
  vim.cmd(":" .. mode .. " " .. file)
end

---@return TextDocument
function M.get_text_document()
  return { uri = vim.uri_from_bufnr(0) }
end

---@param line number
---@param character number
---@return LspPosition
function M.make_position(line, character)
  return { line = line, character = character }
end

---@param start_line number
---@param start_character number
---@param end_line number
---@param end_character number
---@return LspRange
function M.make_range(start_line, start_character, end_line, end_character)
  return {
    start = M.make_position(start_line, start_character),
    ["end"] = M.make_position(end_line, end_character),
  }
end

---@param options table<string, any>
---@return any
function M.tsv(options)
  return options[vim.env.TEST_TYPESCRIPT_VERSION] or options.default
end

---@param version string
---@return boolean
function M.is_typescript_version(version)
  return vim.env.TEST_TYPESCRIPT_VERSION == version
end

---@param capability string
---@return boolean
function M.supports_capability(capability)
  return not not vim.lsp.get_clients({
    name = require("typescript-tools.config").plugin_name,
  })[1].server_capabilities[capability]
end

---@vararg string
function M.print_skip(...)
  print("\27[0;33mSkipped\27[0m ||      " .. table.concat({ ... }, " "))
end

return M
