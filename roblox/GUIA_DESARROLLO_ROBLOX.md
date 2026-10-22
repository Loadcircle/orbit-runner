# Orbit Runner en Roblox: guía de desarrollo

> Documento guía para recrear **Orbit Runner** en Roblox con mecánicas, servicios y recursos nativos de la plataforma.
> Lo ejecutará un **agente con el MCP de Roblox Studio** que tiene acceso a este repositorio.
> Redactado el 2026-10-22 a partir de la rama `feature/freemium-temporadas` (Godot 4.7.2).

---

## 0. Cómo usar esta guía (léelo primero, agente)

### 0.1 Fuente de verdad
El juego de Godot en `orbit_runner_game/` es la **referencia funcional**. Esta guía resume valores y decisiones; si algo no coincide con el código, **manda el código de Godot**. En ese caso anota la diferencia en el registro de decisiones de Roblox (§0.4).

| Tema | Archivo de referencia (rutas relativas a la raíz del repo) |
|---|---|
| Identidad y pilares | `Orbit_Runner_Guia_de_Desarrollo/GUIA_MAESTRA_ORBIT_RUNNER.md` |
| Decisiones de diseño D1–D20 | `orbit_runner_game/docs/DESIGN_DECISIONS.md` |
| Diseño de niveles y alcances | `orbit_runner_game/docs/LEVEL_DESIGN.md` |
| Generador, bot, diarios, temporadas, economía | `orbit_runner_game/docs/LIVE_SERVICE.md` |
| Decisiones técnicas de Godot | `orbit_runner_game/docs/TECHNICAL_DECISIONS.md` |
| Estado general | `ESTADO_DEL_PROYECTO.md` |
| Movimiento (valores) | `orbit_runner_game/scripts/data/movement_tuning.gd` |
| Controlador | `orbit_runner_game/scripts/player/player.gd` |
| Yo-yo cinético | `orbit_runner_game/scripts/player/kinetic_yoyo.gd` |
| Cámara | `orbit_runner_game/scripts/player/follow_camera.gd`, `scripts/props/camera_zone.gd` |
| Controles táctiles | `orbit_runner_game/scripts/ui/touch_controls.gd` |
| Props y peligros | `orbit_runner_game/scripts/props/*.gd` |
| Flujo de nivel, medallas | `orbit_runner_game/scripts/level/level.gd`, `scripts/autoload/progress.gd` |
| Constructor de niveles (DSL) | `orbit_runner_game/scripts/level/level_builder.gd` |
| Generador | `orbit_runner_game/scripts/generator/*.gd` |
| Bot validador | `orbit_runner_game/tools/bot/*.gd` |
| Campaña | `orbit_runner_game/tools/build_levels.gd`, `tools/campaign_plan.gd`, `tools/campaign_generated.json`, `resources/levels/level_catalog.tres` |
| Cosméticos | `orbit_runner_game/resources/cosmetics/cosmetic_catalog.tres` |
| Economía freemium (referencia) | `orbit_runner_game/resources/economy/economy_config.tres` |
| Temporadas | `orbit_runner_game/scripts/season/*.gd`, `resources/seasons/season_schedule.tres` |
| Misiones | `orbit_runner_game/scripts/progress/mission_board.gd` |
| Guardado | `orbit_runner_game/scripts/autoload/save_service.gd` |
| Textos (ES/EN) | `orbit_runner_game/localization/strings.csv` |
| Fuentes 3D | `orbit_runner_game/assets_source/blender/*.blend`, `assets_source/blender/scripts/*.py`, `art/models/*.glb` |
| Audio propio | `orbit_runner_game/audio/music`, `audio/sfx` |

### 0.2 Reglas que no se rompen
- **El movimiento es el centro.** El jugador avanza manualmente. **No hay auto-run.**
- **El yo-yo es una herramienta de locomoción**, nunca un arma. No hay combate en el modo base.
- **Morir no penaliza:** no hay vidas ni game over. Se reaparece en el último checkpoint y el cronómetro sigue corriendo.
- La función de cada superficie (suelo seguro, impulso, temporal, peligro) se comunica con **forma, animación y contraste**, no solo con color.
- **No toques `orbit_runner_game/`** salvo para añadir herramientas de exportación (Fase 2). Los arreglos de assets para Roblox se hacen sobre **copias** en `roblox/`, nunca sobre los `.blend`, GLB o scripts del juego.
- No introduzcas paquetes, plugins ni modelos de terceros (Toolbox incluido) sin autorización del dueño.

### 0.3 Trabajo con el MCP de Roblox
1. Al empezar cada sesión, **inspecciona qué herramientas del MCP de Roblox Studio están disponibles** y qué permiten. No supongas que Studio está abierto ni que hay un lugar publicado.
2. Si una operación no se puede hacer con el MCP (subir assets, crear productos de Robux, publicar), **dilo claramente** y deja instrucciones manuales al dueño. No inventes IDs de assets ni de productos.
3. Trabaja en cambios pequeños y verificables. Al final de cada sesión informa qué cambió, qué se comprobó (en Play Solo, en el emulador de dispositivos o en un servidor de prueba) y qué queda pendiente.
4. Comprobación en Studio: usa *Play* para lo de un jugador y *Start Server + 2 Players* (Test → Clients and Servers) para la replicación. Usa el *Device Emulator* para móvil y no afirmes que funciona en un teléfono sin haberlo probado en uno real.

### 0.4 Organización en el repo
```text
roblox/
  GUIA_DESARROLLO_ROBLOX.md     # este documento
  DECISIONES_ROBLOX.md          # registro de decisiones (crear en Fase 1)
  src/                          # código Luau versionado (ver §2.2)
  assets_source/                # copias de .blend/GLB preparadas para Roblox + scripts de exportación
  levels_json/                  # niveles exportados desde Godot (Fase 2)
  OrbitRunner.rbxl              # lugar de Studio (o .rbxlx), si se guarda en el repo
```
- **Código como texto:** guarda los scripts Luau en `roblox/src/` con la misma jerarquía que en Studio, para que haya diff y revisión. Si el MCP solo escribe dentro de Studio, exporta o sincroniza los scripts a `roblox/src/` al cerrar cada tarea. Si después se quiere Rojo, se propone antes al dueño.
- Registra cada decisión en `roblox/DECISIONES_ROBLOX.md` (formato: R1, R2…; decisión, motivo, impacto), igual que `DESIGN_DECISIONS.md`.

---

## 1. Decisiones ya tomadas para la versión Roblox

| # | Decisión | Detalle |
|---|---|---|
| R-A | **Avatar del jugador + yo-yo propio** | Se juega con el avatar R15 del jugador. El controlador y las animaciones (correr, salto, caída, deslizamiento, dash, lanzamiento, rebote, aterrizaje, victoria, golpe) son nuestros. El yo-yo y el disco son modelos nuestros (`PROP_Yoyo`, `PROP_YoyoDisc`). `CHR_Adventurer` **no** se migra. |
| R-B | **Sin energía; monetización con Robux** | Se elimina el sistema de energía (10 rayos, 20 min) y los anuncios de energía. Se monetiza con Developer Products, Game Passes y Premium Payouts. Se conservan las Chispas, gemas, medallas, la maestría de 4 estrellas, las misiones, los logros y las temporadas. |
| R-C | **Niveles: Godot como compilador + JSON** | El generador y el bot de Godot siguen produciendo y validando niveles. Un exportador nuevo los escribe como JSON y Roblox los construye con un `LevelBuilder` en Luau. **Cómo hacer los niveles infinitos (Torre)** se reevalúa en la Fase 2 (§4.6). |
| R-D | **Hub compartido, niveles en solitario** | Lobby compartido. En un nivel, cada jugador juega solo; los demás que estén en el mismo nivel se ven como fantasmas sin colisión. **Los modos competitivos se reevalúan en la Fase 4** (§6.5). |
| R-E | **Lo que Roblox ya resuelve se elimina** | AgeGate, ParentalGate, el login simulado de Google/Facebook, los nombres de la lista segura y los 60 rivales simulados desaparecen. Roblox ya da cuentas, controles parentales, `PolicyService`, nombres filtrados y amigos reales. Los rivales simulados se sustituyen por jugadores reales en la Fase 4. |

Estas decisiones deben copiarse a `roblox/DECISIONES_ROBLOX.md` como punto de partida.

---

## 2. Convenciones técnicas de Roblox

