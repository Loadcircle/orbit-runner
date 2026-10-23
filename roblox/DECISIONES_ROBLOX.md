# Registro de decisiones — Orbit Runner en Roblox

Decisiones del port a Roblox (rama `feature/roblox`). Cada entrada: decisión, motivo e impacto, como en `orbit_runner_game/docs/DESIGN_DECISIONS.md`. La guía de referencia es [`GUIA_DESARROLLO_ROBLOX.md`](GUIA_DESARROLLO_ROBLOX.md).

---

## Decisiones de partida (copiadas de la guía, §1)

| # | Decisión | Detalle |
|---|---|---|
| R-A | **Avatar del jugador + yo-yo propio** | Se juega con el avatar R15 del jugador. El controlador y las animaciones son nuestros. El yo-yo y el disco son modelos nuestros (`PROP_Yoyo`, `PROP_YoyoDisc`). `CHR_Adventurer` **no** se migra. |
| R-B | **Sin energía; monetización con Robux** | Se elimina el sistema de energía y sus anuncios. Developer Products, Game Passes y Premium Payouts. Se conservan Chispas, gemas, medallas, maestría de 4 estrellas, misiones, logros y temporadas. |
| R-C | **Niveles: Godot como compilador + JSON** | El generador y el bot de Godot producen y validan los niveles; un exportador los escribe en JSON y un `LevelBuilder` en Luau los construye. La Torre infinita se reevalúa en la Fase 2. |
| R-D | **Hub compartido, niveles en solitario** | Lobby compartido; en un nivel cada jugador juega solo y ve a los demás como fantasmas sin colisión. Los modos competitivos se reevalúan en la Fase 4. |
| R-E | **Lo que Roblox ya resuelve se elimina** | AgeGate, ParentalGate, login simulado, nombres de lista segura y rivales simulados desaparecen. |

---

## R1. Rojo para sincronizar el código
- **Decisión:** el código Luau vive en `roblox/src/` y se sincroniza con Studio mediante **Rojo 7.7.1** (`roblox/tools/rojo.exe`, descargado de GitHub `rojo-rbx/rojo` v7.7.1, ignorado en git; SHA-256 `e73e9566…cf6d3`). El plugin se instaló con `rojo plugin install` (`%LOCALAPPDATA%\Roblox\Plugins\RojoManagedPlugin.rbxm`).
- **Regla:** los scripts se editan en el repo, **no en Studio**. El MCP de Studio se usa para inspeccionar, probar en *Play*, leer la salida y construir/probar mapas.
- **Proyecto:** `roblox/default.project.json`.

  | Repo | Studio |
  |---|---|
  | `src/shared/` | `ReplicatedStorage/Shared` |
  | `src/server/Services/` | `ServerScriptService/Services` |
  | `src/entry/ServerMain.server.luau` | `ServerScriptService/ServerMain` (Script) |
  | `src/client/` | `StarterPlayer/StarterPlayerScripts/Client` |
  | `src/entry/ClientMain.client.luau` | `StarterPlayer/StarterPlayerScripts/ClientMain` (LocalScript) |

  Los puntos de entrada están fuera de las carpetas de módulos para que `Shared`, `Services` y `Client` solo contengan ModuleScripts.
- **Uso:** `roblox/tools/rojo.exe serve roblox/default.project.json` y *Connect* en el plugin de Rojo en Studio. Rojo no borra lo que no gestiona (Baseplate, mapas hechos en Studio).
- **Motivo:** diffs, historial, vuelta atrás y revisión del código, igual que en Godot.
- **Impacto:** si alguien edita un script en Studio, el cambio se pierde en la siguiente sincronización.

## R2. Animaciones provisionales
- **Decisión:** en la Fase 1 se usan las animaciones R15 por defecto de Roblox (Idle, Run, Jump, Fall, Land) con retoques procedurales: inclinación en el dash, agachado al deslizar y giro de brazo al lanzar. Se dejará una lista de poses y duraciones para producir las propias.
- **Motivo:** decidido por el dueño (cierra P2 para la Fase 1); no bloquea la calibración de la sensación.
- **Impacto:** la animación queda desacoplada en `Client/AnimationDriver`, de modo que las propias sustituyen a las provisionales sin tocar el controlador.

