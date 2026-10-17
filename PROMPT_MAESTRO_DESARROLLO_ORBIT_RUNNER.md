# Prompt maestro — Desarrollo integral de Orbit Runner

Usa este prompt junto con [`AGENTS.md`](AGENTS.md) y la guía de identidad [`Orbit_Runner_Guia_de_Desarrollo/GUIA_MAESTRA_ORBIT_RUNNER.md`](Orbit_Runner_Guia_de_Desarrollo/GUIA_MAESTRA_ORBIT_RUNNER.md). Si hay conflicto entre un detalle conceptual y una instrucción explícita de este prompt, conserva las decisiones explícitas de este prompt y registra el criterio utilizado.

---

## Encargo

Actúa como **líder autónomo de diseño y desarrollo** de *Orbit Runner*. Tu responsabilidad es llevar el proyecto desde el estado actual hasta un videojuego completo, coherente, pulido y jugable en Android, desde la planificación técnica hasta la integración final y la entrega de un build instalable cuando las herramientas disponibles lo permitan.

No entregues solamente un prototipo, una demo de movimiento, un documento, escenas de muestra o sistemas desconectados. Diseña e implementa un juego integral, incluyendo presentación, flujo completo entre pantallas, campaña, progresión, guardado, recompensas, logros y contenido suficiente para que una persona pueda empezar, jugar, avanzar y completar el juego.

## Autoridad y autonomía

- Toma las decisiones de diseño, tecnología, estructura, controles, dirección de niveles, balance, progresión, economía, interfaz, arte, audio y producción que sean necesarias para completar el juego.
- No solicites aprobación para decisiones rutinarias. Si hay varias opciones válidas, selecciona la que mejor sirva a la identidad, la calidad y la viabilidad de *Orbit Runner*; registra las decisiones importantes y sigue adelante.
- Conserva como compromisos del proyecto: Godot 4.x, GDScript, Android como primer destino, movimiento 3D controlado manualmente por el jugador mediante joystick virtual izquierdo, recorrido principalmente lineal y cámara de seguimiento trasera, y al menos diez niveles completos.
- Elige el renderizador de Godot según el momento de implementación, las capacidades de los dispositivos Android disponibles y las necesidades visuales. Registra la elección y su evidencia en la bitácora técnica.
- Consulta `AGENTS.md` y la guía maestra antes de definir arquitectura o producir contenido. Usa las imágenes adjuntas como referencias de intención visual; crea o adapta assets originales para el juego. Las imágenes de referencia no son recursos finales que deban copiarse literalmente.
- Expande la visión con libertad. Los sistemas o listas de mecánicas de las guías existentes son puntos de partida, no un techo para el diseño.
- Pregunta al usuario solo si una decisión bloquea de verdad el trabajo, si se requiere una autorización externa o si la instrucción nueva contradice un compromiso explícito. Explica brevemente el bloqueo y continúa en paralelo con lo que no dependa de esa respuesta.

## Dirección del juego

Desarrolla un juego de plataformas 3D de aventura y movimiento, con tono optimista y enérgico. El protagonista recorre escenarios estilizados, lee peligros y enlaza movimientos acrobáticos. El yo-yo cinético es una herramienta distintiva de locomoción que puede desplegarse temporalmente como superficie de rebote. El combate no es el bucle central.

El jugador controla el movimiento: **no uses avance automático**. El joystick izquierdo debe permitir dirigir al personaje con respuesta analógica. Implementa las acciones en controles táctiles cómodos de la zona derecha y ofrece controles de teclado para editar y depurar desde PC. Decide la relación entre movimiento y cámara de forma consistente y haz que el jugador pueda entender hacia dónde se moverá.

## Contenido mínimo que debe estar terminado

Entrega, como mínimo, los siguientes sistemas integrados y utilizables:

### Flujo de juego y menús

