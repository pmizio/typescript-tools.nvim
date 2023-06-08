local plugin_config = require "typescript-tools.config"

-- Basic idea is for HTML support is to whenever we edit a file we create a copy of the file and
-- replace every character with " " - space. Then we use treesitter to get all of the script
-- tags from the original file and we insert them into the empty copy in the same positions that they
-- were in original buffer. Because of that we don't have to translate any positions anywhere. Then we
-- override 'didOpen' and 'didChange' events of the tsserver so tsserver thinks that the changes were
-- made to the original copy and not the original file.

local M = {}

local SCRIPT_TEXT_HTML_QUERY = [[
   (script_element
    (start_tag)
    (raw_text) @script.text
    (end_tag))
]]

local function is_position_between_range(position, range)
  local start_row, start_col, end_row, end_col = unpack(range)

  return not (
    position.line < start_row
    or position.line > end_row
    or (position.line == start_row and position.character < start_col)
    or (position.line == end_row and position.character > end_col)
  )
end

--- @param bufnr number - buffer number to extract nodes from
--- @return table - list of script tag's texts nodes
local function extract_script_text_nodes(bufnr)
  local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
  local parserlang = vim.treesitter.language.get_lang(ft)

  if not parserlang then
    return {}
  end

  local language_tree = vim.treesitter.get_parser(bufnr, parserlang)
  local syntax_tree = language_tree:parse()
  local root = syntax_tree[1]:root()

  local query = vim.treesitter.query.parse(parserlang, SCRIPT_TEXT_HTML_QUERY)

  local nodes = {}
  for _, match, _ in query:iter_matches(root, main_nr) do
    for id, node in pairs(match) do
      local name = query.captures[id]
      if name == "script.text" then
        table.insert(nodes, node)
      end
    end
  end

  return nodes
end

--- @param bufnr number - buffer number to extract nodes from
--- @return table - extracts code chunks from script tags including their ranges and texts
local function extract_js_script_code_ranges(bufnr)
  local script_nodes = extract_script_text_nodes(bufnr)
  local code_chunks = {}
  for _, script_node in ipairs(script_nodes) do
    -- we are taking positions of start and end tags because (raw_text) does not include whitespace
    -- and we need to take range between the tags
    local script_start_tag_node = script_node:prev_sibling()
    local script_end_tag_node = script_node:next_sibling()

    local _, _, start_row, start_col = script_start_tag_node:range()
    local end_row, end_col = script_end_tag_node:range()
    -- TS indexes rows from 0 and columns from 0. Nvim indexes rows from 1 and columns from 0.
    -- start_row + 1 because of indexing difference
    -- start_col + 1 because we want to take the first character after opening script tag
    -- end_row + 1 because of indexing difference
    table.insert(code_chunks, {
      range = { start_row + 1, start_col + 1, end_row + 1, end_col == 0 and 0 or end_col - 1 },
    })
  end

  return code_chunks
end

--- Gets the content from buffer, replaces everything with empty lines and then inserts code chunks
--- at correct positions and replaces virtual document with those lines.
--- @param original_buffer_uri string - uri of the buffer to extract code from
--- @return table - list of all script lines without HTML tags
function M.get_virtual_document_lines(original_buffer_uri)
  local original_file_bufnr = vim.uri_to_bufnr(original_buffer_uri)
  local requested_buf_all_lines = vim.api.nvim_buf_get_lines(original_file_bufnr, 0, -1, false)

  local scripts_ranges = extract_js_script_code_ranges(original_file_bufnr)

  local function replace_char(pos, str, r)
    return str:sub(1, pos - 1) .. r .. str:sub(pos + 1)
  end

  -- this might be not that performant but we should observe how it performs
  for line_index, line in ipairs(requested_buf_all_lines) do
    for character_index = 1, #line do
      local is_position_in_script = false

      for _, script_range in ipairs(scripts_ranges) do
        if
          is_position_between_range(
            { line = line_index, character = character_index },
            script_range.range
          )
        then
          is_position_in_script = true
          break
        end
      end

      if not is_position_in_script then
        requested_buf_all_lines[line_index] =
          replace_char(character_index, requested_buf_all_lines[line_index], " ")
      end
    end
  end

  return requested_buf_all_lines
end

-- file:///Users/jaroslaw.glegola/Documents/Praca/node-typescript-boilerplate-main/src/test.html
-- file:///Users/jaroslaw.glegola/Documents/Praca/node-typescript-boilerplate-main/src/test.html-tmp.js
--- To get only results from JS content we override the `didOpen` and `didChange` requests to simulate
--- opening file that does not contain HTML. Firstly we remove all of the HTML tags from HTML file
--- and then when one of those requests come we just override the content with code without HTML tags.
--- Thanks to that tsserver thinks that the HTML file is not HTML file but JS file
--- @param method string - LSP method of the request
--- @param params table - LSP params of the request
--- @param current_buffer_uri string - uri of the current buffer
function M.rewrite_request_document_change_params(method, params, current_buffer_uri)
  if not current_buffer_uri then
    return params
  end

  if params.textDocument.text and (method == "textDocument/didOpen") then
    params.textDocument = {
      languageId = "javascript",
      text = table.concat(M.get_virtual_document_lines(current_buffer_uri), "\n"),
      uri = params.textDocument.uri,
      version = params.textDocument.version,
    }
  end

  if params.contentChanges and (method == "textDocument/didChange") then
    local lines = M.get_virtual_document_lines(current_buffer_uri)
    params.contentChanges = {
      {
        range = {
          start = { character = 0, line = 0 },
          ["end"] = { character = 0, line = #lines + 1 },
        },
        text = table.concat(lines, "\n"),
      },
    }
  end

  return params
end

function M.create_redirect_handlers()
  local baseHoverHandler = vim.lsp.handlers["textDocument/hover"]
  vim.lsp.handlers["textDocument/hover"] = function(err, res, ctx, config)
    if not res then
      return baseHoverHandler(err, res, ctx, config)
    end

    local request_start_range = res.range.start
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    local script_nodes = extract_script_text_nodes(0)
    for _, script_node in ipairs(script_nodes) do
      if
        is_position_between_range(request_start_range, script_node:range())
        and client.name == plugin_config.plugin_name
      then
        baseHoverHandler(err, res, ctx, config)
        return
      end
    end
  end
end

return M
