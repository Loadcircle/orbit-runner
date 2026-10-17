# Juego como servicio — implementación (fases A y B)

Plan de referencia: *Orbit Runner como servicio: plan de desarrollo* (página privada del propietario, enlazada en `ESTADO_DEL_PROYECTO.md`). Este documento describe lo que existe en el código, cómo usarlo y qué queda pendiente. Rama: `feature/juego-como-servicio`.

## Estado del backlog

| ID | Tarea | Estado |
|---|---|---|
| A1 | `LevelSpec` y perfiles de dificultad | Hecho: `scripts/generator/level_spec.gd`, `difficulty_profile.gd`, `resources/generator/difficulty_profiles.tres` |
| A2 | Técnica anotada por pieza y alcances desde `MovementTuning` | Hecho: `LevelBuilder.tag()`, `scripts/generator/movement_reach.gd` |
| A3 | Biblioteca de motivos | Hecho: 15 motivos en `scripts/generator/motif_library.gd` |
| A4 | Validador estático | Hecho: `scripts/generator/level_validator.gd` |
| A5 | Generador (encadenado, descansos, checkpoints, gemas, chispas, hash) | Hecho: `scripts/generator/level_generator.gd` |
| A6 | Bot v2 que ejecuta la técnica anotada | Hecho: `tools/bot/bot_pilot.gd` |
| A7 | Perfiles con ruido | Hecho: `tools/bot/bot_skills.gd` |
| A8 | Métricas | Hecho, con la ventana de tiempo **calculada** (ver "Diferencias con el plan") |
| A9 | Índice, aceptación, reclasificación y reparación | Hecho: `tools/bot/level_rating.gd`, `tools/generate_levels.gd` |
| A10 | Lotes en paralelo con informes | Hecho: `tools/generate_levels.tscn` |
| A11 | Revalidar la campaña con el bot v2 | Hecho: termina los 11 niveles (el bot anterior, 7) |
| A12 | Calibración con personas | **Pendiente** (requiere 5–10 jugadores) |
| B1 | Grabador y reproductor de repeticiones | Hecho y verificado: reproducir las entradas da el mismo tiempo exacto |
| B2 | Fantasma local de la mejor marca | Hecho (ajuste "Mostrar fantasma") |
| B3 | Maestría por nivel (4 estrellas) y premio por mundo | Hecho: 3 trajes de maestría |
| B4 | Torre del Viento sin conexión | Hecho: pisos generados sobre la marcha |
| B5 | Desafío diario local | Hecho, con tabla de semillas validadas por el bot |
| D5 | Misiones diarias y semanales | Hecho en local (premio en chispas; la XP del pase espera a D4) |
| C1–C9, D1–D4, D6–D7, E1–E5 | Servidor, pagos, temporadas | **Pendientes de decisiones del propietario** |

## Generador de niveles

- Entrada: `LevelSpec` (semilla, versión del generador, bioma, dificultad, duración objetivo, mecánicas, modo, `adjustments`). Misma semilla + misma versión = mismo nivel en todos los dispositivos; el hash de la ruta (`LevelGenerator.route_hash`, posiciones redondeadas a cm) lo comprueba.
- El generador elige las familias de técnica que el nivel exige (salto, salto largo, impulso, placa, disco, deslizar, esperar, trampolín, viento) según el rango del perfil, y encadena motivos con pesos que favorecen la variedad y llevan la densidad de peligros hacia el objetivo del perfil.
- Los huecos son una fracción del alcance máximo de la técnica que exigen (`MovementReach`, integración de las ecuaciones del `Player` a 60 Hz: salto ~6,1 m, largo ~7,8, impulso ~9,3, disco ~14). Un hueco que exige una técnica es siempre mayor que lo que salva la técnica más débil.
- Descansos según `motifs_without_rest`; punto de control solo sobre un descanso; 3 gemas en islas laterales un escalón por encima de la ruta.
- Se genera en ~50 ms (PC). Si el validador rechaza un intento se prueba la siguiente sub-semilla (hasta 12).
- Salida: escena `Level` con los metadatos `route` (cada pieza con `tech`, `motif`, `rest`…), `generated` (spec, motivos, longitud, estimación de tiempo, medallas, hash) y `extras` (islas de gemas).
- Reparaciones: `LevelSpec.adjustments` (motivo → escala de hueco y tamaño de plataforma) forma parte de la especificación, así que el nivel reparado se reconstruye igual en el teléfono.

## Bot validador y calificación

- `tools/bot/bot_pilot.gd` juega solo con el `InputMap`. Ejecuta la técnica anotada (en la campaña la deduce del hueco y la subida) y predice aspas, robots, plataformas temporales y móviles a partir de su estado; espera en un punto seguro hasta que la trayectoria prevista está libre, salta los brazos y robots cuando hace falta y se compromete a pasar si no aparece ventana en 3 s.
- Perfiles (`bot_skills.gd`): perfecto, experto (reacción 120 ms, ±40 ms, ±3°), casual (220 ms, ±90 ms, ±7°), novato (320 ms, ±150 ms, ±12°). Un intento falla si el perfil muere 3 veces en el mismo motivo (perfecto: 6) o se agota el tiempo.
- Índice: `ID = 35(1 − Vn) + 20(1 − E_casual) + 15 Cn + 15 Dn + 15 Rn` (`level_rating.gd`). Aceptado si el índice cae en la categoría pedida y se cumplen sus tasas de éxito; reclasificado si cumple las de otra; si no, se repara el motivo con más muertes (hueco −10 %, plataforma un tamaño mayor) o se endurece si quedó fácil, hasta 3 veces; si el perfil perfecto no termina, se descarta.
- Medallas: oro = tiempo mediano del experto × 1,15; plata = × 1,7.

