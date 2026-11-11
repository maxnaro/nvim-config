-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.ai_cmp = false

-- Keep search and explorer rooted at the Git repository before LSP workspaces.
vim.g.root_spec = { ".git", "lsp", "cwd" }

-- Keep the remote-plugin host independent of project Python environments.
local jupyter_python = vim.fn.stdpath("data") .. "/jupyter/bin/python"
if not vim.g.python3_host_prog and vim.fn.executable(jupyter_python) == 1 then
  vim.g.python3_host_prog = jupyter_python
end
