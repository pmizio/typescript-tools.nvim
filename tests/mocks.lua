local M = {}

M.mocked_code_action_context = {
  diagnostics = {
    {
      code = 6133,
      message = "'c' is declared but its value is never read.",
      range = {
        ["end"] = {
          character = 9,
          line = 1,
        },
        start = {
          character = 8,
          line = 1,
        },
      },
      severity = 4,
      source = "tsserver",
    },
  },
  triggerKind = 1,
}

return M
