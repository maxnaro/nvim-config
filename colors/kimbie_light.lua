-- Kimbie Light adaptation, based on Jan T. Sott / idleberg's Kimbie theme.
-- https://github.com/idleberg/vim-kimbie (CC-BY-SA 4.0)
vim.cmd([[highlight clear]])
if vim.fn.exists("syntax_on") == 1 then vim.cmd([[syntax reset]]) end

local p = require("config.palette")
vim.o.background = "light"
vim.g.colors_name = "kimbie_light"

local groups = {
  Normal = { fg = p.fg, bg = "NONE" },
  NormalNC = { fg = p.fg, bg = "NONE" },
  NormalFloat = { fg = p.fg, bg = "NONE" },
  SignColumn = { fg = p.muted, bg = "NONE" },
  FoldColumn = { fg = p.muted, bg = "NONE" },
  LineNr = { fg = p.muted, bg = "NONE" },
  CursorLineNr = { fg = p.red, bold = true, bg = "NONE" },
  EndOfBuffer = { fg = p.muted, bg = "NONE" },
  VertSplit = { fg = p.muted, bg = "NONE" },
  Comment = { fg = p.muted, italic = true },
  Constant = { fg = p.red },
  String = { fg = p.green },
  Character = { fg = p.green },
  Number = { fg = p.purple },
  Boolean = { fg = p.purple },
  Identifier = { fg = p.fg },
  Function = { fg = p.blue },
  Statement = { fg = p.red },
  Conditional = { fg = p.red },
  Repeat = { fg = p.red },
  Operator = { fg = p.yellow },
  Keyword = { fg = p.red, bold = true },
  Exception = { fg = p.red },
  PreProc = { fg = p.purple },
  Type = { fg = p.blue },
  Special = { fg = p.cyan },
  Todo = { fg = p.bg, bg = p.yellow, bold = true },
  Error = { fg = p.red, bold = true },
  DiagnosticError = { fg = p.red },
  DiagnosticWarn = { fg = p.yellow },
  DiagnosticInfo = { fg = p.blue },
  DiagnosticHint = { fg = p.cyan },
  Visual = { bg = p.selection },
  Search = { fg = p.bg, bg = p.yellow },
  IncSearch = { fg = p.bg, bg = p.red },
  Pmenu = { fg = p.fg, bg = p.surface },
  PmenuSel = { fg = p.bright, bg = p.selection },
  DiffAdd = { fg = p.green, bg = p.surface },
  DiffChange = { fg = p.blue, bg = p.surface },
  DiffDelete = { fg = p.red, bg = p.surface },
  DiffText = { fg = p.fg, bg = p.selection, bold = true },
  MatchParen = { fg = p.red, bg = p.selection, bold = true },
  Folded = { fg = p.muted, bg = p.surface },
  ColorColumn = { bg = p.surface },
}

for name, spec in pairs(groups) do vim.api.nvim_set_hl(0, name, spec) end
