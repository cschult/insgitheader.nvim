# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## What this plugin does

`insgitheader.nvim` is a Neovim plugin that registers the `:InsGitHeader` user
command. When invoked, it inserts three commented header lines into the
current buffer:

```
-- file: /path/to/current/file.lua
-- git: /path/to/git/repo
-- author: Name <email> 2024
```

Comment characters are detected automatically from Neovim's `commentstring`
option. VCSH-managed repositories are handled specially in `get-repo-name.lua`.

The command is idempotent: it inserts the header if there is none, and
updates it if there is. Key behaviours:

- **Placement** — if the buffer starts with a prologue line (`#!`, `<?xml`,
  `<?php`, an encoding declaration, `@charset`; at most the first two lines),
  the block is placed below it, separated by a blank line. Existing blank
  lines are reused rather than doubled.
- **Update** — an existing header is three consecutive `file:`/`git:`/`author:`
  lines directly below the prologue, matched strictly against the current
  `commentstring`. The old year is carried over into a range (`2019` →
  `2019-2024`); a displaced author is appended to an `(orig. …)` chain,
  oldest first. A header found above a shebang is updated in place and a
  warning is issued.
- **chezmoi** — target files and source files both get `(managed by chezmoi)`
  in the `git:` line, and both report the chezmoi repository. For a source
  file the `file:` line shows the *target* path, so the header is identical
  in source and target and `chezmoi apply` produces no diff.

## Architecture

```
plugin/insgitheader/init.lua   ← Neovim entry point: registers :InsGitHeader command
lua/insgitheader/init.lua      ← Core module: setup() and insert_headers()
lua/insgitheader/helper/
  find-header.lua              ← Prologue detection, header block lookup, author parsing
  get-chezmoi.lua              ← chezmoi source dir / target path lookup via io.popen
  get-comment-chars.lua        ← Parses vim.o.commentstring
  get-file-name.lua            ← Buffer path, or chezmoi target path for source files
  get-git-config-user.lua      ← Runs `git config user.name/email` via io.popen
  get-repo-name.lua            ← Detects chezmoi, git repo root or VCSH repo name
  get-uid.lua                  ← Reads system user ID (currently unused)
```

`get-comment-chars.lua` returns the comment characters *with* their padding
from `commentstring` (`"-- "`, `" */"`). `init.lua` trims that padding and
adds its own separators — do not add padding twice.

`get-repo-name.lua` returns two values: `repo, is_chezmoi`.

`get-chezmoi.lua` probes the chezmoi source directory once per Neovim session
and caches it; if chezmoi is missing, detection is disabled for the rest of
the session. It also caches the last looked-up path so that
`get-file-name.lua` and `get-repo-name.lua` do not query twice per command.
Call `reset()` to clear both caches (used by the tests).

`plugin/` runs at Neovim startup and lazily loads `lua/insgitheader/` on first
use. The `setup(opts)` function in the core module accepts optional `name` and
`email` overrides; if not provided, they are read from `git config` at module
load time.

## Tests

```bash
make test        # requires: luarocks install busted
```

Tests run with [busted](https://lunarmodules.github.io/busted/) and do not
require Neovim. The `vim` API is stubbed in `tests/spec_helper.lua` via
`_G.vim`. `io.popen`, `os.getenv` and `os.date` are monkey-patched per-test
where needed.

The stub keeps a simulated buffer in `vim._test.lines` and `nvim_buf_set_lines`
really applies to it, so tests assert the resulting buffer rather than the
argument. `vim._test.reset(lines)` sets the starting content and clears
`cursor` and `notifications`.

When a test changes `commentstring`, `bufname` or the `io.popen` mock, the
affected modules must be dropped from `package.loaded` — several of them hold
module-level caches.

## Development notes

- Git operations use `io.popen` (shell calls), not Neovim's job API.
- Neovim ≥ 0.7.0 is required.
- The commented-out keymap in `plugin/insgitheader/init.lua` (`<Leader>ii`) is
  intentionally disabled; users can enable it manually.
