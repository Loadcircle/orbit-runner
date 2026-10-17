# Estado del proyecto — Orbit Runner

Actualizado: 2026-10-17. Punto de entrada para retomar el trabajo en una nueva sesión.

## Leer primero
1. `AGENTS.md`: reglas del proyecto.
2. `Orbit_Runner_Guia_de_Desarrollo/GUIA_MAESTRA_ORBIT_RUNNER.md`: identidad.
3. `orbit_runner_game/docs/TECHNICAL_DECISIONS.md`: versión, renderizador, arquitectura, pipeline, validación y exportación.
4. `orbit_runner_game/docs/DESIGN_DECISIONS.md`: decisiones de diseño (D1–D13) y correcciones.
5. `orbit_runner_game/docs/LEVEL_DESIGN.md`: alcances del movimiento y campaña.
6. Lista de pendientes (página privada del propietario): https://claude.ai/artifact/XUxuVfSV74yRTPuQtvt79i

## Estado actual (v1.0.0 jugable)
- Godot 4.7.2-stable, GDScript, **renderizador Compatibility** en Android y PC (Mobile/Vulkan se descartó porque abortaba en Android sin fallback; ver TECHNICAL_DECISIONS §2).
- Tutorial + 10 niveles (3 mundos), gemas, chispas, medallas, 23 logros, 15 cosméticos, ajustes, guardado atómico versionado, ES/EN.
- Arte: 49 assets creados en Blender por script (`assets_source/blender/scripts/`), `.blend` + `.glb`. Audio sintetizado propio.
- **APK de depuración instalado en el Galaxy S25 del propietario (SM-S931B)** por depuración inalámbrica (`192.168.1.39:40001`, ya emparejado; si se pierde: `adb mdns services` y `adb connect`).
- Última mejora: precarga de shaders al entrar a cada nivel (`scripts/level/shader_warmup.gd`) para los tirones de compilación. **Falta confirmar en el S25.**
- Comentario del propietario en el S25: "se ve muy bien, va fluido, algún tirón".
- Git local en la raíz, sin remoto. Commits por hito.

## Pendientes inmediatos (en orden)
1. Confirmar en el S25 que la precarga elimina los tirones; terminar de probar los 10 niveles (sobre todo *Engranajes Locos* y *Fábrica de Rebotes*, que el piloto automático no completó por su heurística con las aspas).
2. **Pulido visual y coloración**, pedido por el propietario. Primero preguntar la dirección: ¿más fiel a la lámina (anime, más detalle) o refinar el estilo "juguete" actual? Luego: protagonista (cara, pelo/piel que se ven pálidos o amarillentos en el motor, proporciones, animación); paleta de Juguetes (lavada) y Ruinas (las chispas se confunden con la arena); material toon propio compatible con Compatibility; detalle de plataformas, props (palmera), VFX, cielo, fuente/logotipo.
3. **Monetización**: sin decidir (el juego es offline, sin anuncios ni compras). Recomendación inicial: gratis + desbloqueo de mundos 2–3 con compra única, sin anuncios en la v1. Requiere autorización del propietario antes de integrar nada.
4. Publicación: identificador del paquete (`com.orbitrunner.game` es provisional), keystore de publicación, AAB con plantilla Gradle, ficha de tienda, pruebas cerradas.

## Comandos útiles (desde `orbit_runner_game/`)
- Godot: `"C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"`
- Blender (Store): `%LOCALAPPDATA%\Microsoft\WindowsApps\BlenderFoundation.Blender_ppwjx1n5r4v9t\blender-launcher.exe --background --factory-startup --python <script> -- ALL` (el lanzador no devuelve stdout; los scripts escriben `last_build*.json/log`).
- ADB: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`
- Exportar APK: `godot --headless --path . --export-debug "Android" build/android/orbit_runner_debug.apk`
- Regenerar niveles / props / datos: `godot --headless --path . res://tools/build_levels.tscn` (también `build_prop_scenes.tscn`, `build_data.tscn`). **Sobrescriben** las escenas generadas. Ejecutar antes `--import` si se añadió un script con `class_name`.
- Herramientas de validación (bot, capturas, comprobación de scripts): `dev_tools/validation/README.md`.

## Avisos para el agente
- Los generadores de niveles/props escriben escenas `.tscn`; si se editan a mano en Godot, no regenerar sin trasladar los cambios.
- Las herramientas de validación escriben en el guardado local real; limpiar después.
- No cambiar de renderizador sin revisar materiales y shaders (AGENTS.md).
- No integrar pagos, anuncios ni servicios externos sin autorización explícita.
