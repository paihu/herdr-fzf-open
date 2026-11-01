# herdr-fzf-open

![herdr 0.8.2+](https://img.shields.io/badge/herdr-0.8.2%2B-8a2be2)

A herdr plugin: press a key, pick a URL printed in the current pane with `fzf`,
and it opens with `$BROWSER` in a split to the right of the pane you are in.

- A terminal browser (`w3m`, `lynx`, …) draws in that split.
- A GUI launcher (`xdg-open`, `wslview`, `open`) hands the URL off and the split closes at once.
  Point `$BROWSER` at the launcher rather than the browser itself (`firefox` would keep the split
  open until it exits).

`$BROWSER` follows the usual convention: `:`-separated alternatives tried in order, and `%s`
replaced by the URL (otherwise the URL is appended), e.g. `BROWSER='w3m:xdg-open'`. Each
alternative is read by `sh` as a command line (`\ `, `'…'`, `"…"` work); the URL itself is passed as one
argument and never interpreted.

Several browsers can sit on their own fzf keys — see [Browser targets](#browser-targets). URL
extraction is tuned for coding-agent output: dev-server addresses like `localhost:5173` are
recognised, and Markdown links and JSON-embedded URLs come out clean.

The whole plugin is one POSIX `sh` script: nothing to build, no toolchain to install.

## Inspired by

- [to4iki/herdr-fzf-terminal-browser](https://github.com/to4iki/herdr-fzf-terminal-browser) — the
  original herdr plugin (Rust, opens [terminal-browser](https://terminal-browser.com/)). This project
  started as a fork of it and keeps its URL extraction rules and test cases.
- [wfxr/tmux-fzf-url](https://github.com/wfxr/tmux-fzf-url) — where the picker idea comes from.

## Requirements

- [herdr](https://herdr.dev) ≥ 0.8.2
- `$BROWSER` set in the environment herdr runs with
- [fzf](https://github.com/junegunn/fzf)
- [jq](https://jqlang.org/) or [gojq](https://github.com/itchyny/gojq)
- macOS or Linux

## Install

```sh
herdr plugin install paihu/herdr-fzf-open
```

Then bind a key in `~/.config/herdr/config.toml` and run `herdr server reload-config`:

```toml
[[keys.command]]
key = "prefix+f"
type = "plugin_action"
command = "paihu.fzf-open.pick"
description = "open url in $BROWSER"
```

Press `prefix+f` in any pane: the URLs currently on that pane's screen are listed, newest first.
What you see is what you can pick — no more, no less. If there is none, nothing happens.

| Key | Action |
|---|---|
| `enter` | open with `$BROWSER` (or the `enter` target) in a split and focus it |
| other target keys | open with that target — see [Browser targets](#browser-targets) |
| `ctrl-x` | choose the target from a second fzf list, then open |
| `ctrl-y` | copy to clipboard |
| `esc` | cancel |

If you have scrolled the pane back, the picker uses the part you scrolled to. Soft-wrapped lines are
joined back together so a long URL stays in one piece — except while scrolled back, where herdr can
only hand over the screen as rendered.

## Browser targets

To choose between several browsers, list them in `targets` in the plugin's config directory
(`herdr plugin config-dir paihu.fzf-open`), one `key command` per line:

```
# key     command (same format as $BROWSER)
enter     wslview
ctrl-o    w3m
ctrl-t    terminal-browser open
```

Keys are [fzf key names](https://junegunn.github.io/fzf/reference/#available-keys-synonyms); the picker's
header shows each one with its program. `$BROWSER` still serves as `enter` unless the file binds
`enter`, and `open` from the command line uses the `enter` target. `ctrl-x` (pick a target from a
list) and `ctrl-y` (copy) are reserved.

## What gets extracted

| Text in the pane | Opened as |
|---|---|
| `https://…`, `http://…`, `ftp://…`, `file://…` | as is |
| `localhost:5173`, `127.0.0.1:8080/x`, `0.0.0.0:3000`, `[::1]:4000` | `http://localhost:5173`, … |
| `10.0.0.5:8080/api` (IPv4 with port or path) | `http://10.0.0.5:8080/api` |
| `www.example.com/x` | `https://www.example.com/x` |
| `git@github.com:a/b.git`, `ssh://git@host/a/b.git` | `https://github.com/a/b` |

Trailing punctuation and unbalanced brackets are dropped (`[docs](https://a/b)` yields `https://a/b`,
Wikipedia-style `Foo_(bar)` is kept). Duplicates collapse to their newest occurrence.

## How it works

`prefix+f` runs the plugin action `pick`. An action has no TTY, so it only looks for URLs and, if it
finds any, opens the `picker` popup for that pane.

The picker reads the pane's screen with `herdr pane read`, runs fzf over the URLs it finds, and hands
the chosen one to a new split pane beside the pane you pressed the key in, which `exec`s
`$BROWSER <url>`. Focus follows it there.

The plugin runs only `herdr`, `fzf`, `$BROWSER`, and (for `ctrl-y`) the platform's clipboard tool,
`jq`/`gojq`, and writes nothing. The only configuration is the optional `targets` file.

## Not yet / ideas for later

Kept out of the first release on purpose. Open an issue if one of these would help you.

- More configuration: split direction / size, extra fzf flags
- Scanning scrollback beyond the current screen
- Multi-select
- Talking to the herdr socket directly instead of spawning the `herdr` CLI (≈30 ms per call saved)
- URLs hidden behind OSC 8 hyperlinks (`pane read --format ansi`)
- Ctrl+click on a URL (`[[link_handlers]]`) opening in `$BROWSER`

## Command line

Open the picker without a keybinding:

```sh
herdr plugin action invoke paihu.fzf-open.pick
```

`open` and `extract` are subcommands of the script rather than plugin actions, so `action invoke`
does not reach them; run the script from the plugin directory (a checkout you linked with
`herdr plugin link`, or the `plugin_root` in `herdr plugin list --json`):

```sh
sh fzf-open open https://example.com   # open next to this pane
herdr pane read "$HERDR_PANE_ID" --source visible | sh fzf-open extract
```

## Development

```sh
sh tests/run.sh
shellcheck -s sh fzf-open tests/run.sh
herdr plugin link .      # then bind prefix+f as above
```

## License

MIT
