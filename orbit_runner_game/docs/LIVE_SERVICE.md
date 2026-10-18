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
| — | Freemium: energía, tienda, anuncios, temporadas semanales, rivales simulados, amigos, avisos | Hecho en local con proveedores simulados (2026-10-18; ver "Freemium, temporadas, rivales, amigos y avisos") |
| C1–C9, D1–D4, D6–D7, E1–E5 | Servidor, pagos y temporadas en línea | **Pendientes**: integración con Firebase (decisión del propietario) |

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

| Lote (24 niveles, 8 intentos por perfil, 12 procesos) | Aceptados | Reclasificados | Descartados |
|---|---|---|---|
| 1 — valores iniciales del plan | 6 | 9 | 9 |
| 2 — tras la calibración | 18 | 2 | 4 |

En el lote 2, Fácil, Medio y Difícil salen en su categoría casi siempre (índices ~6–10, ~18–27 y ~40–46). **Extremo sigue corto**: el índice ya cae en su franja, pero el perfil experto lo supera casi siempre (el plan pide un 40–80 %), así que solo 1 de 6 se aceptó. Próximo ajuste: endurecer más los motivos combinados y las ventanas de tiempo de Extremo, o revisar si el perfil experto es demasiado preciso.

## Modos en el juego

- **Desafíos** (menú principal): desafío diario, Torre del Viento y misiones (`scripts/ui/challenges_screen.gd`).
- **Desafío Orbital diario** (`DailyChallenge`): semilla = fecha UTC; dificultad rota Medio → Difícil → Extremo; bioma cada 3 días. Si la fecha está en `resources/generator/daily_seeds.tres` (validada por el bot en PC) se usan esa semilla, sus reparaciones y sus medallas; si no, la semilla local con validación estática y medallas estimadas. Se guarda el mejor tiempo, la medalla, las gemas y la racha de días; se conservan 30 días.
- **Torre del Viento** (`TowerMode`): misma torre para todos durante la semana; los pisos se generan de uno en uno por delante del jugador (sin tirones); dificultad Fácil hasta el piso 10, Medio hasta el 20, Difícil hasta el 35 y Extremo después; punto de control cada 10 pisos. La subida termina desde la pausa ("Terminar la subida"); se guarda el récord semanal y el total.
- **Repeticiones** (`scripts/replay/`): entradas en bruto por tic (9 bytes: eje X/Y int16, botones, guiñada de cámara) y pose cada 0,1 s, comprimidas con zstd en `user://replays/<nivel>.rpl` (~18 KB por minuto). `InputReplayer` las reproduce tic a tic forzando la guiñada de cámara; en PC una repetición de *Islas de la Brisa* terminó en el mismo tiempo exacto (19,700 s), base de la futura verificación de marcas en el servidor (C5).
- **Fantasma**: la mejor repetición de cada nivel (campaña y diario) se dibuja translúcida siguiendo el cronómetro.
- **Maestría**: cuatro estrellas por nivel (oro, 3 gemas, todas las chispas en una carrera, sin caídas), visibles en la selección de niveles y en resultados. Dominar un mundo entero desbloquea su traje (*Maestro de la Brisa*, *Maestro Juguetero*, *Maestro Solar*).
- **Misiones** (`MissionBoard`): 3 diarias y 7 semanales elegidas por fecha (iguales para todos), progreso por estadísticas, premio en chispas al cobrarlas.

### Desafíos diarios validados

`resources/generator/daily_seeds.tres` contiene los días 2026-10-17 a 2026-10-29 (13 de 14 aceptados; el 30 de octubre no superó ninguna de las 4 variantes de semilla y usará la semilla local). Hay que regenerarla antes de que se agote (`dailies=N`), hasta que el servidor publique las semillas oficiales (C7).

## Diferencias con el plan

- **Ventana de tiempo (A8)**: se calcula con el modelo cinemático de cada salto (`MovementReach.takeoff_window`) en lugar de medirla perturbando al bot perfecto, que exigiría una ejecución por salto. Es una aproximación optimista en plataformas pequeñas; las tasas de éxito de los perfiles con ruido compensan en el índice.
- **Tamaño de repetición**: ~18 KB/min en vez de 1–2 KB/min, por guardar la guiñada de cámara en coma flotante y los ejes con 16 bits (necesario para que la repetición sea exacta).
- **Misiones**: premian chispas; la XP del pase y la rotación por configuración remota llegan con D4 y C6.
- **Reclasificados**: se guardan siempre en su categoría medida (sin cupos por lote).