## R3. Controles y cámara por defecto de Roblox desactivados (H0)
- **Decisión:** `StarterPlayer` fija `EnableMouseLockOption = false` (Shift queda libre para *Acción*), `DevComputerMovementMode = Scriptable` y `DevTouchMovementMode = Scriptable` (oculta el joystick y el botón de salto de Roblox). `ClientMain` además apaga el `ControlModule` para cubrir también el mando. En esta versión de Studio el `PlayerModule` ya no se copia a `PlayerScripts`: vive en `StarterPlayer.PlayerModule` y su API pública es `ControlModule.Enabled = false` (bandera `UserControlModuleEnabledAPI`). `ClientMain` usa esa API y recurre a `GetControls():Disable()` si encuentra el módulo antiguo. La cámara por defecto se sustituye en H5, cuando `FollowCamera` ponga `CameraType = Scriptable`; no se bifurca el `PlayerModule`.
- **Motivo:** guía §2.4. Los controles propios (`InputRouter`, `TouchControls`) son la única entrada de gameplay.
- **Impacto:** hasta H2 el personaje no se puede mover en *Play*. Esc sigue abriendo el menú de Roblox; la pausa principal en PC será P.
- **Evidencia (2026-10-22, Play Solo vía MCP):** Rojo sincronizó `Shared`, `Services`, `ServerMain`, `Client` y `ClientMain`, y aplicó las propiedades de `StarterPlayer`. Con W pulsada 1 s y Espacio, el avatar R15 se desplazó 0,00 studs y no saltó. Las teclas llegaron al juego (`UserInputService` las registró). No aparece `TouchGui`. La salida muestra los dos mensajes de arranque y ningún error propio. El aviso `rbxassetid://203785492 … Asset type does not match` no viene de nuestro código.

## R4. Controlador del personaje sobre `ControllerManager` (cierra P1)
- **Decisión (dueño, 2026-10-22):** el `Humanoid` se queda para el avatar, la apariencia y la replicación, con `EvaluateStateMachine = false`. El movimiento usa el controlador físico nativo: un `ControllerManager` con `GroundController` y `AirController`, más un `ControllerPartSensor` para el suelo (`Client/PlayerController/CharacterRig`). La lógica es un port de `player.gd` (`Client/PlayerController`):
  - **En suelo:** el `GroundController` acelera y frena con los tiempos de Godot: 38 m/s² al acelerar, 48 al frenar y 70 al invertir el sentido. Se calcula `AccelerationTime = velocidad / aceleración × 0.915` (calibración medida: el controlador tarda un 9 % más por la fricción).
  - **En el aire:** la velocidad horizontal se integra con el `move_toward` de Godot y se escribe en la física; el `AirController` solo mantiene el equilibrio y la orientación. La gravedad asimétrica (28 al subir / 45 al bajar) la aplica un `VectorForce` que sustituye la de `workspace.Gravity`.
  - **K = 3.5 studs/m** se mantiene: no hizo falta reajustarla.
- **Referencia de 60 Hz:** Godot simula a 60 ticks fijos. Tres detalles se ajustan a esa referencia para no depender del framerate:
  - el dash dura 10 ticks (0,167 s) y se mezcla en el fotograma en que termina;
  - el disco se despliega en el fotograma más cercano a 9 ticks (0,15 s);
  - los rebotes al caer se compensan según lo que dura el fotograma (`v² + 2·g·Δy`).
