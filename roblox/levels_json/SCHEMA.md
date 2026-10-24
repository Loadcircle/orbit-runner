# Esquema JSON de niveles (versión 1)

Generado por `orbit_runner_game/tools/export_level_json.gd` (Godot 4.7.2, headless):

```text
godot --headless --path orbit_runner_game res://tools/export_level_json.tscn -- in=res://scenes/levels out=../roblox/levels_json [ids=tutorial,w1_l1]
```

Rojo convierte cada `.json` de esta carpeta en un `ModuleScript` de `ReplicatedStorage.Levels` que devuelve la tabla ya decodificada. Lo leen `Client/LevelRuntime/LevelBuilder` y, en el servidor, `Services/RunValidator`.

## Convenciones

- **Unidades:** metros y segundos, como en Godot. La conversión a studs (×K, `Shared/Units`) se hace en un solo sitio, al construir.
- **Ejes:** los de Godot (Y arriba, adelante −Z), que coinciden con los de Roblox.
- **Rotaciones (`rot`):** ángulos de Euler en grados, en el orden YXZ de Godot (`CFrame.fromEulerAnglesYXZ`).
- **Origen de las plataformas:** el centro de la cara caminable.

## Campos

| Campo | Contenido |
|---|---|
| `schema` | `1` |
| `id`, `name_key`, `hint_key` | Identificador y claves de traducción (`LEVEL_<ID>`, `LEVEL_<ID>_HINT`). |
| `world`, `index`, `tutorial` | Mundo (base 1), posición dentro del mundo (base 1; el tutorial vale 0) y si es el tutorial. |
| `biome`, `difficulty` | `isles` / `toyworks` / `ruins` y `easy` / `medium` / `hard` / `extreme` (vacío en el tutorial). |
| `medals` | `{ gold, silver, mode? }` en segundos. Desde R25 los calcula `scripts/level_kit.py: medal_times` sobre el camino que recoge todo. Bronce = completar; plata = tiempo ≤ `silver`; oro = tiempo ≤ `gold` + las 3 gemas + todas las chispas. Con `mode = "speed"` (niveles de pura velocidad) el oro es solo el tiempo y se calcula sobre la ruta. |
| `kill_height` | Altura de caída en metros. |
| `source` | `{ kind: "handmade" }` o `{ kind: "campaign_gen", seed, route_hash, difficulty_index }`. |
| `player_start` | `{ pos, yaw }` (pies del jugador; yaw de cámara en grados). |
| `route` | Metadatos `route` del nodo raíz (`kind`, `pos`, `yaw`, `len`, `wid`, `gap`, `rise`, `node`…), con los Vector3 convertidos a listas. |
| `platforms` | `{ asset, pos, rot, scale?, collider: { size, offset } }`. `asset` es el GLB (`PLAT_Isle_M`…). |
| `elements` | `{ type, pos, rot, params }` con `type` = `trampoline` (strength), `wind_column` (height, lift, max_up_speed), `boost_pad` (speed), `moving_platform` (travel, period, phase, pause_fraction + `collider`), `timed_platform` (on_time, off_time, phase, warning) o `crumble_platform` (warning_time, respawn_time). |
| `hazards` | `{ type, pos, rot, params }` con `type` = `spikes`, `spinner` (degrees_per_second, start_angle), `patrol` (travel, speed, phase) o `laser` (width, beam_height, period, on_fraction, phase). |
| `collectibles` | `{ gems: [{ index, pos }], sparks: [[x, y, z], …] }`. |
| `checkpoints` | `{ pos, rot, spawn }`, en orden de recorrido (el servidor valida ese orden). |
| `camera_zones` | `{ pos, rot, size, offset, yaw }`: caja del activador y yaw en grados. |
| `prompts` | `{ key, pos, rot, size, offset }` (clave `TUT_*`; existe la variante `_TOUCH`). |
| `decor` | `{ asset, pos, rot, scale? }` (`ENV_*`). |
| `goal` | `{ pos, rot }`. |

## Extensiones solo del laboratorio (`Shared/LabLevel`)

- `rulers`: `{ from, to }`. Regla con marcas cada metro (gruesas cada 5 m) y cada 5 studs.
- `labels`: `{ pos, text }`. Cartel flotante.
