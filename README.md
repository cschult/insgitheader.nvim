# InsGitHeader

A [Neovim](https://github.com/neovim/neovim) plugin that adds a user command
inserting the file name, the git repository and the author details as comment
lines at the top of the current file.

## Features

- adds three comment lines at the top of the current file, like this:

```lua
-- file: /home/cs/files/src/insgitheader.nvim/lua/insgitheader/init.lua
-- git: /home/cs/files/src/insgitheader.nvim
-- author: John Doe <user@example.com> 2024
```

- places the header below a shebang or another prologue line, separated by a
  blank line, so the file stays executable:

```sh
#!/usr/bin/env bash

# file: /home/cs/bin/backup.sh
# git: /home/cs/dotfiles
# author: John Doe <user@example.com> 2024

set -euo pipefail
```

  Recognised prologue lines are `#!`, `<?xml`, `<?php`, an encoding
  declaration such as `# -*- coding: utf-8 -*-`, and `@charset`. At most the
  first two lines are treated as prologue. Existing blank lines are reused
  rather than doubled.

- updates the header in place instead of inserting a second one. Running
  `:InsGitHeader` again refreshes the file name and the repository, and
  extends the year into a range:

```
-- author: John Doe <user@example.com> 2019-2024
```

  If the previous author was someone else, they are kept in the line:

```
-- author: John Doe <user@example.com> 2019-2024 (orig. Jane Roe <jane@example.com>)
```

- handles repositories managed by VCSH

- marks files managed by [chezmoi](https://www.chezmoi.io/). Both the target
  file and its source file report the chezmoi repository, so the header is
  identical in both and `chezmoi apply` produces no diff:

```sh
# file: /home/cs/.bashrc
# git: /home/cs/.local/share/chezmoi (managed by chezmoi)
# author: John Doe <user@example.com> 2024
```

  The lookup is cached per buffer in `b:insgitheader_chezmoi`, so repeated
  calls in the same buffer cost no extra processes. The cache is dropped again
  when the buffer is written or renamed, so a file that has been added to
  chezmoi in the meantime is picked up. To see what the plugin decided:

```vim
:echo b:insgitheader_chezmoi
```

## Requirements

- Neovim >= **0.7.0**
- Git
- [chezmoi](https://www.chezmoi.io/) — optional, needed only for the chezmoi
  detection. If it is not installed, nothing is marked and no error is shown;
  installing it mid-session starts working without restarting Neovim.

## Installation

Install the plugin with your preferred package manager, such as
[folke/lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'headoop/insgitheader.nvim',
    lazy = false,
    opts = {},
}
```

or

```lua
{
    'headoop/insgitheader.nvim',
    lazy = false,
    opts = {
        name = 'John Doe',
        email = 'jd@example.org',
        path = 'full',
    },
}
```

Every option is optional.

| Option  | Values                | Default  | Meaning                                          |
| ------- | --------------------- | -------- | ------------------------------------------------ |
| `name`  | any string            | git config `user.name`  | Author name                       |
| `email` | any string            | git config `user.email` | Author email address              |
| `path`  | `'full'`, `'basename'`| `'full'` | Whether the `file:` line shows the whole path or only the file name |

If `name` or `email` is unset, it is read from the git config.

With `path = 'basename'` the `file:` line is shortened:

```lua
-- file: init.lua
-- git: /home/cs/files/src/insgitheader.nvim
-- author: John Doe <user@example.com> 2024
```

For a chezmoi source file the name is taken from the target path, so source
and target still produce the same line.

## Usage

```vim
:InsGitHeader
```

The command inserts the header if there is none, and updates it if there is.
No key mapping is set up; bind it yourself if you want one:

```lua
vim.keymap.set("n", "<Leader>ii", "<Cmd>InsGitHeader<CR>", { desc = "InsGitHeader" })
```

## Note

I'm just learning to write a Neovim plugin in Lua.
This is a simple project for my personal use.
