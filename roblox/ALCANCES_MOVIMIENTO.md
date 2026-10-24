# Alcances del movimiento (Roblox, plantilla Platformer)

Medido el 2026-10-23 en Studio (Play, cliente) sobre un suelo plano de pruebas, con la
entrada real del teclado (W mantenida, Espacio, Shift, E) y el moveset vigente (R15/R18):
gravedad 160 studs/s², velocidad de carrera 22 studs/s (6,3 m/s), salto 8 studs,
constantes de `ReplicatedStorage.Platformer.Constants` y yo-yo de `MovementTuning`.
Todas las cifras están en **metros** (K = 3,5 studs/m), con los pies como referencia.

- **Alto:** la altura máxima de los pies sobre el punto de despegue.
- **Mismo nivel:** la distancia horizontal desde el despegue hasta volver a la misma altura.
- **+N / −N m:** la distancia máxima a la que se puede aterrizar en una plataforma N metros
  más alta o más baja (el último punto de la trayectoria a esa altura).

Es la regla para diseñar los niveles de la Fase 2 (R18). Si cambia una constante de la
plantilla o del yo-yo, hay que volver a medir.

## Tabla medida

| Movimiento (teclas, tiempos) | Alto | Mismo nivel | +1 m | +2 m | +3 m | +4 m | −1 m | −3 m | −6 m |
|---|---|---|---|---|---|---|---|---|---|
| Salto | 2,31 | 3,87 | 3,35 | 2,61 | — | — | 4,19 | 4,92 | 5,65 |
| Doble salto en la cumbre (+0,32 s) | 4,56 | 6,70 | 6,39 | 5,97 | 5,55 | 4,95 | 7,04 | 7,56 | 8,17 |
| Doble salto tardío (+0,56 s) | 2,96 | 7,75 | 7,33 | 6,81 | — | — | 8,09 | 8,69 | 9,42 |
| Salto + dash en la cumbre | 2,31 | 8,89 | 8,32 | 6,86 | — | — | 9,31 | 9,94 | 10,67 |
| Salto + doble + dash | 4,56 | 11,58 | 11,27 | 10,85 | 10,30 | 9,35 | 11,87 | 12,31 | 13,05 |
| Salto largo (rodar → salto en 0,3 s) | 1,91 | 9,71 | 8,29 | — | — | — | 10,85 | 12,54 | 14,80 |
| Salto largo + doble | 3,31 | 13,95 | 13,50 | 13,08 | 12,27 | — | 14,26 | 14,89 | 15,60 |
| Salto largo + doble + dash | 3,41 | 18,85 | 18,41 | 17,97 | 16,65 | — | 19,16 | 19,66 | 20,42 |
| Yo-yo desde el suelo (disco a 4 m, se corre encima) | 4,52 | 5,55 | 5,23 | 4,81 | 4,39 | 3,66 | 5,86 | 6,38 | 7,01 |
| Salto + yo-yo en el aire | 6,22 | 9,01 | 8,69 | 8,38 | 8,06 | 7,64 | 9,21 | 9,63 | 10,26 |
| Salto + yo-yo + doble + dash | 7,80 | 17,48 | 17,27 | 16,95 | 16,64 | 16,33 | 17,69 | 18,11 | 18,74 |
| Combo completo: largo → doble → dash → yo-yo → doble → dash | 7,99 | 32,58 | 32,37 | 32,16 | 31,85 | 31,53 | 32,90 | 33,31 | 33,84 |
| Vertical sin avanzar: salto → doble → yo-yo → doble | 10,34 | — | | | | | | | |

Notas de las reglas de la plantilla que salen de la medición:

- El rebote del yo-yo (y el del trampolín) **devuelve el doble salto y el dash**. Por eso el
  yo-yo es el eslabón que duplica un combo: dos dobles saltos y dos dash en un mismo vuelo.
- Hay una carga de yo-yo por vuelo. En el aire, si ya se cae a más de 3 m/s, el disco
  aparece bajo los pies y rebota en el acto (un "tercer salto"). Si se sube o se está en la
  cumbre, se lanza por delante y por debajo (0,32 s de avance, 1,4 m más abajo).
- El doble salto **conserva casi toda la velocidad** del salto largo, y el dash le añade
  12 studs (3,4 m) a 60 studs/s y sostiene la altura 0,2 s.
- No se puede hacer doble salto durante los 0,2 s de un dash.
- Al chocar contra una pared en el salto largo, el personaje queda aturdido (Stun).
- Hay 0,15 s de coyote time: se puede saltar justo después de salir del borde.
- No hay salto variable: soltar el botón antes no corta el salto.

## Escalones de diseño

Los huecos se miden **de borde a borde** y en el mismo nivel. Para que se puedan hacer sin
rozar el límite, cada escalón deja como máximo el 85 % de lo medido; el jugador nuevo
necesita ese margen, sobre todo en móvil. Pasar de un escalón al siguiente exige el
movimiento nuevo.

| Escalón | Pide | Hueco (borde a borde) | Subida máxima | Uso |
|---|---|---|---|---|
| E0 | Correr / salto suelto | ≤ 2,0 m | ≤ 1,5 m | Ritmo, descanso, monedas |
| E1 | Salto | 2,0 – 3,3 m | ≤ 1,8 m | Base del mundo 1 |
| E2 | Doble salto | 3,5 – 5,7 m | ≤ 3,8 m | El escalón "flotante" habitual |
| E3 | Salto + dash o doble tardío | 5,7 – 7,5 m | ≤ 1,8 m | Distancia sin altura |
| E4 | Doble + dash | 7,5 – 9,8 m | ≤ 3,8 m (≈ 8 m de hueco a +3 m) | Primer combo |
| E5 | Salto largo (+ doble) | 8 – 11,8 m | ≤ 2,5 m | Pide carrerilla recta sin paredes |
| E6 | Largo + doble + dash | 12 – 16 m | ≤ 2,5 m | Combo de distancia máximo sin yo-yo |
| Y1 | Yo-yo desde el suelo | subida 2,3 – 3,8 m | ≤ 3,8 m | Muro o repisa que el salto no alcanza |
| Y2 | Salto + yo-yo | subida 3,8 – 5,2 m | ≤ 5,2 m | Altura que el doble salto no da |
| Y3 | Salto + yo-yo + doble (+ dash) | 12 – 14,8 m o subida 5,2 – 6,6 m | ≤ 6,6 m | Combo con yo-yo |
| Y4 | Combo completo | 16 – 27 m | — | Desafío opcional, gemas, atajos |

- **Bajadas:** caer da más alcance (columnas −1/−3/−6 m). Una bajada de 3 m deja que un E2
  cubra unos 6,4 m. Las bajadas sirven para que un tramo largo se sienta generoso.
- **Combos de cadena:** varias plataformas pequeñas seguidas en el aire, por ejemplo un E2 a
  una plataforma de 2 m, un salto que no toca el suelo y yo-yo encima. Ver
  `Salto + yo-yo + doble + dash`.
- **Plataformas de aterrizaje:** al menos 3 × 3 m en E0–E3. En E4 o más, al menos 4 m de
  fondo, porque se llega con más velocidad.
- **Carrerilla:** el salto largo necesita unos 3 m de suelo recto antes del borde (rodar
  0,35 s) y nada delante a la altura del pecho, para no chocar y aturdirse.
