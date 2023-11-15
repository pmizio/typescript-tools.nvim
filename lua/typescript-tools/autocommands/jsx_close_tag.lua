local api = vim.api

local common = require "typescript-tools.autocommands.common"
local plugin_config = require "typescript-tools.config"
local plugin_api = require "typescript-tools.api"
local list_contains = require("typescript-tools.utils").list_contains

local M = {}

function M.setup_jsx_close_tag_autocmds()
  local augroup = vim.api.nvim_create_augroup("TypescriptToolsJSXCloseTagGroup", { clear = true })

  common.create_lsp_attach_augcmd(function()
    local changing = false
    local request_id = nil
    local prev_line = nil
    local prev_line_text = ""

    api.nvim_create_autocmd({ "TextChangedI" }, {
      pattern = common.extensions_pattern,
      callback = function()
        if not list_contains(plugin_config.jsx_close_tag.filetypes, vim.bo.filetype) then
          return
        end
        if changing then
          changing = false
          return
        end
        local params = vim.lsp.util.make_position_params(0, "utf-8")
        local bufnr = vim.api.nvim_get_current_buf()
        local line, character = params.position.line, params.position.character
        local line_text = vim.api.nvim_buf_get_text(0, line, 0, line, character, {})[1]

        local is_after_delete = prev_line == line
          and string.len(prev_line_text) >= string.len(line_text)

        prev_line_text = line_text
        prev_line = line

        if is_after_delete then
          return
        end

        local line_words = vim.split(line_text, " ")

        if #line_words == 0 then
          return
        end

        local last_word = line_words[#line_words]

        local last_char = string.sub(last_word, #last_word)

        if last_char ~= ">" then
          return
        end

        request_id = plugin_api.jsx_close_tag(bufnr, params, function()
          changing = true
          request_id = nil
        end, request_id)
      end,
    })
  end, augroup)
end

return M
