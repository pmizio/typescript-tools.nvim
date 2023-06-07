local plugin_config = require "typescript-tools.config"

-- Basic idea is for HTML support is to whenever we edit a file we create an empty buffer
-- and replace every character with " " - space. Then we use treesitter to get all of the script tags
-- from the file and we insert them into the empty buffer in the same positions that they
-- were in original buffer. Because of that we don't have to translate any positions anywhere.

local M = {}

local VIRTUAL_DOCUMENT_EXTENSION = ".js"

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

local function initialize_virtual_document()
  -- creating path in the same directory as edited file so every setting set up for directory will apply
  local virtual_document_path = vim.api.nvim_buf_get_name(0) .. "-tmp" .. VIRTUAL_DOCUMENT_EXTENSION
  M.virtual_document_uri = "file://" .. virtual_document_path
  -- uri_to_bufnr creates a buffer if it doesn't exist
  M.virtual_document_bufnr = vim.uri_to_bufnr(M.virtual_document_uri)

  vim.api.nvim_buf_set_name(M.virtual_document_bufnr, virtual_document_path)
  vim.api.nvim_buf_set_option(M.virtual_document_bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(M.virtual_document_bufnr, "buftype", "nowrite")
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

--- @return table - extracts code chunks from script tags including their ranges and texts
local function extract_js_script_code_ranges()
  local script_nodes = extract_script_text_nodes(0)
  local code_chunks = {}
  for _, script_node in ipairs(script_nodes) do
    local text = vim.treesitter.get_node_text(script_node, 0)
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
function M.update_virtual_document(original_buffer_uri)
  if not M.virtual_document_bufnr then
    initialize_virtual_document()
  end

  local requested_buf_all_lines =
    vim.api.nvim_buf_get_lines(vim.uri_to_bufnr(original_buffer_uri), 0, -1, false)

  local scripts_ranges = extract_js_script_code_ranges()

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

  -- this line throws E565: Not allowed to change text or change window sometimes and nned to investigate why
  vim.api.nvim_buf_set_lines(M.virtual_document_bufnr, 0, -1, false, requested_buf_all_lines)

  return M.virtual_document_bufnr
end

function M.rewrite_request_uris(method, params, current_buffer_uri)
  if not current_buffer_uri then
    return params
  end

  M.update_virtual_document(current_buffer_uri)

  local function replace_original_uri_to_virtual_document_uri(tbl)
    for key, value in pairs(tbl) do
      if type(value) == "table" then
        replace_original_uri_to_virtual_document_uri(value) -- Recursive call for nested tables
      elseif type(value) == "string" and value == current_buffer_uri then
        tbl[key] = M.virtual_document_uri
      end
    end

    -- in those methods there are whole contents of the file so we need to rewrite them as well
    if tbl.text and (method == "textDocument/didOpen") then
      tbl.text =
        table.concat(vim.api.nvim_buf_get_lines(M.virtual_document_bufnr, 0, -1, false), "\n")
    end

    if tbl.text and (method == "textDocument/didChange") then
      local start_row = tbl.range.start.line
      local start_col = tbl.range.start.character
      local end_row = tbl.range["end"].line
      local end_col = tbl.range["end"].character
      tbl.text = table.concat(
        vim.api.nvim_buf_get_text(
          M.virtual_document_bufnr,
          start_row,
          start_col,
          end_row,
          end_col,
          {}
        ),
        "\n"
      )
    end
  end

  replace_original_uri_to_virtual_document_uri(params)

  return params
end

function M.rewrite_response_uris(original_uri, response)
  if not original_uri then
    return response
  end

  local function replace_virtual_document_uri_with_original_uri(tbl)
    for key, value in pairs(tbl) do
      if key == M.virtual_document_uri then
        tbl[original_uri] = tbl[M.virtual_document_uri]
        tbl[M.virtual_document_uri] = nil
        replace_virtual_document_uri_with_original_uri(tbl[original_uri]) -- Recursive call for nested tables
      elseif type(value) == "table" then
        replace_virtual_document_uri_with_original_uri(value) -- Recursive call for nested tables
      elseif type(value) == "string" and value == M.virtual_document_uri then
        tbl[key] = original_uri
      end
    end
  end

  replace_virtual_document_uri_with_original_uri(response)

  return response
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
