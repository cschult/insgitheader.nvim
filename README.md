# InsGitHeader

A [Neovim](https://github.com/neovim/neovim) plugin adding a user command
which inserts filename, git repo name and author infos into comented lines
on top of the current file.

## Features

- adds three commented lines on top of the current file like:
> -- file: /home/cs/files/src/insgitheader.nvim/lua/insgitheader/init.lua
>
> -- git: /home/cs/files/src/insgitheader.nvim
>
> -- author: Christian Schult <cschult@example.com> 2024

- handles VCSH managed repo

## Installation

Install the theme with your preferred package manager, such as
[folke/lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'cschult/insgitheader.nvim'
    lazy = false,
    opts = {},
}
```

## Usage

```vim

:InsGitHeader

```
