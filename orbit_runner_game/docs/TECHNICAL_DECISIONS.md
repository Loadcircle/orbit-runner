# Decisiones técnicas — Orbit Runner

Inicialización del contenedor: 2026-09-28 · Desarrollo del juego: 2026-10-16/17

## 1. Motor, lenguaje y versión

- **Godot 4.7.2-stable** (`4.7.2.stable.official.ed1daf0bf`), instalado en `C:\Program Files\Godot_v4.7.2-stable_win64.exe\`. No actualizar automáticamente; cualquier cambio de versión debe revisar importaciones, shaders y exportación.
- **GDScript** para toda la lógica y las herramientas del proyecto. Sin C#.
- **Física: Jolt Physics** (`physics/3d/physics_engine`), 60 ticks/s con interpolación física activa (movimiento suave en pantallas de 90/120 Hz).
- Plantillas de exportación 4.7.2 descargadas del release oficial de GitHub (`Godot_v4.7.2-stable_export_templates.tpz`, SHA-512 verificado contra `SHA512-SUMS.txt`). Instaladas en `%APPDATA%\Godot\export_templates\4.7.2.stable\` solo para Android y Windows x86_64.

## 2. Renderizador

**Decisión final: Compatibility (OpenGL ES 3 / OpenGL 3.3) en Android y en PC.**

| Opción | Ventajas | Inconvenientes |
|---|---|---|
| **Compatibility (OpenGL)** | Máxima compatibilidad en Android; el mejor rendimiento cuando no se necesitan funciones avanzadas; admite sombras direccionales, niebla, glow, MSAA y materiales toon | Menos funciones avanzadas (sin SDFGI, volumétricos, etc., que este juego no usa) |
| Mobile (Vulkan) | Pensado para GPUs móviles modernas | Requiere un driver Vulkan sano; ver evidencia |
| Forward+ | Máxima calidad | Coste excesivo para móvil |

**Evidencia y criterio** (registro honesto del cambio):
1. Se empezó con *Mobile* por el S25 (Adreno 830, Vulkan 1.3) y la RTX 4070 SUPER del PC.
2. Al probar el APK en el emulador Android (GPU por software), **Vulkan falló al crear el dispositivo y Godot abortó el arranque**: la opción `fallback_to_opengl3` solo actúa cuando Vulkan *no existe*, no cuando un driver presente falla (confirmado en la documentación de Godot 4.7). En móviles Android, drivers Vulkan defectuosos existen en gamas medias/antiguas.
3. El juego no usa ninguna función exclusiva de RenderingDevice: toon con `StandardMaterial3D`, una luz direccional con sombras, niebla y un shader aditivo simple. Se verificó visualmente en PC que el aspecto es prácticamente idéntico en Compatibility.
4. Con Compatibility, el APK **arranca y se juega en el emulador** (OpenGL ES 3.1) y mantiene el mismo aspecto en PC, lo que cumple el objetivo de iterar en PC con la imagen del móvil.

Se cambió antes de existir materiales o shaders dependientes del renderizador, así que no hubo que rehacer contenido. Si en el S25 se quisiera más calidad, cambiar a *Mobile* solo en Android es posible (`rendering_method.mobile`) tras medirlo en el dispositivo.

Materiales (v2, 2026-10-17): **shader toon propio** compatible con Compatibility (`resources/shaders/toon_core.gdshaderinc` + variantes `toon.gdshader`, `toon_fade.gdshader` para decoración con tramado cerca de la cámara, `toon_ghost.gdshader` para gemas ya conseguidas y `toon_outline.gdshader` para contornos). Usa `light()` propio: dos bandas con borde suave, banda de brillo, **sombras de color** (tinte por bioma en lugar de gris), borde de luz (rim) y brillo especular toon para plástico/metal/gemas. El albedo se multiplica por el color de vértice `Col` que pintan los scripts de Blender (degradados, estratos, variación por cara) sin texturas. Los valores compartidos (tinte de sombra, color de rim, suavidad de banda) son **uniformes globales** (`[shader_globals]` en `project.godot`) que fija `LevelEnvironment.apply_toon_globals()` según el `BiomeTheme`. La piel tiene sombra cálida propia (`ToonMaterials.WARM_SHADOW`). Contornos: cascarón invertido horneado en los GLB (materiales `M_Outline*`, sin pasada extra) en coleccionables y peligros; el protagonista mantiene el contorno por `material_overlay` (`grow`). Cielo: `resources/shaders/sky.gdshader` (degradado de tres tonos, sol con halo). Mapeo de tono lineal (el filmic desaturaba), ambiente de color plano y niebla por profundidad (zona de juego nítida, perspectiva aérea solo en el fondo). Shader propio previo: `resources/shaders/wind_column.gdshader` (aditivo). Al compartir todos los materiales un único shader, el número de variantes que compilar (y la precarga) es menor que con `StandardMaterial3D`.

**Precarga de shaders:** Compatibility compila cada shader la primera vez que se dibuja, lo que provocaba tirones en el S25. `scripts/level/shader_warmup.gd` dibuja una vez, en miniatura y bajo el fundido de carga, cada combinación malla/material del nivel (incluidos el disco del yo-yo, la cuerda y las partículas).

**Niveles de calidad** (Ajustes → Juego): *Baja* (sin sombras, sin escenario lejano, escala 3D 75 %), *Media* (sombras 30 m) y *Alta* (sombras 45 m, MSAA 2×, glow). Por defecto: *Alta* en PC y *Media* en móvil.

### Dispositivos y modos de prueba

- **PC (Windows 11, RTX 4070 SUPER)**: ejecución completa del juego (Vulkan Mobile), capturas automatizadas de menús y niveles, y piloto automático (ver §9).
- **Emulador Android**: perfil `S23` (x86_64, API 35) con el APK de pruebas x86_64 (GPU por software y GPU del anfitrión). Ver §9.
- **Samsung Galaxy S25**: **no disponible durante el desarrollo**. No se afirma compatibilidad ni rendimiento medido en hardware real; es la validación pendiente principal.

## 3. Pantalla, orientación y entrada

- Orientación: **horizontal con sensor** (`window/handheld/orientation=4`). Nota: el contenedor inicial tenía `1` (vertical) por error y se corrigió.
- Resolución base 1280×720, `stretch_mode=canvas_items`, `aspect=expand`: la UI se adapta a 19.5:9 (S25) y otras proporciones. La UI usa márgenes de *safe area* (`DisplayServer.get_display_safe_area`) en móvil.
- FPS: límite configurable 30/60/120 (por defecto 60, ahorro de batería). V-Sync activo.
- **Entrada única**: todas las acciones viven en el `InputMap` (`project.godot`): `move_left/right/forward/back`, `jump`, `yoyo`, `action` (deslizar en suelo / impulso aéreo), `pause`, `camera_left/right`. Teclado, mando y táctil alimentan las **mismas acciones**: los controles táctiles (`scripts/ui/touch_controls.gd`) llaman a `Input.action_press/release` con la fuerza analógica del joystick.
- Táctil: joystick analógico flotante en la mitad izquierda (aparece donde se apoya el pulgar), botones de salto (principal), yo-yo y acción a la derecha, arrastre libre en la derecha para girar la cámara. Modo zurdo, tamaño y opacidad configurables. Se muestran automáticamente en móvil o al detectar un toque; en PC se ocultan al usar teclado/mando.
- PC: WASD/flechas mover · Espacio/J saltar · E/K yo-yo · Mayús/L deslizar/impulso · Q/R cámara · Esc/P pausa. Mando: stick izq., A, X/RB, B/LB, stick der., Start.
- Botón Atrás de Android: `quit_on_go_back=false`; `SceneRouter` despacha `Window.go_back_requested` (y `ui_cancel` en PC) a `handle_back()` de cada pantalla. En partida abre la pausa; la pérdida de foco también pausa.

## 4. Arquitectura

- Escena principal: `scenes/ui/title_screen.tscn`.
- **Autoloads** (necesidades transversales reales): `SaveService` (persistencia), `Settings` (opciones), `Progress` (campaña, economía, cosméticos, logros, estadísticas), `AudioDirector` (música con fundidos y pool de efectos), `SceneRouter` (cambios de escena con fundido, nivel actual, botón Atrás, aviso de logros).
- Datos editables en recursos `.tres`: `resources/levels/level_catalog.tres` (`LevelInfo`), `resources/cosmetics/cosmetic_catalog.tres`, `resources/achievements/achievement_catalog.tres`, `resources/biomes/*.tres` (`BiomeTheme`), `resources/player/movement_tuning.tres` (`MovementTuning`: todos los valores de movimiento).
- Jugador desacoplado: `player.gd` (movimiento/estado), `player_visual.gd` (animación, squash, cosméticos; no toca gameplay), `follow_camera.gd` (cámara), `kinetic_yoyo.gd` (yo-yo), `blob_shadow.gd` (sombra de aterrizaje).
- `Level` (`scripts/level/level.gd`) instancia jugador, cámara, yo-yo, HUD, pausa y resultados; `LevelEnvironment` crea cielo, sol, niebla, mar de nubes y escenario lejano a partir del bioma y la calidad.
- **UI construida en código** dentro de escenas raíz `.tscn` (`scripts/ui/ui_kit.gd` + tema `resources/ui/orbit_theme.tres`). Iconos vectoriales dibujados en código (`icon_glyph.gd`): nítidos a cualquier escala y sin imágenes externas. Diferencia respecto a AGENTS.md (que sugiere composición en `.tscn`): se eligió por robustez y porque las listas (niveles, logros, recompensas) son dinámicas; las escenas siguen existiendo como puntos de entrada editables.
- Los elementos de nivel (`scenes/props/*.tscn`) se generan con `tools/build_prop_scenes.tscn` a partir de los GLB (colisiones, áreas y scripts). Los niveles se generan con `tools/build_levels.tscn` (DSL en `scripts/level/level_builder.gd`, que se exporta porque el teléfono también genera niveles); ver `docs/LEVEL_DESIGN.md`. Ambos se ejecutan como escena para tener los autoloads disponibles:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/build_levels.tscn`
  Regenerar **sobrescribe** las escenas generadas; si se editan a mano en el editor, no volver a ejecutar el generador sin trasladar los cambios.

- **Juego como servicio (fases A y B)**: generador de niveles por dificultad (`scripts/generator/`), bot validador y lotes (`tools/bot/`, `tools/generate_levels.tscn`), repeticiones y fantasmas (`scripts/replay/`), desafío diario, Torre del Viento y misiones. Detalle en `docs/LIVE_SERVICE.md`. Sin nuevos autoloads: `Progress` guarda diario, torre, maestría y misiones (`scripts/progress/mission_board.gd`); `SceneRouter.play_generated()` construye el nivel en memoria (`change_scene_to_node`). `SaveService.persist = false` impide que las herramientas escriban el guardado real.

- **Freemium y servicios (2026-10-18)**: nuevo autoload `Services` (`scripts/autoload/services.gd`). Agrupa energía, anuncios, tienda, cuenta, amigos y avisos. Cada servicio externo es una interfaz (`scripts/services/*_provider.gd`) con un proveedor simulado; la integración real (prevista con Firebase) solo cambia los proveedores en `Services.reload()`.
  - Temporadas en `scripts/season/` (calendario, puntuación, rivales simulados, ranking).
  - Energía en `scripts/economy/` y `resources/economy/economy_config.tres`.
  - Diálogos (`Modal`, `EnergyDialog`, `ParentalGate`, `AgeGate`, `NotificationInbox`) construidos en código sobre `UiKit`.
  - La hora sale de `GameClock` (reloj local; adelantable con el argumento `clock_hours=N`).
  - El público incluye menores de 13 años: pantalla de edad neutral, sin login social para menores, puerta parental en compras e invitaciones, anuncios aptos para familias.
  - Detalle en `docs/LIVE_SERVICE.md`.

## 5. Flujo Blender → GLB → Godot

- Blender 5.2.2 LTS (Microsoft Store). Blender MCP conectado y usado para inspección; la producción se hizo con scripts reproducibles en modo *background* (`assets_source/blender/scripts/`):
  - `build_props.py` (46 assets: plataformas por bioma y tamaño, impulso, peligros, coleccionables, decoración),
  - `build_character.py` (protagonista con esqueleto y 11 animaciones, yo-yo y disco),
  - `render_ui_images.py` (icono, icono adaptativo y retrato del HUD).
  Ejecución: `blender --background --factory-startup --python <script> -- [ASSET|ALL]` (en esta máquina, a través de `blender-launcher.exe` de WindowsApps).
- Convenciones: 1 u = 1 m; Z arriba en Blender → Y arriba en Godot; frente del asset +Y en Blender (= -Z en Godot); escala aplicada; modificadores no destructivos en el `.blend` aplicados al exportar (`export_apply`). **Excepción documentada:** las plataformas tienen el origen en el centro de la **superficie superior caminable** (el diseño de niveles trabaja con la altura de pisada).
- `.blend` editables en `assets_source/blender/`; GLB en `art/models/`. `assets_source/` lleva `.gdignore` para que Godot no intente importar los `.blend` directamente.
- Importación: `[importer_defaults] scene` aplica `scripts/tools/toon_post_import.gd` a todos los GLB: convierte cada material glTF en un `ShaderMaterial` del shader toon (`scripts/rendering/toon_materials.gd`), conservando el nombre del material (los cosméticos recolorean por nombre). Las colisiones, áreas y lógica se crean en Godot.
- **Color de vértice (v2):** todos los GLB llevan el atributo `Col` (`COLOR_0`, exportado con `export_vertex_color="ACTIVE"`); `or_common.paint()` lo escribe y `ensure_colors()` pone blanco donde no se pinta (también antes de unir mallas, porque Blender rellena con negro). Los materiales de escenario son blancos con `vcol=True`: el color lo lleva el vértice y la mayoría de assets dibujan con 1–2 superficies.
- Para forzar la reimportación de los GLB tras cambiar el script de importación hay que borrar `.godot/imported/*.glb-*.scn` (borrar solo los `.md5` no basta).
- Imágenes de UI (icono, icono adaptativo, retrato del HUD): `tools/render_ui_images.tscn` las renderiza **en Godot** con el sombreado del juego (necesita ventana; no funciona con `--headless`). `assets_source/blender/scripts/render_ui_images.py` queda como alternativa en Blender.
- Protagonista (v2): proporciones chibi-heroicas (cabeza grande, manos y zapatillas grandes), cara modelada (ojos por capas con brillos, cejas, boca abierta con dientes y lengua, rubor), mechones curvados, gafas sobre la frente. Malla rígida pesada al 100 % por hueso (como una figura de juguete), ~16 700 triángulos; hueso `eyes` para parpadear (escala). Animaciones Idle (con parpadeo), Run, Jump, Fall, Slide, Dash, Throw (con anticipación y seguimiento), Bounce, Land (aplastamiento y rebote), Victory y Hurt.

## 6. Guardado

- Un único JSON versionado en `user://orbit_runner_save.json` (`SaveService`). Escritura atómica: archivo temporal → copia de seguridad `.bak` → renombrado. Al cargar se prueba principal → temporal → copia. `DATA_VERSION` + `_migrate()` para futuras migraciones.
- Guardado diferido (0,4 s) tras cada cambio y forzado al cerrar, pausar la app o perder el foco.

## 7. Audio

Música y efectos **originales generados por procedimiento** (`assets_source/audio/generate_audio.py`, Python + numpy): 22 efectos, 4 bucles de música (menú, islas, juguetes, ruinas) y un *jingle* de victoria. WAV mono 32 kHz. Sin muestras ni licencias de terceros. Buses: Master, Music, SFX.

## 8. Localización

Español e inglés. Por defecto el juego sigue el idioma del dispositivo (`OS.get_locale_language()`, opción "Auto (dispositivo)" en Ajustes → Juego) y, si no es un idioma soportado, usa **inglés** (`Settings.language()` y `locale/fallback="en"`). El jugador puede fijar Español o English en Ajustes. Fuente: `localization/make_strings.py` → `strings.csv` (Godot genera `strings.es/en.translation`). 211 claves. Las indicaciones con variante `_TOUCH` se muestran en pantallas táctiles.

## 9. Validación realizada

- **Carga de scripts y escenas**: los 108 scripts/escenas cargan sin errores.
- **Flujo completo en PC** (automatizado, con capturas): título → menú → ajustes → niveles → recompensas → logros → créditos → nivel → pausa → meta → resultados → desbloqueo del siguiente nivel → guardado en disco.
- **Piloto automático** (herramienta temporal, retirada del repositorio al terminar según AGENTS.md; se puede restaurar si se pide) que juega usando **solo las acciones del InputMap**: completó el tutorial y los 4 niveles del mundo 1 **sin muertes**, y en distintas ejecuciones también *Taller de Juguetes*, *Ruinas del Alba*, *Templo del Viento Solar* y *Corazón del Sol*. *Engranajes Locos* y *Fábrica de Rebotes* se recorrieron hasta sus tramos finales; el bot se atasca en el cruce de aspas giratorias (su heurística de salto sobre el brazo es tosca; para una persona el brazo, a 0,95 m, se salta con un salto normal de 2,36 m). El proceso destapó y corrigió ~15 problemas reales de diseño (ver `docs/DESIGN_DECISIONS.md`).
- **Exportación Android**: APK de depuración firmado y verificado (`apksigner`), arm64-v8a, minSdk 24, targetSdk 36, permiso único `VIBRATE`.
- **Android (emulador S23, x86_64, OpenGL ES 3.1)**: instalación, arranque, pantalla de título, menú en horizontal, toque de botones, carga de nivel, **joystick virtual moviendo al personaje**, indicación táctil del tutorial, **botón Atrás → pausa → reanudar** y archivo de guardado escrito en el almacenamiento de la app. No mide rendimiento real (emulador).

## 10. Exportación

- Android (arm64-v8a): `--export-debug "Android" build/android/orbit_runner_debug.apk` (firmado con el keystore de depuración configurado en los ajustes del editor).
- Android emulador (x86_64, solo pruebas): preset "Android Emulator (x86_64, solo pruebas)".
- Windows: preset "Windows Desktop" (`build/windows/OrbitRunner.exe`).
- **Compilación con Gradle (desde 2026-10-18)**: activada en los presets de Android para incluir el plugin propio de notificaciones (`addons/orbit_notifications/`, fuente en `android/plugins/orbit_notifications/`).
  - La plantilla de compilación está en `android/build/` y no se versiona. En un clon nuevo se instala descomprimiendo `%APPDATA%\Godot\export_templates\4.7.2.stable\android_source.zip` en `android/build/` y escribiendo la versión en `android/.build_version` (o desde el editor: Proyecto → Instalar plantilla de compilación Android).
  - Gradle descarga sus dependencias oficiales (Gradle 8.11.1, Android Gradle Plugin 8.6.1) la primera vez; requiere el JDK 17 configurado en el editor.
  - `addons/*` y `android/*` están excluidos del paquete del juego.
- **Recursos de texto sin convertir** (`editor/export/convert_text_resources_to_binary=false`, 2026-10-18): la conversión de Godot 4.7.2 de `.tres` a binario al exportar vaciaba `world_title_keys` del catálogo de niveles. En el teléfono solo se veía un mundo en la selección de niveles y la pantalla Desafíos fallaba. Los `.tres` se empaquetan tal cual.
- **AAB / publicación** (pendiente, requiere decisiones del propietario):
  - crear un keystore de publicación propio, sin versionarlo (Godot guarda las credenciales en `.godot/export_credentials.cfg`, ignorado por git);
  - cambiar `package/unique_name` (`com.orbitrunner.game` es provisional);
  - exportar con formato AAB.

## 11. Estructura del proyecto

```text
orbit_runner_game/
  project.godot, export_presets.cfg
  scenes/   player/  levels/  props/  props/platforms/  ui/
  scripts/  autoload/  player/  level/  props/  ui/  data/  tools/
  resources/  levels/  biomes/  cosmetics/  achievements/  player/  ui/  shaders/
  art/  models/ (GLB)  ui/ (icono, retrato)
  audio/  music/  sfx/  default_bus_layout.tres
  localization/
  scripts/generator/  generador de niveles (spec, perfiles, alcances, motivos, validador, diario)
  scripts/replay/     repeticiones y fantasma        scripts/progress/  misiones
  scripts/services/   interfaces y proveedores simulados (anuncios, tienda, cuenta, amigos, avisos, reloj)
  scripts/economy/    energía y catálogo              scripts/season/    temporadas, rivales, ranking
  resources/economy/  economy_config.tres             resources/seasons/ season_schedule.tres
  addons/orbit_notifications/  exportación del plugin Android (AAR)
  android/plugins/    fuente de plugins Android (android/build/ = plantilla Gradle, no versionada)
  resources/generator/  difficulty_profiles.tres, daily_seeds.tres
  tools/          generadores (build_data, build_prop_scenes, build_levels, generate_levels) y bot/ (no se exportan)
  assets_source/  blender/ (.blend + scripts)  audio/ (generador)   [.gdignore]
  docs/
```

Diferencias respecto a la guía: `art/materials` y `art/textures` no se usan (materiales planos dentro de los GLB + color de vértice; sin texturas). `scripts/tools/` contiene el script de importación del editor y `scripts/rendering/` la utilidad de materiales toon.

## 12. Limitaciones conocidas

- Sin validación en el S25: rendimiento, *frame pacing*, temperatura y tacto de los controles están pendientes de prueba real.
- Paquete Android y firma de publicación provisionales (ver §10).
- Fuente: se usa la fuente por defecto de Godot.
- Anuncios, compras, login, amigos y rankings son simulados (2026-10-18). La energía y las temporadas usan el reloj del teléfono hasta tener hora del servidor.
- Las sombras dinámicas se limitan a 30–45 m; los objetos lejanos usan la sombra circular del jugador como referencia de aterrizaje.
