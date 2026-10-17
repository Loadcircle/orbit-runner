# Estado del proyecto — Orbit Runner

Actualizado: 2026-10-17 (juego como servicio, fases A y B, rama `feature/juego-como-servicio`). Punto de entrada para retomar el trabajo en una nueva sesión.

## Leer primero
1. `AGENTS.md`: reglas del proyecto.
2. `Orbit_Runner_Guia_de_Desarrollo/GUIA_MAESTRA_ORBIT_RUNNER.md`: identidad.
3. `orbit_runner_game/docs/TECHNICAL_DECISIONS.md`: versión, renderizador, arquitectura, pipeline, validación y exportación.
4. `orbit_runner_game/docs/DESIGN_DECISIONS.md`: decisiones de diseño (D1–D13) y correcciones.
5. `orbit_runner_game/docs/LEVEL_DESIGN.md`: alcances del movimiento y campaña.
6. Lista de pendientes (página privada del propietario): https://claude.ai/artifact/XUxuVfSV74yRTPuQtvt79i
7. Propuestas de monetización (incluye juego como servicio): https://claude.ai/artifact/P6KmeR5NhsNt5SHxbsEkRy
8. `orbit_runner_game/docs/LIVE_SERVICE.md`: lo implementado del juego como servicio (generador, bot, diario, torre, repeticiones, maestría, misiones), cómo usarlo y lo pendiente.
9. **Plan de desarrollo del juego como servicio** (generador de niveles por dificultad + bot validador, backlog A1–E5): https://claude.ai/code/artifact/18e9caa8-6864-4739-933d-74cb5a013861

## Estado actual (v1.0.0 jugable + pase visual v2)
- Godot 4.7.2-stable, GDScript, **renderizador Compatibility** en Android y PC (Mobile/Vulkan se descartó porque abortaba en Android sin fallback; ver TECHNICAL_DECISIONS §2).
- Tutorial + 10 niveles (3 mundos), gemas, chispas, medallas, 23 logros, 15 cosméticos, ajustes, guardado atómico versionado.
- **Idioma:** sigue al dispositivo; si no es ES/EN arranca en inglés; selector en Ajustes → Juego.
- **Pase visual v2 (2026-10-17):** shader toon propio (`resources/shaders/toon*.gdshader*`, sombras de color por bioma, rim, contornos), cielo por shader, tonemap lineal y niebla por profundidad (`scripts/level/level_environment.gd` + `resources/biomes/*.tres`). Los 49 assets se regeneraron en Blender por script con color de vértice; protagonista nuevo (cara expresiva, parpadeo, animaciones nuevas). Polvo al aterrizar y estallidos al recoger. Icono y retrato renderizados en Godot (`tools/render_ui_images.tscn`).
- APK de depuración del pase v2 **instalado en el S25** el 2026-10-17 (arranca sin errores en logcat). El puerto de la depuración inalámbrica cambia: usar `adb mdns services` y conectar al puerto más reciente (último: `192.168.1.39:32883`).
- **Estilo gráfico v2 aprobado por el propietario (2026-10-17)** tras probarlo en el S25. Es la referencia para assets futuros.
- Comentario del propietario sobre la v1 en el S25: "se ve muy bien, va fluido, algún tirón".
- Git local en la raíz, sin remoto. Commits por hito.

## Juego como servicio (rama `feature/juego-como-servicio`, sin fusionar)
- Fase A completa salvo A12 (calibración con personas): generador por dificultad, validador, bot v2 (termina los 11 niveles de campaña), índice de dificultad y lotes en paralelo.
- Fase B completa: desafío diario, Torre del Viento, repeticiones exactas y fantasma, maestría (4 estrellas y 3 trajes), misiones locales; nueva pantalla "Desafíos" en el menú.
- APK de depuración con todo esto exportado el 2026-10-17 (`build/android/orbit_runner_debug.apk`); **sin probar aún en el S25**.
- Fases C, D y E esperan decisiones del propietario (público, servidor, precios). Ver `docs/LIVE_SERVICE.md`.

## Pendientes inmediatos (en orden)
1. Con el APK v2 ya instalado en el S25, medir rendimiento del shader nuevo; confirmar que no hay tirones; recorrer los 10 niveles (sobre todo *Engranajes Locos*, *Fábrica de Rebotes* y *Corazón del Sol*, que el piloto automático no completa por su heurística).
2. Arte v2 aprobado. Efectos pendientes: anillo al desplegar el disco, estela del yo-yo, confeti en la meta. UI/fuente/logotipo se mantienen por decisión del propietario.
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
