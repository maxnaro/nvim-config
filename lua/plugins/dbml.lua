-- Install with: cargo install dbml-language-server
vim.filetype.add({ extension = { dbml = "dbml" } })

return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      require("config.dbml").setup()
    end,
    opts = {
      servers = {
        dbml_language_server = {
          mason = false,
          cmd = { "dbml-language-server" },
          filetypes = { "dbml" },
          root_markers = { ".git" },
          workspace_required = false,
        },
      },
    },
  },
}