- **Orden de cada fotograma** (`LevelRuntime.step`, igual que en Godot): reloj → estado del jugador → props y activadores → lógica del jugador → yo-yo → caída. Una fuerza externa aplicada después del jugador (el rebote del yo-yo) queda pendiente y se escribe al empezar el fotograma siguiente.
- **Evidencia:** laboratorio de mecánicas, batería automática (`Dev/Calibration`), comparada con `MovementReach` de Godot (`tools/_reach_test.gd`, 60 Hz). Hueco plano en metros (incluye el radio de cápsula) / altura máxima:

  | Técnica | Godot | Roblox 60 FPS | Roblox 30 FPS* |
  |---|---|---|---|
  | Salto | 6.13 / 2.27 | 6.13 (0.0 %) / 2.27 | 6.18 (+0.8 %) / 2.27 |
  | Salto largo | 7.80 / 1.53 | 7.81 (+0.1 %) / 1.53 | 7.84 (+0.5 %) / 1.58 (+3.3 %) |
  | Salto + dash | 9.34 / 2.51 | 9.45 (+1.2 %) / 2.51 | 9.81 (**+5.0 %**) / 2.46 (−2.0 %) |
  | Salto + disco | 14.15 / 5.80 | 13.77 (−2.7 %) / 5.85 (+0.9 %) | 14.13 (−0.1 %) / 5.79 (−0.2 %) |
  | Disco en suelo | 8.44 / 4.44 | 8.58 (+1.7 %) / 4.44 | 8.76 (+3.8 %) / 4.44 |
  | Trampolín 20 | 10.46 / 6.98 | 10.46 / 6.98 | 10.51 (+0.5 %) / 6.98 |
  | Trampolín 24 | 12.53 / 10.09 | 12.53 / 10.09 | 12.53 / 10.08 |

  \* Los 30 FPS se simulan con una espera activa en `RenderStepped`. Studio limita a 60 FPS y no deja cambiarlo por script, así que **120+ FPS queda por medir en el S25** con el botón "Medir alcances" del laboratorio, que muestra la misma tabla en pantalla. A 30 FPS el dash queda en el límite (+5.0 %) por la latencia de un fotograma entre la pulsación y el dash.

  Salto completo: 2.27 m de altura, igual que Godot. Con integración continua serían 2.36 m; Godot da 2.27 m porque integra en ticks de 60 Hz. El tiempo en el aire es de 0.70 s (Godot: 0.73 s).
- **Pruebas una a una (Play Solo vía MCP, entrada programada):**
  - Salto variable: un toque de 2 fotogramas sube 0.76 m.
  - Coyote: se salta 0.05 s después de salir del borde y no 0.20 s después.
  - Buffer: pulsar 0.05 s antes de aterrizar salta; 0.25 s antes, no.
  - Láser fijo: de pie muere; deslizando pasa sin morir.
  - Salto largo: 12.50 m/s en horizontal.
  - Dash: solo uno por vuelo; se recarga al aterrizar.
  - Yo-yo: una carga aérea; el disco dura 1.50 s y parpadea al final; regresa en 0.30 s; el despliegue bajo los pies al caer rebota a 16 m/s; el trampolín devuelve la carga.

## R5. `InputRouter` sobre el Input Action System
- **Decisión (dueño):** `InputContext` "Gameplay" con las acciones `move`, `camera`, `jump`, `yoyo`, `action` y `pause`, cada una con sus `InputBinding` de teclado y mando (las teclas de `project.godot`). Los botones táctiles son `InputBinding.UIButton`; el joystick hace `Fire()` de `move`. La zona muerta circular con reescalado (0.2) es la de `Input.get_vector`.
- **Motivo:** es el sistema nativo actual; el propio `PlayerModule` de Roblox ya lo usa.
- **Evidencia:** WASD, Espacio, Mayús y E funcionan en las pruebas. El botón táctil de salto, pulsado con el ratón, produce un salto de 11.5 m/s.

## R6. Animaciones provisionales (desarrollo de R2)
- **Implementación:** `AnimationDriver` carga las animaciones `idle`, `run`, `jump` y `fall` del script `Animate` del avatar y apaga ese script. Elige la animación con los mismos umbrales que `player_visual.gd`: carrera desde 0.6 m/s, salto con vy > 0.5 m/s y ritmo de carrera ×1.15. Los retoques son procedurales sobre los `C0`: agachado y echado atrás al deslizar, inclinación en el dash, brazo al lanzar y compresión al aterrizar.
- **Lista para las animaciones propias** (las mismas acciones que `build_character.py`, a 30 fps): Idle 3 s (bucle), Run 0.53 s (bucle), Jump 0.37 s, Fall 0.53 s (bucle), Slide 0.33 s (bucle), Dash 0.2 s (bucle), Throw 0.5 s, Bounce 0.33 s (bucle), Land 0.3 s, Victory ≥ 0.8 s (bucle) y Hurt 0.43 s. Basta con añadirlas a `DEFAULT_SLOTS`; el controlador no cambia.

