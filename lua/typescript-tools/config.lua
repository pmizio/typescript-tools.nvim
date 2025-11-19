---@class Settings
---@field plugin_name string
---@field separate_diagnostic_server boolean
---@field tsserver_logs string
---@field publish_diagnostic_on publish_diagnostic_mode
---@field tsserver_path string|nil
---@field tsserver_plugins string[]
---@field tsserver_format_options table|fun(filetype: string): table
---@field tsserver_file_preferences table|fun(filetype: string): table
---@field tsserver_max_memory number|"auto"
---@field tsserver_locale string
---@field complete_function_calls boolean
---@field expose_as_code_action ("fix_all"| "add_missing_imports"| "remove_unused" | "remove_unused_imports")[]
---@field include_completions_with_insert_text boolean
---@field code_lens code_lens_mode
---@field jsx_close_tag { enable: boolean, filetypes: string[] }
---@field disable_member_code_lens boolean
---@field code_lens_config { events: table, format: { references: fun(refs: table): string; implementations: fun(impls: table): string } }
local M = {}
local __store = {}

-- INFO: this two defaults are same as in vscode
local default_format_options = {
  insertSpaceAfterCommaDelimiter = true,
  insertSpaceAfterConstructor = false,
  insertSpaceAfterSemicolonInForStatements = true,
  insertSpaceBeforeAndAfterBinaryOperators = true,
  insertSpaceAfterKeywordsInControlFlowStatements = true,
  insertSpaceAfterFunctionKeywordForAnonymousFunctions = true,
  insertSpaceBeforeFunctionParenthesis = false,
  insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis = false,
  insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets = false,
  insertSpaceAfterOpeningAndBeforeClosingNonemptyBraces = true,
  insertSpaceAfterOpeningAndBeforeClosingEmptyBraces = true,
  insertSpaceAfterOpeningAndBeforeClosingTemplateStringBraces = false,
  insertSpaceAfterOpeningAndBeforeClosingJsxExpressionBraces = false,
  insertSpaceAfterTypeAssertion = false,
  placeOpenBraceOnNewLineForFunctions = false,
  placeOpenBraceOnNewLineForControlBlocks = false,
  semicolons = "ignore",
  indentSwitchCase = true,
}

local default_preferences = {
  quotePreference = "auto",
  importModuleSpecifierEnding = "auto",
  jsxAttributeCompletionStyle = "auto",
  allowTextChangesInNewFiles = true,
  providePrefixAndSuffixTextForRename = true,
  allowRenameOfImportPath = true,
  includeAutomaticOptionalChainCompletions = true,
  provideRefactorNotApplicableReason = true,
  generateReturnInDocTemplate = true,
  includeCompletionsForImportStatements = true,
  includeCompletionsWithSnippetText = true,
  includeCompletionsWithClassMemberSnippets = true,
  includeCompletionsWithObjectLiteralMethodSnippets = true,
  useLabelDetailsInCompletionEntries = true,
  allowIncompleteCompletions = true,
  displayPartsForJSDoc = true,
  disableLineTextInReferences = true,
  includeInlayParameterNameHints = "none",
  includeInlayParameterNameHintsWhenArgumentMatchesName = false,
  includeInlayFunctionParameterTypeHints = false,
  includeInlayVariableTypeHints = false,
  includeInlayVariableTypeHintsWhenTypeMatchesName = false,
  includeInlayPropertyDeclarationTypeHints = false,
  includeInlayFunctionLikeReturnTypeHints = false,
  includeInlayEnumMemberValueHints = false,
}

---@enum tsserver_log_level
M.tsserver_log_level = {
  normal = "normal",
  terse = "terse",
  verbose = "verbose",
  off = "off",
}

---@enum publish_diagnostic_mode
M.publish_diagnostic_mode = {
  insert_leave = "insert_leave",
  change = "change",
}

---@enum code_lens_mode
M.code_lens_mode = {
  all = "all",
  implementations_only = "implementations_only",
  references_only = "references_only",
  off = "off",
}

M.plugin_name = "typescript-tools"

