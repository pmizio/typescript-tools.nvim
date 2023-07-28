local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"
local plugin_config = require "typescript-tools.config"

local M = {}

---@type table<"mac" | "unix" | "dos", string>
local eol_chars = {
  mac = "\r",
  unix = "\n",
  dos = "\r\n",
}

---@param bo table
---@return string
local function get_eol_chars(bo)
  return eol_chars[bo.fileformat] or eol_chars.unix
end

---@param params table
---@return TsserverRequest
local function configure(params)
  local text_document = params.textDocument

  local bo = vim.bo[vim.uri_to_bufnr(text_document.uri)]
  local tab_size = bo.tabstop or 2
  local indent_size = bo.shiftwidth or tab_size
  local convert_tabs_to_spaces = bo.expandtab or true
  local new_line_character = get_eol_chars(bo)

  local format_options = plugin_config.tsserver_format_options

  return {
    command = c.CommandTypes.Configure,
    arguments = {
      file = vim.uri_to_fname(text_document.uri),
      formatOptions = vim.tbl_extend(
        "force",
        {
          tabSize = tab_size,
          indentSize = indent_size,
          convertTabsToSpaces = convert_tabs_to_spaces,
          newLineCharacter = new_line_character,
        },
        plugin_config.default_format_options,
        type(format_options) == "function" and format_options(bo.filetype) or format_options
      ),
      preferences = plugin_config.get_tsserver_file_preferences(bo.filetype),
    },
  }
end

---@param params table
---@return TsserverRequest
local function open_request(params)
  local text_document = params.textDocument

  return {
    command = c.CommandTypes.UpdateOpen,
    arguments = {
      openFiles = {
        {
          file = vim.uri_to_fname(text_document.uri),
          fileContent = text_document.text,
          scriptKindName = utils.get_text_document_script_kind(text_document),
        },
      },
      changedFiles = {},
      closedFiles = {},
    },
  }
end

---@type TsserverProtocolHandler
function M.handler(request, _, params)
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/29cbfe9a2504cfae30bae938bdb2be6081ccc5c8/lib/protocol.d.ts#L1305
  request(open_request(params))
  request(configure(params))

  -- INFO: skip first response
  coroutine.yield()
end

return M
