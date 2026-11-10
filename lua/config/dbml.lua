local M = {}

local function open_preview(path)
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

  if path:match("^https://") then
    vim.system({ explorer, path }, { cwd = "/mnt/c", detach = true })
    return
  end

  vim.system({ "wslpath", "-w", path }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 or not result.stdout or result.stdout == "" then
        return vim.notify("Could not convert preview path: " .. (result.stderr or ""), vim.log.levels.ERROR)
      end
      local windows_path = result.stdout:gsub("[\r\n]+$", "")
      vim.system({ explorer, windows_path }, { cwd = "/mnt/c", detach = true })
    end)
  end)
end

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
        open_preview(output)
      else
        vim.notify("DBML diagram exported to " .. output)
      end
    end)
  end)
end

local function cloud_preview()
  if vim.bo.filetype ~= "dbml" then
    return vim.notify("Open a DBML buffer first", vim.log.levels.ERROR)
  end
  local token = vim.env.DBDIAGRAM_API_TOKEN
  if not token or token == "" or token:find("[\r\n]") then
    return vim.notify("Set DBDIAGRAM_API_TOKEN to a dbdiagram workspace API token", vim.log.levels.ERROR)
  end
  if vim.fn.executable("curl") ~= 1 then
    return vim.notify("curl is required for dbdiagram.io", vim.log.levels.ERROR)
  end
  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  local name = vim.fn.expand("%:t:r")
  if name == "" then
    name = "Neovim DBML preview"
  end
  vim.ui.select({ "Cancel", "Upload" }, {
    prompt = "Upload this DBML to dbdiagram.io? This creates a persistent workspace diagram.",
  }, function(choice)
    if choice ~= "Upload" then
      return
    end
    -- Curl config is passed over stdin, so the workspace token is not in argv.
    local function quote(value)
      return '"' .. value:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
    end
    local payload = vim.json.encode({ name = name, content = content })
    local config = "header = " .. quote("dbdiagram-access-token: " .. token) .. "\n"
      .. "header = \"Content-Type: application/json\"\n"
      .. "data = " .. quote(payload) .. "\n"
    vim.system({ "curl", "--silent", "--show-error", "--fail", "--config", "-", "https://api.dbdiagram.io/v1/diagrams" },
      { stdin = config, text = true }, function(result)
        vim.schedule(function()
          if result.code ~= 0 then
            return vim.notify("dbdiagram.io request failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
          end
          local ok, data = pcall(vim.json.decode, result.stdout or "")
          if not ok or type(data) ~= "table" or type(data._id) ~= "string" or not data._id:match("^[%da-fA-F]+$") then
            return vim.notify("dbdiagram.io returned an invalid diagram ID", vim.log.levels.ERROR)
          end
          local url = "https://dbdiagram.io/d/" .. data._id
          vim.notify("Created persistent dbdiagram.io diagram: " .. url)
          open_preview(url)
        end)
      end)
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "dbml",
    callback = function(event)
      vim.keymap.set("n", "<leader>cp", "<cmd>DBMLPreview<cr>", { buffer = event.buf, desc = "Preview DBML diagram" })
      vim.keymap.set("n", "<leader>ce", "<cmd>DBMLExport<cr>", { buffer = event.buf, desc = "Export DBML diagram" })
      vim.keymap.set("n", "<leader>cP", "<cmd>DBMLCloudPreview<cr>", { buffer = event.buf, desc = "Preview DBML on dbdiagram.io" })
    end,
  })

  vim.api.nvim_create_user_command("DBMLCloudPreview", cloud_preview, { desc = "Upload and preview DBML on dbdiagram.io" })

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
