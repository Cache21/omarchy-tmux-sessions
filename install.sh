#!/usr/bin/env bash
# Optional helper: wires the Hyprland keybinding for the tmux sessions.
#
# The plugin itself is installed with:
#   omarchy plugin add https://github.com/Cache21/omarchy-tmux-sessions --enable
#
# This script only adds the SUPER + ALT + T bind to ~/.config/hypr/bindings.lua
# (a plugin cannot edit Hyprland config itself). Re-running it is a no-op.

set -euo pipefail

PLUGIN_ID="io.github.cache21.tmux-sessions"
KEY="SUPER + ALT + T"
BIND_LINE="o.bind(\"$KEY\", \"tmux sessions\", \"omarchy-shell shell toggle $PLUGIN_ID '{}'\")"
BINDINGS="$HOME/.config/hypr/bindings.lua"

if [ ! -f "$BINDINGS" ]; then
  echo "No existe $BINDINGS — ¿es esto Omarchy 4?" >&2
  exit 1
fi

if grep -qF "$PLUGIN_ID" "$BINDINGS"; then
  echo "El bind para $PLUGIN_ID ya está en $BINDINGS — nada que hacer."
  exit 0
fi

if grep -qE '"SUPER \+ ALT \+ T"' "$BINDINGS"; then
  echo "Aviso: SUPER + ALT + T ya está ocupado en $BINDINGS." >&2
  echo "Editá el bind a mano con otra tecla libre. Línea sugerida:" >&2
  echo "  $BIND_LINE" >&2
  exit 1
fi

cp -- "$BINDINGS" "$BINDINGS.bak.$(date +%s)"
printf '\n-- tmux sessions (omarchy-tmux-sessions)\n%s\n' "$BIND_LINE" >> "$BINDINGS"
echo "Agregado a $BINDINGS:"
echo "  $BIND_LINE"

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null && hyprctl configerrors || true
fi
echo "Listo. Probá:  SUPER + ALT + T"
