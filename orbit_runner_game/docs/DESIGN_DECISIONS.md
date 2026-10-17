# Registro de decisiones de diseño — Orbit Runner

Decisiones particulares o difíciles de revertir tomadas durante el desarrollo autónomo (2026-10-16/17). Cada entrada: contexto, opciones, decisión, motivo e impacto. Pensado para revisión del propietario.

---

## D1. Esquema de acciones: un botón contextual para deslizar e impulso aéreo
- **Contexto:** la referencia de HUD muestra tres botones (saltar, yo-yo, deslizar). La guía también menciona impulso aéreo, salto largo, planeo y rebote en paredes.
- **Opciones:** (a) un botón por acción (4–6 botones); (b) tres botones con un botón contextual.
- **Decisión:** tres botones: **Saltar** (principal), **Yo-yo**, **Acción** = deslizar en el suelo / impulso aéreo en el aire. **Salto largo** = saltar mientras se desliza. Sin planeo ni rebote en paredes en esta versión.
- **Motivo:** comodidad táctil (pulgar derecho) y lectura clara. Las corrientes de viento cubren la fantasía de "flotar".
- **Impacto:** el repertorio es corto pero combinable (salto → impulso → yo-yo encadenados). Planeo y paredes quedan como ampliaciones futuras.

## D2. Reglas del yo-yo cinético
- **Contexto:** la guía fija el concepto (disco temporal de rebote) pero no las reglas.
- **Decisión:** en el suelo, el yo-yo se despliega **4 m por delante** (correr encima = rebote alto, útil para escalones de hasta ~3,5 m). En el aire, se despliega **bajo y delante** del jugador (≈ segundo salto, cruza huecos de hasta ~9,5 m o sube ~4 m). **Una carga aérea por salto**, que se recupera al tocar suelo o un trampolín. Disco de 1,5 s que parpadea antes de plegarse; un rebote lo consume y vuelve a la mano. Cuerda visible mientras está fuera.
- **Motivo:** evita escaladas infinitas, mantiene el yo-yo como herramienta de locomoción y legible (nunca ofensivo).
- **Impacto:** define el techo de alcance de todos los niveles (ver `LEVEL_DESIGN.md`).

## D3. Peligros: sin vida, reaparición inmediata en el último punto de control
- **Opciones:** barra de vida, vidas limitadas o reaparición instantánea.
- **Decisión:** tocar un peligro o caer devuelve al último punto de control en ~0,55 s, sin vidas ni "game over". El cronómetro sigue (penaliza la medalla, no el progreso).
- **Motivo:** tono optimista, reinicios rápidos y comprensibles (guía §4 y §5).
- **Impacto:** la dificultad se expresa en medallas y en el logro "Sin un rasguño".

## D4. Cámara guiada por zonas, no por la velocidad
- **Opciones:** cámara que gira con el personaje vs. cámara con orientación fijada por la ruta.
- **Decisión:** la orientación la decide la ruta (zonas de cámara por plataforma, generadas automáticamente). El jugador puede girarla un poco (Q/R, stick derecho o arrastre táctil) y vuelve sola.
- **Motivo:** con movimiento relativo a la cámara, una cámara que sigue a la velocidad hace que "adelante" cambie constantemente; las zonas mantienen la entrada predecible y los giros de ruta legibles.
- **Impacto:** cada giro de ruta necesita su zona (lo hace el generador).

## D5. Campaña: tutorial + 10 niveles en 3 mundos
- **Decisión:** *Primer vuelo* (tutorial) + **Islas de la Brisa** (4 niveles), **Taller de Juguetes** (3) y **Ruinas Solares** (3). Desbloqueo lineal (completar el anterior). Gemas y medallas son opcionales y alimentan recompensas, nunca bloquean la campaña.
- **Motivo:** curva enseñar → combinar → dominar → culminar, y biomas reconocibles.
- **Impacto:** 30 gemas y 10 medallas de oro como objetivos de rejuego.

