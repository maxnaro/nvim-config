local function output_command(command)
  local kernels = vim.fn.MoltenRunningKernels(true)
  if #kernels == 1 then
    vim.cmd(command .. " " .. vim.fn.fnameescape(vim.api.nvim_buf_get_name(0)) .. " " .. kernels[1])
  elseif #kernels > 1 then
    vim.notify("Automatic notebook output sync requires one kernel per buffer", vim.log.levels.WARN)
  end
end

local function notebook()
  return vim.api.nvim_buf_get_name(0):match("%.ipynb$") ~= nil
end

return {
  {
    "GCBallesteros/jupytext.nvim",
    lazy = false,
    opts = { style = "percent" },
  },
  {
    "benlubas/molten-nvim",
    lazy = false,
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_image_provider = "none"
      vim.g.molten_virt_text_output = true
      vim.g.molten_wrap_output = true
      vim.g.molten_auto_open_output = false
    end,
    config = function()
      local group = vim.api.nvim_create_augroup("jupyter-output", { clear = true })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "MoltenInitPost",
        callback = function()
          local buffer = vim.api.nvim_get_current_buf()
          if notebook() then
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(buffer) then
                vim.api.nvim_buf_call(buffer, function()
                  output_command("MoltenImportOutput")
                end)
              end
            end)
          end
        end,
      })
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        pattern = "*.ipynb",
        callback = function()
          if vim.fn.exists("*MoltenStatusLineInit") == 1 and vim.fn.MoltenStatusLineKernels(true) ~= "" then
            output_command("MoltenExportOutput!")
          end
        end,
      })
    end,
  },
  {
    "GCBallesteros/NotebookNavigator.nvim",
    ft = "python",
    dependencies = { "benlubas/molten-nvim" },
    opts = { repl_provider = "molten" },
    config = function(_, opts)
      local nn = require("notebook-navigator")
      nn.setup(opts)
      local group = vim.api.nvim_create_augroup("jupyter-keys", { clear = true })
      local function maps()
        local function map(mode, key, rhs, desc)
          vim.keymap.set(mode, key, rhs, { buffer = true, silent = true, desc = desc })
        end
        map("n", "[j", function()
          nn.move_cell("u")
        end, "Previous Cell")
        map("n", "]j", function()
          nn.move_cell("d")
        end, "Next Cell")
        map("n", "<leader>ji", "<cmd>MoltenInit<cr>", "Initialize Jupyter Kernel")
        map("n", "<leader>jr", nn.run_cell, "Run Cell")
        map("x", "<leader>jr", ":<C-u>MoltenEvaluateVisual<cr>gv", "Run Selection")
        map("n", "<leader>jn", nn.run_and_move, "Run Cell and Advance")
        map("n", "<leader>ja", nn.run_all_cells, "Run All Cells")
        map("n", "<leader>jo", "<cmd>noautocmd MoltenEnterOutput<cr>", "Open Cell Output")
        map("n", "<leader>jp", "<cmd>MoltenImagePopup<cr>", "Open Plot Externally")
        map("n", "<leader>jx", "<cmd>MoltenInterrupt<cr>", "Interrupt Kernel")
        map("n", "<leader>jR", "<cmd>MoltenRestart<cr>", "Restart Kernel")
      end
      vim.api.nvim_create_autocmd("FileType", { group = group, pattern = "python", callback = maps })
      if vim.bo.filetype == "python" then
        maps()
      end
    end,
  },
}
