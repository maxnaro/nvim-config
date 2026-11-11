return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      local palette = require("config.palette")
      local p = palette.mode == "dark" and palette
        or { cyan = "cyan", muted = "default", purple = "magenta", fg = "default" }
      opts.lazygit = vim.tbl_deep_extend("force", opts.lazygit or {}, {
        config = { gui = { theme = {
          activeBorderColor = { p.cyan, "bold" }, inactiveBorderColor = { p.muted },
          searchingActiveBorderColor = { p.purple, "bold" }, defaultFgColor = { p.fg },
          optionsTextColor = { p.cyan }, selectedLineBgColor = { "default" },
        } } },
        win = { border = "rounded", backdrop = false },
      })
    end,
  },
}
