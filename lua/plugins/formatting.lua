return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        markdown = { "prettier_markdown", "markdownlint-cli2", "markdown-toc" },
        ["markdown.mdx"] = { "prettier_markdown", "markdownlint-cli2", "markdown-toc" },
        sql = { "sqlfluff" },
        mysql = { "sqlfluff" },
        plsql = { "sqlfluff" },
      },
      formatters = {
        prettier_markdown = {
          inherit = "prettier",
          append_args = { "--prose-wrap", "always" },
        },
        ["markdownlint-cli2"] = {
          -- Fix even before diagnostics have been published, including on the first save.
          condition = function()
            return true
          end,
        },
        sqlfluff = {
          -- Use LazyVim's ANSI defaults even without a project SQLFluff config.
          require_cwd = false,
        },
      },
    },
  },
}