### 2.1 Escala: metros → studs
Factor único **K = 3.5 studs/m** (provisional).
- **Motivo:** la cápsula del personaje en Godot mide 1.5 m. 1.5 × 3.5 ≈ 5.25 studs, que es más o menos la altura de un avatar R15 estándar. Así se mantienen las proporciones de salto contra el cuerpo (≈1.57 alturas de personaje).
- **Regla de conversión:**
  - distancias, velocidades, aceleraciones y gravedades se multiplican por K;
  - tiempos, ángulos, fracciones y velocidades angulares no cambian.
- Si después de probar con avatares reales hace falta reajustar K, se cambia **solo en un lugar** (`Shared/Units`) y todo lo demás se deriva. Registra el cambio en `DECISIONES_ROBLOX.md`.
- **Escala de avatar:** fija la escala R15 en la configuración del juego (Avatar Settings: escalas en un rango estrecho o fijas). Así el alcance no depende del avatar de cada jugador. Hitbox de juego = cápsula propia, no las partes del avatar.

### 2.2 Estructura del lugar en Studio
```text
ReplicatedStorage/
  Shared/
    Units            (ModuleScript)  K y helpers m→studs
    MovementTuning   (ModuleScript)  todos los valores de §3.1 (en metros; se convierten al cargar)
    PropTuning       (ModuleScript)  valores de §3.5
    Catalog/         LevelCatalog, CosmeticCatalog, MissionPool, Achievements
    Net/             RemoteEvents/RemoteFunctions (con nombre descriptivo)
  Assets/            Prefabs de plataformas, props, peligros, yo-yo, decoración
  Levels/            ModuleScripts o StringValues con el JSON de cada nivel (Fase 2)
ServerScriptService/
  Services/          ProgressService, ProfileStore (DataStore), RunValidator, ShopService, SeasonService…
StarterPlayer/StarterPlayerScripts/
  Client/            PlayerController, YoyoController, FollowCamera, InputRouter, TouchControls,
                     LevelRuntime (construye y anima el nivel local), Hud, Menus
StarterGui/          ScreenGuis (o se crean desde código, como en Godot)
Workspace/           Hub (lobby) y una carpeta vacía `ActiveLevel` que llena cada cliente
```
- Un **ModuleScript por responsabilidad.** Entrada, cámara, aceleración y animación van separados, como en Godot (AGENTS.md).
- Evita "singletons" globales salvo los servicios del servidor, que son naturales en Roblox.
- **Nombres descriptivos** en inglés para el código (igual que en Godot) y en español para los textos del jugador vía `LocalizationTable`.

### 2.3 Autoridad cliente/servidor
- **Movimiento:** en el **cliente**. El personaje es propiedad de red del jugador; no se toca la propiedad de red del avatar.
- **Nivel en juego:** el cliente **construye su copia local** del nivel en `Workspace.ActiveLevel` (piezas locales, no replicadas). Así las plataformas temporizadas, móviles y que se desmoronan se animan sin latencia, y cada jugador ve su propio estado. Es coherente con R-D.
- **Servidor:** es dueño del **progreso, la economía y las puntuaciones**.
  - El cliente informa de eventos: inicio de intento, checkpoint, gema, chispas recogidas, meta.
  - `RunValidator` comprueba que tengan sentido: orden de checkpoints, tiempo mínimo plausible (por ejemplo ≥ 0.6 × oro), número de chispas ≤ total del nivel, y ritmo de envío.
  - Si algo no cuadra, no se paga ni se registra récord. No se expulsa sin revisión.
- **Nunca** se confía en el cliente para conceder Chispas compradas, Game Passes ni recompensas de temporada.

### 2.4 Plataformas y entrada
- **Prioridad móvil** (horizontal), con teclado/ratón y mando también soportados. Consola queda como "si sale gratis", sin prometerla.
- Desactiva los controles por defecto de Roblox (`PlayerModule`: controles y cámara) y usa los propios.
- **Mapa de acciones** central (`InputRouter`), equivalente al `InputMap` de Godot: `move` (vector), `jump`, `yoyo`, `action` (deslizar en suelo / dash en aire), `camera` (eje), `pause`.
  - Usa `ContextActionService` o el sistema de acciones de entrada de Roblox para teclado y mando. **Los botones táctiles llaman al mismo `InputRouter`** (regla de AGENTS.md).

| Acción | Teclado | Mando |
|---|---|---|
| Mover | WASD / flechas | Stick izquierdo |
| Saltar | Espacio / J | A (ButtonA) |
| Yo-yo | E / K | X (ButtonX) / RB |
| Acción | Shift / L | B (ButtonB) / LB |
| Cámara | Q / R | Stick derecho X |
| Pausa | Esc / P | Start |

> Aviso: en Roblox, Shift puede activar el *Shift Lock* y Esc abre el menú de Roblox. Desactiva Shift Lock (`StarterPlayer.EnableMouseLockOption = false`) y usa P como pausa principal en PC.

### 2.5 Rendimiento móvil
- Objetivo: frame pacing estable en teléfonos medios.
- Preferencias:
  - `MeshPart` con `RenderFidelity = Automatic` y `CollisionFidelity = Box` o `Hull`;
  - colisiones de plataforma con **Parts invisibles simples** separadas del mesh visual;
  - pocas luces dinámicas y partículas moderadas;
  - `StreamingEnabled` revisado: el nivel es local, así que el streaming afecta sobre todo al hub.
- Usa el *MicroProfiler* para medir y deja los resultados en `DECISIONES_ROBLOX.md`. No afirmes compatibilidad con teléfonos no probados.

---

## 3. FASE 1: mecánica, gameplay y nivel piloto

**Objetivo:** un nivel piloto que funcione **al 100 %** como en Godot (sensación, alcances, props, flujo completo de intento a resultados) en PC y en móvil. No se pasa a la Fase 2 hasta que se cumpla la lista de aceptación de §3.9.

### 3.1 Controlador del personaje
Referencia: `scripts/player/player.gd` y `scripts/data/movement_tuning.gd`. Los valores son hipótesis de prototipo ajustadas en Godot y son el punto de partida obligatorio.

**Enfoque recomendado** (regístralo como R1 si lo confirmas):
- Se conserva el `Humanoid` para avatar, animación y replicación. **La velocidad la calcula nuestro controlador** en `RunService.PreSimulation` (o `Heartbeat`), con integración propia que no dependa de los FPS (usa `dt`).
- Se escribe en `HumanoidRootPart.AssemblyLinearVelocity`, o mediante `LinearVelocity`/`AlignOrientation`.
- Se anula la gravedad del mundo sobre el personaje (con `VectorForce` igual a masa × `workspace.Gravity` hacia arriba, o con un estado Humanoid adecuado) y se aplica **nuestra gravedad asimétrica**.
- Detección de suelo con `workspace:Spherecast`/`Blockcast` propios. No uses `Humanoid.FloorMaterial` como única fuente.
- Si el Humanoid interfiere (auto-saltos, escalones, estados), desactiva los estados que no se usen (`SetStateEnabled`). Si sigue sin dar la sensación, prueba un controlador con física manual y documenta la elección.

**Valores** (Godot en m; Roblox = × K):

| Grupo | Parámetro | Godot | Roblox (K = 3.5) |
|---|---|---|---|
| Suelo | Velocidad de carrera | 8 m/s | 28 st/s |
| | Aceleración / deceleración / giro contra el movimiento | 38 / 48 / 70 | 133 / 168 / 245 |
| Aire | Aceleración / deceleración | 20 / 6 | 70 / 21 |
| | Gravedad al subir / al bajar | 28 / 45 | 98 / 157.5 |
| | Caída máxima | 32 | 112 |
| Salto | Velocidad de salto | 11.5 | 40.25 |
| | Corte de salto al soltar (fracción) | 0.45 | 0.45 |
| | Coyote / buffer | 0.12 s / 0.13 s | igual |
| Deslizamiento | Velocidad mínima de entrada | 2.5 | 8.75 |
| | Velocidad / fricción | 11 / 9 por s | 38.5 / 31.5 |
| | Suelo de velocidad (60 % de carrera) | 4.8 | 16.8 |
| | Duración / enfriamiento | 0.6 s / 0.25 s | igual |
| | Cápsula de pie / deslizando | r 0.35, h 1.5 / h 0.8 | r 1.225, h 5.25 / h 2.8 |
| Salto largo | Vertical / horizontal | 9.5 / 12.5 | 33.25 / 43.75 |
| Dash aéreo | Velocidad / duración | 15 m/s / 0.18 s | 52.5 / igual |
| | Elevación / velocidad de salida | 1.5 / 10 | 5.25 / 35 |
| Sensación | Rotación hacia el movimiento (si v > 0.6) | 14 | 14 (umbral 2.1) |
| | Caída del límite extra por boost aire / suelo | 4 / 10 por s | 14 / 35 |
| Suelo | Pendiente máxima / snap | 48° / 0.35 m | 48° / 1.225 |

