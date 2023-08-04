local c = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local M = {}

---@param context table
---@return SignatureHelpTriggerReason
local function tsserver_reason_to_lsp_kind(context)
  local kind = context.kind

  if kind == c.SignatureHelpTriggerKind.Invoked then
    return c.SignatureHelpTriggerReason.Invoked
  elseif kind == c.SignatureHelpTriggerKind.ContentChange then
    return context.isRetrigger and c.SignatureHelpTriggerReason.Retrigger
      or c.SignatureHelpTriggerReason.CharacterTyped
  elseif kind == c.SignatureHelpTriggerKind.TriggerCharacter then
    if context.triggerCharacter then
      if context.isRetrigger then
        return c.SignatureHelpTriggerReason.Retrigger
      else
        return c.SignatureHelpTriggerReason.CharacterTyped
      end
    else
      return c.SignatureHelpTriggerReason.Invoked
    end
  end

  return c.SignatureHelpTriggerReason.Invoked
end

---@param context table
---@return table|nil
local function signature_help_context_to_trigger_reason(context)
  if context then
    return {
      kind = tsserver_reason_to_lsp_kind(context),
      triggerCharacter = context.triggerCharacter,
    }
  end

  return nil
end

---@param prefix table
---@param params table
---@param suffix table
---@return string
local function make_signature_label(prefix, params, suffix)
  return table.concat({
    utils.tsserver_docs_to_plain_text(prefix, ""),
    table.concat(
      vim.tbl_map(function(param)
        return utils.tsserver_docs_to_plain_text(param.displayParts, "")
      end, params),
      ", "
    ),
    utils.tsserver_docs_to_plain_text(suffix, ""),
  }, "")
end

---@param items table
---@return table
local function make_signatures(items)
  return vim.tbl_map(function(item)
    return {
      label = make_signature_label(
        item.prefixDisplayParts,
        item.parameters,
        item.suffixDisplayParts
      ),
      documentation = utils.make_markup_content(table.concat({
        utils.tsserver_docs_to_plain_text(item.documentation, ""),
        "\n",
        utils.tsserver_make_tags(item.tags or {}),
      }, "")),
      parameters = vim.tbl_map(function(param)
        return {
          label = utils.tsserver_docs_to_plain_text(param.displayParts, ""),
          documentation = utils.make_markup_content(
            utils.tsserver_docs_to_plain_text(param.documentation, "")
          ),
        }
      end, item.parameters),
    }
  end, items)
end

---@type TsserverProtocolHandler
function M.handler(request, response, params)
  local text_document = params.textDocument
  local context = params.context
  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/96894db6cb5b7af6857b4d0c7f70f7d8ac782d51/lib/protocol.d.ts#L1973
  request {
    command = c.CommandTypes.SignatureHelp,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
      triggerReason = signature_help_context_to_trigger_reason(context),
    }, utils.convert_lsp_position_to_tsserver(params.position)),
  }

  local body = coroutine.yield()

  -- tsserver protocol reference:
  -- https://github.com/microsoft/TypeScript/blob/96894db6cb5b7af6857b4d0c7f70f7d8ac782d51/lib/protocol.d.ts#L1980
  response {
    signatures = make_signatures(body.items),
    activeSignature = body.selectedItemIndex,
    activeParameter = body.argumentIndex,
  }
end

return M
