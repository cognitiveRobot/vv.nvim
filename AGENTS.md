# AGENTS.md

Neovim plugin that visualizes pandas/polars DataFrames in `visidata`, driven by an
`iron.nvim` REPL. Pure Lua, no build, no tests, no CI, no dependencies beyond
`iron.nvim` + `visidata` + the data library in the target Python env.

## Module layout & flow

- `lua/bear/init.lua` — entrypoint (`require("bear")`). `M.setup(opts)` registers
  commands `DFView`, `DFViewBuf`, `DFViewStats`, `DFClean` and the `<leader>df` /
  `<leader>bdf` keymaps. `DFViewStats` forces `opts.stats` regardless of config.
- `lua/bear/core.lua` — the whole pipeline:
  1. `visualise_dataframe` grabs the variable name via `expand("<cword>")` (prompts
     if empty) and checks `visidata` is on PATH.
  2. `save_dataframe_py_expr` builds an embedded Python snippet that exports the df
     to a CSV in `opts.cache_dir`.
  3. Sends it with `iron.send(vim.bo.filetype, expr)` to the iron REPL for the
     current buffer's filetype (creates one if none active).
  4. `poll_for_dataframe` polls the filesystem until the CSV appears, then launches
     `visidata` via `termopen` in a float (`Mode.FLOAT`) or buffer (`Mode.BUFFER`).
- `lua/bear/utils.lua` — `clean_cache` (`:DFClean`, interactive y/n confirm).

The export is **async and filesystem-mediated** — the CSV appears in the cache dir
only after the REPL finishes, so logic depends on polling, not on REPL output.

## Stats mode

`opts.stats` (default `true`). When enabled the Python snippet computes per-column
stats in the REPL (pandas `describe(include='all')`-style): `count`, `unique`,
`top`, `freq` for categorical; `count`, `mean`, `std`, `min`, `25%`, `50%`, `75%`,
`max` for numeric. Each column's stats are embedded as newline-separated lines
**inside the CSV column name** (single header row), e.g. `name\ncount: 4\nunique:
3\n...`. visidata renders column names split on `\n` as stacked header rows
(`sheets.py` `drawColHeader` / `nHeaderRows`), so stats appear directly under each
column name with no `--header N` flag. The first CSV column is the row index
(pandas `index=True`, polars `with_row_index`) with the literal header `bear_index`;
its 1-line name anchors the bottom of the stacked header block, keeping data rows
aligned.

## Gotchas

- `save_dataframe_py_expr` builds the Python snippet with `string.format` and now
  has **three** `%s` placeholders (`df_var`, `file_path`, `use_stats`). A literal
  `%` in any of those breaks interpolation, and any literal `%` inside the
  template itself must be written `%%` — the stat names `"25%"`, `"50%"`, `"75%"`
  are escaped as `%%` in the template source.
- The template is **dedented to column 0**. Earlier versions indented every line by
  6 spaces, which raises `IndentationError: unexpected indent` in a plain `python3`
  REPL (iron sends the block verbatim); only ipython-class REPLs tolerated it.
- `STAT_HEADER_ROWS` no longer exists. Earlier versions wrote the stats as 12
  physical header rows and launched visidata with `--header 12`, but visidata joins
  multi-row headers into a single name per column (`sheets.py` `setCols`), mangling
  everything into one string. Stats must be embedded inside each column name as
  `\n`-separated lines, with a single header row.
- Stats are computed per column in the REPL: pandas uses
  `pd.api.types.is_numeric_dtype`; polars uses `s.dtype.is_numeric()` (the older
  `Series.is_numeric()` does not exist in polars 1.x).
- `opts.poll_interval` (ms) is used in `core.lua` but is **not** in the default
  config in `init.lua`; falls back to 200. `opts.timeout` defaults to 30 s.
- Default `file_name` is second-precision (`tmp_MMDD_HHMMSS.csv`); collisions within
  the same second are possible.
- `opts.remove_file` deletes the CSV when the visidata job exits. `q` in normal mode
  inside the visidata terminal buffer `jobstop`s the terminal (buffer-local map in
  `core.lua`).
- `vim` is a global; `.luarc.json` declares it for lua-language-server.

## Verification

No test/lint/typecheck harness exists. Manual end-to-end check: open a python file
in Neovim with iron.nvim, define a DataFrame in the REPL, run `:DFView` (or the
`<leader>df` keymap) and confirm a visidata float opens. Requires `visidata` on
PATH and pandas/polars in the REPL's Python env.
