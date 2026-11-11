-- Keep the file path stable so running LazyGit jobs can reload it on focus.
local function setup_theme()
  local path = vim.fn.stdpath("cache") .. "/lazygit-theme.yml"
  local function write()
    local p = require("config.palette")
    local config = {
      os = { editPreset = "nvim-remote" },
      gui = {
        nerdFontsVersion = "3",
        colorScheme = p.mode,
        theme = {
          activeBorderColor = { p.cyan, "bold" },
          inactiveBorderColor = { p.muted },
          searchingActiveBorderColor = { p.purple, "bold" },
          defaultFgColor = { p.fg }, optionsTextColor = { p.cyan },
          selectedLineBgColor = { "default" },
          inactiveViewSelectedLineBgColor = { "default" },
          cherryPickedCommitFgColor = { p.green },
          cherryPickedCommitBgColor = { p.blue },
          markedBaseCommitFgColor = { p.blue },
          markedBaseCommitBgColor = { p.yellow },
          unstagedChangesColor = { p.red },
        },
      },
    }
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    local temporary = path .. "." .. vim.fn.getpid() .. ".tmp"
    -- JSON is valid YAML and avoids a second serializer for this overlay.
    vim.fn.writefile({ vim.json.encode(config) }, temporary)
    local ok, err = vim.uv.fs_rename(temporary, path)
    if not ok then
      vim.fn.delete(temporary)
      error(err)
    end
  end
  write()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("DotfilesLazyGitTheme", { clear = true }),
    pattern = { "kimbie_light", "chocolatier" },
    callback = write,
  })
  local files = vim.split(vim.env.LG_CONFIG_FILE or "", ",", { trimempty = true })
  if #files == 0 then
    local result = vim.fn.system({ "lazygit", "-cd" })
    if vim.v.shell_error == 0 then
      local directory = vim.split(result, "\n", { trimempty = true })[1]
      local default = directory and (directory .. "/config.yml")
      if default and vim.fn.filereadable(default) == 1 then files[1] = default end
    end
  end
  if not vim.tbl_contains(files, path) then files[#files + 1] = path end
  return table.concat(files, ",")
end

return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.lazygit = vim.tbl_deep_extend("force", opts.lazygit or {}, {
        configure = false,
        env = { LG_CONFIG_FILE = setup_theme() },
        win = { border = "rounded", backdrop = false },
      })
    end,
  },
}
