# tmux sessions — Omarchy plugin

> ⚠️ **Vibe-coded.** Escrito por un agente de IA (Claude Code) a partir de prompts.
> Funciona y tiene tests, pero leé el código antes de habilitarlo: los plugins de
> Omarchy corren sin sandbox dentro de `omarchy-shell`.

Un menú overlay para el [Omarchy shell](https://omarchy.org/) que lista las
sesiones tmux activas y te deja **reanudarlas** o **matarlas**.

- Cada fila muestra el nombre, cantidad de ventanas, última actividad y el
  directorio del pane activo; `● abierta` si ya hay una terminal conectada.
- A la derecha, un preview con las ventanas de la sesión y las últimas líneas
  del pane activo (se refresca cada 2 s mientras el menú está abierto).
- **Reanudar** una sesión que ya está abierta en otra terminal **enfoca esa
  ventana** en vez de abrir un segundo cliente. Si no está abierta, abre una
  terminal nueva (`omarchy-launch-tui --app-id=tmux-session`) con
  `tmux attach-session`.

## Atajos dentro del menú

| Tecla | Acción |
|---|---|
| `↑` / `↓`, `PgUp` / `PgDn` | Mover la selección |
| escribir | Filtrar (fuzzy por nombre o ruta) |
| `Enter` / click | Reanudar la sesión |
| `Ctrl+K` / click medio | Matar la sesión |
| `Ctrl+P` | Mostrar/ocultar el preview |
| `Esc` | Limpiar el filtro, o cerrar |

## Instalación

```bash
omarchy plugin add https://github.com/Cache21/omarchy-tmux-sessions --enable
./install.sh   # opcional: agrega el bind SUPER + ALT + T
```

O a mano, en `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + T", "tmux sessions", "omarchy-shell shell toggle io.github.cache21.tmux-sessions '{}'")
```

## Requisitos

`tmux`, `jq`, `hyprctl` (para enfocar la terminal existente).

## Desarrollo

```bash
node tests/model.test.js
bin/tmux-sessions list | preview <name> | attach <name> | kill <name>
```

Nota: si tu `tmux.conf` tiene `detach-on-destroy off`, matar una sesión que está
abierta en una terminal hace que esa terminal salte a otra sesión en vez de cerrarse.
