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

-- TODO fix empty script tag case <script></script>
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

    local _, _, start_tag_end_row, start_tag_end_column = script_start_tag_node:range()
    local end_tag_start_row, end_tag_start_column = script_end_tag_node:range()
    -- TS indexes rows from 0 and columns from 0. Nvim indexes rows from 1 and columns from 0.
    -- start_row + 1 because of indexing difference
    -- start_col + 1 because we want to take the first character after opening script tag
    -- end_row + 1 because of indexing difference
    local code_start_column = start_tag_end_column + 1
    local code_end_column = end_tag_start_column == 0 and 0
      or end_tag_start_column == code_start_column and code_start_column
      or end_tag_start_column
    table.insert(code_chunks, {
      range = { start_tag_end_row + 1, code_start_column, end_tag_start_row + 1, code_end_column },
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
  local requested_buf_emptied_lines = vim.tbl_map(function(line)
    return string.rep(" ", #line)
  end, requested_buf_all_lines)

  local scripts_ranges = extract_js_script_code_ranges(original_file_bufnr)

  local function replace_char(pos, string_to_replace, string_to_replace_with)
    local char = string.sub(string_to_replace_with, pos, pos)
    return table.concat(
      { string_to_replace:sub(1, pos - 1), char, string_to_replace:sub(pos + 1) },
      ""
    )
  end

  for _, script_range in ipairs(scripts_ranges) do
    local range = script_range.range

    -- start line
    for i = range[2], #requested_buf_emptied_lines[range[1]] do
      if is_position_between_range({ line = range[1], character = i }, script_range.range) then
        requested_buf_emptied_lines[range[1]] =
          replace_char(i, requested_buf_emptied_lines[range[1]], requested_buf_all_lines[range[1]])
      end
    end

    -- lines in the middle
    for i = range[1] + 1, range[3] - 1 do
      requested_buf_emptied_lines[i] = requested_buf_all_lines[i]
    end

    -- end line
    for i = 1, range[4] do
      if is_position_between_range({ line = range[3], character = i }, script_range.range) then
        requested_buf_emptied_lines[range[3]] =
          replace_char(i, requested_buf_emptied_lines[range[3]], requested_buf_all_lines[range[3]])
      end
    end
  end

  return requested_buf_emptied_lines
end

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

-- create autocmd on bufenter to override this handlers and the unoverride
function M.create_redirect_handlers()
  local function redirect_handler(base_handler)
    return function(err, res, ctx, config)
      if not res then
        return base_handler(err, res, ctx, config)
      end

      local request_start_range = res.range.start
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      local script_nodes = extract_script_text_nodes(0)
      for _, script_node in ipairs(script_nodes) do
        if
          -- TODO this line throws an error
          is_position_between_range(request_start_range, script_node:range())
          and client.name == plugin_config.plugin_name
        then
          base_handler(err, res, ctx, config)
          return
        end
      end
    end
  end

  vim.lsp.handlers["textDocument/hover"] = redirect_handler(vim.lsp.handlers["textDocument/hover"])
  vim.lsp.handlers["textDocument/definition"] =
    redirect_handler(vim.lsp.handlers["textDocument/definition"])
  vim.lsp.handlers["textDocument/references"] =
    redirect_handler(vim.lsp.handlers["textDocument/references"])
end

M.create_redirect_handlers()

return M
