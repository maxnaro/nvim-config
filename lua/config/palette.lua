local fallback = {
  bg = "#281F11", surface = "#30211C", selection = "#4E3819", muted = "#7C5F35", fg = "#D3AF86", bright = "#EBC295",
  red = "#C33A2B", green = "#889B4A", yellow = "#F4AA2B", blue = "#83A598", purple = "#BB7D81", cyan = "#8EC07C",
  -- File labels need contrast against the picker selection as well as the background.
  picker = {
    hidden = "#C5A37D", muted = "#AA8C6B", blue = "#83A598", green = "#889B4A", yellow = "#F4AA2B", red = "#C33A2B", purple = "#BB7D81", cyan = "#8EC07C",
  },
  ansi = { "#4E3819", "#C33A2B", "#889B4A", "#F4AA2B", "#83A598", "#BB7D81", "#8EC07C", "#AA8C6B", "#8A693C", "#CE5D51", "#9DAD6B", "#F6B951", "#99B5AB", "#C79498", "#A2CB94", "#EBC295" },
}

-- Keep the editor usable when this configuration is installed standalone.
local config = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")
local state = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
local mode = "dark"
local file = io.open(state .. "/dotfiles/theme/mode", "r")
if file then
  local saved = file:read("*l")
  file:close()
  if saved == "light" or saved == "dark" then mode = saved end
end
local ok, data = pcall(vim.fn.readfile, config .. "/dotfiles/theme/palette.json")
if ok then
  local valid, palettes = pcall(vim.json.decode, table.concat(data, "\n"))
  if valid and type(palettes[mode]) == "table" then
    local palette = vim.tbl_deep_extend("force", fallback, palettes[mode])
    palette.mode = mode
    return palette
  end
end
fallback.mode = "dark"
return fallback
