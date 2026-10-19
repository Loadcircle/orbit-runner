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

30 niveles, 10 por mundo (D20). La etiqueta de la tarjeta es la categoría de dificultad en la misma escala que el diario y las temporadas: Brisa va de Fácil a Difícil, Taller de Medio a Difícil y Ruinas de Difícil a Extremo. Los primeros de cada mundo son los hechos a mano (presentan las mecánicas); los demás salen del generador con las mecánicas que el mundo ya enseñó y están validados por el bot (índice de dificultad 0–100, ver `LIVE_SERVICE.md`). Las medallas de los generados salen de las carreras del bot experto.

| # | Nivel | Mundo | Etiqueta | Origen | Enseña / combina | Oro | Plata |
|---|---|---|---|---|---|---|---|
| T | Primer vuelo | Brisa | — | A mano | Mover, saltar, deslizar bajo láser, yo-yo en suelo y aire, impulso, trampolín, salto largo, viento (con indicaciones) | — | — |
| 1 | Islas de la Brisa | Brisa | Fácil | A mano | Saltos y escalones, primer trampolín, giro de cámara, pinchos sencillos | 26,5 s | 42 s |
| 2 | Saltos del Viento | Brisa | Fácil | A mano | Corrientes de viento, plataformas móviles (adelante, lateral, ascensor), hueco de yo-yo | 32 s | 49,5 s |
| 3 | Puentes de Cristal | Brisa | Fácil | A mano | Losas que se rompen, salto largo, pinchos | 26,5 s | 42 s |
| 4 | Cumbre de las Nubes | Brisa | Fácil | A mano | Escalada vertical: trampolines, viento, ascensor, yo-yo, varios giros | 32 s | 49 s |
| 5 | Praderas Flotantes | Brisa | Fácil | Generado: Fácil, índice 6,3 | Pinchos, escalones, losas | 40,5 s | 59,5 s |
| 6 | Arco de las Gaviotas | Brisa | Fácil | Generado: Fácil, índice 6,9 | Pinchos, escalones, losas | 42,5 s | 63 s |
| 7 | Colinas Saltarinas | Brisa | Medio | Generado: Medio, índice 19,4 | Trampolines, escalones, pinchos, losas | 38 s | 56 s |
| 8 | Puente de Cometas | Brisa | Medio | Generado: Medio, índice 18,2 | Escalones, pinchos, losas, disco, móviles | 37,5 s | 55,5 s |
| 9 | Acantilados Celestes | Brisa | Medio | Generado: Medio, índice 18,9 | Pinchos, escalones, losas, móviles | 39 s | 57,5 s |
| 10 | Ojo del Huracán | Brisa | Difícil | Generado: Difícil, índice 38,2 | Viento, pinchos, escalones, trampolines, losas | 40,5 s | 60 s |
| 11 | Taller de Juguetes | Juguetes | Medio | A mano | Aspas giratorias, placas de impulso, ritmo de plataformas temporales | 32 s | 49,5 s |
| 12 | Engranajes Locos | Juguetes | Medio | A mano | Robots patrulla, láseres (fijos y parpadeantes), móviles encadenadas | 38,5 s | 58,5 s |
| 13 | Fábrica de Rebotes | Juguetes | Medio | A mano | Trampolines en cadena, ritmo rápido, impulsos aéreos, aspas | 41 s | 61,5 s |
| 14 | Muelles Traviesos | Juguetes | Medio | Generado: Medio, índice 19,3 | Pinchos, trampolines, escalones, losas | 42,5 s | 63 s |
| 15 | Cadena de Montaje | Juguetes | Medio | Generado: Medio, índice 21,2 | Aspas, móviles, losas, láseres, escalones, robots, temporales, pinchos | 45 s | 66,5 s |
| 16 | Tren de Cuerda | Juguetes | Medio | Generado: Medio, índice 25,8 | Pinchos, temporales, escalones, aspas, combos, robots, placas de impulso | 42,5 s | 62,5 s |
| 17 | Torre de Bloques | Juguetes | Difícil | Generado: Difícil, índice 44,1 | Láseres, trampolines, pinchos, placas de impulso, escalones, combos | 45 s | 66,5 s |
| 18 | Pasillo de Láseres | Juguetes | Difícil | Generado: Difícil, índice 40,4 | Pinchos, trampolines, láseres, losas, escalones | 44 s | 65 s |
| 19 | Desfile de Robots | Juguetes | Difícil | Generado: Difícil, índice 48,7 | Láseres, combos, robots, aspas, escalones, pinchos, móviles | 61,5 s | 90,5 s |
| 20 | Caja Sorpresa | Juguetes | Difícil | Generado: Difícil, índice 48,4 | Aspas, combos, robots, pinchos, escalones, temporales | 40,5 s | 60 s |
| 21 | Ruinas del Alba | Ruinas | Difícil | A mano | Precisión: salto largo tras láser, losas, robots, láseres en serie | 32 s | 49 s |
| 22 | Templo del Viento Solar | Ruinas | Difícil | A mano | Torres de viento, yo-yo, temporales, aspas en altura | 36,5 s | 55 s |
| 23 | Corazón del Sol | Ruinas | Difícil | A mano | Desafío final con todo lo anterior, 4 puntos de control | 52 s | 76 s |
| 24 | Escalinata Dorada | Ruinas | Difícil | Generado: Difícil, índice 42,6 | Pinchos, escalones, disco, láseres, combos, losas, viento | 51,5 s | 76 s |
| 25 | Jardines Colgantes | Ruinas | Difícil | Generado: Difícil, índice 43 | Robots, temporales, aspas, losas, móviles, pinchos, escalones | 58,5 s | 86,5 s |
| 26 | Puerta del Eclipse | Ruinas | Difícil | Generado: Difícil, índice 44,7 | Robots, láseres, losas, aspas, pinchos, combos | 74 s | 109 s |
| 27 | Mirador del Ocaso | Ruinas | Difícil | Generado: Difícil, índice 42,4 | Pinchos, móviles, losas, láseres, robots, escalones, aspas | 54 s | 80 s |
| 28 | Cripta del Espejismo | Ruinas | Difícil | Generado: Difícil (pedido Extremo), índice 50,6 | Pinchos, robots, disco, láseres, temporales, aspas, viento, losas | 93,5 s | 138,5 s |
| 29 | Llamarada Eterna | Ruinas | Extremo | Generado: Extremo, índice 61,1 | Robots, aspas, viento, pinchos, combos, escalones | 60,5 s | 89 s |
| 30 | Trono del Sol | Ruinas | Extremo | Generado: Extremo, índice 59,4 | Pinchos, robots, temporales, láseres, viento, aspas, combos | 92 s | 135,5 s |