## R7. Textos en una `LocalizationTable` dentro de `ReplicatedStorage.Localization`
- **Decisión:** `roblox/scripts/build_localization.py` genera `localization/GameStrings.csv` a partir de `orbit_runner_game/localization/strings.csv` (Source = inglés, columna `es`, `%d` → `{1}`), con correcciones propias de Roblox (la pausa es P). Rojo la crea como `LocalizationTable`. `Client/Strings` la lee con `GetTranslator(RobloxLocaleId)`. La UI se crea desde código con `AutoLocalize = false`.
- **Motivo:** `GetTranslatorForPlayerAsync` exige el juego publicado. Además, Rojo no sincroniza en vivo los servicios que se añaden al proyecto con la sesión ya conectada (`LocalizationService`).
- **Impacto:** si en la Fase 3 se usa la traducción automática de Roblox, la tabla se mueve a `LocalizationService`; el código no cambia.

## R8. Vestíbulo propio en lugar del Baseplate de la plantilla
- **Decisión:** `world/Lobby.model.json` (Rojo) crea `Workspace.Lobby`, con suelo y `LobbySpawn` en z = +300 studs, lejos de los niveles. Se quitaron del lugar el `Baseplate` y el `SpawnLocation` de la plantilla.
- **Motivo:** el Baseplate estaba a la altura 0 de los niveles: atravesaba las plataformas y frenaba las caídas.
- **Impacto:** al salir de un nivel se vuelve al vestíbulo. El hub real es de la Fase 4.

## R9. Exportador JSON adelantado de la Fase 2
- **Decisión:** se añadió `orbit_runner_game/tools/export_level_json.gd` y su `.tscn`, que es el único cambio en el juego de Godot y solo añade una herramienta. El tutorial y `w1_l1` se construyen desde `roblox/levels_json/*.json`, con el esquema de `levels_json/SCHEMA.md`, en lugar de transcribirlos a mano.
- **Motivo:** la guía (§3.9) lo permite y da exactitud: chispas, zonas de cámara, indicaciones y medallas salen tal cual de las escenas.
- **Evidencia:** el tutorial tiene 11 plataformas, 44 chispas, 3 checkpoints y 10 indicaciones; `w1_l1` tiene 19 plataformas, 43 chispas, 2 checkpoints y 19 zonas de cámara. Indicaciones y zonas de cámara probadas (la zona de 90° gira la cámara a 90°).

## R10. Assets: `EditableMesh` desde Blender, color por vértice (cierra P3)
- **Exportación:** `assets_source/scripts/export_for_roblox.py` usa Blender 5.2.2 en segundo plano y abre los `.blend` solo en lectura. Para cada asset:
  - quita los contornos de casco invertido;
  - aplica los modificadores;
  - convierte los ejes como el exportador glTF y escala ×K;
  - guarda el color por esquina en sRGB y las normales por esquina;
  - separa las piezas animadas (Pad, Arm, Flag, Halo, Rotor, Tile_*).

  Exporta los 23 assets de la Fase 1 (Isles, plataformas especiales, props, peligros, yo-yo y disco, gema, chispa, árbol y pino). Todos quedan por debajo de 20 000 triángulos por pieza.
- **P3, color por vértice:** sí. Una malla creada en Studio con `EditableMesh` (la gema) muestra su color por vértice y el sombreado plano correctos, y el importador 3D también lo admite. No hace falta hornear texturas.
- **Subida (hecha el 2026-10-23):** el lugar está publicado como privado (experiencia "Orbit Runner (Test)", PlaceId 103224184916710). `AssetService:CreateAssetAsync` es aún una **función beta de Studio**: hay que activarla en *File → Beta Features* ("Lua Asset Creation"). Sin ella responde *"not available yet"* incluso en un lugar publicado. Con la beta activada, el plugin local `studio_tools/OrbitRunnerAssetUploader.lua` subió las 23 mallas (51 piezas) sin errores. Los IDs están en `Shared/AssetIds.meshes`. El plugin guarda el resultado en `ServerStorage.UploadResult`, porque Rojo borra lo que no está en disco dentro de `MeshData`.
- **Prefabs:** `studio_tools/build_prefabs.luau` lee `Shared/AssetIds` y monta los 23 modelos en `ReplicatedStorage.Assets` por tandas; el atributo `BuildStatus` indica el progreso. Viven en el lugar y no en Rojo: hay que **guardar o publicar** el lugar tras montarlos. En Play, `w1_l1` usa 12 de ellos (islas, gemas, chispas, trampolines, checkpoints, meta y decoración) sin errores.
- **En juego:** `LevelRuntime/AssetLibrary` hace que props, plataformas, decoración y yo-yo usen el prefab si existe; si no, usan formas nativas provisionales. Las colisiones siempre son `Part`s invisibles aparte, como pide §2.5. Los grupos emisivos con color casi uniforme pasan a material Neon.
- **Temporal:** `ServerScriptService.MeshData`, unos 2.8 MB de datos solo de servidor, sigue en el proyecto porque `build_prefabs` y nuevas subidas lo necesitan. No se replica a los clientes. Se quitará cuando el arte de la Fase 1 quede cerrado.

