# Orbit Runner (nombre provisional)

Plataformas 3D de movimiento y aventura para Android (y PC) hecho con **Godot 4.7.2** y **GDScript**. Corre, salta, deslízate e impúlsate por islas flotantes con un **yo-yo cinético** que se convierte en un disco de rebote.

## Abrir y jugar en PC

1. Abrir `project.godot` con `C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe` (no actualizar la versión).
2. Pulsar **F5**. Escena principal: `scenes/ui/title_screen.tscn`. Cualquier nivel se puede probar directamente con **F6** desde `scenes/levels/`.

Controles PC: WASD/flechas mover · Espacio saltar (mantener = más alto) · E yo-yo · Mayús deslizar (suelo) / impulso (aire) · Q/R cámara · Esc pausa. Mando compatible.

## Android

- APK de depuración: `build/android/orbit_runner_debug.apk` (arm64). Instalar con `adb install -r build/android/orbit_runner_debug.apk`.
- Regenerar: `Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-debug "Android" build/android/orbit_runner_debug.apk`
- AAB de publicación: ver `docs/TECHNICAL_DECISIONS.md` §10.

## Contenido

Tutorial + 10 niveles en 3 mundos, gemas, chispas, medallas, 23 logros, 15 recompensas cosméticas, ajustes (audio, táctil, zurdo, calidad, idioma ES/EN, FPS), guardado local con copias de seguridad.

## Documentación

- `docs/TECHNICAL_DECISIONS.md`: versión, renderizador, arquitectura, Blender → GLB, guardado, validación y exportación.
- `docs/DESIGN_DECISIONS.md`: decisiones de diseño para revisar.
- `docs/LEVEL_DESIGN.md`: alcances del movimiento, campaña y curva de dificultad.
- `assets_source/blender/PARAMETROS_ASSETS_ORBIT_RUNNER.md`: convenciones de assets.

## Regenerar contenido

| Qué | Comando (desde esta carpeta) |
|---|---|
| Modelos 3D | `blender --background --factory-startup --python assets_source/blender/scripts/build_props.py -- ALL` (y `build_character.py`) |
| Escenas de props | `godot --headless --path . res://tools/build_prop_scenes.tscn` |
| Niveles + catálogo | `godot --headless --path . res://tools/build_levels.tscn` |
| Recompensas y logros | `godot --headless --path . res://tools/build_data.tscn` |
| Audio | `python assets_source/audio/generate_audio.py` |
| Textos | `python localization/make_strings.py` |

Los generadores sobrescriben sus salidas; tras editar a mano en Godot, no volver a ejecutarlos sin trasladar los cambios.
