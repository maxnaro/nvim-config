"""Run from this directory with: python3 tests/dbml.py"""
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "lua" / "config" / "dbml.lua"


RENDERER = r'''#!/usr/bin/env python3
import html
import json
import os
from pathlib import Path
import sys
import time

args = sys.argv[1:]
source = Path(args[args.index("-i") + 1]).read_text()
output = Path(args[args.index("-o") + 1])
with open(os.environ["DBML_RENDER_LOG"], "a") as log:
    log.write(json.dumps({"source": source, "output": str(output)}) + "\n")
if "SLOW=" in source:
    time.sleep(float(source.split("SLOW=", 1)[1].split()[0]))
if "FAIL" in source:
    print("fake renderer rejected input", file=sys.stderr)
    sys.exit(2)
output.write_text('<svg xmlns="http://www.w3.org/2000/svg"><text>' + html.escape(source) + '</text></svg>')
'''


LUA = r'''local module = dofile(vim.env.DBML_MODULE)
module.setup()

local api = vim.api
local opened = {}
local notifications = {}
vim.notify = function(message, level)
  table.insert(notifications, { message = message, level = level })
end
local has = vim.fn.has
vim.fn.has = function(name)
  if name == "wsl" then return 0 end
  return has(name)
end
vim.ui.open = function(path)
  table.insert(opened, path)
  return true
end

local function wait_for(predicate, label, timeout)
  assert(vim.wait(timeout or 8000, predicate, 20), "timed out: " .. label)
end

local function read(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local value = file:read("*a")
  file:close()
  return value
end

local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function log_rows()
  local rows = {}
  local file = io.open(vim.env.DBML_RENDER_LOG, "r")
  if not file then return rows end
  for line in file:lines() do table.insert(rows, vim.json.decode(line)) end
  file:close()
  return rows
end

local function make_buffer(name, lines)
  local buf = api.nvim_create_buf(true, false)
  api.nvim_buf_set_name(buf, name)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_set_option_value("filetype", "dbml", { buf = buf })
  return buf
end

local function in_buffer(buf, fn)
  return api.nvim_buf_call(buf, fn)
end

local function set_lines(buf, lines)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

local function trigger(buf, event)
  api.nvim_exec_autocmds(event, { buffer = buf, modeline = false })
end

local function svg_from_html(html_path)
  local html = read(html_path)
  assert(html, "preview HTML missing: " .. html_path)
  local src = html:match('image%.src = ["\']([^"\']+)["\']')
  assert(src, "preview HTML has no image source")
  assert(not src:match("^/"), "SVG source must be relative")
  local relative = src:match("^[^?]+")
  local svg = vim.fs.normalize(vim.fs.dirname(html_path) .. "/" .. relative)
  assert(src:find("?t=", 1, true), "preview image URL needs cache-buster")
  return svg
end

local function preview(buf)
  local opened_before = #opened
  in_buffer(buf, function() vim.cmd("DBMLPreview") end)
  wait_for(function() return #opened > opened_before end, "preview opens")
  local html_path = opened[#opened]
  wait_for(function()
    local html = read(html_path)
    return html and html:find("<img", 1, true) and html:find("?t=", 1, true)
  end, "preview HTML is written")
  local svg = svg_from_html(html_path)
  wait_for(function() return exists(svg) end, "initial SVG")
  return html_path, svg
end

local function wait_svg(svg, text)
  wait_for(function()
    local content = read(svg)
    return content and content:find(text, 1, true)
  end, "SVG contains " .. text)
end

local function count_source(fragment)
  local count = 0
  for _, row in ipairs(log_rows()) do
    if row.source:find(fragment, 1, true) then count = count + 1 end
  end
  return count
end

local function assert_no_file(path, label)
  wait_for(function() return not exists(path) end, label)
end

local a = make_buffer(vim.env.DBML_TEST_DIR .. "/a.dbml", { "Table A { id int }" })
local html_a, svg_a = preview(a)
assert(#opened == 1, "first preview should open one HTML wrapper")
local initial_html = read(html_a)
assert(initial_html:find(vim.fs.basename(svg_a), 1, true), "wrapper should reference sibling SVG")

-- Unsaved edit triggers refresh without another browser launch.
set_lines(a, { "Table A { name varchar }" })
trigger(a, "TextChanged")
wait_svg(svg_a, "name varchar")
assert(#opened == 1, "refresh must reuse the open wrapper")

-- A burst coalesces into one renderer invocation and publishes final content.
local before_burst = count_source("BURST_")
set_lines(a, { "// BURST_1" })
trigger(a, "TextChangedI")
set_lines(a, { "// BURST_2" })
trigger(a, "TextChangedP")
set_lines(a, { "// BURST_FINAL" })
trigger(a, "BufWritePost")
wait_svg(svg_a, "BURST_FINAL")
vim.wait(700)
assert(count_source("BURST_") - before_burst == 1, "edit burst should render once")

-- Newer edit during a running process must win, even when old process ends later.
set_lines(a, { "// SLOW=0.8 STALE_RENDER" })
trigger(a, "TextChanged")
wait_for(function() return count_source("STALE_RENDER") > 0 end, "slow renderer starts")
set_lines(a, { "// LATEST_RENDER" })
trigger(a, "TextChanged")
wait_svg(svg_a, "LATEST_RENDER")
vim.wait(1000)
local final_svg = read(svg_a)
assert(not final_svg:find("STALE_RENDER", 1, true), "stale render overwrote latest SVG")

-- Failed render keeps last good diagram; later edit recovers.
local good_svg = read(svg_a)
set_lines(a, { "// FAIL" })
trigger(a, "TextChanged")
wait_for(function() return count_source("FAIL") > 0 end, "invalid render starts")
vim.wait(300)
assert(read(svg_a) == good_svg, "failed render must preserve last good SVG")
set_lines(a, { "// RECOVERED" })
trigger(a, "TextChanged")
wait_svg(svg_a, "RECOVERED")

-- Buffer identity must survive switching current buffer before its event fires.
local b = make_buffer(vim.env.DBML_TEST_DIR .. "/b.dbml", { "// BUFFER_B" })
local html_b, svg_b = preview(b)
assert(html_a ~= html_b and svg_a ~= svg_b, "buffers need independent preview files")
api.nvim_set_current_buf(b)
set_lines(a, { "// BUFFER_A_NONCURRENT" })
trigger(a, "TextChanged")
wait_svg(svg_a, "BUFFER_A_NONCURRENT")
assert(read(svg_b):find("BUFFER_B", 1, true), "editing A changed B preview")

-- Stop during active render: no late publish/open; temporary files are removed.
local opened_before_stop = #opened
set_lines(a, { "// SLOW=0.8 STOPPED_RENDER" })
trigger(a, "TextChanged")
wait_for(function() return count_source("STOPPED_RENDER") > 0 end, "stoppable renderer starts")
in_buffer(a, function() vim.cmd("DBMLPreviewStop") end)
assert_no_file(html_a, "stop removes HTML")
assert_no_file(svg_a, "stop removes SVG")
vim.wait(1000)
assert(#opened == opened_before_stop, "stopped render opened browser late")
assert(not exists(svg_a), "stopped render published after cleanup")
local stopped_render_count = #log_rows()
set_lines(a, { "// EDIT_AFTER_STOP" })
trigger(a, "TextChanged")
vim.wait(650)
assert(#log_rows() == stopped_render_count, "edit after stop launched renderer")
assert(not exists(svg_a), "edit after stop recreated preview SVG")

-- Deleting a watched buffer also cleans its preview paths.
in_buffer(b, function() vim.cmd("DBMLPreviewStop") end)
assert_no_file(html_b, "stop removes second HTML")
assert_no_file(svg_b, "stop removes second SVG")

local c = make_buffer(vim.env.DBML_TEST_DIR .. "/c.dbml", { "// BUFFER_C" })
local html_c, svg_c = preview(c)
api.nvim_set_current_buf(b)
vim.cmd("bunload! " .. c)
assert_no_file(html_c, "buffer unload removes HTML")
assert_no_file(svg_c, "buffer unload removes SVG")
assert(not api.nvim_buf_is_loaded(c), "bunload should unload buffer")
api.nvim_buf_delete(c, { force = true })

local wipe_buf = make_buffer(vim.env.DBML_TEST_DIR .. "/wipe.dbml", { "// BUFFER_WIPE" })
local wipe_html, wipe_svg = preview(wipe_buf)
api.nvim_buf_delete(wipe_buf, { force = true })
assert_no_file(wipe_html, "buffer wipe removes HTML")
assert_no_file(wipe_svg, "buffer wipe removes SVG")

-- Invalid first render opens no browser; later valid edit opens exactly once.
local d = make_buffer(vim.env.DBML_TEST_DIR .. "/d.dbml", { "// FAIL" })
local opened_before_invalid = #opened
in_buffer(d, function() vim.cmd("DBMLPreview") end)
wait_for(function() return count_source("FAIL") > 1 end, "invalid initial render")
vim.wait(300)
assert(#opened == opened_before_invalid, "invalid initial render opened browser")
set_lines(d, { "// INITIAL_RECOVERY" })
trigger(d, "TextChanged")
wait_for(function()
  return #opened == opened_before_invalid + 1
end, "valid edit opens preview after failure")
local html_d = opened[#opened]
local svg_d = svg_from_html(html_d)
wait_svg(svg_d, "INITIAL_RECOVERY")
assert(#opened == opened_before_invalid + 1, "recovered initial preview opened more than once")

-- A delayed WSL path conversion must not launch Explorer after stop.
local wsl_buf = make_buffer(vim.env.DBML_TEST_DIR .. "/wsl.dbml", { "// WSL_PREVIEW" })
local real_has = vim.fn.has
local real_executable = vim.fn.executable
local real_exepath = vim.fn.exepath
local real_system = vim.system
local wsl_callback
local explorer_launches = 0
vim.fn.has = function(name)
  if name == "wsl" then return 1 end
  return real_has(name)
end
vim.fn.executable = function(name)
  if name == "wslpath" or name == "explorer.exe" then return 1 end
  return real_executable(name)
end
vim.fn.exepath = function(name)
  if name == "explorer.exe" then return "explorer.exe" end
  return real_exepath(name)
end
vim.system = function(command, opts, callback)
  if command[1] == "wslpath" then
    wsl_callback = callback
    return { kill = function() end }
  end
  if command[1] == "explorer.exe" then
    explorer_launches = explorer_launches + 1
    return { kill = function() end }
  end
  return real_system(command, opts, callback)
end
in_buffer(wsl_buf, function() vim.cmd("DBMLPreview") end)
wait_for(function() return wsl_callback ~= nil end, "WSL path conversion starts")
local wsl_html = nil
for _, row in ipairs(log_rows()) do
  if row.source:find("WSL_PREVIEW", 1, true) then
    wsl_html = row.output:gsub("%.svg%.tmp%-.*$", ".html")
  end
end
assert(wsl_html, "WSL render output not recorded")
local wsl_svg = wsl_html:gsub("%.html$", ".svg")
local notification_count = #notifications
in_buffer(wsl_buf, function() vim.cmd("DBMLPreviewStop") end)
assert_no_file(wsl_html, "WSL stop removes HTML")
assert_no_file(wsl_svg, "WSL stop removes SVG")
wsl_callback({ code = 0, stdout = "C:\\preview.html\r\n", stderr = "" })
vim.wait(100)
assert(explorer_launches == 0, "stopped WSL callback launched Explorer")
assert(#notifications == notification_count, "late WSL callback emitted a notification")
vim.fn.has = real_has
vim.fn.executable = real_executable
vim.fn.exepath = real_exepath
vim.system = real_system

-- Export behavior: create, protect existing file, and replace with bang.
local export = vim.env.DBML_TEST_DIR .. "/export.svg"
set_lines(b, { "// EXPORT_FIRST" })
in_buffer(b, function() vim.cmd("DBMLExport " .. vim.fn.fnameescape(export)) end)
wait_for(function() return exists(export) end, "first export")
assert(read(export):find("EXPORT_FIRST", 1, true), "export has wrong source")
local exported = read(export)
set_lines(b, { "// EXPORT_REFUSED" })
local before_refused_logs = #log_rows()
local before_refused_notifications = #notifications
local refused = pcall(function()
  in_buffer(b, function() vim.cmd("DBMLExport " .. vim.fn.fnameescape(export)) end)
end)
assert(refused, "export guard should report existing output without throwing")
vim.wait(250)
assert(read(export) == exported, "export overwrote existing output without bang")
assert(#log_rows() == before_refused_logs, "refused export launched renderer")
assert(#notifications == before_refused_notifications + 1, "refused export should report existing output")
set_lines(b, { "// EXPORT_REPLACED" })
in_buffer(b, function() vim.cmd("DBMLExport! " .. vim.fn.fnameescape(export)) end)
wait_for(function()
  local content = read(export)
  return content and content:find("EXPORT_REPLACED", 1, true)
end, "bang export replaces output")

print("DBML preview watcher and export checks passed")
vim.cmd("qa!")
'''


def main():
    with tempfile.TemporaryDirectory(prefix="nvim dbml ") as directory:
        temp = Path(directory)
        bin_dir = temp / "bin"
        bin_dir.mkdir()
        renderer = bin_dir / "dbml-renderer"
        renderer.write_text(RENDERER)
        renderer.chmod(0o755)

        lua = temp / "check.lua"
        lua.write_text(LUA)
        env = dict(os.environ)
        env.update(
            DBML_MODULE=str(MODULE),
            DBML_TEST_DIR=str(temp),
            DBML_RENDER_LOG=str(temp / "renderer.jsonl"),
            PATH=str(bin_dir) + os.pathsep + env.get("PATH", ""),
        )
        result = subprocess.run(
            ["nvim", "--headless", "--clean", "-u", "NONE", "-i", "NONE", "-l", str(lua)],
            env=env,
            capture_output=True,
            text=True,
            timeout=35,
        )
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        print("DBML preview watcher and export checks passed")


if __name__ == "__main__":
    main()