---@param settings Settings
function M.load_settings(settings)
  local validation_config = {
    settings = { settings, "table", true },
    ["settings.separate_diagnostic_server"] = {
      settings.separate_diagnostic_server,
      "boolean",
      true,
    },
    ["settings.publish_diagnostic_on"] = { settings.publish_diagnostic_on, "string", true },
    ["settings.tsserver_path"] = { settings.tsserver_path, "string", true },
    ["settings.tsserver_plugins"] = { settings.tsserver_plugins, "table", true },
    ["settings.tsserver_format_options"] = {
      settings.tsserver_format_options,
      { "table", "function" },
      true,
    },
    ["settings.tsserver_file_preferences"] = {
      settings.tsserver_file_preferences,
      { "table", "function" },
      true,
    },
    ["settings.tsserver_logs"] = { settings.tsserver_logs, "string", true },
    ["settings.tsserver_max_memory"] = {
      settings.tsserver_max_memory,
      { "number", "string" },
      true,
    },
    ["settings.tsserver_locale"] = {
      settings.tsserver_locale,
      "string",
      true,
    },
    ["settings.complete_function_calls"] = { settings.complete_function_calls, "boolean", true },
    ["settings.expose_as_code_action"] = {
      settings.expose_as_code_action,
      { "table", "string" },
      true,
    },
    ["settings.include_completions_with_insert_text"] = {
      settings.include_completions_with_insert_text,
      "boolean",
      true,
    },
    ["settings.code_lens"] = { settings.code_lens, "string", true },
    ["settings.disable_member_code_lens"] = { settings.disable_member_code_lens, "boolean", true },
    ["settings.jsx_close_tag"] = { settings.jsx_close_tag, "table", true },
    ["settings.code_lens_config"] = { settings.code_lens_config, "table", true },
    ["settings.code_lens_config.events"] = {
      settings.code_lens_config and settings.code_lens_config.events,
      "table",
      true,
    },
    ["settings.code_lens_config.format"] = {
      settings.code_lens_config and settings.code_lens_config.format,
      "table",
      true,
    },
    ["settings.code_lens_config.format.references"] = {
      settings.code_lens_config
        and settings.code_lens_config.format
        and settings.code_lens_config.format.references,
      "function",
      true,
    },
    ["settings.code_lens_config.format.implementations"] = {
      settings.code_lens_config
        and settings.code_lens_config.format
        and settings.code_lens_config.format.implementations,
      "function",
      true,
    },
  }

  if vim.fn.has "nvim-0.11" == 1 then
    for name, validate_config in pairs(validation_config) do
      vim.validate(name, validate_config[1], validate_config[2], validate_config[3])
    end
  else
    vim.validate(validation_config)
  end

  local defaults = {
    separate_diagnostic_server = true,
    publish_diagnostic_on = M.publish_diagnostic_mode.insert_leave,
    tsserver_plugins = {},
    tsserver_format_options = {},
    tsserver_file_preferences = {},
    tsserver_logs = M.tsserver_log_level.off,
    tsserver_max_memory = "auto",
    tsserver_locale = "en",
    complete_function_calls = false,
    expose_as_code_action = {},
    include_completions_with_insert_text = {},
    code_lens = M.code_lens_mode.off,
    jsx_close_tag = {
      enable = false,
      filetypes = { "javascriptreact", "typescriptreact" },
    },
    code_lens_config = {
      events = { "BufEnter", "InsertLeave", "CursorHold" },
      format = {
        references = function(refs)
          return "references: " .. #refs
        end,
        implementations = function(impls)
          return "implementations: " .. #impls
        end,
      },
    },
  }
  __store = vim.tbl_deep_extend("force", __store, defaults, settings)

  --#region Additionally handle enumerated values
  if not M.publish_diagnostic_mode[settings.publish_diagnostic_on] then
    __store.publish_diagnostic_on = M.publish_diagnostic_mode.insert_leave
  end

  if not M.tsserver_log_level[settings.tsserver_logs] then
    __store.tsserver_logs = M.tsserver_log_level.off
  end

  if not M.code_lens_mode[settings.code_lens] then
    __store.code_lens = M.code_lens_mode.off
  end
  --#endregion
end

setmetatable(M, {
  __index = function(_, key)
    return __store[key]
  end,
})

---@param filetype vim.opt.filetype
---@return table
function M.get_tsserver_file_preferences(filetype)
  local preferences = __store.tsserver_file_preferences
  return vim.tbl_extend(
    "force",
    default_preferences,
    type(preferences) == "function" and preferences(filetype) or preferences
  )
end

M.default_format_options = default_format_options

return M
