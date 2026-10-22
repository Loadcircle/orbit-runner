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
- **Decisión:** `StarterPlayer` fija `EnableMouseLockOption = false` (Shift queda libre para *Acción*), `DevComputerMovementMode = Scriptable` y `DevTouchMovementMode = Scriptable` (oculta el joystick y el botón de salto de Roblox). `ClientMain` llama a `PlayerModule:GetControls():Disable()` para cubrir también el mando. La cámara por defecto se sustituye en H5, cuando `FollowCamera` ponga `CameraType = Scriptable`; no se bifurca el `PlayerModule`.
- **Motivo:** guía §2.4. Los controles propios (`InputRouter`, `TouchControls`) son la única entrada de gameplay.
- **Impacto:** hasta H2 el personaje no se puede mover en *Play*. Esc sigue abriendo el menú de Roblox; la pausa principal en PC será P.