## R11. Escala de avatar fija con `HumanoidDescription`
- **Decisión:** `Services/AvatarService` aplica en el servidor las escalas estándar R15 (altura, anchura, profundidad y cabeza a 1; tipo de cuerpo y proporción a 0) al cargar la apariencia. `CharacterRig` se reajusta si cambia `HipHeight`.
- **Motivo:** las Avatar Settings no se pueden fijar por script y el lugar aún no está publicado; así el ajuste además vive en el código. La cápsula de juego ya era propia.
- **Evidencia:** escalas aplicadas (1, 1, 1, 1, 0, 0) y `HipHeight` = 2.0. El salto sigue en 6.17 m.

## R12. Servidor: validación y progreso en memoria
- **Decisión:**
  - `Shared/Net` contiene `RemoteEvent`s y `RemoteFunction`s declarados en `.model.json`.
  - `Services/RunValidator` comprueba el orden de checkpoints, el tiempo ≥ 0.6 × oro, que el tiempo del cliente no supere el real del servidor más 2 s, que las chispas no pasen del total, las gemas notificadas y un máximo de 20 eventos/s.
  - `Services/ProgressService` es un port de `submit_run` y `mastery`: récord, medalla, gemas, chispas y estrellas acumulativas. Todo en memoria (la persistencia es de la Fase 3). El laboratorio no se registra.
- **Evidencia:**
  - Teletransportarse a la meta en 1.02 s se rechaza (`too_fast`); la pantalla lo indica y el servidor lo anota en la salida.
  - Un intento plausible de 17.87 s con los checkpoints en orden se acepta: oro, nuevo récord, estrella de oro, +6 chispas y "Resultado registrado".

## R13. Limitaciones conocidas de la Fase 1
- **Audio:** no se ha subido. `Shared/AssetIds.sounds` está vacío y `Sfx` no reproduce nada. La subida va con la de las mallas.
- **Vibración:** `HapticService` solo vibra en mando. En móvil queda pendiente comprobar el soporte en el S25.
- **Sin probar todavía:**
  - joystick táctil con toques reales (se necesita emulador o teléfono; el MCP solo simula ratón y teclado);
  - servidor con 2 jugadores (el MCP solo arranca Play Solo);
  - 120+ FPS;
  - rendimiento en teléfono.
- **Rendimiento en Studio (PC):** 60 FPS de media en el laboratorio (785 piezas) y en `w1_l1`. El peor fotograma (43.8 ms) se da al cargar el nivel. No se afirma nada sobre teléfonos sin probar.

## R14. Cambio de base: plantilla Platformer de Roblox (2026-10-23, sustituye a R2–R6 y R8)
- **Motivo:** el dueño probó el port y lo calificó de "muy mal" al jugarlo. La plantilla oficial **Platformer** de Roblox se sentía mucho mejor. Decisión del dueño: usar la plantilla como base, con **todas** las mecánicas (las suyas y las nuestras) y sus assets. Se acepta reajustar los niveles después.
- **Qué aporta la plantilla:** vive en el lugar, no en Rojo; el código de la plantilla no se ha modificado.
  - `ReplicatedStorage.Platformer`: `ControlScript`, `Controller`, `Actions` (salto, doble salto, dash, rodar, salto largo, aturdido), animaciones, efectos, sonidos y la cámara suavizada `SmoothCameraScript`.
  - `ReplicatedStorage.Utility.ActionManager` y `Gameplay`: monedas, plataformas móviles y de un solo sentido.
  - El escenario, la iluminación y el audio.
  - El movimiento es el **Humanoid nativo**, con cámara Classic y joystick y botón de salto táctiles nativos.