## Pendiente

Estado al 2026-10-17. APK de depuración: `build/android/orbit_runner_debug.apk` (instalado en el S25; en prueba por el propietario).

### Trabajo que puede hacer el agente

1. **Ajustes tras la prueba del propietario**: dificultad de los niveles generados, tirones al generar pisos de la Torre, fantasma, pantalla Desafíos. Es lo prioritario.
2. **Endurecer Extremo**: el perfil experto lo supera casi siempre (el plan pide 40–80 %), 1 de 6 aceptados en el lote 2. Opciones: huecos y ventanas de tiempo más estrechos en `difficulty_profiles.tres` (vía `tools/build_data.gd`), más motivos combinados, o un perfil experto menos preciso en `bot_skills.gd`. Después, un lote de 24 para comprobar.
3. **Ampliar los desafíos diarios**: `daily_seeds.tres` cubre del 2026-10-17 al 10-29 (el 30 de octubre usa la semilla local). Regenerar con `dailies=30` antes de que se agote, hasta que exista C7.

### Requiere personas

4. **A12**: jugar 12 niveles de calibración (3 por categoría) con 5–10 personas y comparar con el bot. Hasta entonces la calibración del índice es provisional.

### Decisiones del propietario

5. **Fase C (en línea)**: elegir servidor (Nakama propio o gestionado) y decidir si el público incluye menores de 13 años; después cuentas, guardado en la nube, rankings, verificación de repeticiones, configuración remota y analítica.
6. **Fase D (monetización)**: precios del pase, recargas y tarjeta Órbita; integrar Google Play Billing con validación en servidor. No se ha integrado ningún pago ni servicio externo.
7. **Fase E (temporadas)**: depende de C y D.
8. **Fusión con master**: solo cuando el propietario lo pida, idealmente tras su prueba.

Orden recomendado: 1 → 2 y 3 en la misma tanda → decisiones de la fase C.

## Freemium, temporadas, rivales, amigos y avisos (2026-10-18)

Este trabajo está en la rama `feature/freemium-temporadas`, creada sobre `master`. `master` ya contiene las fases A y B; el `master` anterior quedó guardado en `respaldo/master-v1`.

Todo lo externo es **simulado** detrás de interfaces. El siguiente paso es sustituir los proveedores simulados por los reales (previsto: Firebase).

Decisiones del propietario:
- energía: 1 por intento, máximo 10;
- temporadas semanales de 20 niveles;
- el público **incluye menores de 13 años**.

### Arquitectura

- **Autoload nuevo `Services`** (`scripts/autoload/services.gd`). Crea la energía, los anuncios, la tienda, la cuenta, los amigos y los avisos. Reprograma los avisos al abrir el juego y cada 30 s, y liquida las temporadas terminadas. Es el único sitio donde se cambia un proveedor simulado por uno real.
- **Interfaces y simulados** en `scripts/services/`:
  - `AdsProvider` / `SimulatedAds`: anuncio con premio de 5 s; cerrarlo antes no da premio. El modo `family_safe` está siempre activo.
  - `StoreProvider` / `SimulatedStore`: confirma la compra sin cobrar.
  - `AuthProvider` / `SimulatedAuth`: login con Google o Facebook.
  - `SocialProvider` / `SimulatedSocial`: amigos e invitaciones.
  - `NotificationCenter`: bandeja de avisos y avisos programados.
  - `GameClock`: hora local. El argumento `clock_hours=N` adelanta el reloj para pruebas.
- **Valores ajustables**: `resources/economy/economy_config.tres` (`EconomyConfig`): energía, anuncios, premios de temporada y catálogo de productos (`StoreProduct`).
- **Guardado**: sección `services` (energía, cuenta, avisos) y `progress.seasons` (récord de cada nivel de temporada, posición final, premio cobrado).

### Energía