## D6. Economía y recompensas sin conexión ni pagos
- **Decisión:** moneda **chispas** (recogidas en niveles y entregadas por logros) para comprar cosméticos; otros cosméticos se desbloquean con **gemas**, **medallas de oro** o **logros**. 8 trajes y 7 yo-yos (cambian colores del personaje, del yo-yo/disco y de la estela). Sin anuncios, compras ni servicios externos.
- **Motivo:** recompensas funcionales y visibles sin afectar el equilibrio jugable.
- **Impacto:** precios de 120 a 400 chispas; una campaña completa (~550 chispas) + logros (~2 000) permiten comprarlo todo con algo de rejuego.

## D7. Medallas calculadas a partir de la longitud de la ruta
- **Decisión:** oro = longitud/7 m·s⁻¹ + 1,6 × esperas inevitables (móviles/temporales) + 4 s; plata = oro × 1,35 + 6 s; bronce = terminar.
- **Motivo:** objetivos coherentes entre niveles; el piloto automático (sin errores) bate el oro por ~20 %, así que es exigente pero alcanzable.
- **Impacto:** los tiempos están en `level_catalog.tres` y se pueden ajustar a mano tras pruebas reales.

## D8. Generación de niveles con un DSL (en vez de colocarlos a mano en el editor)
- **Decisión:** los niveles se escriben en `tools/build_levels.gd` con un DSL (`plat`, `mover`, `crumble`, `timed`, `wind`, `spinner`…) que coloca piezas por **hueco** y **desnivel** respecto al borde anterior.
- **Motivo:** garantiza que cada salto respeta el alcance documentado; permitió iterar y corregir rápido decenas de problemas detectados por el piloto automático.
- **Impacto:** las escenas `.tscn` resultantes son editables en Godot, pero **regenerar sobrescribe** los cambios manuales.

## D9. Renderizador Compatibility (cambio a mitad del desarrollo)
- **Contexto:** se inició con *Mobile* (Vulkan) pensando en el S25.
- **Decisión:** **Compatibility** en Android y PC (detalle en `TECHNICAL_DECISIONS.md` §2).
- **Motivo:** en el emulador Android el driver Vulkan falló y Godot abortó sin recurrir a OpenGL; el juego no necesita funciones exclusivas de Vulkan y el aspecto es equivalente.
- **Impacto:** máxima compatibilidad; si se quisiera más calidad en el S25 podría reactivarse *Mobile* solo en Android tras medirlo.

## D10. Correcciones de diseño detectadas por el piloto automático
El piloto automático (que usa solo las acciones del InputMap) reveló problemas reales que se corrigieron:
1. **Doble muerte al reaparecer:** las áreas de peligro conservaban el solape anterior → 0,35 s de protección tras reaparecer.
2. **Trampolines imposibles de pisar corriendo:** la base bloqueaba antes del disparador → disparador más ancho y bajo.
3. **Trampolines demasiado justos** para subir +5/+8 m → fuerza 20 y 24 (margen de ~2 m).
4. **Corrientes de viento difíciles de mantener** a 8 m/s → arrastre de aire dentro de la columna y radio 1,65 m.
5. **Plataformas temporales desfasadas al revés** (la siguiente aparecía antes) → la fase pasa a ser un retardo; ritmo recalibrado a ~0,8 s por salto.
6. **Plataformas móviles con pausa de 0,24 s** en los extremos → 1 s.
7. **Impulso de velocidad que duraba demasiado en el suelo** → decae 2,5× más rápido en el suelo.
8. **Láseres en la zona de aterrizaje** de un salto → movidos ≥2,5 m después del aterrizaje.
9. **Pinchos en la línea de salida de un giro / pasillos de 0,35 m** → pasillos libres de ≥1 m y pinchos fuera de la salida.
10. **Robots patrulla en la zona de aterrizaje o donde hay que esperar** → carriles que cruzan la ruta más adelante; se eliminó uno en una plataforma de giro.
11. **Aspas que cubrían toda la plataforma donde hay que esperar** (móvil/temporal) y puntos de control dentro del barrido → esas plataformas pasan a 14 m (XL) con zonas seguras en ambos extremos.
12. **Plataforma temporal justo después de una losa que se rompe** (obliga a esperar sobre algo que cae) → reordenado: primero las temporales, después las losas.
13. **Aterrizajes de 3 m tras huecos de impulso/yo-yo** → plataformas de 6 m.
14. **Combinación impulso + cadena de losas** → plataforma larga intermedia para frenar.
15. **Láser + salto largo:** el láser se acercó al borde para que el deslizamiento bajo el láser enlace con el salto largo.

