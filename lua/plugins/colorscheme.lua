local function style()
  local p = require("config.palette")
  local overrides = {
    WinSeparator = { fg = p.muted, bg = "NONE" },
    Pmenu = { fg = p.fg, bg = p.surface },
    PmenuSel = { fg = p.bright, bg = p.selection },
    -- Keep file states distinct and readable over selected and inactive rows.
    SnacksPickerPathHidden = { fg = p.picker.hidden },
    SnacksPickerPathIgnored = { fg = p.picker.muted },
    SnacksPickerDir = { fg = p.picker.muted },
    SnacksPickerDirectory = { fg = p.picker.blue, bold = true },
    SnacksPickerLink = { fg = p.picker.muted, italic = true },
    SnacksPickerLinkBroken = { fg = p.picker.red },
    SnacksPickerGitStatus = { fg = p.picker.yellow },
    SnacksPickerGitStatusAdded = { fg = p.picker.green },
    SnacksPickerGitStatusModified = { fg = p.picker.yellow },
    SnacksPickerGitStatusDeleted = { fg = p.picker.red },
    SnacksPickerGitStatusRenamed = { fg = p.picker.purple },
    SnacksPickerGitStatusCopied = { fg = p.picker.purple },
    SnacksPickerGitStatusUntracked = { fg = p.picker.blue },
    SnacksPickerGitStatusIgnored = { fg = p.picker.muted },
    SnacksPickerGitStatusUnmerged = { fg = p.picker.red },
    SnacksPickerGitStatusStaged = { fg = p.picker.cyan },
    BlinkCmpMenuBorder = { fg = p.cyan, bg = p.surface },
    BlinkCmpDocBorder = { fg = p.cyan, bg = "NONE" },
    BlinkCmpSignatureHelpBorder = { fg = p.cyan, bg = "NONE" },
    NoiceCmdlinePopupBorder = { fg = p.cyan, bg = "NONE" },
    StatusLine = { fg = p.fg, bg = "NONE" },
    StatusLineNC = { fg = p.picker.muted, bg = "NONE" },
    FloatBorder = { fg = p.cyan, bg = "NONE" },
    LazyGitBorder = { fg = p.cyan, bg = "NONE" },
    LazyGitFloat = { fg = p.fg, bg = "NONE" },
  }
  if vim.g.colors_name == "gruvbox" then
    for _, name in ipairs({ "Normal", "NormalNC", "NormalFloat", "SignColumn", "FoldColumn", "LineNr", "CursorLineNr", "EndOfBuffer", "VertSplit" }) do
      local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
      highlight.bg = nil
      vim.api.nvim_set_hl(0, name, highlight)
    end
    for _, color in ipairs({ "Red", "Green", "Yellow", "Blue", "Purple", "Aqua", "Orange" }) do
      local name = "Gruvbox" .. color .. "Sign"
      local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
      highlight.bg = nil
      vim.api.nvim_set_hl(0, name, highlight)
    end
  end
  for name, highlight in pairs(overrides) do vim.api.nvim_set_hl(0, name, highlight) end
  for index, color in ipairs(p.ansi) do vim.g["terminal_color_" .. index - 1] = color end
end

local function apply()
  package.loaded["config.palette"] = nil
  local p = require("config.palette")
  local palette = { dark0 = p.bg, dark1 = p.surface, dark2 = p.selection, dark3 = p.selection,
    dark4 = p.muted, light0 = p.bright, light1 = p.fg }

  palette.alt_g = p.picker.muted
  palette.alt_a = p.bg
  palette.alt_b = p.surface
  palette.alt_c = p.cyan
  palette.alt_h = p.bg
  palette.alt_r = p.bg
  palette.alt_s = p.selection
  if p.mode == "dark" then
    palette.light2, palette.light3, palette.light4 = p.fg, p.picker.muted, p.picker.muted
  end
  vim.o.background = p.mode
  for name, color in pairs({ red = p.red, green = p.green, yellow = p.yellow, blue = p.blue,
    purple = p.purple, teal = p.cyan, orange = p.yellow, fuscia = p.purple }) do
    for _, prefix in ipairs({ "light_", "dark_", "neutral_", "bright_", "faded_" }) do
      palette[prefix .. name] = color
    end
  end
  if p.mode == "dark" then
    require("chocolatier").setup({
      terminal_colors = false,
      palette_overrides = palette,
      transparent_mode = true,
    })
    vim.cmd([[colorscheme chocolatier]])
  else
    vim.g.gruvbox_contrast_light = "medium"
    vim.cmd([[colorscheme gruvbox]])
  end
  for index, color in ipairs(p.ansi) do
    vim.g["terminal_color_" .. index - 1] = color
  end
  if package.loaded["lualine"] then
    local opts = require("lualine").get_config()
    local spec = dofile(vim.fn.stdpath("config") .. "/lua/plugins/statusline.lua")
    spec[1].opts(nil, opts)
    require("lualine").setup(opts)
  end
end

return {
  {
    "qaptoR-nvim/chocolatier.nvim",
    lazy = false,
    priority = 1000,
    dependencies = { "rktjmp/lush.nvim", "morhetz/gruvbox" },
    config = function()
      local group = vim.api.nvim_create_augroup("DotfilesTheme", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", { group = group, pattern = { "gruvbox", "chocolatier" }, callback = style })

      apply()
      local state = (vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")) .. "/dotfiles/theme"
      local function refresh()
        local file = io.open(state .. "/mode", "r")
        local mode = file and file:read("*l") or "dark"
        if file then file:close() end
        if mode ~= require("config.palette").mode then apply() end
      end
      local watcher = vim.uv.new_fs_event()
      if watcher then
        watcher:start(state, {}, vim.schedule_wrap(refresh))
        vim.api.nvim_create_autocmd("VimLeavePre", { callback = function() watcher:stop(); watcher:close() end })
      end
      vim.api.nvim_create_autocmd("FocusGained", { callback = refresh })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = apply,
    },
  },
}
