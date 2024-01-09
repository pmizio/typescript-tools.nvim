return {
  ServerCompositeType = {
    Single = "single",
    Primary = "primary",
    Diagnostics = "diagnostics",
  },
  InternalCommands = {
    InvokeAdditionalRename = "invoke_additional_rename",
    CallApiFunction = "call_api_function",
    RequestReferences = "request_references",
    RequestImplementations = "request_implementations",
  },
  ---@enum CommandTypes
  CommandTypes = {
    JsxClosingTag = "jsxClosingTag",
    Brace = "brace",
    BraceCompletion = "braceCompletion",
    GetSpanOfEnclosingComment = "getSpanOfEnclosingComment",
    Change = "change",
    Close = "close",
    ---@deprecated Prefer CompletionInfo -- see comment on CompletionsResponse
    Completions = "completions",
    CompletionInfo = "completionInfo",
    CompletionDetails = "completionEntryDetails",
    CompileOnSaveAffectedFileList = "compileOnSaveAffectedFileList",
    CompileOnSaveEmitFile = "compileOnSaveEmitFile",
    Configure = "configure",
    Definition = "definition",
    DefinitionAndBoundSpan = "definitionAndBoundSpan",
    Implementation = "implementation",
    Exit = "exit",
    FileReferences = "fileReferences",
    Format = "format",
    Formatonkey = "formatonkey",
    Geterr = "geterr",
    GeterrForProject = "geterrForProject",
    SemanticDiagnosticsSync = "semanticDiagnosticsSync",
    SyntacticDiagnosticsSync = "syntacticDiagnosticsSync",
    SuggestionDiagnosticsSync = "suggestionDiagnosticsSync",
    NavBar = "navbar",
    Navto = "navto",
    NavTree = "navtree",
    NavTreeFull = "navtree-full",
    ---@deprecated
    Occurrences = "occurrences",
    DocumentHighlights = "documentHighlights",
    Open = "open",
    Quickinfo = "quickinfo",
    References = "references",
    Reload = "reload",
    Rename = "rename",
    Saveto = "saveto",
    SignatureHelp = "signatureHelp",
    FindSourceDefinition = "findSourceDefinition",
    Status = "status",
    TypeDefinition = "typeDefinition",
    ProjectInfo = "projectInfo",
    ReloadProjects = "reloadProjects",
    Unknown = "unknown",
    OpenExternalProject = "openExternalProject",
    OpenExternalProjects = "openExternalProjects",
    CloseExternalProject = "closeExternalProject",
    UpdateOpen = "updateOpen",
    GetOutliningSpans = "getOutliningSpans",
    TodoComments = "todoComments",
    Indentation = "indentation",
    DocCommentTemplate = "docCommentTemplate",
    CompilerOptionsForInferredProjects = "compilerOptionsForInferredProjects",
    GetCodeFixes = "getCodeFixes",
    GetCombinedCodeFix = "getCombinedCodeFix",
    ApplyCodeActionCommand = "applyCodeActionCommand",
    GetSupportedCodeFixes = "getSupportedCodeFixes",
    GetApplicableRefactors = "getApplicableRefactors",
    GetEditsForRefactor = "getEditsForRefactor",
    OrganizeImports = "organizeImports",
    GetEditsForFileRename = "getEditsForFileRename",
    ConfigurePlugin = "configurePlugin",
    SelectionRange = "selectionRange",
    ToggleLineComment = "toggleLineComment",
    ToggleMultilineComment = "toggleMultilineComment",
    CommentSelection = "commentSelection",
    UncommentSelection = "uncommentSelection",
    PrepareCallHierarchy = "prepareCallHierarchy",
    ProvideCallHierarchyIncomingCalls = "provideCallHierarchyIncomingCalls",
    ProvideCallHierarchyOutgoingCalls = "provideCallHierarchyOutgoingCalls",
    ProvideInlayHints = "provideInlayHints",
    EncodedSemanticClassificationsFull = "encodedSemanticClassifications-full",
  },
  ---@enum ScriptElementKind
  ScriptElementKind = {
    unknown = "",
    warning = "warning",
    -- predefined type (void) or keyword (class)
    keyword = "keyword",
    -- top level script node
    scriptElement = "script",
    -- module foo {}
    moduleElement = "module",
    -- class X {}
    classElement = "class",
    -- var x = class X {}
    localClassElement = "local class",
    -- interface Y {}
    interfaceElement = "interface",
    -- type T = ...
    typeElement = "type",
    -- enum E
    enumElement = "enum",
    enumMemberElement = "enum member",
    --[[
    Inside module and script only
    const v = ..
    --]]
    variableElement = "var",
    -- Inside function
    localVariableElement = "local var",
    --[[
    Inside module and script only
    function f() { }
    --]]
    functionElement = "function",
    -- Inside function
    localFunctionElement = "local function",
    -- class X { [public|private]* foo() {} }
    memberFunctionElement = "method",
    -- class X { [public|private]* [get|set] foo:number; }
    memberGetAccessorElement = "getter",
    memberSetAccessorElement = "setter",
    --[[
    class X { [public|private]* foo:number; }
    interface Y { foo:number; }
    --]]
    memberVariableElement = "property",
    --[[
    class X { constructor() { } }
    class X { static { } }
    --]]
    constructorImplementationElement = "constructor",
    -- interface Y { ():number; }
    callSignatureElement = "call",
    -- interface Y { []:number; }
    indexSignatureElement = "index",
    -- interface Y { new():Y; }
    constructSignatureElement = "construct",
    -- function foo(*Y*: string)
    parameterElement = "parameter",
    typeParameterElement = "type parameter",
    primitiveType = "primitive type",
    label = "label",
    alias = "alias",
    constElement = "const",
    letElement = "let",
    directory = "directory",
    externalModuleName = "external module name",
    -- <JsxTagName attribute1 attribute2={0} />
    ---@deprecated
    jsxAttribute = "JSX attribute",
    -- String literal
    string = "string",
    -- Jsdoc @link: in `{@link C link text}`, the before and after text "{@link " and "}"
    link = "link",
    -- Jsdoc @link: in `{@link C link text}`, the entity name "C"
    linkName = "link name",
    -- Jsdoc @link: in `{@link C link text}`, the link text "link text"
    linkText = "link text",
  },
  CompletionsTriggerCharacter = { ".", '"', "'", "`", "/", "@", "<", "#", " " },
  ScriptKindName = {
    TS = "TS",
    JS = "JS",
    TSX = "TSX",
    JSX = "JSX",
  },
  ---@enum DiagnosticEventKind
  DiagnosticEventKind = {
    SemanticDiag = "semanticDiag",
    SyntaxDiag = "syntaxDiag",
    SuggestionDiag = "suggestionDiag",
    RequestCompleted = "requestCompleted",
  },
  RequestCompletedEventName = "requestCompleted",
  ---@enum SignatureHelpTriggerReason
  SignatureHelpTriggerReason = {
    Invoked = "invoked",
    CharacterTyped = "characterTyped",
    Retrigger = "retrigger",
  },
  HighlightSpanKind = {
    none = "none",
    definition = "definition",
    reference = "reference",
    writtenReference = "writtenReference",
  },
  ---@enum LspMethods
  LspMethods = {
    Initialize = "initialize",
    Shutdown = "shutdown",
    DidOpen = "textDocument/didOpen",
    DidChange = "textDocument/didChange",
    DidClose = "textDocument/didClose",
    DidSave = "textDocument/didSave",
    Rename = "textDocument/rename",
    Completion = "textDocument/completion",
    CompletionResolve = "completionItem/resolve",
    PublishDiagnostics = "textDocument/publishDiagnostics",
    Hover = "textDocument/hover",
    Definition = "textDocument/definition",
    Implementation = "textDocument/implementation",
    TypeDefinition = "textDocument/typeDefinition",
    Declaration = "textDocument/declaration",
    Reference = "textDocument/references",
    DocumentSymbol = "textDocument/documentSymbol",
    SignatureHelp = "textDocument/signatureHelp",
    DocumentHighlight = "textDocument/documentHighlight",
    CodeAction = "textDocument/codeAction",
    CodeActionResolve = "codeAction/resolve",
    Formatting = "textDocument/formatting",
    RangeFormatting = "textDocument/rangeFormatting",
    PrepareCallHierarchy = "textDocument/prepareCallHierarchy",
    FoldingRange = "textDocument/foldingRange",
    SemanticTokensFull = "textDocument/semanticTokens/full",
    SemanticTokensRange = "textDocument/semanticTokens/range",
    InlayHint = "textDocument/inlayHint",
    IncomingCalls = "callHierarchy/incomingCalls",
    OutgoingCalls = "callHierarchy/outgoingCalls",
    WorkspaceSymbol = "workspace/symbol",
    Progress = "$/progress",
    ExecuteCommand = "workspace/executeCommand",
    WillRenameFiles = "workspace/willRenameFiles",
    CancelRequest = "$/cancelRequest",
    CodeLens = "textDocument/codeLens",
    CodeLensResolve = "codeLens/resolve",
  },
  ---@enum CustomMethods
  CustomMethods = {
    OrganizeImports = "typescriptTools/organizeImports",
    Diagnostic = "typescriptTools/diagnostic",
    BatchCodeActions = "typescriptTools/batchCodeActions",
    ConfigurePlugin = "typescriptTools/configurePlugin",
    JsxClosingTag = "typescriptTools/jsxClosingTag",
    FileReferences = "typescriptTools/fileReferences",
    SaveTo = "typescriptTools/saveTo",
  },
  TsserverEvents = {
    ProjectLoadingStart = "projectLoadingStart",
    ProjectLoadingFinish = "projectLoadingFinish",
  },
  ---@enum CompletionItemKind
  CompletionItemKind = {
    Text = 1,
    Method = 2,
    Function = 3,
    Constructor = 4,
    Field = 5,
    Variable = 6,
    Class = 7,
    Interface = 8,
    Module = 9,
    Property = 10,
    Unit = 11,
    Value = 12,
    Enum = 13,
    Keyword = 14,
    Snippet = 15,
    Color = 16,
    File = 17,
    Reference = 18,
    Folder = 19,
    EnumMember = 20,
    Constant = 21,
    Struct = 22,
    Event = 23,
    Operator = 24,
    TypeParameter = 25,
  },
  FoldingRangeKind = {
    Comment = "comment",
    Imports = "imports",
    Region = "region",
  },
  ---@enum InsertTextFormat
  InsertTextFormat = {
    PlainText = 1,
    Snippet = 2,
  },
  MarkupKind = {
    PlainText = "plaintext",
    Markdown = "markdown",
  },
  ---@enum DiagnosticSeverity
  DiagnosticSeverity = {
    Error = 1,
    Warning = 2,
    Information = 3,
    Hint = 4,
  },
  ---@enum DiagnosticTag
  DiagnosticTag = {
    Unnecessary = 1,
    Deprecated = 2,
  },
  -- https://github.com/microsoft/TypeScript/blob/7f292bf2a19aa14ed69a55e646111af9533d8f1c/src/server/protocol.ts#L699
  ---@enum OrganizeImportsMode
  OrganizeImportsMode = {
    All = "All",
    SortAndCombine = "SortAndCombine",
    RemoveUnused = "RemoveUnused",
  },
  SignatureHelpTriggerKind = {
    Invoked = 1,
    TriggerCharacter = 2,
    ContentChange = 3,
  },
  ---@enum SymbolKind
  SymbolKind = {
    File = 1,
    Module = 2,
    Namespace = 3,
    Package = 4,
    Class = 5,
    Method = 6,
    Property = 7,
    Field = 8,
    Constructor = 9,
    Enum = 10,
    Interface = 11,
    Function = 12,
    Variable = 13,
    Constant = 14,
    String = 15,
    Number = 16,
    Boolean = 17,
    Array = 18,
    Object = 19,
    Key = 20,
    Null = 21,
    EnumMember = 22,
    Struct = 23,
    Event = 24,
    Operator = 25,
    TypeParameter = 26,
  },
  DocumentHighlightKind = {
    Text = 1,
    Read = 2,
    Write = 3,
  },
  ---@enum CodeActionKind
  CodeActionKind = {
    Empty = "",
    QuickFix = "quickfix",
    Refactor = "refactor",
    RefactorExtract = "refactor.extract",
    RefactorInline = "refactor.inline",
    RefactorRewrite = "refactor.rewrite",
    Source = "source",
    SourceOrganizeImports = "source.organizeImports",
    SourceFixAll = "source.fixAll",
  },
  ---@enum DiagnosticReportKind
  DocumentDiagnosticReportKind = {
    Full = "full",
    Unchanged = "unchanged",
  },
  ---@enum LspErrorCodes
  LspErrorCodes = {
    ServerCancelled = -32802,
  },
  DiagnosticSource = "tsserver",
}