**Comportamientos a reproducir exactamente:**
1. **Entrada relativa a la yaw de la cámara.** Adelante = sentido de la ruta. Atrás está permitido (sin auto-run).
2. En el aire **se conserva la velocidad por encima de la de carrera** (saltos largos, boosts y dashes mantienen inercia). Empujar contra el movimiento devuelve el objetivo a la velocidad de carrera.
3. **Salto variable:** soltar pronto multiplica la velocidad vertical por 0.45. El salto largo **no** se corta.
4. **Coyote y buffer:** ambos se reinician en cuanto sale el salto.
5. **Al tocar suelo** se restauran el coyote, el dash aéreo y la carga aérea del yo-yo.
6. **Botón contextual `action`** (D1): en suelo desliza (si v > 2.5 m/s y sin enfriamiento); en aire hace dash (uno por vuelo, con la dirección del stick o, sin entrada, la del personaje; ignora la gravedad mientras dura; al aterrizar se cancela).
   - El deslizamiento termina al salir del suelo **solo si hay espacio para ponerse de pie** (comprobación esférica hacia arriba).
7. **Saltar durante el deslizamiento** produce un salto largo en la dirección del deslizamiento.
8. **Fuerzas externas** (la API se replica como funciones del controlador):
   - `bounce(v, source)` (trampolín/yo-yo): fija la velocidad vertical, termina deslizamiento y dash, restaura el dash y desactiva el corte de salto. Solo el trampolín restaura la carga del yo-yo.
   - `applyBoost(dir, speed)`: sube un límite temporal de velocidad y suma velocidad en `dir`. El extra decae según la tabla.
   - `applyWind(dt)`: mitad de gravedad, arrastre horizontal ×(1 − 2.8·dt), elevación hasta la velocidad máxima vertical y restaura el dash.
9. **No hay** planeo, salto en pared ni carrera por pared (D1). No los añadas.

**Animaciones:** se crean como `Animation` para R15 en Studio (Animation Editor), con los mismos nombres que en Godot: Idle, Run, Jump, Fall, Slide, Dash, Throw, Bounce, Land, Victory, Hurt. El controlador elige la animación por estado y nunca al revés (animación desacoplada de la lógica). Si el MCP no puede crear animaciones, deja la lista de poses clave y duraciones al dueño, y usa las animaciones por defecto de Roblox como provisionales.

### 3.2 Yo-yo cinético
Referencia: `scripts/player/kinetic_yoyo.gd` y D2. Estados: **Guardado → Volando → Desplegado → Regresando.**

| Parámetro | Godot | Roblox |
|---|---|---|
| Distancia del lanzamiento en suelo (delante, +0.1 m de altura) | 4 m | 14 st |
| Margen de parada ante pared (raycast) | 1.3 m | 4.55 st |
| Tiempo de vuelo / arco seno | 0.14 s / 0.4 m | igual / 1.4 st |
| Radio del disco | 1.35 m | 4.725 st |
| Vida del disco / parpadeo final | 1.5 s / 0.5 s | igual |
| Velocidad de rebote | 16 m/s | 56 st/s |
| Condición de rebote | vy ≤ 2 m/s y posición ≥ disco − 0.45 m | vy ≤ 7, ≥ disco − 1.575 |
| Lanzamiento aéreo: adelanto / caída | vel. horizontal × 0.32 / −1.4 m | igual / −4.9 st |
| Despliegue inmediato bajo los pies si cae más rápido que | 3 m/s | 10.5 st/s |
| Regreso (ease-in hasta el jugador +1 m) | 0.3 s | igual (+3.5 st) |

- Lanzamientos **en suelo ilimitados**. **En aire, 1 carga** por vuelo, que se recarga al tocar suelo o con un trampolín.
- **No hay enfriamiento propio:** no se puede volver a lanzar hasta que el yo-yo vuelve.
- Un rebote consume el disco, que luego regresa. El hilo se dibuja con un `Beam` entre dos `Attachment` mientras el yo-yo está fuera.
- El botón táctil del yo-yo se **atenúa** cuando no está disponible.
- **Alcances de diseño** (D2 y `LEVEL_DESIGN.md`): salto + disco cubre ~9.5 m (máx. ~13) o sube +4 m. Correr sobre el disco en suelo sube ≈ +3.2 m.

### 3.3 Cámara de seguimiento
Referencia: `scripts/player/follow_camera.gd` y D4. `Camera.CameraType = Scriptable`, actualizada en `RenderStepped` (o `BindToRenderStep` con prioridad `Camera`).

| Parámetro | Valor Godot | Roblox |
|---|---|---|
| Distancia / altura del foco | 6.6 m / 1.4 m | 23.1 / 4.9 st |
| Inclinación | −17°, más hasta 9° extra al caer (vy × 0.5) | igual |
| FOV | 70, hasta +7 entre 8 y 15 m/s | `FieldOfView` es vertical en Roblox; calibra para que la vista sea equivalente a la de Godot (también vertical) |
| Suavizados | yaw 3, horizontal 11, vertical en suelo 7 / en aire 2.6 | igual (exponencial con dt) |
| Límites del foco vertical | −1.6 / +1.2 m | −5.6 / +4.2 st |
| Anticipación | velocidad de avance × 0.16, entre −0.6 y 2 | ×K en los límites |
| Ajuste manual | 2.2 rad/s, ±75°, vuelve tras 1.2 s; táctil 0.006 rad/px | igual |

- **La yaw la fija la ruta, no la velocidad.** Las **CameraZones** (volúmenes invisibles, `CanCollide = false`, detectadas con `GetPartsInPart` o comprobación de caja propia) fijan la yaw objetivo por plataforma.
- Al reaparecer, la cámara salta a la yaw guardada en el último checkpoint. Al morir hay un temblor de 0.6.
- Evita oclusiones: un `Spherecast` desde el foco hacia la cámara acerca la cámara sin atravesar plataformas (equivalente al *spring arm*).

### 3.4 Controles táctiles
Referencia: `scripts/ui/touch_controls.gd`. Se hacen en una `ScreenGui` propia (`ScreenInsets = DeviceSafeInsets`, `IgnoreGuiInset` según convenga), escalada por resolución.
- **Joystick flotante:**
  - aparece donde se apoya el pulgar en el 45 % izquierdo de la pantalla (bajo el 30 % superior);
  - radio 105 px (a 720p, escalado), zona muerta 0.12;
  - la base sigue al pulgar cuando este se aleja más de 1.3 × el radio.
- **Botones a la derecha:** salto r88 (naranja, principal), yo-yo r64 (cian), acción r60. Zona táctil = 1.25 × radio.
- **Arrastre libre a la derecha** mueve la cámara.
- **Ajustes:** modo zurdo (espejo), escala (1.0) y opacidad (0.65).
- Los controles táctiles se muestran con `UserInputService.TouchEnabled` / `PreferredInput` y se ocultan al usar teclado o mando.
- **Varios dedos:** usa `InputBegan/Changed/Ended` con `InputObject` por toque, no `TouchTap`.

### 3.5 Props, peligros y elementos de nivel
Referencia: `scripts/props/*.gd` y `scenes/props/*.tscn`. Valores por defecto (entre paréntesis, rango usado en los niveles). Todas las distancias se convierten con K.

