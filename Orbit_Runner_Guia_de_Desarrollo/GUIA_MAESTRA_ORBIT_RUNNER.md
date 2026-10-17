# ORBIT RUNNER
## Guía maestra de identidad y desarrollo

**Estado del nombre:** provisional, aprobado como nombre de trabajo actual  
**Tipo de documento:** guía de identidad y referencia para desarrollo  
**Versión:** 1.0

---

## 1. Propósito y alcance de esta guía

Esta guía reúne la identidad central de **Orbit Runner** para que diseño, arte, animación, programación, audio y producción compartan una misma dirección. Consolida los conceptos previos y establece un vocabulario común para hablar del protagonista, su yo-yo, el movimiento, los escenarios, los peligros, la presentación visual y la interfaz.

**Esta guía no define ni limita el alcance del proyecto.** No establece un máximo de niveles, mecánicas, modos, plataformas, recursos, presupuesto ni duración total del desarrollo. Las ideas y sistemas incluidos describen la identidad que se busca y ofrecen una base de trabajo; el equipo podrá ampliarlos, desarrollarlos o reorganizarlos según las decisiones de producción.

Las cuatro imágenes adjuntas son **referencias de intención y ejemplos de dirección visual**. Comunican forma, color, tono, lectura y posibles soluciones. No son diseños finales, especificaciones de modelado, capturas de un juego terminado ni una representación exacta de los recursos que se deban producir. El arte final debe adaptarse a las necesidades reales de cámara, jugabilidad, rendimiento, accesibilidad y estilo del juego.

Cuando una referencia previa entra en conflicto con esta guía, prevalece la dirección consolidada aquí. Los valores numéricos heredados se consideran puntos iniciales para prototipos y ajuste, salvo que un documento técnico posterior los confirme expresamente.

## 2. Identidad del juego

### 2.1 Nombre

El nombre de trabajo unificado es **Orbit Runner**. Sigue siendo provisional y puede cambiar más adelante mediante decisión del equipo. Se eliminan como nombres de proyecto en documentos futuros *Kite Kid*, *Leap Runner*, *Yo-yo Kid* y *Orbit Runner 3D*; pueden conservarse únicamente como referencias históricas.

El protagonista todavía no tiene un nombre propio definitivo. “Orbit” puede usarse como nombre interno o apodo de trabajo, pero no implica una decisión de narrativa o marca.

### 2.2 Definición breve

**Orbit Runner es un juego de plataformas 3D de acción y aventura centrado en correr, saltar y encadenar movimientos acrobáticos con la ayuda de un yo-yo cinético que se transforma temporalmente en una superficie de impulso.** El jugador lee el espacio, conserva el ritmo y encuentra rutas de movimiento a través de escenarios expresivos y peligros dinámicos.

### 2.3 Fantasía del jugador

Sentirse ágil, ingenioso y audaz: correr por circuitos tridimensionales, improvisar en el aire y usar un artefacto personal para convertir obstáculos y vacíos en oportunidades de movimiento. El dominio se expresa en fluidez, precisión y creatividad, no en derrotar enemigos.

### 2.4 Pilares de identidad

1. **El movimiento es la recompensa.** La aceleración, el salto, el vuelo breve, los rebotes y las transiciones deben sentirse expresivos y conectados.
2. **El yo-yo amplía la locomoción.** Es un artefacto cinético reconocible y útil para desplazarse; no es un arma ni la base de un sistema de combate.
3. **El espacio se entiende al jugar.** Superficies seguras, puntos de impulso, elementos temporales y peligros se distinguen con forma, color, animación y composición.
4. **El tono es optimista y enérgico.** La aventura puede presentar retos y altura, pero mantiene una personalidad juguetona, luminosa y accesible.
5. **La identidad admite crecimiento.** Esta dirección orienta futuras decisiones sin cerrar posibilidades de contenido o producción.

## 3. Protagonista y artefacto cinético

