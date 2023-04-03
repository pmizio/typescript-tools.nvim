local make_protocol_handlers = function()
  local request_handlers, response_handlers = {}, {}

  local assign_handlers = function(config)
    local request = config.request
    local response = config.response

    if vim.tbl_islist(request) then
      for _, it in ipairs(request) do
        request_handlers[it.method] = it.handler
      end
    else
      request_handlers[request.method] = request.handler
    end

    if response then
      if vim.tbl_islist(response) then
        for _, it in ipairs(response) do
          response_handlers[it.method] = it.handler
        end
      else
        response_handlers[response.method] = response.handler
      end
    end
  end

  assign_handlers(require "typescript-tools.protocol.handlers.initialize")
  assign_handlers(require "typescript-tools.protocol.handlers.did_open")
  assign_handlers(require "typescript-tools.protocol.handlers.did_close")
  assign_handlers(require "typescript-tools.protocol.handlers.did_change")
  assign_handlers(require "typescript-tools.protocol.handlers.rename")
  assign_handlers(require "typescript-tools.protocol.handlers.completion")
  assign_handlers(require "typescript-tools.protocol.handlers.completion.resolve")
  assign_handlers(require "typescript-tools.protocol.handlers.hover")
  assign_handlers(require "typescript-tools.protocol.handlers.definition")
  assign_handlers(require "typescript-tools.protocol.handlers.type_definition")
  assign_handlers(require "typescript-tools.protocol.handlers.implementation")
  assign_handlers(require "typescript-tools.protocol.handlers.references")
  assign_handlers(require "typescript-tools.protocol.handlers.document_symbol")
  assign_handlers(require "typescript-tools.protocol.handlers.document_highlight")
  assign_handlers(require "typescript-tools.protocol.handlers.code_action_resolve")
  assign_handlers(require "typescript-tools.protocol.handlers.signature_help")
  assign_handlers(require "typescript-tools.protocol.handlers.formatting")
  assign_handlers(require "typescript-tools.protocol.handlers.prepare_call_hierarchy")
  assign_handlers(require "typescript-tools.protocol.handlers.hierarchy_calls")
  assign_handlers(require "typescript-tools.protocol.handlers.workspace_symbol")
  assign_handlers(require "typescript-tools.protocol.handlers.will_rename_file")

  -- custom handlers
  assign_handlers(require "typescript-tools.protocol.handlers.organize_imports")

  assign_handlers(require "typescript-tools.protocol.handlers.shutdown")

  return request_handlers, response_handlers
end

return make_protocol_handlers