- Pantalla inicial/título y menú principal.
- Inicio de campaña, selección de nivel y acceso a los niveles desbloqueados.
- HUD en partida, pausa, reanudación, reinicio, salida segura y pantalla de resultado al completar un nivel.
- Pantallas de progreso, coleccionables, recompensas y logros.
- Ajustes relevantes para Android: audio, idioma si corresponde, controles/tamaño u opacidad táctil, modo zurdo si es viable y opciones visuales que realmente existan.
- Tutorial o introducción jugable que enseñe los controles y el yo-yo sin depender únicamente de un bloque largo de texto.
- Créditos y atribución de recursos de terceros cuando corresponda.

### Campaña y niveles

- Diseña e implementa **al menos diez niveles completos**, jugables de principio a fin y conectados con la progresión.
- Crea una curva de dificultad deliberada: enseñar, combinar, exigir dominio y culminar con retos avanzados, manteniendo una dificultad justa y legible.
- Varía la composición, ritmo, geometría, rutas y obstáculos. Usa la dirección de arte para construir ambientes reconocibles y retadores; no resuelvas diez niveles cambiando solo el color o la colocación de los mismos objetos.
- Incluye checkpoints y recuperación apropiados para el nivel de desafío. Los reinicios deben ser rápidos y comprensibles.
- Añade objetivos opcionales y motivos de rejuego cuando refuercen la experiencia, por ejemplo gemas/rutas alternativas, puntuación, medallas o contrarreloj. No sacrifiques control y legibilidad para acumular sistemas.
- Cada nivel debe tener inicio, recorrido, meta, condiciones claras de éxito y tratamiento de caída/fracaso; no dejes niveles como escenas decorativas o placeholders.

### Progresión, recompensas y logros

- Diseña un sistema persistente de progreso que desbloquee niveles y comunique claramente qué se obtuvo y qué falta.
- Implementa recompensas funcionales y atractivas por jugar, explorar, mejorar tiempos o dominar acciones. Elige por cuenta propia el tipo de recompensa —por ejemplo, contenido cosmético, variantes visuales, insignias o retos adicionales— y asegúrate de que las recompensas existan en el juego y puedan obtenerse.
- Implementa un conjunto coherente de logros con condiciones verificables, progreso/estado y feedback al desbloquearse. Vincula logros, cuando convenga, a exploración, dominio, campaña y rejugabilidad.
- Guarda localmente el progreso, ajustes, coleccionables, mejores resultados y logros. Protege los datos ante cierres inesperados y contempla una versión de datos para migraciones futuras.
- Diseña una economía equilibrada y comprensible. Por defecto, la progresión debe funcionar sin conexión, sin anuncios, compras integradas ni servicios de pago. No agregues dependencias comerciales o servicios externos sin autorización específica.

### Calidad de presentación

- Produce o integra modelos, materiales, animaciones, VFX, interfaz, audio y música suficientes para que la experiencia se sienta como un juego completo. Usa Blender para contenido 3D cuando sea útil.
- Conserva los `.blend` como fuentes editables y usa `.glb` como intercambio con Godot. Comprueba escala, orientación, pivotes, materiales y colisiones al integrar recursos.
- Mantén el HUD legible sobre los escenarios, las funciones reconocibles por forma/animación además de color y los aterrizajes comprensibles desde la cámara.
- Atiende el ciclo de vida móvil: orientación horizontal, diferentes proporciones y zonas seguras, pérdida/recuperación de foco, pausa y botón Atrás de Android.
- Busca rendimiento estable en los dispositivos objetivo. Usa perfilado y niveles de calidad si hacen falta; no prometas compatibilidad universal basándote solo en el editor de PC.

## Blender y herramientas disponibles

- Inspecciona las herramientas disponibles antes de usarlas. Si Blender MCP está conectado, úsalo de acuerdo con sus instrucciones para crear, inspeccionar o ajustar assets.
- Si Blender MCP no está disponible, no finjas tener acceso. Usa Blender local, automatización local o los recursos existentes cuando estén disponibles; registra cualquier limitación que afecte el resultado y continúa con alternativas prácticas.
- Puedes usar las herramientas y recursos ya disponibles para el trabajo. Prefiere herramientas verificables, formatos abiertos y flujos que dejen el proyecto editable.
- No inventes llamadas, APIs, resultados de exportación, compatibilidad de dispositivos ni trabajo realizado por herramientas.
- No publiques en tiendas, no compres recursos/servicios, no contactes a terceros y no uses cuentas, credenciales o claves privadas sin autorización explícita. La autonomía cubre decisiones de desarrollo dentro del workspace.

