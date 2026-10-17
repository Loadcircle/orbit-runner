# Estado del proyecto — Orbit Runner

Actualizado: 2026-10-17 (pase visual v2). Punto de entrada para retomar el trabajo en una nueva sesión.

## Leer primero
1. `AGENTS.md`: reglas del proyecto.
2. `Orbit_Runner_Guia_de_Desarrollo/GUIA_MAESTRA_ORBIT_RUNNER.md`: identidad.
3. `orbit_runner_game/docs/TECHNICAL_DECISIONS.md`: versión, renderizador, arquitectura, pipeline, validación y exportación.
4. `orbit_runner_game/docs/DESIGN_DECISIONS.md`: decisiones de diseño (D1–D13) y correcciones.
5. `orbit_runner_game/docs/LEVEL_DESIGN.md`: alcances del movimiento y campaña.
6. Lista de pendientes (página privada del propietario): https://claude.ai/artifact/XUxuVfSV74yRTPuQtvt79i
7. Propuestas de monetización (incluye juego como servicio): https://claude.ai/artifact/P6KmeR5NhsNt5SHxbsEkRy

## Estado actual (v1.0.0 jugable + pase visual v2)
- Godot 4.7.2-stable, GDScript, **renderizador Compatibility** en Android y PC (Mobile/Vulkan se descartó porque abortaba en Android sin fallback; ver TECHNICAL_DECISIONS §2).
- Tutorial + 10 niveles (3 mundos), gemas, chispas, medallas, 23 logros, 15 cosméticos, ajustes, guardado atómico versionado.
- **Idioma:** sigue al dispositivo; si no es ES/EN arranca en inglés; selector en Ajustes → Juego.
- **Pase visual v2 (2026-10-17):** shader toon propio (`resources/shaders/toon*.gdshader*`, sombras de color por bioma, rim, contornos), cielo por shader, tonemap lineal y niebla por profundidad (`scripts/level/level_environment.gd` + `resources/biomes/*.tres`). Los 49 assets se regeneraron en Blender por script con color de vértice; protagonista nuevo (cara expresiva, parpadeo, animaciones nuevas). Polvo al aterrizar y estallidos al recoger. Icono y retrato renderizados en Godot (`tools/render_ui_images.tscn`).
- APK de depuración del pase v2 exportado en `orbit_runner_game/build/android/orbit_runner_debug.apk` pero **no instalado**: la depuración inalámbrica del S25 rechazó la conexión (activarla y `adb connect`; ver comandos).
- Comentario del propietario sobre la v1 en el S25: "se ve muy bien, va fluido, algún tirón".
- Git local en la raíz, sin remoto. Commits por hito.

## Pendientes inmediatos (en orden)
1. Instalar el APK v2 en el S25 y medir rendimiento del shader nuevo; confirmar que no hay tirones; recorrer los 10 niveles (sobre todo *Engranajes Locos*, *Fábrica de Rebotes* y *Corazón del Sol*, que el piloto automático no completa por su heurística).
2. Recoger la opinión del propietario sobre el arte v2 y ajustar. Efectos pendientes: anillo al desplegar el disco, estela del yo-yo, confeti en la meta. UI/fuente/logotipo se mantienen por decisión del propietario.
3. **Monetización**: el propietario debe elegir modelo (propuestas en la página enlazada; recomendación: gratis + desbloqueo completo y modelo como servicio por fases). No integrar nada sin autorización.
4. Publicación: identificador del paquete (`com.orbitrunner.game` es provisional), keystore de publicación, AAB con plantilla Gradle, ficha de tienda, pruebas cerradas.

## Comandos útiles (desde `orbit_runner_game/`)
- Godot: `"C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"`
- Blender (Store): `%LOCALAPPDATA%\Microsoft\WindowsApps\BlenderFoundation.Blender_ppwjx1n5r4v9t\blender-launcher.exe --background --factory-startup --python <script> -- ALL` (el lanzador no devuelve stdout; los scripts escriben `last_build*.json/log`).
- ADB: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`
- Exportar APK: `godot --headless --path . --export-debug "Android" build/android/orbit_runner_debug.apk`
- Assets 3D: `build_props.py` / `build_character.py` en Blender (ver arriba). Tras cambiar el script de importación, borrar `.godot/imported/*.glb-*.scn` y ejecutar `--import`.
- Imágenes de UI: `godot --path . res://tools/render_ui_images.tscn` (con ventana).
- Regenerar niveles / props / datos: `godot --headless --path . res://tools/build_levels.tscn` (también `build_prop_scenes.tscn`, `build_data.tscn`). **Sobrescriben** las escenas generadas. Ejecutar antes `--import` si se añadió un script con `class_name`.
- Herramientas de validación (bot, capturas, comprobación de scripts): `dev_tools/validation/README.md`.

## Avisos para el agente
- Los generadores de niveles/props escriben escenas `.tscn`; si se editan a mano en Godot, no regenerar sin trasladar los cambios.
- Las herramientas de validación escriben en el guardado local real; limpiar después.
- No cambiar de renderizador sin revisar materiales y shaders (AGENTS.md).
- No integrar pagos, anuncios ni servicios externos sin autorización explícita.
