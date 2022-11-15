local M = {}

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
