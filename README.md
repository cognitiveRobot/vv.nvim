# 🐼`bear.nvim`🐻‍❄️

A neovim plugin for debugging `pandas` and `polars` DataFrames.

https://github.com/user-attachments/assets/55e22539-9938-4b48-9ec5-b1b6a43b976b


## ⚡️ Requirements

- [iron.nvim](https://github.com/Vigemus/iron.nvim)
- [visidata](https://www.visidata.org/install/) installed globally
- [polars](https://github.com/pola-rs/polars) and/or
  [pandas](https://github.com/pandas-dev/pandas) installed in your virtual
  environment

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "nelnn/bear.nvim",
  dependencies = {
    "Vigemus/iron.nvim",
  },
}
```


<details>
<summary>Default Confguration</summary>

```lua
{
  "nelnn/bear.nvim",
  dependencies = {
    "Vigemus/iron.nvim",
  },
  opts = {
      cache_dir = "~/.cache/nvim/bear",
      file_name = "tmp_" .. os.date("%m%d_%H%M%S") .. ".csv",
      remove_file = true, -- remove file upon quitting visidata
      timeout = 30, -- seconds to wait for the export to complete
      window = {
        width = 0.9,
        height = 0.8,
        border = "rounded"
      },
      keymap = {
        visualise = "<leader>df",
        visualise_buf = "<leader>bdf",
        exit_terminal_mode = "<C-o>",
      }
  },

  config = function(_, opts)
    local df_visidata = require("bear")
    df_visidata.setup(opts)
  end,

  ft = { "python" },
}

```
</details>

## 🚀 Usage (with default keymaps)
- `<leader>df`/`<leader>dfb` to view the dataframe under the cursor.
- `<leader>df`/`<leader>dfb` in the repl session and input the dataframe variable.
- `<C-o>` to exit from terminal to normal mode and `i` to enter. This is useful
  when you want to change buffers.
- `q` to close floating window or buffer in normal and terminal mode.

> [!NOTE]
> The dataframe variable must exist in the iron.nvim REPL namespace (i.e. it
> must have been defined in the running python session). If no iron REPL is
> active, one is created automatically for the current buffer's filetype.

You can see my debugging setup [here](https://github.com/nelnn/dotfiles/blob/main/.config/nvim/lua/plugins/debugging.lua).

## ⌘ Commands
| Command | Action |
| ------------- | -------------- |
| DFView | View dataframe in a floating window|
| DFViewBuf | View dataframe in a new buffer|
| DFClean | Clear cache directory|


> [!NOTE]
> I am not knowledgeable in lua. PRs for code refactor and new features are more than welcome.
