# tmux sessions — Omarchy plugin

> ⚠️ **Vibe-coded.** Written by an AI coding agent (Claude Code) from prompts.
> It works and has tests, but read the code before you enable it: Omarchy
> plugins run unsandboxed inside `omarchy-shell`.

An overlay menu for the [Omarchy shell](https://omarchy.org/) that lists your
live tmux sessions and lets you **resume** or **kill** them.

https://github.com/Cache21/omarchy-tmux-sessions/raw/main/demo.mp4

- Each row shows the session name, window count, last activity and the active
  pane's directory, plus `● attached` when a terminal is already connected.
- On the right, a preview with the session's windows and the last lines of the
  active pane (refreshed every 2 s while the menu is open).
- **Resuming** a session that is already open in another terminal **focuses
  that window** instead of opening a second client. Otherwise it opens a new
  terminal (`omarchy-launch-tui --app-id=tmux-session`) running
  `tmux attach-session`.
- Follows your Omarchy theme, like the rest of the shell.

## Keys inside the menu

| Key | Action |
|---|---|
| `↑` / `↓`, `PgUp` / `PgDn` | Move the selection |
| type | Fuzzy filter by name or path |
| `Enter` / click | Resume the session |
| `Ctrl+K` / middle click | Kill the session |
| `Ctrl+P` | Toggle the preview |
| `Esc` | Clear the filter, or close |

## Install

```bash
omarchy plugin add https://github.com/Cache21/omarchy-tmux-sessions --enable
./install.sh   # optional: adds the SUPER + ALT + T bind
```

Or by hand, in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + T", "tmux sessions", "omarchy-shell shell toggle io.github.cache21.tmux-sessions '{}'")
```

## Requirements

`tmux`, `jq`, `hyprctl` (to focus the existing terminal).

## Development

```bash
node tests/model.test.js
bin/tmux-sessions list | preview <name> | attach <name> | kill <name>
```

Note: if your `tmux.conf` sets `detach-on-destroy off`, killing a session that
is open in a terminal makes that terminal jump to another session instead of
closing.