### 3.1 Protagonista

La referencia actual es un joven aventurero de proporciones estilizadas, expresivo y fácil de leer durante el juego. La silueta combina cabello llamativo, gafas protectoras, ropa ligera de explorador, guantes y calzado deportivo de rebote. La ropa puede evolucionar; debe conservarse la impresión de agilidad, curiosidad y preparación para explorar.

La lámina propone cabeza y extremidades algo acentuadas para comunicar poses y acciones desde una cámara distante. Es una intención visual, no una proporción obligatoria. El diseño final debe sostener una silueta clara en carrera, salto, caída y uso del artefacto.

### 3.2 Yo-yo cinético

El **yo-yo cinético** es el elemento icónico del protagonista y la mecánica distintiva de la identidad actual. En reposo es un dispositivo tecnológico compacto que se porta en la cadera o se acopla al equipo. Al lanzarlo, sus partes se separan o despliegan para formar durante un breve intervalo una plataforma/disco giratorio de energía, sobre la que el protagonista puede rebotar y redirigir su trayectoria.

Su lenguaje visual combina cian o turquesa luminoso, acentos naranja solar y un núcleo claro. La cuerda, el giro, la expansión y el retorno ayudan a comunicar conexión, impulso y tiempo disponible. Debe leerse como una herramienta de locomoción juguetona, no como un proyectil ofensivo.

La mochila es un accesorio compacto de transporte y apoyo visual. **No se despliega como cometa ni como ala** en la dirección consolidada. El planeo, si se implementa, es una capacidad de movimiento del protagonista o de su equipo, y no convierte la mochila en el objeto principal.

### 3.3 Secuencia de uso de referencia

1. El jugador lanza el yo-yo hacia una posición útil.
2. El yo-yo se despliega en un disco temporal y claramente legible.
3. El protagonista aterriza o rebota sobre él para obtener impulso vertical, horizontal o una combinación definida por el diseño del nivel.
4. Antes de retirarse, el disco comunica visualmente que su duración termina; después se repliega y vuelve al protagonista.

La duración de **1,5 segundos** aparece en los conceptos previos como valor de referencia para prototipado. No es un requisito definitivo. El tiempo, el alcance, el impulso, el enfriamiento y las reglas de recuperación se deben ajustar con pruebas de jugabilidad.

## 4. Movimiento y experiencia de juego

El juego prioriza una locomoción con inercia y cambios de ritmo. El conjunto de acciones ya explorado incluye correr, saltar, encadenar saltos, realizar un impulso aéreo, rebotar con el yo-yo, deslizarse, efectuar saltos largos, planear brevemente, rebotar en paredes y aprovechar corrientes de aire o trampolines. Este repertorio comunica la dirección buscada; **no constituye un límite ni una lista cerrada de funciones**.

Principios para diseñar y ajustar el movimiento:

- La aceleración y la frenada deben sentirse comprensibles y controlables.
- Los movimientos encadenados deben conservar sensación de ritmo y permitir correcciones razonables.
- La lectura del aterrizaje importa tanto como la espectacularidad del salto; la sombra del personaje y las señales del entorno pueden ayudar.
- Los impulsos deben comunicar su dirección y fuerza mediante animación, sonido, partículas y respuesta del control.
- El error debe enseñar algo sobre el espacio o el timing. Los checkpoints y el reinicio ágil son opciones de diseño que apoyan esa experiencia.
- El equilibrio entre precisión, velocidad, exploración y accesibilidad debe probarse en juego, no decidirse solo desde una tabla de valores.

Los niveles cortos de aproximadamente **60–120 segundos** y las medallas de contrarreloj son referencias de formato presentes en los documentos iniciales. No limitan el tamaño, la variedad ni los modos futuros del proyecto.

## 5. Filosofía de obstáculos y progreso

