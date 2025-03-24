local ftplugin = _G.nnyIAsk5fJtqzUaJ_typescript_tools_ftplugin

if not ftplugin then
  ftplugin = dofile(vim.fn.expand "<sfile>:h:h" .. "/utils/ftplugin-common.lua")
  _G.nnyIAsk5fJtqzUaJ_typescript_tools_ftplugin = ftplugin
end

ftplugin.initialize()