**Elementos del recorrido:**
| Elemento | Comportamiento y valores |
|---|---|
| **Plataformas seguras** | Tamaños (ancho × largo, m): S 3×3, M 4×6, L 6×10, XL 8×14, Strip 2.5×8, Wide 6×6. Tres biomas: Isles, Toy, Ruins. **El origen de cada plataforma es el centro de su cara caminable.** |
| **Trampolín** | Fuerza 20 (niveles: 24). Disparador cilíndrico r 1.15–1.35. Solo actúa si vy ≤ 1. Restaura dash y yo-yo. Alcance de diseño +5 / +8 m. |
| **Boost pad** | Velocidad 17 hacia su frente. Se vuelve a activar tras 0.3 s. Área 2.2×0.8×3.2. |
| **Columna de viento** | Altura 8 (7–12), radio 1.65. Elevación 62, que se atenúa en los 2.5 m superiores. Velocidad máxima de subida 10. |
| **Plataforma móvil** | Recorrido (0,0,−6), periodo 4 s, 25 % del ciclo en pausa en los extremos (≈1 s, D10), suavizado *smoothstep*. Debe **arrastrar al jugador**: aplica el delta de la plataforma al personaje en el controlador. |
| **Plataforma temporizada** | Sólida 2.2 s / desaparecida 1.4 s (1.2–1.6 / 0.9–1.1). Parpadea los últimos 0.6 s. `phase` es un retraso. |
| **Plataforma que se desmorona** | 3×3. Al pisarla tiembla 0.55 s, cae y reaparece a los 3 s. |
| **Checkpoint** | Área 4×3×2. Se activa una vez y guarda el punto de aparición y la yaw de cámara. |
| **Meta** | Arco dorado, área 4.6×4×1.6. Congela al jugador. |

**Peligros** (todos llaman a `hurt()`):
| Peligro | Comportamiento y valores |
|---|---|
| Pinchos | 1.8×0.5×1.8. |
| Spinner | Brazo 6.6×0.5×0.5 a ~0.95 m de altura, 70°/s (±70–130). |
| Robot patrulla | Esfera r 0.75, recorrido (6,0,0) a velocidad 3 (2.5–4.5), ida y vuelta con *smoothstep*. |
| Puerta láser | Ancho 4, haz a 1.05 m (caja 3.7×0.32×0.4). Puede parpadear con un periodo: encendido el 60 %, aviso 0.4 s. **Se puede pasar deslizando por debajo.** |
| Caída | Por debajo de `kill_height` (−12; niveles −9 a −11). |

**Coleccionables:**
- **Gemas:** 3 por nivel (índice 0–2), r 0.9. Las ya conseguidas se ven como "fantasma" y se pueden volver a recoger.
- **Chispas:** r 0.6, imán a 2.2 m a 14 m/s. Sus líneas dibujan los arcos de salto recomendados.

**Indicaciones del tutorial:** áreas con claves TUT_MOVE, JUMP, SLIDE, YOYO_GROUND, YOYO_AIR, DASH, TRAMPOLINE, LONG_JUMP, WIND, GOAL, con variante `_TOUCH` según el dispositivo (D11). Los textos están en `localization/strings.csv` y pasan a una `LocalizationTable` (ES/EN).

**Implementación en Roblox:**
- Los props animados (móviles, temporizados, spinner, patrulla, láser) se mueven **en el cliente** con un **reloj de nivel común** (tiempo desde el inicio del intento + `phase`), no con tweens independientes. Así su sincronización es determinista y coincide con lo que espera el generador.
- Las colisiones de peligros se resuelven con **comprobación de solapamiento propia** contra la cápsula del jugador (`GetPartBoundsInBox` / `GetPartsInPart` con `OverlapParams` filtrados), no con `Touched`, que es poco fiable a alta velocidad.
- Las plataformas móviles se mueven con `CFrame` en `PreSimulation`, y el controlador suma el desplazamiento de la plataforma que pisa.
- **Lenguaje visual:** seguro = cálido/verde, impulso = amarillo/naranja, temporal o móvil = cian/azul, peligro = magenta/morado. Además, **cada función tiene forma o animación propia** (chevrones, parpadeo, temblor, pinchos).

### 3.6 Flujo de intento, medallas y estrellas
Referencia: `scripts/level/level.gd`, `scripts/autoload/progress.gd`, D3, D7 y D18.
- **Cronómetro:** empieza con la primera entrada y **no se detiene al morir** (D3).
- **Muerte:**
  1. Golpe: temblor de cámara, destello y vibración (`HapticService` cuando haya soporte).
  2. A los 0.55 s, reaparición en el checkpoint.
  3. 0.35 s de protección; el yo-yo vuelve al instante.
- **Meta:** congelar al jugador, celebración "¡Meta!" y, a los 1.4 s, pantalla de resultados.
- **Medallas:** oro si el tiempo ≤ `gold_time`, plata si ≤ `silver_time`, bronce por terminar. Los tiempos por nivel están en `resources/levels/level_catalog.tres` (y llegan en el JSON, Fase 2).
- **4 estrellas de maestría (D18):** oro, las 3 gemas, todas las chispas en un solo intento y sin reapariciones. Dominar un mundo completo da un premio cosmético.
- **Recompensa:** las chispas recogidas se suman a la cartera en cada intento. El servidor valida con `RunValidator` (§2.3).

### 3.7 HUD y pantallas
Referencia: `scripts/ui/hud.gd`, `level_select.gd`, `pause_menu.gd`, `results_screen.gd`, `main_menu.gd`.
- **HUD:**
  - arriba a la izquierda: retrato (el avatar del jugador con `Players:GetUserThumbnailAsync`), cronómetro, objetivo de oro (dorado mientras vas a ritmo) y barra de progreso de la ruta;
  - arriba en el centro: 3 casillas de gemas y chispas recogidas / total;
  - arriba a la derecha: pausa (sin tapar los botones de Roblox del borde superior);
  - en el centro: mensajes y panel de indicaciones del tutorial.
- **Pausa:** Continuar, Reiniciar, Ajustes, Salir (al selector).
- **Resultados:** tiempo, nuevo récord, tiempos de medalla, gemas, chispas, sin caídas, estrellas y recompensas. Botones Reintentar, Siguiente y, al final de la campaña, créditos.
- **Ajustes:** volúmenes, escala y opacidad táctiles, modo zurdo, vibración, sensibilidad de cámara, temblor, mostrar cronómetro y mostrar fantasma.
- En Roblox, el **menú principal** se integra con el **hub**: los paneles de UI se abren desde el hub o desde un botón de menú.

### 3.8 Assets: qué se migra desde Blender y qué se hace nativo
Regla: **solo se migra lo que aporta identidad.** Lo que se resuelve igual de bien con Parts, materiales y efectos nativos se hace nativo. Las fuentes del juego no se tocan (§0.2); el trabajo sobre copias va en `roblox/assets_source/`.

| Asset (GLB en `orbit_runner_game/art/models/`) | En Roblox | Motivo |
|---|---|---|
| `PROP_Yoyo`, `PROP_YoyoDisc` | **MeshPart migrado** | Identidad central del juego |
| `PLAT_Isle_*`, `PLAT_Toy_*`, `PLAT_Ruin_*` (18) | **MeshPart migrado** (solo visual) + Part invisible de colisión | Le dan carácter a los biomas |
| `PROP_GoalGate`, `PROP_Checkpoint`, `PROP_Trampoline`, `PROP_BoostPad`, `PROP_WindRing` | **MeshPart migrado** | Props reconocibles. Las áreas son Parts invisibles |
| `PLAT_Moving`, `PLAT_Timed`, `PLAT_Crumble` | **MeshPart migrado** | Su forma comunica la función (chevrones, hexágono, grietas) |
| `HAZ_Spinner`, `HAZ_PatrolBot`, `HAZ_LaserPost` | **MeshPart migrado** | Silueta de peligro propia |
| `HAZ_Spikes` | **Nativo** (Parts/`WedgePart` o un mesh sencillo) | Conos simples |
| `PROP_Gem`, `PROP_Spark` | **MeshPart migrado** (poligonaje bajo) con brillo nativo (`PointLight` limitado o material Neon) | Coleccionables legibles |
| `ENV_Tree`, `ENV_Pine`, `ENV_Palm`, `ENV_Gear`, `ENV_ToyBlocks`, `ENV_LampPost`, `ENV_RuinArch`, `ENV_Obelisk`, `ENV_Crystal`, `ENV_RuinPillar` | **MeshPart migrado** | Decoración propia de cada bioma |
| `ENV_Bush`, `ENV_Rock_A/B`, `ENV_Cloud` | **Nativo** (Parts/esferas con material; nubes con Parts suaves o `Clouds` del terreno/cielo) | Formas triviales |
| `CHR_Adventurer` | **No se migra** | R-A: se usa el avatar del jugador |
| Láser (haz), hilo del yo-yo, estelas, viento, destellos | **Nativo**: `Beam`, `Trail`, `ParticleEmitter` | Efectos nativos más baratos |
| Cielo, iluminación | **Nativo**: `Sky`, `Atmosphere`, `Lighting` (`Future` o `ShadowMap` según rendimiento) | — |
| Audio (`audio/music`, `audio/sfx`) | **Migrado**: se suben como assets propios (D13, audio sintetizado propio: sin riesgo de licencias) | Identidad sonora |