- Máximo 10. Se recupera 1 rayo cada 20 min mientras está por debajo del máximo: de 0 a lleno, 3 h 20 min.
- Las compras y los anuncios pueden superar el máximo; la recarga solo corre por debajo de él.
- **Cuesta 1 por intento al empezar cualquier nivel**: campaña, diario, Torre y temporada. Reintentar y "Siguiente" también cuentan como intento. Morir no cuesta nada.
- **El tutorial es gratis** (`free_tutorial`), para que nadie se quede bloqueado en la primera partida.
- El cobro está en un único punto: `SceneRouter.play_level()` y `play_generated()`.
- Sin energía aparece `EnergyDialog`, con tres opciones: esperar (muestra el tiempo hasta el siguiente rayo), ver un anuncio (+2, hasta 5 al día) o ir a la tienda.
- **Tienda** (`scripts/ui/store_screen.gd`): anuncio gratis, packs de 10 y 30 rayos, energía ilimitada 1 h, 1000 chispas y pase de temporada ("Próximamente"). Los precios son orientativos.
- **Puerta parental** (`ParentalGate`: una multiplicación que se escribe):
  - antes de cualquier compra;
  - antes de copiar o canjear invitaciones si el jugador es menor.

### Temporadas

- **Calendario**: `resources/seasons/season_schedule.tres` (`SeasonSchedule`). Cada temporada tiene id, número, fecha de inicio (00:00 UTC), duración en días, dificultad y 20 niveles validados por el bot (semilla, reparaciones, medallas y hash de ruta).
- **Lanzar una temporada** es añadirla al calendario o mover su fecha. Con el servicio en línea vendrá de configuración remota.
- **Generación**:
  `godot --headless --fixed-fps 60 --path . res://tools/generate_levels.tscn -- season=5 start=2026-11-15 difficulty=2 biome=rotate levels=20 days=7 attempts=8 workers=12 out=res://build/season5`
  - Los 4 primeros niveles son un escalón más fáciles, como calentamiento.
  - Se prueban hasta 4 variantes de semilla por nivel. Se queda la primera aceptada; si ninguna lo es, la primera reclasificada.
  - En la entrada del calendario, `difficulty` es la dificultad usada para generar y `category` la que midió el bot.
- **Preprogramadas**:

  | Temporada | Inicio | Dificultad | Bioma |
  |---|---|---|---|
  | S1 | 2026-10-18 | Medio | Islas |
  | S2 | 2026-10-25 | Difícil | Taller |
  | S3 | 2026-11-01 | Medio | Ruinas |
  | S4 | 2026-11-08 | Difícil | Mezcla |

- **Puntos por nivel** (`SeasonScoring`):
  - medalla: oro 1000, plata 700, bronce 400;
  - 100 por gema;
  - hasta 200 por chispas;
  - 150 si no hay caídas.
- Cuenta la mejor puntuación de cada nivel. El ranking ordena por puntos, después por niveles completados y desempata por la suma de los mejores tiempos. Los niveles se desbloquean en orden.
- **Al terminar la temporada** se fija la posición final en el ranking global, se pagan chispas y llega un aviso a la bandeja. Premios: 1.º 1500, top 3 1000, top 10 600, mitad superior 300, resto 100.
- **Pantalla** `scripts/ui/season_screen.gd` (menú → Temporada):
  - durante la temporada: cuenta atrás, los 20 niveles y la clasificación con pestañas Amigos / Global; sin amigos, muestra los rivales cercanos;
  - entre temporadas: cuenta atrás de la próxima y el último resultado.

### Rivales simulados

- `RivalRoster` define 60 corredores deterministas. Cada uno tiene:
  - nombre de una lista segura y un traje;
  - perfil de habilidad (novato, casual, experto o perfecto, como el bot);
  - ritmo de niveles por día y retraso inicial;
  - probabilidad de estar jugando en cada hora.
- Su resultado en una temporada se calcula con la semilla rival + temporada, a partir de las medallas validadas. Avanza con la hora real, así que el ranking se mueve sin conexión y es el mismo en cada apertura.
- **Siempre se marcan** con un rombo y una nota, en el ranking y en amigos. Es una decisión del agente: presentar bots como personas reales sería engañoso, sobre todo con menores, y choca con las políticas de Google Play.
- Retirarlos cuando haya jugadores reales es filtrar `simulated` en `Leaderboard`.

