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

---@param settings table
function M.load_settings(settings)
  vim.validate {
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
  }

  __store = vim.tbl_deep_extend("force", __store, settings)

  if type(settings.separate_diagnostic_server) == "nil" then
    __store.separate_diagnostic_server = true
  end

  if not M.publish_diagnostic_mode[settings.publish_diagnostic_on] then
    __store.publish_diagnostic_on = M.publish_diagnostic_mode.insert_leave
  end

  if not settings.tsserver_plugins then
    __store.tsserver_plugins = {}
  end

  if not settings.tsserver_format_options then
    __store.tsserver_format_options = {}
  end

  if not settings.tsserver_file_preferences then
    __store.tsserver_file_preferences = {}
  end

  if not M.tsserver_log_level[settings.tsserver_logs] then
    __store.tsserver_logs = M.tsserver_log_level.off
  end

  if not settings.tsserver_max_memory then
    __store.tsserver_max_memory = "auto"
  end

  if not settings.tsserver_locale then
    __store.tsserver_locale = "en"
  end

  if not settings.complete_function_calls then
    __store.complete_function_calls = false
  end

  if not settings.expose_as_code_action then
    __store.expose_as_code_action = {}
  end

  if not settings.include_completions_with_insert_text then
    __store.include_completions_with_insert_text = true
  end

  if not M.code_lens_mode[settings.code_lens] then
    __store.code_lens = M.code_lens_mode.off
  end

  local default_jsx_filetypes = { "javascriptreact", "typescriptreact" }

  if not settings.jsx_close_tag then
    __store.jsx_close_tag = {
      enable = false,
      filetypes = default_jsx_filetypes,
    }
  end

  if settings.jsx_close_tag and not settings.jsx_close_tag.filetypes then
    __store.jsx_close_tag.filetypes = default_jsx_filetypes
  end
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
