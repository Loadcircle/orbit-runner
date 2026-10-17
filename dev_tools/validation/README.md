# Herramientas de validación (no forman parte del juego)

Se guardan fuera de `orbit_runner_game/` para no incluirlas en el proyecto ni en la exportación (AGENTS.md: no añadir pruebas automatizadas al juego salvo que se pida). Para usarlas, copiarlas a `orbit_runner_game/tools/` (ignoradas por git con el patrón `tools/_*`), ejecutar `--import` una vez y lanzar:

| Herramienta | Uso |
|---|---|
| `_check_scripts.tscn` | `godot --headless --path . res://tools/_check_scripts.tscn` — carga todos los scripts y escenas y lista los que fallan. |
| `_bot.tscn` | Bot v1 (histórico). Sustituido por el bot v2 de `tools/bot/run_bot.tscn` (ver `orbit_runner_game/docs/LIVE_SERVICE.md`). |
| `_shot.tscn` | `godot --path . --resolution 1280x720 res://tools/_shot.tscn -- <nivel.tscn> <carpeta> tour 8` — hoja de capturas recorriendo un nivel. |
| `_flow.tscn` | `godot --path . --resolution 1280x720 res://tools/_flow.tscn -- <carpeta>` — recorre título → menús → nivel → resultados con capturas. |
| `_char_shot.tscn` | `godot --path . --resolution 1280x720 res://tools/_char_shot.tscn -- <salida.png> [isles|toyworks|ruins] [animación]` — protagonista (tres poses), chispa y gema con la luz de un bioma, más un primer plano de la cara (`<salida>_face.png`). |
| `../blender/render_preview.py` | `blender --background --factory-startup --python dev_tools/blender/render_preview.py -- <carpeta> <ASSET> [...]` — vistas previas Eevee de los `.blend` (los personajes añaden cara y espalda). |
| `_modes.tscn` | `godot --headless --fixed-fps 60 --path . res://tools/_modes.tscn -- daily\|tower\|replay [segundos]` — el bot juega el desafío diario o la torre por el flujo real, o comprueba que una repetición reproduce la partida exacta. |
| `run_campaign_bot.sh` | `bash ../dev_tools/validation/run_campaign_bot.sh [perfil] [intentos]` — bot v2 (`tools/bot/`, sí versionado porque lo usa el generador de lotes) sobre los 11 niveles. |
| `_route.tscn` | `godot --headless --path . res://tools/_route.tscn -- <nivel.tscn>` — imprime las piezas de la ruta. |

**Atención:** estas herramientas usan los autoloads reales y **escriben en el guardado local** (`%APPDATA%\Godot\app_userdata\Orbit Runner\`). Borrar `orbit_runner_save*.json` después si se quiere empezar de cero.
