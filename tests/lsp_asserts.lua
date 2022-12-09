local M = {}

function M.response(resp)
  assert.is.table(resp)
  assert.are.same(#resp, 1)

  local result = resp[1].result
  assert.is.table(result)

  return result
end

function M.position(position, line, character)
  assert.is.table(position)
  assert.are.same(position.line, line)
  assert.are.same(position.character, character)
end

function M.range(range, start_line, start_character, end_line, end_character)
  M.position(range.start, start_line, start_character)
  M.position(range["end"], end_line, end_character)
end

return M
