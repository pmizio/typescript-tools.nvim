local utils = require "tests.utils"
local c = require "typescript-tools.protocol.constants"
local custom_methods = c.CustomMethods

describe("Lsp request", function()
  after_each(function()
    -- INFO: close all buffers
    _G.file_closed = false
    vim.cmd "silent 1,$bd!"
    utils.wait_for_lsp_did_close()
  end)

  it(
    "should return correct response for " .. custom_methods.BatchCodeActions .. " - Remove unused",
    function()
      utils.open_file "src/batch_code_actions.ts"
      utils.wait_for_lsp_initialization()

      local initial_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

      assert.is.same(vim.tbl_contains(initial_lines, "  const unused = 0;"), true)
      assert.is.same(vim.tbl_contains(initial_lines, "  const unused = export1;"), true)

      vim.wait(1000)

      vim.cmd ":TSToolsRemoveUnused"

      vim.wait(200)

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

      assert.is.same(vim.tbl_contains(lines, "  const unused = 0;"), false)
      assert.is.same(vim.tbl_contains(lines, "  const unused = export1;"), false)
    end
  )

  it(
    "should return correct response for " .. custom_methods.BatchCodeActions .. " - Fix all",
    function()
      utils.open_file "src/batch_code_actions.ts"
      utils.wait_for_lsp_initialization()

      vim.wait(1000)

      vim.cmd ":TSToolsFixAll"

      vim.wait(200)

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

      assert.is.same(vim.tbl_contains(lines, "async function bar() {"), true)
    end
  )

  it(
    "should return correct response for "
      .. custom_methods.BatchCodeActions
      .. " - Add missing imports",
    function()
      utils.open_file "src/batch_code_actions.ts"
      utils.wait_for_lsp_initialization()

      vim.wait(1000)

      vim.cmd ":TSToolsAddMissingImports"

      vim.wait(200)

      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

      assert.is.same(vim.tbl_contains(lines, 'import { export1 } from "exports";'), true)
    end
  )
end)