**Problemas conocidos de los GLB** (auditoría del 2026-10-18) que hay que resolver **en las copias** antes de subirlos:
1. **Contornos de casco invertido** (`M_Outline*`, materiales `doubleSided`): fuera de Godot salen negros. **Quítalos al exportar para Roblox.** Si hace falta contorno, usa `Highlight` solo en elementos clave (hay un límite de instancias simultáneas) o un borde oscuro en la textura horneada.
2. **Sin UVs, color solo por vertex color.** Comprueba en Studio si el importador respeta el vertex color de los MeshParts. Si no lo hace, **crea UVs y hornea el vertex color a una textura pequeña** (paleta compartida por bioma) con un script de Blender en `roblox/assets_source/`.
3. **`ENV_RuinPillar`** tiene caras degeneradas y aristas no-manifold. Límpialo en la copia.
4. **Ejes y escala:** Blender Z arriba y 1 u = 1 m (`assets_source/blender/PARAMETROS_ASSETS_ORBIT_RUNNER.md`). Para Roblox, escala ×K al exportar (o al importar) y verifica que el origen de cada plataforma sigue siendo el centro de su cara caminable.
5. Límites de Roblox: 20 000 triángulos por MeshPart (las plataformas Toy llegan a ~9k; están dentro). Agrupa los assets con el *3D Importer* o *Asset Manager* en paquetes por bioma.

> La subida de assets la hace el dueño si el MCP no puede. Los IDs (`rbxassetid://…`) se guardan en un único módulo `Shared/AssetIds` y nunca se escriben a mano en varios sitios.

### 3.9 Nivel piloto y criterios de aceptación de la Fase 1
**Contenido del piloto:**
1. **Laboratorio de mecánicas:** una pista de pruebas con todas las plataformas, props y peligros, con marcas de distancia en studs/m para medir alcances.
2. **Tutorial "Primer vuelo"** y **w1_l1** reconstruidos a mano en Studio a partir de sus escenas (`scenes/levels/tutorial.tscn`, `w1_l1.tscn`) y de sus llamadas en `tools/build_levels.gd`. Si el exportador JSON de la Fase 2 se adelanta, se pueden construir con él.

**Lista de aceptación** (todas obligatorias; deja la evidencia en `DECISIONES_ROBLOX.md`):
- [ ] **Altura de salto completo ≈ 2.36 m** (≈ 8.3 st), con duración ≈ 0.73 s, a 30, 60 y 120+ FPS (independiente del framerate).
- [ ] **Tabla de alcances** (cómodo / máximo, m) reproducida con ±5 %:

  | Técnica | Cómodo | Máximo |
  |---|---|---|
  | Salto plano | 3.5 | 5.9 |
  | Salto largo | 6 | 7 |
  | Salto + dash | 7.5 | 9 |
  | Salto + disco | 9.5 | 13 |
  | Trampolín (subida) | +5 / +8 | +7.1 / +10.3 |

- [ ] Coyote, buffer, salto variable, deslizamiento bajo un láser, salto largo, dash único por vuelo, recarga al aterrizar: probados uno por uno.
- [ ] Yo-yo: lanzamiento en suelo con subida ≈ +3.2 m, lanzamiento aéreo, despliegue inmediato al caer rápido, vida y parpadeo del disco, regreso, 1 carga aérea y botón atenuado.
- [ ] Todos los props y peligros con sus valores, y el reloj común de nivel verificado (sincronización tras morir y reaparecer).
- [ ] Cámara: zonas, anticipación, sin oclusión, ajuste manual, salto a la yaw del checkpoint.
- [ ] Flujo completo: inicio → muertes y reapariciones → meta → resultados con medalla, gemas, chispas y estrellas, y el servidor registra el resultado.
- [ ] Controles: táctil (joystick flotante, 3 botones, cámara por arrastre, modo zurdo) en emulador **y en al menos un teléfono real**; teclado y mando.
- [ ] Rendimiento medido en el teléfono real (FPS medio y peor caso) y anotado.
- [ ] El dueño ha jugado el piloto y da el visto bueno a la **sensación** (comparándolo con el APK de Godot).

---

## 4. FASE 2: migración de niveles

**Objetivo:** llevar a Roblox la campaña completa (tutorial + 30 niveles), los desafíos diarios y las temporadas, con un flujo semiautomático que reutilice el generador y el bot de Godot.

### 4.1 Lo que ya existe en Godot
- **Campaña:** `scenes/levels/tutorial.tscn` y `w{1..3}_l{1..10}.tscn` (31 escenas generadas por herramienta).
  - Los niveles hechos a mano están en `tools/build_levels.gd`.
  - Los 20 generados se describen por especificación en `tools/campaign_generated.json` y se planifican en `tools/campaign_plan.gd`.
  - Catálogo y medallas en `resources/levels/level_catalog.tres`. La tabla completa está en `docs/LEVEL_DESIGN.md`.
- **Metadatos en el nodo raíz** de cada nivel:
  - `route`: lista ordenada de piezas `{kind, pos, yaw, len, wid, gap, rise, node, tech, motif, rest, floor…}`;
  - `generated`: especificación, familias, motivos, tiempos y `route_hash`;
  - `extras`: islas de gemas.
- **Generador:** `scripts/generator/level_generator.gd` (15 motivos en `motif_library.gd`, alcances en `movement_reach.gd`, validador estático en `level_validator.gd`). Es determinista por semilla.
- **Bot:** `tools/bot/` (4 perfiles: perfect, expert, casual, novice). Calcula el índice de dificultad `35(1−Vn)+20(1−E_casual)+15Cn+15Dn+15Rn` y las medallas (oro = mediana expert × 1.15, plata × 1.7).
- **Producción por lotes:** `godot --headless --fixed-fps 60 --path orbit_runner_game res://tools/generate_levels.tscn -- key=value…` (`count`, `seed`, `difficulty`, `biome`, `dailies=N`, `season=N`, `campaign=1`, `workers`…). Tarda unos 70 s por nivel por proceso.
- **Diarios** (`resources/generator/daily_seeds.tres`: 30 días desde 2026-10-18, 28 validados) y **temporadas** (`resources/seasons/season_schedule.tres`: S1–S4 entre el 2026-10-18 y el 2026-11-15, 79/80 validados). **Ojo:** estos calendarios caducan pronto; habrá que generar nuevos lotes cuando se llegue a esta fase.

### 4.2 Exportador JSON (nuevo, en Godot)
Crear `orbit_runner_game/tools/export_level_json.gd` + `.tscn`.
- **Es la única modificación permitida en el juego de Godot.** Solo **añade** una herramienta; no cambia gameplay.
- **Entrada:** una escena de nivel, una carpeta o una especificación (`gen:<seed>:<difficulty>:<biome>`). Para especificaciones construye el nivel en memoria con el generador (como `GeneratedRun.build`) antes de exportar.
- **Salida:** `roblox/levels_json/<id>.json` en **metros** y en **ejes de Godot** (Y arriba, adelante −Z). La conversión a studs y a los ejes de Roblox la hace el `LevelBuilder` de Luau, en un solo sitio.
- Recorre los grupos del nivel (Geometry, Elements, Hazards, Collectibles, Checkpoints, CameraZones, Prompts, Decor, PlayerStart) y exporta cada nodo con tipo, transform y parámetros `@export` relevantes.
- Lánzalo en lote igual que las demás herramientas headless:
  ```text
  godot --headless --path orbit_runner_game res://tools/export_level_json.tscn -- in=res://scenes/levels out=../roblox/levels_json
  ```