### Uso

```
# Un nivel o la campaña con el bot
godot --headless --fixed-fps 60 --path . res://tools/bot/run_bot.tscn -- res://scenes/levels/w2_l2.tscn all 5
godot --headless --fixed-fps 60 --path . res://tools/bot/run_bot.tscn -- gen:1000:2:ruins perfect 1 300 trace
bash ../dev_tools/validation/run_campaign_bot.sh perfect 1

# Lote: 24 niveles, 12 procesos
godot --headless --fixed-fps 60 --path . res://tools/generate_levels.tscn -- count=24 seed=3000 attempts=8 workers=12 out=res://build/batch

# Desafíos diarios validados para los próximos 30 días (escribe resources/generator/daily_seeds.tres)
godot --headless --fixed-fps 60 --path . res://tools/generate_levels.tscn -- dailies=30 attempts=8 workers=12 out=res://build/dailies
```

Salida del lote: `<out>/reports/<semilla>.json` (índice, componentes, tasas por perfil, muertes por motivo, ventana más estrecha, tiempos, medallas, motivos), `<out>/summary.csv` y las escenas aceptadas en `<out>/levels/<categoría>/`. `build/` no se versiona. Coste medido: ~70 s por nivel y proceso con 8 intentos por perfil.

### Calibración actual

Primera calibración contra el bot (2026-10-17, lotes de 24 niveles): el índice medido ocupa ~5–65, no 0–100, y los niveles salían un escalón por debajo de lo pedido. Se ajustaron los rangos del índice (Fácil 0–18, Medio 18–38, Difícil 38–58, Extremo 58+) y se generan más exigentes Medio, Difícil y Extremo. Son valores provisionales: la calibración con personas (A12) y la telemetría de muertes por motivo (ya registrada en `Level.deaths_by_motif`) deben ajustarlos.

## Modos en el juego

- **Desafíos** (menú principal): desafío diario, Torre del Viento y misiones (`scripts/ui/challenges_screen.gd`).
- **Desafío Orbital diario** (`DailyChallenge`): semilla = fecha UTC; dificultad rota Medio → Difícil → Extremo; bioma cada 3 días. Si la fecha está en `resources/generator/daily_seeds.tres` (validada por el bot en PC) se usan esa semilla, sus reparaciones y sus medallas; si no, la semilla local con validación estática y medallas estimadas. Se guarda el mejor tiempo, la medalla, las gemas y la racha de días; se conservan 30 días.
- **Torre del Viento** (`TowerMode`): misma torre para todos durante la semana; los pisos se generan de uno en uno por delante del jugador (sin tirones); dificultad Fácil hasta el piso 10, Medio hasta el 20, Difícil hasta el 35 y Extremo después; punto de control cada 10 pisos. La subida termina desde la pausa ("Terminar la subida"); se guarda el récord semanal y el total.
- **Repeticiones** (`scripts/replay/`): entradas en bruto por tic (9 bytes: eje X/Y int16, botones, guiñada de cámara) y pose cada 0,1 s, comprimidas con zstd en `user://replays/<nivel>.rpl` (~18 KB por minuto). `InputReplayer` las reproduce tic a tic forzando la guiñada de cámara; en PC una repetición de *Islas de la Brisa* terminó en el mismo tiempo exacto (19,700 s), base de la futura verificación de marcas en el servidor (C5).
- **Fantasma**: la mejor repetición de cada nivel (campaña y diario) se dibuja translúcida siguiendo el cronómetro.
- **Maestría**: cuatro estrellas por nivel (oro, 3 gemas, todas las chispas en una carrera, sin caídas), visibles en la selección de niveles y en resultados. Dominar un mundo entero desbloquea su traje (*Maestro de la Brisa*, *Maestro Juguetero*, *Maestro Solar*).
- **Misiones** (`MissionBoard`): 3 diarias y 7 semanales elegidas por fecha (iguales para todos), progreso por estadísticas, premio en chispas al cobrarlas.

## Diferencias con el plan

- **Ventana de tiempo (A8)**: se calcula con el modelo cinemático de cada salto (`MovementReach.takeoff_window`) en lugar de medirla perturbando al bot perfecto, que exigiría una ejecución por salto. Es una aproximación optimista en plataformas pequeñas; las tasas de éxito de los perfiles con ruido compensan en el índice.
- **Tamaño de repetición**: ~18 KB/min en vez de 1–2 KB/min, por guardar la guiñada de cámara en coma flotante y los ejes con 16 bits (necesario para que la repetición sea exacta).
- **Misiones**: premian chispas; la XP del pase y la rotación por configuración remota llegan con D4 y C6.
- **Reclasificados**: se guardan siempre en su categoría medida (sin cupos por lote).

## Pendiente y decisiones del propietario

1. **A12**: jugar 12 niveles de calibración (3 por categoría) con 5–10 personas y comparar con el bot.
2. **Fase C (en línea)**: elegir servidor (Nakama propio o gestionado) y decidir si el público incluye menores de 13 años; después cuentas, guardado en la nube, rankings, verificación de repeticiones, configuración remota y analítica.
3. **Fase D (monetización)**: precios del pase, recargas y tarjeta Órbita; integrar Google Play Billing con validación en servidor. No se ha integrado ningún pago ni servicio externo.
4. **Fase E (temporadas)**: depende de C y D.
