# InsGitHeader

A [Neovim](https://github.com/neovim/neovim) plugin adding a user command
which inserts filename, git repo name and author infos into comented lines
on top of the current file.

## Features

adds three commented lines on top of the current file like:

> file: /home/cs/files/src/git/insgitheader.nvim/README.md
>
> git: /home/cs/files/src/git/insgitheader.nvim
>
> author: Christian Schult <cschult@example.com> 2024

Install the theme with your preferred package manager, such as
[folke/lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    url = 'ssh://devmem.de/srv/git/insgitheader.nvim'
    lazy = false,
    opts = {},
}
```

## Usage

```vim

:InsGitHeader

```

## what's coming next

- get name and email from git config (not yet implemented)
- set name and email as config option (not yet implemented)
- get year from system date (not yet implemented)
