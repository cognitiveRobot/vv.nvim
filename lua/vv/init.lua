local M = {}

M.config = {
  cache_dir = "~/.cache/nvim/vv",
  file_name = "tmp_" .. os.date("%m%d_%H%M%S") .. ".csv",
  remove_file = true,
  timeout = 30,
  stats = true,
  window = {
    width = 0.9,
    height = 0.8,
    border = "rounded",
  },
  keymap = {
    visualise = "<leader>df",
    visualise_buf = "<leader>bdf",
    exit_terminal_mode = "<C-o>",
  }
}

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", {}, M.config, opts or {})

  vim.api.nvim_create_user_command("DFView", function()
    require("vv.core").visualise_dataframe(opts, "float")
  end, { desc = "Visualise DataFrame in floating window under cursor" })

  vim.api.nvim_create_user_command("DFViewBuf", function()
    require("vv.core").visualise_dataframe(opts, "buffer")
  end, { desc = "Visualise DataFrame in new buffer under cursor" })

  vim.api.nvim_create_user_command("DFViewStats", function()
    local stats_opts = vim.tbl_deep_extend("force", {}, opts, { stats = true })
    require("vv.core").visualise_dataframe(stats_opts, "float")
  end, { desc = "Visualise DataFrame with column stats in floating window" })

  vim.api.nvim_create_user_command("DFClean", function()
    require("vv.utils").clean_cache(opts)
  end, { desc = "Clean cache directory" })

  vim.keymap.set("n", opts.keymap.visualise,
    function() require("vv.core").visualise_dataframe(opts, "float") end,
    { desc = "Visualise DataFrame in floating window" })

  vim.keymap.set("n", opts.keymap.visualise_buf,
    function() require("vv.core").visualise_dataframe(opts, "buffer") end,
    { desc = "Visualise DataFrame in new buffer" })
end

M.visualise = function(opts)
  opts = vim.tbl_deep_extend("force", {}, M.config, opts or {})
  require("vv.core").visualise_dataframe(opts)
end

return M
