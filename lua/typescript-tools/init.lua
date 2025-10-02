local rpc = require "typescript-tools.rpc"
local plugin_config = require "typescript-tools.config"

local M = {}

-- Native utility functions to replace lspconfig.util
local function root_pattern(...)
  local patterns = vim.tbl_flatten { ... }
  return function(startpath)
    local found = vim.fs.find(patterns, {
      path = startpath,
      upward = true,
    })[1]
    return found and vim.fs.dirname(found) or nil
  end
end

function M.setup(config)
  config = config or {}
  local settings = config.settings or {}

  plugin_config.load_settings(settings)

  -- Check if we're on Neovim 0.11+ with native LSP config support
  if vim.lsp.config and vim.lsp.enable then
    -- Use native Neovim 0.11 LSP configuration instead of lspconfig framework
    vim.lsp.config[plugin_config.plugin_name] = {
      cmd = function(...)
        return rpc.start(...)
      end,
      filetypes = {
        "javascript",
        "javascriptreact",
        "javascript.jsx",
        "typescript",
        "typescriptreact",
        "typescript.tsx",
      },
      root_markers = { "tsconfig.json", "package.json", "jsconfig.json", ".git" },
      single_file_support = true,
      -- Pass through lspconfig-compatible options
      on_attach = config.on_attach,
      capabilities = config.capabilities,
      handlers = config.handlers,
      init_options = config.init_options,
    }

    -- Enable the LSP server
    vim.lsp.enable(plugin_config.plugin_name)
  else
    -- Fallback to lspconfig for older Neovim versions
    local lspconfig = require "lspconfig"
    local configs = require "lspconfig.configs"

    if configs[plugin_config.plugin_name] == nil then
      configs[plugin_config.plugin_name] = {
        default_config = {
          cmd = function(...)
            return rpc.start(...)
          end,
          filetypes = {
            "javascript",
            "javascriptreact",
            "javascript.jsx",
            "typescript",
            "typescriptreact",
            "typescript.tsx",
          },
          root_dir = function(fname)
            local root_dir = root_pattern "tsconfig.json"(fname)
              or root_pattern("package.json", "jsconfig.json", ".git")(fname)

            -- Make sure we don't pick up root_dir inside node_modules
            local node_modules_index = root_dir and root_dir:find("node_modules", 1, true)
            if node_modules_index and node_modules_index > 0 then
              root_dir = root_dir:sub(1, node_modules_index - 2)
            end

            return root_dir
          end,
          single_file_support = true,
        },
      }
    end

    lspconfig[plugin_config.plugin_name].setup(config)
  end
end

return M
