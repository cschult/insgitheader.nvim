# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this plugin does

`insgitheader.nvim` is a Neovim plugin that registers the `:InsGitHeader` user command. When invoked, it inserts three commented header lines at the top of the current buffer:

```
-- file: /path/to/current/file.lua
-- git: /path/to/git/repo
-- author: Name <email> 2024
```

Comment characters are detected automatically from Neovim's `commentstring` option. VCSH-managed repositories are handled specially in `get-repo-name.lua`.

## Architecture

```
plugin/insgitheader/init.lua   ← Neovim entry point: registers :InsGitHeader command
lua/insgitheader/init.lua      ← Core module: setup() and insert_headers()
lua/insgitheader/helper/
  get-comment-chars.lua        ← Parses vim.o.commentstring
  get-file-name.lua            ← Returns current buffer's full path
  get-git-config-user.lua      ← Runs `git config user.name/email` via io.popen
  get-repo-name.lua            ← Detects git repo root or VCSH repo name via io.popen
  get-uid.lua                  ← Reads system user ID (currently unused)
```

`plugin/` runs at Neovim startup and lazily loads `lua/insgitheader/` on first use. The `setup(opts)` function in the core module accepts optional `name` and `email` overrides; if not provided, they are read from `git config` at module load time.

## Tests

```bash
make test        # requires: luarocks install busted
```

Tests run with [busted](https://lunarmodules.github.io/busted/) and do not require Neovim. The `vim` API is stubbed in `tests/spec_helper.lua` via `_G.vim`. `io.popen` and `os.getenv` are monkey-patched per-test where needed.

## Development notes

- Git operations use `io.popen` (shell calls), not Neovim's job API.
- Neovim ≥ 0.7.0 is required.
- The commented-out keymap in `plugin/insgitheader/init.lua` (`<Leader>ii`) is intentionally disabled; users can enable it manually.
