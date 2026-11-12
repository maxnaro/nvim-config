local M = {}
local previews = {}

local function write_preview_page(path, svg)
  local page = [[<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DBML Preview</title>
<style>
  body { margin: 16px; background: white; font-family: sans-serif; }
  img { max-width: 100%; height: auto; }
</style>
<p id="status">Waiting for diagram...</p>
<img id="diagram" alt="DBML diagram" hidden>
<script>
  const diagram = document.getElementById("diagram");
  const status = document.getElementById("status");
  function refresh() {
    const image = new Image();
    image.onload = () => {
      diagram.src = image.src;
      diagram.hidden = false;
      status.hidden = true;
      setTimeout(refresh, 1000);
    };
    image.onerror = () => setTimeout(refresh, 1000);
    image.src = "__SVG__?t=" + Date.now();
  }
  refresh();
</script>
</html>]]
  page = page:gsub("__SVG__", vim.fn.fnamemodify(svg, ":t"))
  vim.fn.writefile(vim.split(page, "\n"), path)
end

local function open_preview(path, active)
  if vim.fn.has("wsl") ~= 1 then
    local _, err = vim.ui.open(path)
    if err then
      vim.notify("Could not open diagram: " .. err, vim.log.levels.ERROR)
    end
    return
  end

  if vim.fn.executable("wslpath") ~= 1 then
    return vim.notify("Could not open diagram: wslpath is unavailable", vim.log.levels.ERROR)
  end
  local explorer = vim.fn.exepath("explorer.exe")
  if explorer == "" then
    explorer = "/mnt/c/Windows/explorer.exe"
  end
  if vim.fn.executable(explorer) ~= 1 then
    return vim.notify("Could not open diagram: Windows explorer.exe is unavailable", vim.log.levels.ERROR)
  end

  vim.system({ "wslpath", "-w", path }, { text = true }, function(result)
    vim.schedule(function()
      if not active() then
        return
      end
      if result.code ~= 0 or not result.stdout or result.stdout == "" then
        return vim.notify("Could not convert preview path: " .. (result.stderr or ""), vim.log.levels.ERROR)
      end
      local windows_path = result.stdout:gsub("[\r\n]+$", "")
      vim.system({ explorer, windows_path }, { cwd = "/mnt/c", detach = true })
    end)
  end)
end

local function can_render(buf)
  if vim.bo[buf].filetype ~= "dbml" then
    vim.notify("Open a DBML buffer first", vim.log.levels.ERROR)
    return false
  end
  if vim.fn.executable("dbml-renderer") ~= 1 then
    vim.notify("Install @softwaretechnik/dbml-renderer to render DBML", vim.log.levels.ERROR)
    return false
  end
  return true
end

local function render(buf, output, done)
  local input = vim.fn.tempname() .. ".dbml"
  local rendered = output .. ".tmp-" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t") .. ".svg"
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.fn.writefile(lines, input)
  vim.system({ "dbml-renderer", "-i", input, "-o", rendered }, { text = true }, function(result)
    vim.schedule(function()
      vim.fn.delete(input)
      done(result, rendered)
      vim.fn.delete(rendered)
    end)
  end)
end

local function render_succeeded(result)
  if result.code == 0 then
    return true
  end
  local message = result.stderr and result.stderr ~= "" and result.stderr or result.stdout
  vim.notify("DBML rendering failed: " .. (message or ""), vim.log.levels.ERROR)
  return false
end

local function stop_preview(buf)
  local state = previews[buf]
  if not state then
    return
  end
  previews[buf] = nil
  state.timer:stop()
  state.timer:close()
  vim.fn.delete(state.html)
  vim.fn.delete(state.svg)
end

local function update_preview(buf, state)
  if previews[buf] ~= state or state.running or not state.dirty then
    return
  end
  state.dirty = false
  state.running = true
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  render(buf, state.svg, function(result, rendered)
    state.running = false
    if previews[buf] ~= state then
      return
    end
    if vim.api.nvim_buf_get_changedtick(buf) ~= tick then
      state.dirty = true
    end
    if not state.dirty and render_succeeded(result) then
      local ok, err = vim.uv.fs_rename(rendered, state.svg)
      if not ok then
        vim.notify("Could not update DBML preview: " .. err, vim.log.levels.ERROR)
      elseif not state.opened then
        state.opened = true
        open_preview(state.html, function()
          return previews[buf] == state
        end)
      end
    end
    if state.dirty and not state.timer:is_active() then
      update_preview(buf, state)
    end
  end)
end

local function watch_preview(buf)
  local state = previews[buf]
  if not state then
    return
  end
  state.dirty = true
  state.timer:stop()
  state.timer:start(
    400,
    0,
    vim.schedule_wrap(function()
      update_preview(buf, state)
    end)
  )
end

function M.setup()
  local group = vim.api.nvim_create_augroup("DBMLPreview", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "dbml",
    callback = function(event)
      vim.keymap.set("n", "<leader>cp", "<cmd>DBMLPreview<cr>", { buffer = event.buf, desc = "Preview DBML diagram" })
      vim.keymap.set("n", "<leader>ce", "<cmd>DBMLExport<cr>", { buffer = event.buf, desc = "Export DBML diagram" })
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP", "BufWritePost" }, {
    group = group,
    callback = function(event)
      watch_preview(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(event)
      stop_preview(event.buf)
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      for buf in pairs(previews) do
        stop_preview(buf)
      end
    end,
  })

  vim.api.nvim_create_user_command("DBMLPreview", function()
    local buf = vim.api.nvim_get_current_buf()
    if not can_render(buf) then
      return
    end
    local state = previews[buf]
    if not state then
      local path = vim.fn.tempname()
      state = { html = path .. ".html", svg = path .. ".svg", timer = vim.uv.new_timer() }
      write_preview_page(state.html, state.svg)
      previews[buf] = state
    elseif state.opened then
      open_preview(state.html, function()
        return previews[buf] == state
      end)
    end
    state.dirty = true
    update_preview(buf, state)
  end, { desc = "Open a DBML diagram and watch for edits" })

  vim.api.nvim_create_user_command("DBMLPreviewStop", function()
    stop_preview(vim.api.nvim_get_current_buf())
  end, { desc = "Stop watching the current DBML diagram" })

  vim.api.nvim_create_user_command("DBMLExport", function(opts)
    local buf = vim.api.nvim_get_current_buf()
    if not can_render(buf) then
      return
    end
    local name = vim.api.nvim_buf_get_name(0)
    if opts.args == "" and name == "" then
      return vim.notify("Specify an SVG output path for an unnamed buffer", vim.log.levels.ERROR)
    end
    local output = opts.args ~= "" and vim.fn.fnamemodify(opts.fargs[1], ":p")
      or vim.fn.fnamemodify(name, ":r") .. ".svg"
    if not opts.bang and vim.uv.fs_stat(output) then
      return vim.notify("File exists; use :DBMLExport! to overwrite: " .. output, vim.log.levels.ERROR)
    end
    render(buf, output, function(result, rendered)
      if not render_succeeded(result) then
        return
      end
      local ok, err
      if opts.bang then
        ok, err = vim.uv.fs_rename(rendered, output)
      else
        ok, err = vim.uv.fs_link(rendered, output)
      end
      if not ok then
        return vim.notify("Could not export DBML diagram: " .. err, vim.log.levels.ERROR)
      end
      vim.notify("DBML diagram exported to " .. output)
    end)
  end, { nargs = "?", bang = true, complete = "file", desc = "Export the current DBML diagram to SVG" })
end

return M