### Cuenta, amigos y menores de 13

- **Pantalla de edad** (`AgeGate`), la primera vez:
  - es neutral: se elige el año de nacimiento con −10/−1/+1/+10, empezando en el año actual, sin edad sugerida;
  - solo se guarda el grupo de edad; quien cumple 13 este año cuenta como menor;
  - hasta responder, el juego trata al jugador como menor.
- **Menores**: sin login social, nombre elegido de la lista segura, anuncios aptos para familias, y compras e invitaciones tras la puerta parental.
- **Pantalla de amigos** (`scripts/ui/friends_screen.gd`):
  - nombre del jugador;
  - conectar con Google o Facebook (simulado: aparecen 4 amigos de la lista de rivales);
  - código de invitación `ORB-XXXX`, que se copia al portapapeles, y campo para canjear códigos;
  - estado de cada amigo (jugando ahora / hace N h) y sus puntos de temporada.

### Avisos

- **`NotificationCenter`**: avisos por id, con hora y caducidad. Al vencer pasan a la bandeja (campana del menú) y se muestran como aviso emergente. Un aviso caducado se descarta en lugar de llegar tarde.
- **Avisos programados**:
  - energía llena;
  - temporada nueva (caduca cuando termina);
  - último día de la temporada, si participas (caduca cuando termina);
  - nuevo desafío diario, si jugaste el de hoy;
  - resultado de la temporada.
- Se pueden desactivar en Ajustes → Juego → Avisos.
- **Android**: plugin propio `OrbitNotifications`.
  - Fuente en `android/plugins/orbit_notifications/`: Java, `AlarmManager` inexacto y `NotificationManager`.
  - En Android 13+ pide el permiso `POST_NOTIFICATIONS` después de la pantalla de edad.
  - Se incluye en la exportación con el addon `addons/orbit_notifications/` (AAR en `bin/`).
  - Las alarmas no sobreviven a un reinicio del teléfono; el juego las reprograma al abrirse.
  - Sin el plugin (PC, o exportación sin Gradle) solo funciona la bandeja.
- **Recompilar el AAR**:
  1. `cd android/plugins/orbit_notifications && ../../build/gradlew.bat -p . assembleRelease`, con `JAVA_HOME` en el JDK 17 y `local.properties` con `sdk.dir=<SDK de Android>`.
  2. Copiar `build/outputs/aar/orbit_notifications-release.aar` a `addons/orbit_notifications/bin/`.

### Corrección del generador (determinismo)

- **Fallo**: `MovementReach.max_gap` guardaba en caché el alcance usando la altura redondeada, pero lo calculaba con la altura exacta. El primer nivel generado en un proceso fijaba el valor para los siguientes, así que el mismo `LevelSpec` podía dar otro nivel en el teléfono. Se detectó porque un nivel de temporada salía "no verificado".
- **Corrección**:
  - ahora el alcance se calcula con la altura redondeada;
  - el lote genera cada intento a partir de la especificación ya pasada por JSON, exactamente como se guarda.
- Esto cambia algunos niveles generados, así que se regeneraron los desafíos diarios (`daily_seeds.tres`, 30 días desde el 2026-10-18).

### Pendiente (freemium)

1. **Integración real** con Firebase (decisión del propietario). Solo hay que cambiar los proveedores en `Services.reload()`:
   - Authentication (Google; Facebook requiere crear una app de Facebook);
   - Firestore y Functions para rankings, amigos y validación de marcas con las repeticiones;
   - Remote Config para temporadas y economía;
   - FCM para avisos;
   - AdMob en modo familias;
   - Play Billing con verificación en el servidor.
2. **Hora del servidor**: la energía y las temporadas usan el reloj del teléfono, que se puede adelantar.
3. **Pase de temporada**: definir recompensas y precio.
4. **Precios reales y valores de energía**, tras probar con jugadores.
5. **Revisión de privacidad y cumplimiento** (COPPA, Families, GDPR-K) antes de publicar.