La tensión principal proviene de la geometría, el timing y la trayectoria: abismos, plataformas que se mueven o desaparecen, superficies de impulso, mecanismos giratorios, obstáculos de patrulla y corrientes de viento. La dirección actual es **cero combate como pilar**: los peligros se esquivan, se superan o se usan como parte del recorrido; no se plantea derrotar enemigos como bucle central.

Los elementos dinámicos del escenario pueden funcionar como pequeñas preguntas de movimiento: cuándo saltar, qué ruta tomar, qué impulso reservar o cómo aprovechar una ventana temporal. Coleccionables, rutas alternativas, contrarreloj, checkpoints y nuevos tipos de obstáculo son herramientas compatibles con la identidad, no condiciones obligatorias para cada nivel.

## 6. Dirección visual

### 6.1 Estilo y tono

La dirección objetivo es **3D estilizado con acabado toon/cel-shaded limpio**, formas claras, materiales mates o satinados, luces de borde moderadas y acentos luminosos en los elementos activos. La referencia mezcla aventura anime/chibi, plataformas coloridas y tecnología juguetona. Debe sentirse cálida y expresiva, con contraste suficiente para que el recorrido siga siendo fácil de leer.

### 6.2 Gramática visual

- **Superficie segura:** formas estables, lectura amable y materiales naturales o cálidos; por ejemplo, césped esmeralda y piedra clara.
- **Impulso fijo:** amarillo solar y naranja, con símbolos o animación que sugieren rebote.
- **Elemento temporal o móvil:** azules y cian, bandas o movimiento que indiquen dirección y estado.
- **Peligro:** magenta, púrpura eléctrico o rojo oscuro con formas más agresivas y señalización evidente.
- **Yo-yo activo:** cian/turquesa luminoso con acentos naranja y animación de giro o retracción.

Estos colores son un vocabulario de partida, no una paleta cerrada. El color debe apoyarse con silueta, patrón, movimiento y contraste para que la función no dependa únicamente de distinguir tonos.

### 6.3 Composición y legibilidad

La zona de juego inmediata debe tener más contraste que la decoración distante. Las plataformas y peligros importantes deben separarse del fondo, y las trayectorias de salto deben poder leerse desde la cámara de juego. Biselados, sombras proyectadas, líneas direccionales, señales de viento y anillos temporales son recursos sugeridos. Su forma final puede cambiar si se mantiene una lectura clara y coherente.

La iluminación puede usar sombras toon de pocos tonos, ambientación suave, contornos sutiles y profundidad atmosférica. Debe evitarse que el bloom, la saturación o los detalles decorativos oculten bordes, estados o distancias importantes.

## 7. Escenarios, biomas y props

La propuesta de partida combina islas suspendidas, cielo luminoso, vegetación estilizada, ruinas ligeras y mecanismos de juguete. “Archipiélago de Engranajes y Nubes” o “Sky Breeze Toyworks” puede servir como nombre de trabajo de un bioma, no como escenario obligatorio o único. Las ideas previas de parque mecánico y ruinas solares amplían el repertorio posible.

Dos props ilustran el lenguaje de impulso:

- **Botón de impacto / trampolín mecánico:** dispositivo amarillo y naranja montado sobre una base robusta. Comunica compresión y lanzamiento mediante deformación, expansión y feedback audiovisual.
- **Anillo de viento ascendente:** estructura clara con acento cian, giro interno y una columna visible de aire. Comunica elevación y dirección del flujo.

En notas conceptuales aparecen dimensiones y valores como un trampolín de 2,4 m, una corriente de 3 m de diámetro y 8 m de altura, un lanzamiento de 22 m/s y una aceleración de viento expresada como “14 m/s”. Son **valores de referencia sin validar**. En particular, antes de implementar el último dato debe definirse si se trata de velocidad objetivo, aceleración u otra medida, con unidades coherentes. Ninguna de estas cifras debe copiarse a producción como requisito final sin revisión de diseño y programación.

