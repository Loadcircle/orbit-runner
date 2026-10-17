# AGENTS.md — Orbit Runner

## Misión

Desarrolla **Orbit Runner**, un juego de plataformas 3D de movimiento y aventura. La identidad vigente, los pilares de diseño y las referencias visuales están en [`Orbit_Runner_Guia_de_Desarrollo/GUIA_MAESTRA_ORBIT_RUNNER.md`](Orbit_Runner_Guia_de_Desarrollo/GUIA_MAESTRA_ORBIT_RUNNER.md). Léela antes de tomar decisiones de juego o arte y consúltala cuando una implementación pueda alterar la identidad.

El nombre Orbit Runner es provisional. Este archivo guía al agente que colabora en el proyecto; no establece el alcance máximo del juego. No interpretes la lista actual de mecánicas, ejemplos de niveles o documentos visuales como un límite para futuras propuestas.

## Decisiones confirmadas

- **Motor:** Godot 4.x.
- **Lenguaje de gameplay y herramientas de proyecto:** GDScript. No agregues C# salvo que el usuario cambie esta decisión.
- **Destino prioritario inicial:** Android. Usa PC/editor para desarrollar y depurar cuando esté disponible.
- **Juego:** plataformas 3D con recorrido principalmente lineal y cámara de seguimiento colocada detrás del protagonista.
- **Avance:** manual. El jugador dirige al personaje con un joystick virtual en la zona inferior izquierda. No implementes autoavance como comportamiento predeterminado.
- **Arte 3D:** Blender desde el inicio. Usa `.blend` como fuente editable y `.glb` como formato de intercambio/importación en Godot.
- **Lógica de gameplay:** vive en Godot/GDScript. Blender se usa para crear o preparar contenido 3D; no traslades allí la lógica jugable.
- **Renderizador:** decisión delegada al agente de desarrollo. Elige según los teléfonos realmente disponibles, soporte de GPU/API, aspecto requerido y rendimiento medido. Antes de fijarlo, explica brevemente las opciones y por qué conviene una; no cambies renderizador a mitad de camino sin revisar materiales, shaders y escenas afectados.

## Estado inicial del workspace

El workspace puede contener primero la guía de identidad, documentos de referencia e imágenes, sin un proyecto Godot. Antes de editar:

1. Inspecciona el estado real del repositorio, sus instrucciones adicionales, archivos existentes y cambios sin guardar.
2. No supongas que ya existe un proyecto Godot, una versión concreta del motor, un dispositivo Android conectado o acceso efectivo al MCP de Blender.
3. Si aún no hay proyecto de juego, crea el proyecto Godot en una carpeta de juego dedicada (por ejemplo, `orbit_runner_game/`) para mantener separados el material de referencia y el proyecto ejecutable. No muevas, borres ni sobrescribas los documentos fuente para hacer sitio.
4. Conserva la guía maestra en su ubicación y usa sus imágenes como referencias; no las presentes como arte final.
5. Elige una versión estable de Godot disponible en el entorno cuando se inicialice el proyecto, fija la versión exacta en la documentación del proyecto y evita actualizaciones automáticas no solicitadas.

## Reglas de diseño e implementación

### Movimiento y cámara

- Construye un controlador 3D con entrada analógica desde el joystick izquierdo. El joystick representa movimiento controlado por el jugador, no una señal de correr automáticamente.
- Como interpretación inicial, orienta el movimiento en relación con la cámara: empujar hacia delante mueve al protagonista hacia el avance de la ruta y los laterales permiten corregir trayectoria. Conserva una opción de retroceso o limita su comportamiento de forma deliberada según el diseño del nivel; no lo conviertas accidentalmente en auto-run.
- La cámara sigue al protagonista desde atrás con movimiento estable, lectura clara de aterrizajes y anticipación suficiente del recorrido. Evita cambios bruscos, obstrucciones y movimientos que oculten peligros o plataformas.
- Mantén desacopladas las decisiones de cámara, entrada, aceleración y animación para que puedan ajustarse sin rehacer todo el controlador.
- El movimiento debe dar espacio a aceleración/inercia, salto, uso del yo-yo cinético y las demás acciones de la identidad. Los valores de velocidad, gravedad, impulso, duración y enfriamiento de documentos conceptuales son hipótesis de prototipo, no constantes de producción.
- Incluye entrada de teclado para iteración en PC y asignaciones centralizadas mediante `InputMap`. La ruta táctil y la ruta de depuración deben llamar al mismo sistema de entrada de gameplay.
- Considera la cámara y los controles en orientación horizontal como configuración inicial de Android. Deja el diseño flexible para reajustar proporciones de pantalla, zonas seguras y dispositivos.

### Identidad de gameplay

- El movimiento es el centro de la experiencia. Diseña para enlazar carrera, saltos, correcciones aéreas y recursos del entorno con sensación de ritmo.
- El yo-yo cinético es una herramienta de locomoción: se lanza, se despliega temporalmente como disco/superficie de rebote y regresa. No lo conviertas en arma ni añadas un bucle de combate como supuesto predeterminado.
- El protagonista se representa como aventurero estilizado, expresivo y legible a distancia. Su nombre propio no está definido.
- Distingue visualmente suelo seguro, impulso, plataformas temporales y peligro con forma, valor de color, animación y contraste; no comuniques función solo mediante color.
- La dirección actual propone tono optimista, 3D estilizado/toon y escenarios coloridos. Los biomas, props y mecánicas descritos en la guía son una base ampliable.
- Si una petición futura parece contradecir estos pilares, señala la tensión de forma concreta y pide dirección cuando la decisión sea material. No bloquees extensiones razonables por leer los pilares como restricciones de alcance.