**Esquema** (versión 1; documéntalo también en `roblox/levels_json/SCHEMA.md`):
```json
{
  "schema": 1,
  "id": "w1_l1",
  "name_key": "LEVEL_W1_L1",
  "world": 1, "index": 1,
  "biome": "isles",
  "difficulty": "easy",
  "medals": { "gold": 26.5, "silver": 42.0 },
  "kill_height": -12.0,
  "source": { "kind": "handmade|campaign_gen|daily|season|tower",
              "seed": 0, "generator_version": 1, "route_hash": "…", "difficulty_index": 0.0 },
  "player_start": { "pos": [0,0,0], "yaw": 0 },
  "route": [ { "kind": "plat", "pos": [x,y,z], "yaw": 0, "len": 6, "wid": 4,
               "gap": 3.1, "rise": 0, "tech": "jump", "motif": "stairs", "rest": false } ],
  "platforms":   [ { "asset": "PLAT_Isle_M", "pos": [..], "rot": [..] } ],
  "elements":    [ { "type": "trampoline", "pos": [..], "rot": [..], "params": { "strength": 24 } },
                   { "type": "moving_platform", "params": { "travel": [0,0,-6], "period": 4, "phase": 0, "pause_fraction": 0.25 } },
                   { "type": "timed_platform", "params": { "on_time": 1.4, "off_time": 1.0, "phase": 0.3, "warning": 0.6 } },
                   { "type": "crumble_platform" }, { "type": "boost_pad", "params": { "speed": 17 } },
                   { "type": "wind_column", "params": { "height": 9, "lift": 62, "max_up_speed": 10 } } ],
  "hazards":     [ { "type": "spikes|spinner|patrol|laser", "pos": [..], "rot": [..], "params": { } } ],
  "collectibles":{ "gems": [ { "index": 0, "pos": [..] } ], "sparks": [ [x,y,z] ] },
  "checkpoints": [ { "pos": [..], "spawn": [..], "camera_yaw": 0 } ],
  "camera_zones":[ { "pos": [..], "size": [..], "rot": [..], "yaw": 0 } ],
  "prompts":     [ { "key": "TUT_JUMP", "pos": [..], "size": [..] } ],
  "decor":       [ { "asset": "ENV_Tree", "pos": [..], "rot": [..], "scale": 1 } ],
  "goal":        { "pos": [..], "rot": [..] }
}
```
- Los `type` y `asset` usan los mismos nombres que los scripts y GLB de Godot, para que la tabla de equivalencias sea directa.
- **No hace falta reproducir el RNG de Godot en Luau:** el JSON contiene el nivel ya resuelto.

### 4.3 LevelBuilder en Luau
- Módulo `Client/LevelRuntime/LevelBuilder`: lee el JSON (`HttpService:JSONDecode`), convierte metros → studs y ejes Godot → Roblox, instancia prefabs desde `ReplicatedStorage.Assets` y configura cada prop con sus `params`.
- **Ejes:** Godot y Roblox son ambos Y arriba y diestros. Adelante es −Z en los dos, así que la conversión es **solo escala ×K**. Rotaciones: yaw en grados o radianes igual que en Godot; verifica el signo con un nivel de prueba asimétrico.
- **Almacenamiento:** cada nivel es un `ModuleScript` en `ReplicatedStorage/Levels/<id>` que devuelve la cadena JSON (o la tabla ya decodificada). Hay que tener en cuenta el límite de tamaño de los scripts; si un nivel no cabe, divídelo.
- El mismo módulo sirve para el servidor (`RunValidator` lee medallas, número de chispas y orden de checkpoints).
- **Importación:** el agente pasa los JSON de `roblox/levels_json/` a los ModuleScripts mediante el MCP. Si no puede, crea un script de Studio (comando de barra o plugin local propio) documentado en `roblox/src/tools/`.

### 4.4 Catálogo, selector y desbloqueo
- `Shared/Catalog/LevelCatalog`: tutorial + 3 mundos × 10, con los nombres de `level_catalog.tres`:
  - Mundo 1 **Brisa** (Isles): L1–4 hechos a mano, L5–10 generados, de Easy a Hard; objetivo 40 s.
  - Mundo 2 **Taller de Juguetes** (Toy): L1–3 a mano, L4–10 generados, de Medium a Hard; objetivo 45 s.
  - Mundo 3 **Ruinas Solares** (Ruins): L1–3 a mano, L4–10 generados, de Hard a Extreme; objetivo 50 s. `w3_l8` está reclasificado como Hard.
- **Desbloqueo lineal:** completar un nivel abre el siguiente. El tutorial es gratuito y se recomienda la primera vez.
- **Botón "Continuar":** lleva al siguiente nivel sin completar.

### 4.5 Flujo semiautomático para niveles nuevos
1. **Generar y validar en Godot** con `tools/generate_levels.tscn` (el bot acepta, reclasifica o repara; las medallas salen de la mediana de expert).
2. **Exportar** a JSON con `export_level_json`.
3. **Importar** en Roblox (§4.3).
4. **Verificar en Roblox:**
   - comparar el `route_hash` del JSON con un hash calculado por el LevelBuilder sobre las posiciones de la ruta en metros, redondeadas a cm (mismo algoritmo: SHA-256 de `kind:x,y,z` por pieza, 16 caracteres; en Luau hay que implementar SHA-256 o usar una alternativa documentada);
   - recorrido manual del nivel, o con un bot en Roblox si se decide hacerlo (opcional).
5. **Diarios y temporadas:** se generan **por lotes** en Godot (`dailies=N`, `season=N start=… levels=20 days=7`) y se exportan con su calendario (fecha de inicio UTC, duración, dificultad). En Roblox, el calendario se lee de un módulo, y en la Fase 4 de una fuente actualizable sin publicar (por ejemplo `DataStore`/`MemoryStore` o un módulo cargado por versión).
   - **Desafío diario:** semilla = fecha UTC YYYYMMDD. La dificultad rota Medium → Hard → Extreme y el bioma cambia cada 3 días. Se guardan récord, medalla, gemas y racha (historial de 30 días).

> **Si los alcances de Roblox no coinciden con los de Godot** (lista de §3.9), los niveles validados por el bot pueden volverse imposibles o triviales. Por eso **la Fase 2 no empieza hasta que la Fase 1 está aceptada**.

### 4.6 Torre del Viento (infinita): decisión pendiente
En Godot, la Torre genera pisos en el dispositivo a medida que se sube:
- semilla 900000 + semana;
- bandas: Easy hasta el piso 10, Medium hasta el 20, Hard hasta el 35 y Extreme después;
- checkpoint cada 10 pisos y sin vidas (D16).

Al llegar aquí, evalúa y propone al dueño:
- **Opción 1, pisos pregenerados:** se exporta un banco grande (por ejemplo 200 pisos por banda) y se encadenan por semilla semanal. Mínimo riesgo; no es "infinita" en sentido estricto.
- **Opción 2, generador en Luau:** se porta `level_generator.gd`, `motif_library.gd`, `movement_reach.gd` y `level_validator.gd` (solo la validación estática). Es infinita de verdad, pero no será idéntica a Godot y no tendrá validación del bot.
- **Criterios:**
  - coste de portar (líneas y complejidad);
  - si la tabla de alcances de Roblox ya está calibrada;
  - si hace falta igualdad entre jugadores (una clasificación semanal exige que todos vean la misma torre: la opción 2 debe ser determinista **dentro de Roblox**, con `Random.new(seed)`);
  - rendimiento de generar mientras se juega.

---

## 5. FASE 3: monetización en Roblox

**Objetivo:** una economía justa para todas las edades, sin energía, sin ventaja de pago en las clasificaciones y sin cajas de botín. Los precios en Robux son **hipótesis** que se validan con datos.

### 5.1 Qué se conserva y qué cambia
| Godot (freemium) | Roblox |
|---|---|
| Energía 10, 1 por intento, recarga cada 20 min | **Eliminada** (R-B) |
| Anuncio recompensado (+2 energía) | **Eliminado.** Más adelante se puede evaluar un anuncio recompensado de Roblox (Rewarded Video Ads, si el juego es elegible) a cambio de Chispas. Decisión del dueño |
| Tienda: energy_10, energy_30, unlimited_60 | **Eliminados** |
| sparks_1000 (0.99 €) | **Developer Products** de paquetes de Chispas |
| season_pass ("Próximamente") | **Pase de temporada** (§5.4) |
| AgeGate, ParentalGate, login simulado | **Eliminados**. Usa `PolicyService` y los controles parentales de Roblox |
| Chispas (moneda blanda), gemas y medallas como umbrales, maestría, logros (23), misiones | **Se conservan** |

### 5.2 Cosméticos (reinterpretados para el avatar de Roblox)
En Godot, los cosméticos son trajes y colores del yo-yo, el disco y la estela (`resources/cosmetics/cosmetic_catalog.tres`). En Roblox **no se modifica el avatar del jugador**. Los cosméticos pasan a ser:
- **Skins de yo-yo y disco:** colores, materiales, formas y efectos.
- **Estelas** (`Trail`) al correr, saltar o hacer dash, y **auras/partículas** de rebote y aterrizaje.
- **Efecto de meta** (celebración) y, opcionalmente, **accesorios de juego** que no cambien la hitbox.