## D11. Indicaciones del tutorial adaptadas al dispositivo
- **Decisión:** cada indicación tiene variante de teclado y variante táctil (`_TOUCH`); se elige según el modo de entrada activo.
- **Impacto:** el tutorial enseña con el control real del jugador sin bloques largos de texto.

## D12. Arte: protagonista con malla rígida por hueso y colores planos
- **Decisión:** protagonista estilizado modelado en Blender por script, con piezas rígidas por hueso (sin pesos suaves) y materiales planos convertidos a toon al importar; sin texturas.
- **Motivo:** silueta limpia y legible a distancia, coste muy bajo en móvil y reproducible.
- **Impacto:** el estilo es más "juguete" que la lámina conceptual; un artista puede sustituir el GLB manteniendo nombres de materiales (`M_Jacket`, `M_Hair`, etc.) para que los cosméticos sigan funcionando.

## D13. Audio sintetizado propio
- **Decisión:** música y efectos generados por procedimiento (sin bibliotecas de terceros).
- **Motivo:** cero riesgo de licencias y coherencia; reproducible.
- **Impacto:** estética *chiptune* sencilla; sustituir por música compuesta es una mejora natural de producción.

## D14. Niveles generados por motivos, validados por un bot (juego como servicio)
- **Decisión:** el contenido renovable (diario, torre, futuras temporadas) sale de un generador que encadena 15 motivos de diseño probado; cada pieza anota la técnica que la resuelve y un bot con cuatro perfiles de habilidad la juega para medir la dificultad.
- **Motivo:** ritmo de contenido sin diseñar cada nivel a mano, con la garantía de que todo nivel publicado es pasable.
- **Impacto:** detalle en `docs/LIVE_SERVICE.md`. La calibración actual es contra el bot; falta la calibración con personas.

## D15. El teléfono genera el diario y la torre desde la semilla
- **Decisión:** el diario usa la fecha UTC como semilla y la torre la semana; el generador corre en el dispositivo. Las semillas validadas por el bot en PC (`daily_seeds.tres`) tienen prioridad.
- **Motivo:** contenido diario sin descargas y jugable sin conexión; el futuro servidor solo tendrá que publicar semillas y verificar marcas.

## D16. Torre del Viento: subida infinita sin vidas
- **Decisión:** reintentos ilimitados desde el último punto de control (cada 10 pisos); la puntuación es el piso más alto y la subida termina desde la pausa.
- **Motivo:** principio del plan "sin energía ni vidas"; el récord semanal da el motivo para volver.

## D17. Repeticiones exactas por entradas
- **Decisión:** se graban las entradas en bruto de cada tic de física y la guiñada de cámara; el fantasma usa poses cada 0,1 s.
- **Motivo:** la misma grabación sirve para el fantasma y para verificar marcas en el servidor (la reproducción da el mismo tiempo exacto).
- **Impacto:** ~18 KB por minuto de partida (más que lo estimado en el plan).

## D18. Maestría con premio visible
- **Decisión:** 4 estrellas por nivel (oro, 3 gemas, todas las chispas, sin caídas); dominar un mundo da un traje propio.
- **Motivo:** rejugar la campaña con objetivos claros sin tocar el equilibrio.

## D19. Misiones locales con chispas
- **Decisión:** 3 misiones diarias y 7 semanales elegidas por fecha, premiadas con chispas.
- **Motivo:** hábito de vuelta ya en la versión sin conexión; la XP del pase de temporada llegará con la fase D.

## Pendiente de decisión del propietario
- Nombre definitivo del juego y del protagonista (sigue siendo *Orbit Runner* provisional).
- Identificador del paquete Android (`com.orbitrunner.game` es provisional) y keystore de publicación.
- Validar en el S25: sensibilidad del joystick, tamaño por defecto de los botones y tiempos de medalla.