### Renderizado y rendimiento móvil

- Decide entre los renderizadores disponibles de Godot durante la inicialización, considerando el dispositivo Android objetivo y las pruebas posibles. Deja registrada la selección y sus razones en la documentación del proyecto.
- Prioriza frame pacing estable, controles responsivos y legibilidad del recorrido. Evita añadir efectos de pantalla completa, transparencias costosas, luces dinámicas o partículas abundantes sin necesidad visual y verificación en hardware.
- Mantén materiales y shaders dentro de las capacidades del renderizador elegido. Si necesitas una función exclusiva, documenta la dependencia y su alternativa antes de incorporarla.
- No afirmes compatibilidad con una gama de teléfonos que no se haya probado o definido.

## Blender MCP y flujo de assets

- Al comenzar una tarea que use Blender, inspecciona las herramientas MCP disponibles y sus instrucciones. Usa el MCP de Blender solo si realmente está conectado y la herramienta permite la operación solicitada.
- Si el MCP no está disponible, informa brevemente de esa condición y continúa con las capacidades locales existentes: archivos `.blend`, Blender instalado, scripts de Blender o assets que ya estén en el workspace. No inventes resultados del MCP ni des por hecho que una operación externa se ejecutó.
- Mantén los `.blend` editables como fuentes y exporta a `.glb` para integrar modelos en Godot. Conserva escalas, ejes, origen/pivote, nombres y materiales de forma consistente; revisa visualmente el GLB en Godot cuando las herramientas lo permitan.
- Separa modelos reutilizables de escenas que contienen reglas o lógica de juego. Las colisiones finales, activadores, comportamiento, señales, cámara e interfaz se implementan en Godot salvo que haya una razón explícita para hornear una parte como dato de arte.
- No reemplaces referencias conceptuales por recursos finales sin avisar. No descargues ni introduzcas paquetes, plugins o contenido de terceros sin necesidad clara y autorización aplicable.

## Organización recomendada del proyecto de juego

Adapta esta estructura al proyecto existente si ya hay una organización establecida; evita reorganizaciones amplias sin necesidad.

```text
orbit_runner_game/
  project.godot
  scenes/
    player/
    levels/
    props/
    ui/
  scripts/
  resources/
  art/
    models/          # GLB importados
    materials/
    textures/
  audio/
  docs/
    TECHNICAL_DECISIONS.md
  assets_source/
    blender/         # fuentes .blend editables
```

- Usa escenas `.tscn` para composición, recursos `.tres`/`.res` para datos reutilizables, scripts `.gd` para lógica y GLB para modelos intercambiables.
- Mantén cada escena/script con una responsabilidad clara y evita singletons/autoloads globales hasta que una necesidad transversal real los justifique.
- Extrae parámetros de gameplay que deban iterarse a recursos editables cuando eso simplifique el ajuste sin dispersar valores duplicados.
- Usa nombres descriptivos y consistentes. Evita abreviaturas opacas y rutas absolutas locales.
- Conserva el proyecto ejecutable: no dejes escenas principales rotas ni referencias a assets que no existan.

## Forma de trabajo del agente

1. Comprende la petición y el estado del proyecto antes de modificarlo. Revisa primero las instrucciones locales y los archivos relacionados.
2. Para decisiones técnicas que sigan abiertas, presenta una recomendación con sus tradeoffs; aplica la decisión delegada del renderizador con evidencia de entorno/dispositivos y anótala.
3. Implementa cambios acotados, coherentes con la estructura existente y fáciles de revisar. No reescribas áreas no relacionadas.
4. No marques como hecho algo que solo está representado en una imagen o en un documento conceptual.
5. No añadas ni ejecutes pruebas automatizadas salvo que el usuario lo pida. Para cambios de proyecto, realiza solo las comprobaciones necesarias para confirmar que los archivos y recursos referenciados existen y que el proyecto puede abrirse/ejecutarse con las herramientas disponibles; comunica con claridad si el entorno impide esa comprobación.
6. Al terminar, resume qué cambió, qué decisión técnica se tomó, qué comprobación se pudo hacer y qué queda pendiente. Usa rutas relativas al proyecto al documentar decisiones.

## Decisiones por registrar en `docs/TECHNICAL_DECISIONS.md`

Al crear el proyecto de juego, registra como mínimo:

- versión exacta de Godot y fecha de inicialización;
- renderizador elegido y razón, dispositivos y modos de prueba disponibles, y limitaciones conocidas;
- orientación objetivo y configuración de entrada táctil/PC;
- convenciones de escala, ejes, origen y exportación Blender → GLB → Godot;
- estructura de carpetas adoptada y cualquier diferencia relevante respecto a esta guía.

No registres credenciales, contraseñas ni claves privadas en el repositorio.