## 8. Interfaz y plataformas

La referencia actual de interfaz está pensada para controles táctiles en orientación horizontal: movimiento en la zona inferior izquierda, acciones en la inferior derecha, información de carrera y pausa en la parte superior, y el centro despejado para observar el recorrido. El botón de salto/rebote es primario; el lanzamiento del yo-yo y el deslizamiento se presentan como acciones diferenciadas.

Las posiciones, tamaños, opacidades y controles de la lámina son ejemplos, no medidas definitivas. El diseño debe adaptarse a proporciones de pantalla, zonas seguras, comodidad de agarre, opciones de accesibilidad y cualquier otra plataforma que se decida apoyar. Incluir modo zurdo, escalado y opacidad ajustables son opciones sugeridas por la referencia.

## 9. Audio, animación y respuesta

La sensación cinética debe apoyarse con anticipación, compresión y liberación. El lanzamiento del yo-yo, la apertura del disco, el rebote, el retorno magnético y los impulsos del entorno son oportunidades de animación y feedback. Sonidos de mecanismo elástico, viento y acople pueden diferenciar acciones; vibración breve puede reforzar impactos cuando el dispositivo lo permita.

Las referencias a impactos instantáneos, squash-and-stretch, estelas, anillos de energía y partículas son indicaciones de carácter. El equipo puede ajustar duración, intensidad y complejidad para mantener respuesta clara y rendimiento estable.

## 10. Guía de decisiones para el equipo

Al evaluar una nueva mecánica, recurso o interfaz, comprobar:

1. ¿Refuerza el movimiento, la exploración o la lectura del recorrido?
2. ¿El jugador entiende qué es seguro, qué impulsa y qué representa peligro?
3. ¿El yo-yo sigue siendo reconocible como herramienta cinética y no como arma?
4. ¿El tono mantiene energía, curiosidad y una sensación juguetona?
5. ¿La propuesta abre posibilidades para el juego sin contradecir sus pilares?

Si una respuesta no está clara, debe tratarse como una decisión pendiente de diseño, no como una prohibición automática. Registrar las decisiones que cambien esta identidad para que las áreas del equipo trabajen con la misma versión.

## 11. Referencias visuales adjuntas

Las imágenes se encuentran en `referencias_visuales/` junto a esta guía. Deben consultarse como referencias conceptuales, nunca como especificaciones exactas de los recursos finales.

| Archivo | Qué comunica | Uso recomendado |
|---|---|---|
| [protagonista_y_yoyo_cinetico.png](referencias_visuales/protagonista_y_yoyo_cinetico.png) | Silueta del héroe, equipo, colores del yo-yo y ejemplo de rebote | Alinear concepto de personaje y artefacto; no copiar proporciones o detalles literalmente |
| [entorno_plataformas_y_peligros.png](referencias_visuales/entorno_plataformas_y_peligros.png) | Plataformas flotantes, contraste de planos, trampolín, peligro y plataforma móvil | Orientar composición y gramática ambiental |
| [gameplay_y_hud_movil.png](referencias_visuales/gameplay_y_hud_movil.png) | Ejemplo de cámara, fantasía de juego y controles táctiles horizontales | Inspirar presentación y jerarquía de HUD; no es captura ni layout final |
| [props_impulso_trampolin_y_anillo.png](referencias_visuales/props_impulso_trampolin_y_anillo.png) | Forma y feedback visual de dos props de impulso | Referenciar lenguaje de forma, color y funcionamiento visual |

## 12. Documentos de origen consolidados

Esta guía integra los conceptos de los documentos iniciales sobre diseño general, arte del protagonista, HUD móvil, escenarios y props interactivos. Los originales permanecen en la raíz del proyecto como material de consulta histórica. Si se actualizan, conviene indicar que esta guía maestra define la identidad vigente para evitar que sobrevivan decisiones incompatibles, especialmente la antigua mochila-cometa.