**Conversión de los desbloqueos existentes** (mismo tipo y mismo umbral):
| Godot | Desbloqueo | Roblox (propuesta) |
|---|---|---|
| outfit_explorer / yoyo_classic | Por defecto | Estela básica / yo-yo clásico |
| outfit_sunset 150, outfit_midnight 400 | Chispas | Estelas "Atardecer" y "Medianoche" |
| yoyo_ember 120, yoyo_lime 250 | Chispas | Yo-yos Brasa y Lima |
| outfit_forest 9, outfit_coral 21, outfit_shadow 30, yoyo_storm 15 | Gemas totales | Auras y el yo-yo Tormenta |
| outfit_solar 10, yoyo_gold 5 | Medallas de oro | Estela Solar y yo-yo Dorado |
| outfit_polar, yoyo_violet, yoyo_prism | Logros (yoyo_master, air_ace, campaign_complete) | Igual |
| breeze_master, toy_master, sun_master | Maestría de mundo (D18) | Set temático por mundo (yo-yo + estela + aura) |

- **Diseño de la economía:** la campaña da ~550 Chispas y los logros ~2 000, suficiente para comprarlo todo. Este equilibrio se mantiene para lo que se gana jugando.
- **Para monetizar** se **amplía el catálogo** con cosméticos nuevos (comprables con Chispas o directamente con Robux), siempre **solo estéticos**. Usa `MarketplaceService` para los de Robux.

### 5.3 Productos de Robux (hipótesis iniciales)
- **Developer Products** (consumibles) en `ShopService`:

  | Producto | Contenido | Precio hipótesis |
  |---|---|---|
  | Paquete pequeño | 500 Chispas | ~49 R$ |
  | Paquete mediano | 1 200 Chispas | ~99 R$ |
  | Paquete grande | 3 000 Chispas | ~199 R$ |

  El procesamiento va **solo en el servidor** con `MarketplaceService.ProcessReceipt`, idempotente (guardar `PurchaseId` en el perfil antes de devolver `PurchaseGranted`).
- **Game Passes** (permanentes):
  - **VIP / Pase de Orbitador:** estela y yo-yo exclusivos, marco en el HUD y +20 % de Chispas ganadas jugando. Ventaja **solo cosmética**: las Chispas no influyen en las clasificaciones.
  - **Pack de fundador:** cosméticos de lanzamiento.
- **Servidores privados (VIP Servers):** gratuitos o baratos, para jugar con amigos (útiles desde la Fase 4).
- **Premium Payouts:** activos por defecto (ingresos por tiempo de juego de miembros Premium). Opcional: un pequeño beneficio cosmético para Premium (`Player.MembershipType`).
- Los IDs de productos y pases los crea el dueño en el Creator Dashboard. El código los lee de `Shared/AssetIds` / `ProductIds`.

### 5.4 Pase de temporada
- Los **Game Passes son permanentes**, así que un pase **por temporada** se vende como **Developer Product** ligado a la temporada actual (guardar `seasonPass[seasonId] = true` en el perfil).
- **Pista gratuita y premium** con recompensas por **puntos de temporada** (puntuación por nivel: oro 1000, plata 700, bronce 400, +100 por gema, hasta 200 por chispas, +150 sin caídas; cuenta el mejor resultado por nivel).
- Las recompensas son **solo cosméticas y Chispas**. Las de clasificación de fin de temporada (1.º 1 500, top 3 1 000, top 10 600, mitad superior 300, resto 100 Chispas) se mantienen y se activan en la Fase 4, cuando haya clasificación real.
- Contenido y precio del pase **por definir con el dueño** (también lo estaba en Godot).

