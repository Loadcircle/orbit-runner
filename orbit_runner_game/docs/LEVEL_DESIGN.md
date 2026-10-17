# Diseño de niveles — Orbit Runner

## Alcances del movimiento (valores de `resources/player/movement_tuning.tres`)

Carrera 8 m/s · salto 11,5 m/s (altura ≈ 2,36 m, ~0,73 s en llano) · gravedad 28 subiendo / 45 bajando · salto variable (soltar antes = salto corto) · tiempo de coyote 0,12 s · buffer de salto 0,13 s.

| Movimiento | Alcance usado en el diseño (holgado) | Máximo aproximado |
|---|---|---|
| Salto normal en llano | ≤ 3,5 m | ~5,9 m |
| Salto subiendo +1 m / +1,5 m | ≤ 3 m / ≤ 2,5 m | — |
| Salto largo (deslizar + saltar) | ≤ 6 m | ~7 m |
| Salto + impulso aéreo | ≤ 7,5 m | ~9 m |
| Salto + disco de yo-yo | ≤ 9,5 m en llano o +4 m de subida | ~13 m |
| Yo-yo en el suelo (correr sobre el disco) | escalón de +3,2 m | ~4,5 m |
| Trampolín 20 / 24 | +5 m / +8 m | +7,1 m / +10,3 m |
| Corriente de viento | hasta su altura (7–12 m) | — |

Reglas que salieron de las pruebas (ver `DESIGN_DECISIONS.md` D10): ningún peligro en la zona de aterrizaje de un salto; zonas seguras para esperar antes de plataformas móviles o temporales; no esperar nunca sobre una losa que se rompe; pinchos con pasillo libre ≥ 1 m; aterrizajes de ≥ 6 m tras huecos largos.

## Gramática visual

- **Seguro:** islas de césped (Brisa), bloques menta con tachuelas rojas (Juguetes), losas de arenisca (Ruinas).
- **Impulso:** amarillo/naranja con flechas (trampolín, placa de impulso).
- **Temporal / móvil:** cian y azul; las móviles llevan chevrones de dirección, las temporales son hexagonales y parpadean antes de desaparecer, las que se rompen están agrietadas y tiemblan.
- **Peligro:** magenta/púrpura con púas (pinchos, aspas, robots, láseres con postes rayados).
- **Coleccionables:** chispas (estrella dorada de 4 puntas) y gemas (diamante azul). Las líneas de chispas dibujan los arcos de salto recomendados.

## Campaña y curva de dificultad

| # | Nivel | Mundo | Enseña / combina | Oro | Plata |
|---|---|---|---|---|---|
| T | Primer vuelo | Brisa | Mover, saltar, deslizar bajo láser, yo-yo en suelo y aire, impulso, trampolín, salto largo, viento (con indicaciones) | — | — |
| 1 | Islas de la Brisa | Brisa | Saltos y escalones, primer trampolín, giro de cámara, pinchos sencillos | 26,5 s | 42 s |
| 2 | Saltos del Viento | Brisa | Corrientes de viento, plataformas móviles (adelante, lateral, ascensor), hueco de yo-yo | 32 s | 49,5 s |
| 3 | Puentes de Cristal | Brisa | Losas que se rompen, salto largo, pinchos | 26,5 s | 42 s |
| 4 | Cumbre de las Nubes | Brisa | Escalada vertical: trampolines, viento, ascensor, yo-yo, varios giros | 32 s | 49 s |
| 5 | Taller de Juguetes | Juguetes | Aspas giratorias, placas de impulso, ritmo de plataformas temporales | 32 s | 49,5 s |
| 6 | Engranajes Locos | Juguetes | Robots patrulla, láseres (fijos y parpadeantes), móviles encadenadas | 38,5 s | 58,5 s |
| 7 | Fábrica de Rebotes | Juguetes | Trampolines en cadena, ritmo rápido, impulsos aéreos, aspas | 41 s | 61,5 s |
| 8 | Ruinas del Alba | Ruinas | Precisión: salto largo tras láser, losas, robots, láseres en serie | 32 s | 49 s |
| 9 | Templo del Viento Solar | Ruinas | Torres de viento, yo-yo, temporales, aspas en altura | 36,5 s | 55 s |
| 10 | Corazón del Sol | Ruinas | Desafío final con todo lo anterior, 4 puntos de control | 52 s | 76 s |

Las primeras partidas duran bastante más que el oro (exploración, reapariciones). El piloto automático, sin errores, tarda entre 15 s (tutorial) y ~65 s (nivel final).

## Coleccionables y rejuego

- **3 gemas por nivel** en islas laterales o en el aire: requieren un desvío con yo-yo, impulso aéreo, salto largo o trampolín, o caer y recuperarse con el yo-yo. Las ya conseguidas se ven como "fantasma" (siguen siendo recogibles).
- **Chispas** a lo largo de la ruta (43–90 por nivel), con imán corto.
- **Medallas** de bronce/plata/oro por tiempo; récord personal guardado.
- **Puntos de control** cada 2–4 secciones; caer al mar de nubes o tocar un peligro reaparece en el último activado.

## Herramienta

`scripts/level/level_builder.gd` (DSL) y `tools/build_levels.gd` (los 11 niveles). Los niveles generados usan el mismo DSL (`docs/LIVE_SERVICE.md`). Cada pieza de la ruta se guarda en el metadato `route` del nivel, que usa la barra de progreso del HUD. Ejecutar:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/build_levels.tscn
```

Regenera `scenes/levels/*.tscn` y `resources/levels/level_catalog.tres` (sobrescribe ediciones manuales).
