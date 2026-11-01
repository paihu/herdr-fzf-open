# Project Guide

## Overview

herdr-fzf-open is a [herdr](https://herdr.dev) plugin: pick URLs printed in the current pane with
fzf and open them with `$BROWSER` (or a configured target) in a split pane next to the source pane.
A POSIX sh rewrite inspired by to4iki/herdr-fzf-terminal-browser, whose extraction rules and test
cases it keeps.

## Tech Stack

- One POSIX `sh` script, `fzf-open` (URL extraction in POSIX `awk`); no build step
- External processes: `herdr` (via `HERDR_BIN_PATH`), `$BROWSER`, `fzf`, `jq` or `gojq`
- Configuration: only the optional `targets` file (key → browser command) in `HERDR_PLUGIN_CONFIG_DIR`;
  further candidates are listed in README ("Not yet / ideas for later")
- Release: bump `version` in `herdr-plugin.toml` by hand and tag `vX.Y.Z`

## Development

```sh
sh tests/run.sh
shellcheck -s sh fzf-open tests/run.sh
herdr plugin link .   # local E2E inside herdr; bind prefix+f to paihu.fzf-open.pick
```

## Coding Guide

- POSIX only: no bashisms, no GNU-only flags, no awk interval expressions (macOS ships BSD awk/sed).
- Quote every expansion; data (URLs, pane text) is never `eval`ed — only `$BROWSER` is.
- `tests/run.sh` covers `extract`, `browser`, and `picker`/`open` against fake `herdr` and `fzf`;
  add a case there with each change.
- Keep the surface small: five subcommands, one config file. Add features only when asked.
- Conventional Commits (`feat:`, `fix:`, `feat(extract):` ...).
