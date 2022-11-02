local constants = require "typescript-tools.protocol.constants"
local utils = require "typescript-tools.protocol.utils"

local tsserver_reason_to_lsp_kind = function(context)
  local kind = context.kind

  if kind == constants.SignatureHelpTriggerKind.Invoked then
    return constants.SignatureHelpTriggerReason.Invoked
  elseif kind == constants.SignatureHelpTriggerKind.ContentChange then
    return context.isRetrigger and constants.SignatureHelpTriggerReason.Retrigger
      or constants.SignatureHelpTriggerReason.CharacterTyped
  elseif kind == constants.SignatureHelpTriggerKind.TriggerCharacter then
    if context.triggerCharacter then
      if context.isRetrigger then
        return constants.SignatureHelpTriggerReason.Retrigger
      else
        return constants.SignatureHelpTriggerReason.CharacterTyped
      end
    else
      return constants.SignatureHelpTriggerReason.Invoked
    end
  end
end

local signature_help_context_to_trigger_reason = function(context)
  if context then
    return {
      kind = tsserver_reason_to_lsp_kind(context),
      triggerCharacter = context.triggerCharacter,
    }
  end

  return nil
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/96894db6cb5b7af6857b4d0c7f70f7d8ac782d51/lib/protocol.d.ts#L1973
local signature_help_request_handler = function(_, params)
  local text_document = params.textDocument
  local context = params.context

  return {
    command = constants.CommandTypes.SignatureHelp,
    arguments = vim.tbl_extend("force", {
      file = vim.uri_to_fname(text_document.uri),
      triggerReason = signature_help_context_to_trigger_reason(context),
    }, utils.convert_lsp_position_to_tsserver(
      params.position
    )),
  }
end

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

local function make_signatures(items)
  return vim.tbl_map(function(item)
    return {
      label = make_signature_label(
        item.prefixDisplayParts,
        item.parameters,
        item.suffixDisplayParts
      ),
      documentation = table.concat({
        utils.tsserver_docs_to_plain_text(item.documentation, ""),
        "\n",
        utils.tsserver_make_tags(item.tags or {}),
      }, ""),
      parameters = vim.tbl_map(function(param)
        return {
          label = utils.tsserver_docs_to_plain_text(param.displayParts, ""),
          documentation = utils.tsserver_docs_to_plain_text(param.documentation, ""),
        }
      end, item.parameters),
    }
  end, items)
end

-- tsserver protocol reference:
-- https://github.com/microsoft/TypeScript/blob/96894db6cb5b7af6857b4d0c7f70f7d8ac782d51/lib/protocol.d.ts#L1980
local signature_help_response_handler = function(_, body)
  return {
    signatures = make_signatures(body.items),
    activeSignature = body.selectedItemIndex,
    activeParameter = body.argumentIndex,
  }
end

return {
  request = { method = constants.LspMethods.SignatureHelp, handler = signature_help_request_handler },
  response = {
    method = constants.CommandTypes.SignatureHelp,
    handler = signature_help_response_handler,
  },
}