### 5.5 Persistencia
- `DataStoreService` con un perfil por jugador (clave `user_<UserId>`), con sesión bloqueada para evitar duplicados entre servidores (patrón tipo *ProfileService*/*ProfileStore*, **implementado en casa** o con autorización expresa si se usa una librería externa).
- **Esquema equivalente** a `save_service.gd` (`progress`):
  - `levels[id] = {completed, best_time, gems[3], medal, best_sparks, flawless, all_sparks}`;
  - `sparks`, `owned`, `equipped {yoyo, trail, aura}`, `stats`, `achievements`, `daily`, `tower`, `missions`, `seasons`, `tutorial_done`, `purchases[]`, `version`.
- **Ajustes:** en el mismo perfil (sección `settings`) para que viajen entre dispositivos.
- **Guardado:**
  - al cambiar, con *debounce* (en Godot era 0.4 s; en Roblox respeta los límites de peticiones y guarda cada ~30–60 s o en eventos clave);
  - en `PlayerRemoving` y en `game:BindToClose`.
- **Versionado y migración** del esquema desde el primer día (`version = 1`).

### 5.6 Misiones, logros y maestría
- **Misiones** (`scripts/progress/mission_board.gd`):
  - 3 diarias de un fondo de 12 (30–60 Chispas);
  - 7 semanales de un fondo de 12 (100–200 Chispas);
  - se eligen por **fecha UTC**, iguales para todos. Se calculan en el servidor con `os.time()` / `DateTime` del servidor; ya no hace falta la protección contra cambiar la hora del móvil.
- **Logros:** los 23 de Godot. Revisa los que dependan de sistemas eliminados (energía, login) y cámbialos por equivalentes. Opcional: algunos como **Badges** de Roblox (`BadgeService`), que crea el dueño.
- **Maestría (D18):** igual que en Godot.

### 5.7 Cumplimiento y políticas
- **Sin cajas de botín** ni recompensas aleatorias pagadas. Si se añaden más adelante, se consulta `PolicyService:GetPolicyInfoForPlayerAsync` (`ArePaidRandomItemsRestricted`) y se muestran las probabilidades.
- Consulta `PolicyService` para enlaces sociales externos y otros contenidos restringidos por país o edad.
- **No uses texto libre del jugador.** Los nombres son los de Roblox (`DisplayName`). Si alguna vez hay texto, se filtra con `TextService`.
- Las guías de cumplimiento de Roblox (Community Standards, Terms of Use, cuestionario de madurez de la experiencia) las completa el dueño en el Creator Dashboard.
- Sigue en pie el principio de Godot: **no hacer pasar bots por personas.** Si algún modo usa fantasmas generados, se marcan como tales.

### 5.8 Criterios de aceptación de la Fase 3
- [ ] Comprar cada producto en Studio (las compras de prueba no cobran), con concesión idempotente verificada (repetir `ProcessReceipt` no duplica).
- [ ] Perfil persistente: salir y entrar conserva progreso, cartera, cosméticos equipados y ajustes; dos sesiones simultáneas no corrompen datos.
- [ ] Cosméticos visibles para el propio jugador y replicados a otros en el hub.
- [ ] Misiones y logros pagan solo una vez y su estado se valida en el servidor.
- [ ] Revisión: nada de lo que se compra da ventaja en tiempos ni en puntos.

---

## 6. FASE 4: juego online con servicios de Roblox

**Objetivo:** sustituir todo lo simulado de Godot (rivales, clasificaciones, amigos, reloj local) por servicios reales de Roblox y reevaluar los modos multijugador.

### 6.1 Hub y servidores
- **Hub compartido** (R-D):
  - punto de reunión con acceso a mundos, tienda, temporada, desafíos y torre;
  - muestra los cosméticos de otros jugadores;
  - tablón de clasificación físico (`SurfaceGui`).
- **En un nivel**, los jugadores que juegan el mismo nivel en el mismo servidor se ven como **fantasmas** (sin colisión con `CollisionGroups`, con transparencia y su nombre). Los que están en otro nivel u otra zona se ocultan en local.
- Grupo para el **teletransporte entre lugares** (`TeleportService`) si en el futuro se separan hub y modos. En esta fase basta con un lugar.

### 6.2 Clasificaciones
- **Por nivel** (mejor tiempo), **por temporada** (puntos), **torre semanal** (piso más alto) y **diario** (tiempo del día).
  - `OrderedDataStore` con claves por periodo (por ejemplo `season_S5`, `daily_20261205`, `tower_w42`) para la clasificación persistente.
  - `MemoryStoreService` (`SortedMap`) para la clasificación en vivo de la temporada y el diario, de baja latencia.
- **Orden de temporada:** puntos → niveles completados → suma de mejores tiempos (desempate).
- Pestañas **Amigos / Global**. Los amigos salen de `Players:GetFriendsAsync`.
- Solo puntúan resultados que pasen el `RunValidator` (§2.3). Se pueden añadir validaciones adicionales, como comprobar la telemetría de posiciones del intento (§6.4).

### 6.3 Temporadas semanales reales
- **Calendario** por UTC del **servidor**: inicio, duración de 7 días, dificultad, 20 niveles, y los 4 primeros un escalón más fáciles.
- **Cierre:**
  - al terminar, un servidor (con bloqueo en `MemoryStore` para que lo haga solo uno) fija el rango final y reparte recompensas (§5.4);
  - los premios se entregan al entrar el jugador, leyendo su rango final.
- Contenido nuevo cada semana **sin publicar el juego**: el agente genera lotes en Godot (§4.5) y los publica en un `DataStore` de contenido (o con Open Cloud desde una herramienta del dueño). Proponer al dueño el mecanismo concreto.
- **Notificaciones:** las de Godot (energía llena, nueva temporada, último día, resultado) se adaptan a **Experience Notifications** de Roblox si el juego es elegible, y si no a avisos dentro del juego al entrar. La de "energía llena" desaparece.

### 6.4 Fantasmas y repeticiones
- En Godot, las repeticiones son **entradas por tick** reproducibles exactamente (D17). **En Roblox la física no es determinista entre clientes**, así que se graban **posiciones**: muestreo de CFrame y estado de animación cada 0.05–0.1 s, cuantizado y comprimido.
- **Fantasma propio:** el mejor intento, guardado en el perfil o en un DataStore aparte por nivel (límite de tamaño por clave).
- **Fantasmas de otros:** el del primero de la clasificación, de un amigo o de alguien cercano en el ranking, en un DataStore `ghosts_<levelId>` con claves por `UserId`.

### 6.5 Modos competitivos: a reevaluar al llegar aquí
El dueño quiere explorar:
1. **Carrera contra fantasmas** (asíncrona o en directo en el mismo servidor): los rivales se ven sin colisión. Encaja de lleno con la identidad.
2. **Modo de derribar al rival:** los jugadores interfieren entre sí (empujar o tirar de la plataforma).
   - ⚠️ **Tensión con un pilar:** la identidad dice "sin combate" y "el yo-yo no es arma". Antes de diseñarlo, hay que presentar al dueño una propuesta que respete el tono: empujes físicos ligeros, sin daño ni vidas, o interacción indirecta (como discos que estorban o activar trampas del entorno), en un **modo separado** que no altere la campaña.
- Para cualquier modo en directo: servidores por partida (`TeleportService:ReserveServer` o *matchmaking* por cola en `MemoryStore`), autoridad del servidor sobre la sincronización de props (reloj de nivel común) y prueba con varios clientes.

### 6.6 Criterios de aceptación de la Fase 4
- [ ] Clasificaciones con datos reales y desempates correctos, y cierre de temporada probado con una temporada corta de prueba.
- [ ] Amigos: la pestaña muestra solo amigos reales que juegan.
- [ ] Fantasmas: se graban, guardan y reproducen sin desincronización visible.
- [ ] Nada simulado queda visible como si fuera real (rivales simulados eliminados o marcados).
- [ ] Prueba con varios clientes en Studio y una prueba pública cerrada con el dueño.

---

## 7. Pendientes y decisiones abiertas

| # | Tema | Cuándo | Quién decide |
|---|---|---|---|
| P1 | Enfoque del controlador (Humanoid + velocidad propia o física manual) y valor final de K | Fase 1 | Agente (con evidencia), lo aprueba el dueño |
| P2 | Animaciones R15 propias: quién las produce (MCP, dueño o provisionales) | Fase 1 | Dueño |
| P3 | Si los MeshParts respetan el vertex color o hay que hornear texturas | Fase 1 | Agente (prueba) |
| P4 | Torre infinita: pisos pregenerados o generador en Luau | Fase 2 | Dueño, con la propuesta del agente |
| P5 | Verificación de niveles en Roblox: SHA-256 en Luau o alternativa, y bot en Roblox (sí/no) | Fase 2 | Agente |
| P6 | Precios en Robux, contenido del pase de temporada, catálogo ampliado | Fase 3 | Dueño |
| P7 | Anuncios recompensados de Roblox a cambio de Chispas | Fase 3 | Dueño |
| P8 | Publicación de contenido semanal sin actualizar el juego (DataStore u Open Cloud) | Fase 4 | Dueño, con la propuesta del agente |
| P9 | Modos competitivos (carrera de fantasmas, modo de derribo) y su encaje con "sin combate" | Fase 4 | Dueño |
| P10 | Nombre definitivo del juego (Orbit Runner es provisional), icono y miniaturas | Antes de publicar | Dueño |

---

## 8. Trazabilidad Godot → Roblox

| Sistema | Origen en Godot | En Roblox | Fase |
|---|---|---|---|
| Valores de movimiento | `scripts/data/movement_tuning.gd` | `Shared/MovementTuning` (+ `Units`) | 1 |
| Controlador | `scripts/player/player.gd` | `Client/PlayerController` | 1 |
| Yo-yo | `scripts/player/kinetic_yoyo.gd` | `Client/YoyoController` + prefab `PROP_Yoyo/YoyoDisc` | 1 |
| Cámara | `scripts/player/follow_camera.gd`, `props/camera_zone.gd` | `Client/FollowCamera` (Scriptable) | 1 |
| Entrada | `project.godot` InputMap, `ui/touch_controls.gd` | `Client/InputRouter`, `Client/TouchControls` | 1 |
| Props/peligros | `scripts/props/*.gd` | `Client/LevelRuntime/Props/*` con reloj común | 1 |
| Intento, medallas, estrellas | `scripts/level/level.gd`, `autoload/progress.gd` | `Client/LevelRuntime` + `Server/ProgressService` + `RunValidator` | 1 |
| HUD y pantallas | `scripts/ui/*.gd` | ScreenGuis en `Client/Hud`, `Client/Menus` | 1 |
| Textos | `localization/strings.csv` | `LocalizationTable` (ES/EN) | 1 |
| Audio | `audio/music`, `audio/sfx` | `SoundService` + `SoundGroup` | 1 |
| Assets | `art/models/*.glb` (copias en `roblox/assets_source/`) | MeshParts en `ReplicatedStorage/Assets` | 1 |
| Niveles | `scenes/levels/*.tscn`, `tools/build_levels.gd` | `roblox/levels_json/*.json` → `ReplicatedStorage/Levels` | 2 |
| Generador y bot | `scripts/generator/*`, `tools/bot/*`, `tools/generate_levels.gd` | Se quedan en Godot; exportador `tools/export_level_json.gd` | 2 |
| Catálogo de campaña | `resources/levels/level_catalog.tres` | `Shared/Catalog/LevelCatalog` | 2 |
| Diario | `scripts/generator/daily_challenge.gd`, `daily_seeds.tres` | Lote JSON + calendario UTC del servidor | 2 / 4 |
| Torre | `scripts/level/tower_mode.gd` | Pendiente (P4) | 2 |
| Cosméticos | `resources/cosmetics/cosmetic_catalog.tres` | `Shared/Catalog/CosmeticCatalog` (yo-yos, estelas, auras) | 3 |
| Economía | `resources/economy/economy_config.tres`, `scripts/economy/*` | `Server/ShopService` (Developer Products, Game Passes); sin energía | 3 |
| Guardado | `scripts/autoload/save_service.gd` | `Server/ProfileStore` (DataStoreService) | 3 |
| Misiones y logros | `scripts/progress/mission_board.gd` | `Server/MissionService`, `AchievementService` (+ Badges) | 3 |
| Edad, control parental, cuentas | `ui/age_gate.gd`, `ui/parental_gate.gd`, `services/simulated_auth` | Eliminados: cuentas de Roblox + `PolicyService` | 3 |
| Temporadas | `scripts/season/*.gd`, `season_schedule.tres` | `Server/SeasonService` (OrderedDataStore + MemoryStore) | 3 / 4 |
| Rivales simulados | `scripts/season/rival_roster.gd` | Eliminados: jugadores reales | 4 |
| Amigos | `services/simulated_social` | `Players:GetFriendsAsync` | 4 |
| Repeticiones y fantasmas | `scripts/replay/*.gd` (entradas por tick) | Grabación de poses y DataStore | 4 |
| Notificaciones | `NotificationCenter`, plugin Android | Experience Notifications o avisos en el juego | 4 |
