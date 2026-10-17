# Parámetros para crear assets 3D — Orbit Runner

Guía práctica para agentes y artistas que creen modelos en Blender para este proyecto. Complementa la [guía maestra de identidad](../../../Orbit_Runner_Guia_de_Desarrollo/GUIA_MAESTRA_ORBIT_RUNNER.md); no convierte sus referencias conceptuales en diseños finales ni limita el contenido futuro.

## 1. Identidad que debe conservar el arte

- Juego de plataformas 3D de aventura, optimista y enérgico. El movimiento y la lectura del recorrido son prioritarios.
- Estilo: formas estilizadas, proporciones expresivas y lectura clara desde una cámara trasera y a distancia. Acabado toon/cel-shaded limpio, con materiales mates o satinados y luces de borde moderadas.
- El protagonista debe comunicar agilidad, curiosidad y aventura. Su nombre propio sigue sin estar definido.
- El yo-yo cinético es equipo de locomoción. Debe leerse como dispositivo juguetón de cian/turquesa con acentos naranja y núcleo claro; no como arma. Puede desplegar un disco temporal visualmente legible. La mochila no se convierte en cometa ni ala.
- Las imágenes de `Orbit_Runner_Guia_de_Desarrollo/referencias_visuales/` expresan intención. No se deben calcar ni importar al juego como modelos o texturas finales.

## 2. Unidades, orientación y transformaciones

Usar estas convenciones salvo que una tarea documente una excepción:

| Parámetro | Convención |
|---|---|
| Unidad | Sistema métrico; 1 unidad Blender representa 1 metro en Godot. |
| Arriba | Z positivo dentro de Blender; el exportador glTF convierte a Y arriba para Godot. |
| Frente del asset | Orientar el frente local hacia +Y en Blender, de modo que el asset quede mirando hacia -Z al integrarse en Godot. Confirmar visualmente con un asset de prueba si la configuración del exportador cambia. |
| Escala | Modelar a tamaño real. Aplicar rotación y escala antes de exportar; procurar escala `(1, 1, 1)` y evitar escalas negativas. |
| Origen | Elegirlo por uso y documentarlo. Personajes: centro entre los pies sobre el suelo. Plataformas: centro del volumen de apoyo. Props verticales: centro de la base. Rotores: centro exacto del eje de giro. |
| Nombres | Nombres descriptivos, sin `Cube`, `Sphere` ni `Object`. Usar prefijos consistentes (sección 5). |

No ajustar el tamaño de un asset solamente para que “se vea bien” en Blender. Compararlo con una figura de referencia de 1,8 m y con las medidas de la escena Godot. Las dimensiones de props citadas en documentos conceptuales son puntos de partida sin validar, no requisitos de producción.

## 3. Geometría y rendimiento móvil

- Priorizar silueta, volúmenes grandes, biseles controlados y detalles visibles a distancia de juego. Evitar microgeometría que no cambie la lectura.
- Como presupuesto inicial orientativo, no como límite: personaje protagonista hasta unas **15 000 caras trianguladas**; prop común hasta **2 000**; pieza ambiental repetida hasta **500**. Reducirlos cuando la forma lo permita y revisar tras probar en hardware Android objetivo.
- Usar modificadores no destructivos en `.blend`; aplicar los necesarios en la copia/exportación para GLB. Evitar subdivisiones altas, geometría duplicada interna, caras superpuestas y piezas diminutas separadas sin función visual.
- Revisar normales, caras invertidas, sombreado, costuras, malla no manifold cuando corresponda y objetos fuera de escala. Triangular solo para inspeccionar el presupuesto final, no necesariamente para destruir la malla editable.
- Crear LOD solo si el asset o la escena lo justifican por distancia o rendimiento. No generar variantes automáticamente sin necesidad.
- Evitar transparencias salvo que comuniquen una función importante. Para energía, preferir silueta, patrón, bandas o material opaco con emisión discreta antes que grandes superficies transparentes.

## 4. Materiales, color y renderizador

El proyecto parte de **Godot Compatibility (OpenGL)** como selección provisional. No hay móvil objetivo ni medición de rendimiento todavía. Por ello:

- Usar materiales Principled BSDF sencillos que exporten correctamente a glTF Metallic-Roughness. En Godot, mantener materiales estándar y compatibles con Compatibility.
- No depender de nodos procedurales exclusivos de Blender, shaders personalizados, toon shader exclusivo, decals, transmisión, subsurface complejo ni efectos que glTF/Godot Compatibility no reproduzcan igual. Si un efecto es esencial, describirlo y proponer una alternativa compatible antes de modelar alrededor de él.
- La estética toon se puede sostener con siluetas claras, paleta, valores de color, luces sencillas y bandas de material pintadas; no asumir que una configuración de nodos Blender se conservará en Godot.
- Mantener pocos materiales por asset y compartir materiales entre piezas que usen el mismo acabado. Como guía de producción: un personaje puede usar 2–4 materiales y un prop común 1–2 si la lectura lo permite.
- Paleta funcional de partida: superficies seguras verdes/naturales/cálidas; impulso fijo amarillo y naranja; elementos temporales o móviles azules/cian; peligro magenta, púrpura eléctrico o rojo oscuro; yo-yo activo cian/turquesa con naranja y núcleo claro.
- El color nunca debe ser la única señal de función: añadir diferencias de forma, patrón, orientación, animación o contraste.
- Texturas, cuando hagan falta: potencia de dos, UV sin solapes accidentales y resolución conservadora. Como valores iniciales: personaje 1024 px por mapa; prop común 512 px; pieza grande protagonista de escenario hasta 1024 px. Reutilizar atlas y evitar mapas innecesarios; confirmar su coste en dispositivos reales.
- Limitar emisión a acentos que necesiten comunicar actividad. No usar bloom como requisito de lectura.

## 5. Organización y nombres

Guardar la fuente editable y el intercambio por separado:

```text
assets_source/blender/
  <nombre_asset>.blend
  PARAMETROS_ASSETS_ORBIT_RUNNER.md
art/models/
  <nombre_asset>.glb
```

Nombrar con prefijo + función + variante opcional, en `PascalCase` o `snake_case` consistente, sin espacios ni acentos:

- `CHR_` personaje; `PROP_` prop; `ENV_` pieza ambiental; `PLAT_` plataforma; `HAZ_` peligro.
- `SM_` malla estática; `SK_` esqueleto; `M_` material; `T_` textura; `AN_` animación.
- Ejemplos: `CHR_Adventurer`, `PROP_KineticYoyo`, `PLAT_Safe_01`, `HAZ_Spinner_01`, `M_Cloth_Teal`.

Organizar cada asset en una colección con su nombre. Eliminar cámaras, luces, cubos de referencia y objetos auxiliares de la colección exportada. Las guías de escala pueden permanecer en el `.blend`, fuera de la selección exportada.

## 6. Frontera entre arte y juego

- El asset contiene geometría, UV, materiales y, cuando se solicita, rig/animación visual. No incluir scripts, reglas de nivel, colisiones finales, triggers, lógica de rebote, señales ni comportamiento de gameplay dentro de Blender.
- Las colisiones de juego, activadores, cuerpos físicos, puntos de anclaje funcionales y lógica se implementan en Godot. Si el arte necesita una malla de colisión de referencia, nombrarla claramente y separarla de la malla visual; el agente de gameplay decidirá si la usa.
- Separar piezas móviles/articuladas cuando deban animarse. Acordar pivote y nombres de huesos antes de producir animaciones. No hornear comportamiento que deba permanecer ajustable en Godot.
- Para el yo-yo, producir solo las piezas visuales requeridas (dispositivo, disco y/o elementos de cuerda/retorno solicitados). No diseñar ataques ni proyectiles ofensivos.

## 7. Exportación Blender → GLB → Godot

1. Guardar el `.blend` editable en `assets_source/blender/` y exportar el `.glb` correspondiente a `art/models/`.
2. Usar **glTF 2.0 Binary (`.glb`)**. Exportar solo la colección u objetos del asset; incluir geometría, materiales y armature/animaciones únicamente cuando existan y sean parte del encargo. Omitir cámaras y luces salvo petición explícita.
3. Mantener la conversión de ejes glTF habilitada (Y arriba). Aplicar escala/rotación, revisar el frente `-Z` en Godot y conservar los pivotes comprobados.
4. Exportar materiales Principled/glTF Metallic-Roughness y texturas realmente usadas. Evitar rutas externas rotas; revisar que queden incluidas o accesibles junto al GLB.
5. Importar el GLB en Godot y revisar tamaño, orientación, origen, materiales, animaciones, normales y lectura a distancia. Corregir el `.blend` fuente y reexportar si algo falla.
6. No declarar que un recurso funciona por el solo hecho de que el exportador produjo un archivo. Confirmar su integración en Godot; dejar anotadas las limitaciones que no puedan probarse.

## 8. Entrega que debe acompañar cada asset

Al generar un asset, informar en el mensaje o nota del encargo:

- qué recurso se creó y para qué función/lectura está pensado;
- rutas `.blend` y `.glb`;
- dimensiones aproximadas, orientación y ubicación del origen;
- cantidad de triángulos y materiales/texturas usados;
- ajustes o excepciones de exportación relevantes;
- qué se verificó dentro de Godot y qué falta validar en hardware.

No añadir paquetes, bibliotecas, texturas ni recursos de terceros sin una necesidad clara; identificar licencia y atribución cuando un recurso externo sea autorizado e integrado.