Las primeras partidas duran bastante más que el oro (exploración, reapariciones). El piloto automático, sin errores, tarda entre 15 s (tutorial) y ~65 s (*Corazón del Sol*); los generados más largos (*Cripta del Espejismo*, *Trono del Sol*) rondan los 80 s del bot experto.

## Coleccionables y rejuego

- **3 gemas por nivel** en islas laterales o en el aire: requieren un desvío con yo-yo, impulso aéreo, salto largo o trampolín, o caer y recuperarse con el yo-yo. Las ya conseguidas se ven como "fantasma" (siguen siendo recogibles).
- **Chispas** a lo largo de la ruta (43–90 por nivel), con imán corto.
- **Medallas** de bronce/plata/oro por tiempo; récord personal guardado.
- **Puntos de control** cada 2–4 secciones; caer al mar de nubes o tocar un peligro reaparece en el último activado.

## Herramienta

`scripts/level/level_builder.gd` (DSL) y `tools/build_levels.gd` (el tutorial, los 10 niveles a mano y la reconstrucción de los 20 generados desde `tools/campaign_generated.json`). Los niveles generados usan el mismo DSL (`docs/LIVE_SERVICE.md`). Cada pieza de la ruta se guarda en el metadato `route` del nivel, que usa la barra de progreso del HUD. Ejecutar:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tools/build_levels.tscn
```

Regenera `scenes/levels/*.tscn` y `resources/levels/level_catalog.tres` (sobrescribe ediciones manuales).
