local M = {}

local iron = require("iron.core")

local Mode = {
  FLOAT = "float",
  BUFFER = "buffer"
}

local function save_dataframe_py_expr(df_var, path, use_stats)
  return string.format([[
import csv
from pathlib import Path
try:
    try:
        import polars as pl
        polars_installed = True
    except ImportError:
        polars_installed = False
    try:
        import pandas as pd
        pandas_installed = True
    except ImportError:
        pandas_installed = False

    var_name = "%s"
    file_path = "%s"
    use_stats = %s

    if var_name not in locals() and var_name not in globals():
        print(f"ERROR: Variable '{var_name}' not found")
    else:
        df_var = eval(var_name)
        is_pandas = pandas_installed and isinstance(df_var, pd.DataFrame)
        is_polars = polars_installed and isinstance(df_var, pl.DataFrame)
        is_lazy = polars_installed and isinstance(df_var, pl.LazyFrame)

        if is_lazy:
            df_var = df_var.collect()
            is_polars = True

        if not (is_pandas or is_polars):
            print("ERROR: Variable is not a pandas or polars DataFrame")
        elif use_stats:
            stat_names = ["count", "unique", "top", "freq", "mean", "std", "min", "25%%", "50%%", "75%%", "max"]
            cols = list(df_var.columns)
            col_stats = {}
            for c in cols:
                s = df_var[c]
                if is_pandas:
                    is_num = pd.api.types.is_numeric_dtype(s)
                else:
                    try:
                        is_num = s.dtype.is_numeric()
                    except AttributeError:
                        is_num = False
                st = {name: None for name in stat_names}
                st["count"] = s.count()
                if is_num:
                    st["mean"] = s.mean()
                    st["std"] = s.std()
                    st["min"] = s.min()
                    st["25%%"] = s.quantile(0.25)
                    st["50%%"] = s.quantile(0.5)
                    st["75%%"] = s.quantile(0.75)
                    st["max"] = s.max()
                else:
                    if is_pandas:
                        st["unique"] = s.nunique()
                        vc = s.value_counts()
                    else:
                        st["unique"] = s.n_unique()
                        vc = s.value_counts(sort=True)
                    if len(vc) > 0:
                        if is_pandas:
                            st["top"] = vc.index[0]
                            st["freq"] = vc.iloc[0]
                        else:
                            top_row = vc.row(0)
                            st["top"] = top_row[0]
                            st["freq"] = top_row[1]
                col_stats[c] = st

            def fmt(v):
                if v is None:
                    return ""
                if isinstance(v, float):
                    if v != v:
                        return ""
                    return f"{v:.2f}"
                return str(v)

            headers = []
            for c in cols:
                lines = [c]
                for name in stat_names:
                    v = col_stats[c][name]
                    if v is not None:
                        lines.append(f"{name}: {fmt(v)}")
                headers.append("\n".join(lines))

            with open(file_path, "w", newline="") as fh:
                w = csv.writer(fh)
                w.writerow(["bear_index"] + headers)
            if is_pandas:
                df_var.to_csv(file_path, mode="a", header=False, index=True)
            else:
                with open(file_path, "a") as fh:
                    df_var.with_row_index(name="bear_index").write_csv(fh, include_header=False)
            if Path(file_path).exists():
                print(f"SUCCESS: DataFrame saved to {file_path}")
        else:
            if is_pandas:
                df_var.to_csv(file_path, index=True)
            else:
                df_var.write_csv(file_path)
            if Path(file_path).exists():
                print(f"SUCCESS: DataFrame saved to {file_path}")
except Exception as e:
    print("ERROR: " + str(e))
]], df_var, path, use_stats and "True" or "False")
end

local function show_floating_window(opts, path, cmd)
  local width = math.floor(vim.o.columns * opts.window.width)
  local height = math.floor(vim.o.lines * opts.window.height)
  local buf = vim.api.nvim_create_buf(false, true)

  local _ = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded"
  })
  vim.api.nvim_buf_set_keymap(buf, 't', opts.keymap.exit_terminal_mode, '<C-\\><C-n>', { noremap = true })

  local job = vim.fn.termopen(cmd, {
    on_exit = function()
      if opts.remove_file then
        vim.fn.system("rm -f " .. path)
      end
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { unload = true })
      end
    end
  })

  vim.keymap.set("n", "q", function()
    vim.fn.jobstop(job)
  end, { noremap = true, silent = true, buffer = buf })

  vim.cmd("startinsert")
end

local function show_in_new_buffer(opts, path, cmd)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "VisiData: " .. path)
  vim.api.nvim_buf_set_option(buf, "buflisted", true)
  local current_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_keymap(buf, 't', opts.keymap.exit_terminal_mode, '<C-\\><C-n>', { noremap = true })

  local job = vim.fn.termopen(cmd, {
    on_exit = function()
      if opts.remove_file then
        vim.fn.system("rm -f " .. path)
      end
      vim.api.nvim_set_current_buf(current_buf)
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { unload = true })
      end
    end
  })

  vim.keymap.set("n", "q", function()
    vim.fn.jobstop(job)
  end, { noremap = true, silent = true, buffer = buf })

  vim.cmd("startinsert")
end

local function poll_for_dataframe(opts, df_path, mode, cmd)
  local timeout = opts.timeout or 30
  local interval = opts.poll_interval or 200
  local elapsed = 0

  local function check()
    if vim.fn.filereadable(df_path) == 1 then
      if mode == Mode.BUFFER then
        show_in_new_buffer(opts, df_path, cmd)
      elseif mode == Mode.FLOAT then
        show_floating_window(opts, df_path, cmd)
      end
      return
    end

    elapsed = elapsed + interval
    if elapsed >= timeout * 1000 then
      vim.notify(
        "Failed to export DataFrame. Is the variable defined in the iron REPL?",
        vim.log.levels.ERROR
      )
      return
    end

    vim.defer_fn(check, interval)
  end

  vim.defer_fn(check, interval)
end

function M.visualise_dataframe(opts, mode)
  opts = opts or {}
  mode = mode or Mode.FLOAT

  if vim.fn.executable("visidata") ~= 1 then
    vim.notify(
      "visidata not found in PATH. Install it: https://www.visidata.org/install/",
      vim.log.levels.ERROR
    )
    return
  end

  vim.fn.system("mkdir -p " .. opts.cache_dir)

  local df_var = vim.fn.expand("<cword>")
  if df_var == "" then
    df_var = vim.fn.input("Enter dataframe variable name: ")
    if df_var == "" then
      vim.notify("No variable specified", vim.log.levels.WARN)
      return
    end
  end

  local df_path = vim.fn.expand(opts.cache_dir .. "/" .. opts.file_name)

  local use_stats = opts.stats == true
  local expr = save_dataframe_py_expr(df_var, df_path, use_stats)

  local cmd = "visidata " .. df_path

  iron.send(vim.bo.filetype, expr)

  poll_for_dataframe(opts, df_path, mode, cmd)
end

return M
