-- Install with: go install github.com/ptdewey/plantuml-lsp@latest
-- Install PlantUML separately to enable diagnostics.
vim.filetype.add({
  extension = { puml = "plantuml", plantuml = "plantuml" },
})

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        plantuml_lsp = {
          mason = false,
          cmd = vim.fn.executable("plantuml") == 1 and { "plantuml-lsp", "--exec-path=plantuml" }
            or { "plantuml-lsp" },
          filetypes = { "plantuml" },
          root_markers = { ".git" },
          workspace_required = false,
        },
      },
    },
  },
}
