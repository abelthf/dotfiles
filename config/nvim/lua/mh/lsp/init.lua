local vim = vim
local uv = vim.loop
local lspconfig = require "lspconfig"
local mapBuf = require "mh.mappings".mapBuf
local autocmd = require "mh.autocmds".autocmd
local capabilities = vim.lsp.protocol.make_client_capabilities()

capabilities.textDocument.completion.completionItem.snippetSupport = true

local M = {}
local function requestCompletionItemResolve(bufnr, item)
   vim.lsp.buf_request(bufnr, "completionItem/resolve", item, function(err, _, result)
     if err or not result then
       return
     end
     if result.additionalTextEdits then
       vim.lsp.util.apply_text_edits(result.additionalTextEdits, bufnr)
     end
    end)
end
function M.on_complete_done()

  local bufnr = vim.api.nvim_get_current_buf()
  local completed_item_var = vim.v.completed_item
  if
   completed_item_var and
   completed_item_var.user_data and
   completed_item_var.user_data.nvim and
   completed_item_var.user_data.nvim.lsp and
   completed_item_var.user_data.nvim.lsp.completion_item
   then
     local item = completed_item_var.user_data.nvim.lsp.completion_item
     requestCompletionItemResolve(bufnr, item)
 end
 if
   completed_item_var and
   completed_item_var.user_data and
   completed_item_var.user_data and
   completed_item_var.user_data.lsp and
   completed_item_var.user_data.lsp.completion_item
  then
   local item = completed_item_var.user_data.lsp.completion_item
   requestCompletionItemResolve(bufnr, item)
  end
  -- vim.v.completed_item = nil
end



vim.lsp.handlers["textDocument/publishDiagnostics"] =
  vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {virtual_text = false})

local function get_node_modules(root_dir)
  -- util.find_node_modules_ancestor()
  local root_node = root_dir .. "/node_modules"
  local stats = uv.fs_stat(root_node)
  if stats == nil then
    return nil
  else
    return root_node
  end
end

local function organize_imports()
  local params = {
    command = "_typescript.organizeImports",
    arguments = {vim.api.nvim_buf_get_name(0)},
    title = ""
  }
  vim.lsp.buf.execute_command(params)
end

local default_node_modules = get_node_modules(vim.fn.getcwd())

local on_attach = function(_, bufnr)
  require "completion".on_attach()
  mapBuf(bufnr, "n", "<Leader>gdc", "<Cmd>lua vim.lsp.buf.declaration()<CR>")
  mapBuf(bufnr, "n", "<Leader>gd", "<Cmd>lua vim.lsp.buf.definition()<CR>")
  mapBuf(bufnr, "n", "<Leader>gt", "<Cmd>lua vim.lsp.buf.hover()<CR>")
  mapBuf(bufnr, "n", "<Leader>gi", "<cmd>lua vim.lsp.buf.implementation()<CR>")
  mapBuf(bufnr, "n", "<Leader>gs", "<cmd>lua vim.lsp.buf.signature_help()<CR>")
  mapBuf(bufnr, "n", "<Leader>gtd", "<cmd>lua vim.lsp.buf.type_definition()<CR>")
  mapBuf(bufnr, "n", "<Leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>")
  mapBuf(bufnr, "n", "<Leader>gr", "<cmd>lua vim.lsp.buf.references()<CR>")
  mapBuf(bufnr, "n", "<Leader>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>")
  mapBuf(bufnr, "v", "<Leader>ca", "<cmd>lua vim.lsp.buf.range_code_action()<CR>")
  autocmd("CursorHold", "<buffer>", "lua vim.lsp.diagnostic.show_line_diagnostics()")
  autocmd("CompleteDone", "<buffer>", "lua require('mh.lsp').on_complete_done()")
  vim.bo.omnifunc = "v:lua.vim.lsp.omnifunc"
  vim.fn.sign_define("LspDiagnosticsSignError", {text = "•"})
  vim.fn.sign_define("LspDiagnosticsSignWarning", {text = "•"})
  vim.fn.sign_define("LspDiagnosticsSignInformation", {text = "•"})
  vim.fn.sign_define("LspDiagnosticsSignHint", {text = "•"})
  vim.cmd("hi LspDiagnosticsUnderlineError gui=undercurl")
  vim.cmd("hi LspDiagnosticsUnderlineWarning gui=undercurl")
  vim.cmd("hi LspDiagnosticsUnderlineInformation gui=undercurl")
  vim.cmd("hi LspDiagnosticsUnderlineHint gui=undercurl")
end
local servers = {"pyls", "bashls"}
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = on_attach,
    capabilities = capabilities
  }
end

lspconfig.tsserver.setup {
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
    "vue"
  },
  on_attach = on_attach,
  capabilities = capabilities,
  commands = {
    OrganizeImports = {
      organize_imports,
      description = "Organize Imports"
    }
  }
}

local vs_code_extracted = {
  html = "vscode-html-language-server",
  cssls = "vscode-css-language-server",
  jsonls = "vscode-json-language-server",
  vimls = "vim-language-server"
}

for ls, cmd in pairs(vs_code_extracted) do
  lspconfig[ls].setup {
    cmd = {cmd, "--stdio"},
    on_attach = on_attach,
    capabilities = capabilities
  }
end

local lua_lsp_loc = "/Users/mhartington/Github/lua-language-server"

local ngls_cmd = {
  "ngserver",
  "--stdio",
  "--tsProbeLocations",
  default_node_modules,
  "--ngProbeLocations",
  default_node_modules
}

lspconfig.angularls.setup {
  cmd = ngls_cmd,
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = {'html'},
  on_new_config = function(new_config)
    new_config.cmd = ngls_cmd
  end
}

lspconfig.sumneko_lua.setup {
  cmd = {lua_lsp_loc .. "/bin/macOS/lua-language-server", "-E", lua_lsp_loc .. "/main.lua"},
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    Lua = {
      runtime = {version = "LuaJIT", path = vim.split(package.path, ";")},
      diagnostics = {globals = {"vim"}},
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = {
          [vim.fn.expand "$VIMRUNTIME/lua"] = true,
          [vim.fn.expand "$VIMRUNTIME/lua/vim/lsp"] = true
        }
      }
    }
  }
}
return M
