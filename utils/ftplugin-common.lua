if vim.fn.exists "g:disable_typescript_tools" == 1 then
  return
end
if vim.fn.exists "b:did_typescript_tools_ftplugin" == 1 then
  return
end
vim.b.did_typescript_tools_ftplugin = true

---@param name string
---@param fn function
local function create_command(name, fn)
  local command_completion = {
    nargs = "?",
    complete = function()
      return { "sync" }
    end,
  }
  vim.api.nvim_buf_create_user_command(0, name, function(cmd)
    local words = cmd.fargs

    if #words == 1 and words[1] ~= "sync" then
      vim.notify("No such command", vim.log.levels.ERROR)
      return
    end

    fn(#words == 1)
  end, command_completion)
end

create_command("TSToolsOrganizeImports", function(is_sync)
  require("typescript-tools.api").organize_imports(is_sync)
end)

create_command("TSToolsSortImports", function(is_sync)
  require("typescript-tools.api").sort_imports(is_sync)
end)

create_command("TSToolsRemoveUnusedImports", function(is_sync)
  require("typescript-tools.api").remove_unused_imports(is_sync)
end)

create_command("TSToolsGoToSourceDefinition", function(is_sync)
  require("typescript-tools.api").go_to_source_definition(is_sync)
end)

create_command("TSToolsRemoveUnused", function(is_sync)
  require("typescript-tools.api").remove_unused(is_sync)
end)

create_command("TSToolsAddMissingImports", function(is_sync)
  require("typescript-tools.api").add_missing_imports(is_sync)
end)

create_command("TSToolsFixAll", function(is_sync)
  require("typescript-tools.api").fix_all(is_sync)
end)

create_command("TSToolsRenameFile", function(is_sync)
  require("typescript-tools.api").rename_file(is_sync)
end)

create_command("TSToolsFileReferences", function(is_sync)
  require("typescript-tools.api").file_references(is_sync)
end)
