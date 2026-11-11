local fallback = {
  bg = "#221A15", surface = "#2A201A", selection = "#44342A", muted = "#5C483C",
  fg = "#D3C6AA", bright = "#F2E7C9", red = "#DC7062", green = "#889B4A",
  yellow = "#E6B450", blue = "#7FA2B5", purple = "#BC8CBC", cyan = "#7EA69F",
  -- File labels need contrast against the picker selection as well as the background.
  picker = {
    hidden = "#C2AE93", muted = "#B09D87", blue = "#9AB7C7", green = "#A2B465",
    yellow = "#E6B450", red = "#E58A7D", purple = "#CB9ECB", cyan = "#96B9B3",
  },
  ansi = { "#2A201A", "#DC7062", "#889B4A", "#E6B450", "#7FA2B5", "#BC8CBC", "#7EA69F", "#D3C6AA",
    "#5C483C", "#E08577", "#A2B465", "#F0C36B", "#9AB7C7", "#CB9ECB", "#96B9B3", "#F2E7C9" },
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