- **Qué se queda de nuestro port, adaptado:**
  - `Client/Character` sustituye a `PlayerController`, `CharacterRig` y `AnimationDriver`. Es un adaptador sobre el Humanoid con la misma interfaz que usan la sesión, los props y el yo-yo.
  - Comportamiento del adaptador:
    - los rebotes y el viento convierten la velocidad de Godot para alcanzar la misma altura con la gravedad de Roblox (160);
    - los boost pads usan `LinearVelocity`, como el rodar;
    - **rodar** hace de deslizamiento: baja la cápsula para pasar bajo los láseres;
    - lanza el yo-yo.
  - `Client/CameraRig` sustituye a `FollowCamera`: cámara nativa, más la orientación al reaparecer y la sacudida.
  - `InputRouter` queda solo para el yo-yo (con el `ActionManager` de la plantilla: E, Y del mando o botón táctil) y la pausa (P o Start).
  - Se eliminan `TouchControls`, `LabPanel` y `Dev/Calibration`, que dependían del controlador viejo.
- **Escenario:** el de la plantilla hace de vestíbulo, desplazado +3000 studs en Z para no pisar los niveles, que se construyen en el origen. El vestíbulo propio de R8 se retira.
- **Proyecto:** `StarterPlayer` vuelve a `UserChoice` y fija los valores de la plantilla (WalkSpeed 22, JumpHeight 8, `UseJumpPower` desactivado). `Workspace.Gravity` = 160.
- **Alcances (Play Solo, 2026-10-23):**
  - Salto: unos 8 studs de altura. Doble salto: unos 14 studs sobre el suelo. Dash en el aire: unos 25 studs.
  - Rebote del yo-yo: unos 16 studs (≈ 4,5 m, como en Godot).
  - El salto simple es más corto que en Godot (unos 14 studs frente a 21,5), así que los huecos de los niveles se salvan con el doble salto. **Pendiente:** recalibrar los niveles con el dueño.
- **Lugar:** Place1, la plantilla con Rojo sincronizado, pasa a ser el lugar del juego. Hay que publicarla sobre "Orbit Runner (Test)". Los prefabs de mallas se volvieron a montar en ella.

## R15. Aspecto de los niveles con los assets de la plantilla (2026-10-23, sustituye a R10 en juego)
- **Motivo:** el dueño vio mal los niveles con las mallas de Blender. Las mallas no coincidían con sus colisiones: el jugador flotaba sobre las islas y el trampolín salía gigante y desplazado. Pidió usar los assets propios de Roblox y traer de lo nuestro solo lo que no exista allí.
- **Plataformas:** la propia caja de colisión es el bloque visible, como en la plantilla. Lleva el material de muro (`Concrete_Template_Walls`) con el color del bioma y una losa superior con el material de suelo (`Concrete_Template_Floors`). Lo que se ve es lo que se pisa.
  - isles: blanco y menta;
  - toyworks: blanco y naranja;
  - ruins: crema y lavanda.
- **Assets de la plantilla:** se copiaron en el lugar a `ReplicatedStorage.TemplateAssets`, porque los originales están en `ServerStorage` y el cliente no los ve.
  - `LevelRuntime/AssetLibrary` traduce los nombres de los niveles a esos assets, con su encaje:
    - `PLAT_Moving` → plataforma móvil de la plantilla;
    - `PLAT_Timed` → plataforma de un solo sentido;
    - `PROP_Spark` → moneda;
    - `ENV_Tree`, `ENV_Pine`, `ENV_Bush`, `ENV_Rock_*` y `ENV_LampPost` → helechos, hostas, rocas y columna.
  - Los assets se encajan así:
    - las plataformas se estiran en X/Z con la cara de arriba en el origen;
    - la decoración se escala con la base en el origen;
    - se quitan las luces de cada pieza.