## Planificación y registro de decisiones

Antes de implementar, haz una inspección real del repositorio y prepara un plan de hitos. No presupongas que el proyecto Godot ya existe. Mantén el material de referencia y los archivos originales; si hace falta, crea el proyecto ejecutable en una carpeta dedicada.

Divide el trabajo en hitos revisables, por ejemplo:

1. Auditoría del workspace, decisiones técnicas y esqueleto ejecutable.
2. Controlador, cámara, controles táctiles y primer circuito de movimiento.
3. Flujo de menús, guardado y progresión.
4. Producción de niveles y recursos de arte.
5. Recompensas, logros, ajustes, pulido y accesibilidad.
6. Integración final, validación funcional y exportación Android.

Adapta el orden si el trabajo lo requiere, pero no abandones sistemas a medias. Mantén `docs/TECHNICAL_DECISIONS.md` en el proyecto con decisiones técnicas importantes. Mantén además un registro de decisiones de diseño particulares o difíciles de revertir, indicando fecha, contexto, opciones consideradas, decisión, motivo e impacto; este registro se presentará al usuario al final para revisión. No conviertas el registro en una lista de microdecisiones triviales.

Documenta al menos:

- versión exacta de Godot y renderizador elegido;
- dispositivos/perfiles Android usados para decidir y validar;
- organización del proyecto y flujo Blender → GLB → Godot;
- controles, cámara y decisiones relevantes de movimiento;
- diseño de la campaña, curva de dificultad, progresión y guardado;
- dependencias/plugins o recursos de terceros, con sus licencias y atribuciones;
- limitaciones pendientes y alternativas descartadas que tengan impacto importante.

## Validación y criterio de finalización

El trabajo está terminado cuando:

- El proyecto Godot se abre sin errores críticos y el juego puede iniciarse desde el menú hasta completar la campaña.
- Hay al menos diez niveles completos y accesibles mediante progresión; todos pueden jugarse hasta la meta y los fallos se recuperan correctamente.
- Controles táctiles, salto/movimiento central y cámara funcionan en Android o, si no hay dispositivo disponible, se valida lo más posible con exportación/importación y ejecución local, dejando clara la limitación.
- Guardado, desbloqueos, recompensas, mejores resultados y logros persisten tras reiniciar la aplicación.
- Menús, HUD, pausa, reinicio, ajustes y flujo entre niveles no contienen controles muertos ni pantallas provisionales.
- Assets enlazados, escenas, audio y recursos cargan; los assets Blender usados tienen su exportación GLB integrada.
- Se realiza una revisión funcional de la campaña y de los sistemas principales con las herramientas disponibles. Corrige errores encontrados antes de dar por terminado el proyecto; no declares validaciones que no se hicieron.
- Se entrega el proyecto fuente y un APK de depuración instalable si la cadena Android está disponible. Deja documentados los pasos o bloqueos para generar un AAB de distribución; no guardes claves de publicación en el repositorio.
- El usuario recibe un resumen con lo entregado, la ruta del proyecto/build, el estado de validación, limitaciones conocidas y las decisiones particulares que conviene revisar.

No cierres la tarea al completar solo el primer hito ni presentes una lista de pendientes como si el juego estuviera terminado. Si una limitación del entorno impide completar o validar una parte, agota alternativas razonables, entrega el máximo resultado funcional y explica con precisión qué falta y por qué.

## Comunicación durante el trabajo

Comparte avances breves en hitos importantes: decisiones técnicas, primer controlador jugable, sistemas de progresión, niveles completados, validación Android y entrega. Mantén el resumen enfocado en cambios verificables, riesgos reales y siguientes pasos.

Debes reportar esto al terminar unicamente pues trabajaras de forma 100% autonoma y solo se revisara tu trabajo una vez hayas terminado.
Si surgen dudas o problemas durando el desarrollo eres libre de resolverlas como puedas y llevar esas dudas para refinamiento al terminar el entregable. 