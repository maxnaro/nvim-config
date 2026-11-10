local M = {}

local function render(output, preview, overwrite)
  if vim.bo.filetype ~= "dbml" then
    return vim.notify("Open a DBML buffer first", vim.log.levels.ERROR)
  end
  if vim.fn.executable("dbml-renderer") ~= 1 then
    return vim.notify("Install @softwaretechnik/dbml-renderer to render DBML", vim.log.levels.ERROR)
  end
  if not preview and not overwrite and vim.uv.fs_stat(output) then
    return vim.notify("File exists; use :DBMLExport! to overwrite: " .. output, vim.log.levels.ERROR)
  end

  local input = vim.fn.tempname() .. ".dbml"
  local rendered = preview and output or (output .. ".tmp-" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t") .. ".svg")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  vim.fn.writefile(lines, input)
  vim.system({ "dbml-renderer", "-i", input, "-o", rendered }, { text = true }, function(result)
    vim.schedule(function()
      vim.fn.delete(input)
      if result.code ~= 0 then
        vim.fn.delete(rendered)
        local message = result.stderr ~= "" and result.stderr or result.stdout
        return vim.notify("DBML rendering failed: " .. (message or ""), vim.log.levels.ERROR)
      end
      if not preview then
        local ok, err
        if overwrite then
          ok, err = vim.uv.fs_rename(rendered, output)
        else
          ok, err = vim.uv.fs_link(rendered, output)
        end
        vim.fn.delete(rendered)
        if not ok then
          return vim.notify("Could not export DBML diagram: " .. err, vim.log.levels.ERROR)
        end
      end
      if preview then
        local _, err = vim.ui.open(output)
        if err then
          vim.notify("Could not open diagram: " .. err, vim.log.levels.ERROR)
        end
      else
        vim.notify("DBML diagram exported to " .. output)
      end
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("DBMLPreview", function()
    render(vim.fn.tempname() .. ".svg", true, false)
  end, { desc = "Render and open the current DBML diagram" })

  vim.api.nvim_create_user_command("DBMLExport", function(opts)
    local name = vim.api.nvim_buf_get_name(0)
    if opts.args == "" and name == "" then
      return vim.notify("Specify an SVG output path for an unnamed buffer", vim.log.levels.ERROR)
    end
    local output = opts.args ~= "" and vim.fn.fnamemodify(opts.fargs[1], ":p") or vim.fn.fnamemodify(name, ":r") .. ".svg"
    render(output, false, opts.bang)
  end, { nargs = "?", bang = true, complete = "file", desc = "Export the current DBML diagram to SVG" })
end

return M