- **Lo que no existe en Roblox** se queda con nuestras formas nativas: trampolín, impulsor, viento, plataforma que se rompe, peligros, checkpoint, meta, gemas y yo-yo.
- **Mallas de Blender retiradas del juego:** se borran `ReplicatedStorage.Assets` del lugar y `ServerScriptService.MeshData` del proyecto. Los IDs subidos siguen en `Shared/AssetIds` y las herramientas siguen en `studio_tools/`, por si se recuperan.
- **HUD:** el contorno del mensaje "¡Punto de control!" ya se desvanece con el texto; antes se quedaba visible. El mensaje baja para no tapar el panel de indicaciones.

## R16 — Gesto del yo-yo, sonidos y props con el estilo de la plantilla (2026-10-23)
- **Rodar bajo el láser:** se queda como está. Usa la animación Roll de la plantilla y el dueño le dio el visto bueno.
- **Gesto de lanzar el yo-yo:** se usa la animación nativa `toolslash` del `Animate` estándar de Roblox (`rbxassetid://522635514`), con prioridad Action2 y a velocidad ×1.6. Si el avatar trae otro paquete de animaciones, se usa su `toolslash`. Es un asset de Roblox, así que se replica a los demás jugadores sin subir nada.
- **Sonidos:** `client/Sfx.luau` clona los `AudioPlayer` de la plantilla (`Platformer.Sounds` y `Gameplay.Sounds`), con un tono propio por evento, y los enruta al bus "UI" de `SoundService.Audio`. Así suenan chispas, gemas, checkpoint, meta, muerte, impulsor, trampolín, plataforma que se rompe y el yo-yo. `AssetIds.sounds` queda sin uso.
- **Props propios:** `PartFactory` usa por defecto Plastic con la variante `Concrete_Template_Walls`. Las piezas con material explícito no cambian: Neon para impulso y peligro, ForceField para el viento y Metal para la meta.
- **Calibración de niveles: no hace falta para poder completarlos.**
  - El salto simple de la plantilla alcanza 8 studs (2.29 m), igual que Godot (2.36 m), y llega a unos 4 m frente a los 5.9 m de Godot.
  - Los huecos de `w1_l1` miden 3.5 m como máximo, y el doble salto (~7.7 m), el dash y el salto largo (~10 m) cubren los del tutorial.
  - Con la plantilla, los niveles quedan algo más fáciles. Si se quiere la distancia de Godot sin tocar los niveles, se puede usar Gravity 118 y WalkSpeed 28, aunque se siente más flotante. La decisión queda para el dueño.

## Estado de la lista de aceptación (§3.9) a 2026-10-22
- [x] Salto completo: 2.27 m (= Godot a 60 Hz), 0.70 s, a 60 FPS. A 30 FPS: 2.27 m. 120+ FPS pendiente (S25).
- [x] Tabla de alcances a ±5 % a 60 FPS. A 30 FPS todo dentro salvo el dash, en el límite (+5.0 %). Ver R4.
- [x] Coyote, buffer, salto variable, deslizar bajo el láser, salto largo, dash único y recarga al aterrizar.
- [x] Yo-yo: subida en suelo (altura 4.44 m = Godot), lanzamiento aéreo, despliegue al caer rápido, vida de 1.5 s con parpadeo, regreso, una carga aérea. El atenuado del botón está implementado (`TouchControls.update`) pero falta verlo en el teléfono.
- [x] Props y peligros con sus valores:
  - boost a 17 m/s;
  - viento de 8 m (sube hasta 9.8 m y recupera el dash);
  - plataforma móvil que arrastra 6 m;
  - temporizadas en ola 0 / 0.3 / 0.6 con ciclo de 3.6 s;
  - desmoronable que cae y se reconstruye;
  - pinchos, spinner y patrulla que matan;
  - reloj común que sigue tras morir.
- [x] Cámara: zonas, anticipación, anti-oclusión (`Raycast` del brazo), ajuste manual y salto a la yaw del checkpoint.
- [x] Flujo completo: inicio → muertes y reapariciones → meta → resultados con medalla, gemas, chispas y estrellas. El servidor registra o rechaza.
- [ ] Controles táctiles en emulador y en un teléfono real; teclado listo; mando sin probar en físico.
- [ ] Rendimiento en el teléfono.
- [ ] Visto bueno del dueño a la sensación.
- [ ] Mallas migradas en el juego (bloqueado por la publicación del lugar).
