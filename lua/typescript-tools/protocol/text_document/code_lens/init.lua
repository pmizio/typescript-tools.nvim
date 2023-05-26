local lsp_util = require "vim.lsp.util"
local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.utils"
local proto_utils = require "typescript-tools.protocol.utils"
local config = require "typescript-tools.config"

local document_cache = {}

local M = {}

---@param item table - NavTreeItem
---@return boolean
local function is_abstract(item)
  return utils.toboolean(string.find(item.kindModifiers, "abstract", 1, true))
end

local kinds_with_implementations = {
  [c.ScriptElementKind.interfaceElement] = true,
  [c.ScriptElementKind.classElement] = is_abstract,
  [c.ScriptElementKind.memberFunctionElement] = is_abstract,
  [c.ScriptElementKind.memberVariableElement] = is_abstract,
  [c.ScriptElementKind.memberGetAccessorElement] = is_abstract,
  [c.ScriptElementKind.memberSetAccessorElement] = is_abstract,
}

---@param item table - NavTreeItem
---@return boolean
local function is_exported(item)
  return utils.toboolean(string.find(item.kindModifiers, "export", 1, true))
end

---@param item table - NavTreeItem
---@param parent table|nil - NavTreeItem
---@return boolean|nil
local function fulfill_member_rules(item, parent)
  if config.disable_member_code_lens then
    return false
  end

  if parent then
    local parent_span = parent.spans[1]
    local item_span = item.spans[1]

    if
      parent_span.start.line == item_span.start.line
      and parent_span.start.offset == item_span.start.offset
    then
      return false
    end
  end

  return parent
    and (
      parent.kind == c.ScriptElementKind.classElement
      or parent.kind == c.ScriptElementKind.interfaceElement
      or parent.kind == c.ScriptElementKind.type
    )
end

local kinds_with_references = {
  [c.ScriptElementKind.interfaceElement] = true,
  [c.ScriptElementKind.typeElement] = true,
  [c.ScriptElementKind.enumElement] = true,
  [c.ScriptElementKind.constElement] = is_exported,
  [c.ScriptElementKind.letElement] = is_exported,
  [c.ScriptElementKind.variableElement] = is_exported,
  [c.ScriptElementKind.memberFunctionElement] = fulfill_member_rules,
  [c.ScriptElementKind.memberGetAccessorElement] = fulfill_member_rules,
  [c.ScriptElementKind.memberSetAccessorElement] = fulfill_member_rules,
  [c.ScriptElementKind.constructorImplementationElement] = fulfill_member_rules,
  [c.ScriptElementKind.memberVariableElement] = fulfill_member_rules,
  ---@param item table - NavTreeItem
  [c.ScriptElementKind.classElement] = function(item)
    return item.text ~= "<class>"
  end,
}

---@param rules table
---@param item table - NavTreeItem
---@param parent table|nil - NavTreeItem
---@return boolean|function
local function resolve_support(rules, item, parent)
  local rule = rules[item.kind]

  if type(rule) == "function" then
    return rule(item, parent)
  end

  return rule
end

---@param text_document table
---@param item table - NavTreeItem
---@param parent table|nil - NavTreeItem
---@param lenses table
local function walk_nav_tree(text_document, item, parent, lenses)
  if
    config.code_lens ~= config.code_lens_mode.references_only
    and resolve_support(kinds_with_implementations, item, parent)
  then
    table.insert(lenses, {
      range = proto_utils.convert_tsserver_range_to_lsp(item.spans[1]),
      data = {
        textDocument = text_document,
        implementations = true,
      },
    })
  end

  if
    config.code_lens ~= config.code_lens_mode.implementations_only
    and resolve_support(kinds_with_references, item, parent)
  then
    table.insert(lenses, {
      range = proto_utils.convert_tsserver_range_to_lsp(item.spans[1]),
      data = {
        textDocument = text_document,
      },
    })
  end

  for _, it in ipairs(item.childItems or {}) do
    walk_nav_tree(text_document, it, item, lenses)
  end
end

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local text_document = params.textDocument

  local document_version = lsp_util.buf_versions[vim.uri_to_bufnr(text_document.uri)]
  local cache = document_cache[text_document.uri] or {}

  if document_version == cache.version then
    request { cache = cache.data }
    return
  end

  request {
    command = c.CommandTypes.NavTree,
    arguments = {
      file = vim.uri_to_fname(text_document.uri),
    },
  }

  local body = coroutine.yield()

  local lenses = {}

  walk_nav_tree(text_document, body, nil, lenses)

  document_cache[text_document.uri] = {
    version = document_version,
    data = lenses,
  }

  response(lenses)
end

return M
