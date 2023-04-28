---@class Dispatchers
---@field notification fun(method: string, params: table)
---@field server_request fun(method: string, params: table): nil, table
---@field on_exit fun(code: number, signal: number)

---@alias LspCallback fun(err: any, result: any)

---@class LspInterface
---@field request fun(method: string, params: table|nil, callback: LspCallback, notify_reply_callback: function|nil): boolean, number:nil
---@field notify fun(method: string, params: table|nil): boolean
---@field terminate function
---@field is_closing fun(): boolean

---@class TsserverRequest
---@field command CommandTypes
---@field arguments table

---@alias TsserverRequestFn fun(request: TsserverRequest): number
---@alias LspResponseFn fun(seq: number, response: table|nil): boolean
---@alias TsserverProtocolHandler fun(request: TsserverRequestFn, response: LspResponseFn, params: table): boolean

---@alias ServerType "syntax"|"diagnostic"

---@class LspPosition
---@field line number
---@field character number
--
---@class TssPosition
---@field line number
---@field offset number

---@class LspRange
---@field start LspPosition
---@field end LspPosition

---@class TssRange
---@field start TssPosition
---@field end TssPosition

---@class LspEdit
---@field newText string
---@field range LspRange

---@class CallHierarchyItem
---@field name string
---@field kind SymbolKind
---@field uri string
---@field range LspRange
---@field selectionRange LspRange

---@class TextDocument
---@field uri string
---@field languageId string|nil
