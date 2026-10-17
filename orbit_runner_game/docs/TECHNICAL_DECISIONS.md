# Decisiones técnicas — Orbit Runner

Fecha de inicialización: 2026-09-28

## Base del proyecto

- Motor fijado: Godot **4.7.2-stable**, la versión estable disponible al inicializar, según el [archivo oficial de versiones](https://godotengine.org/download/archive/). Mantener esta versión al abrir el proyecto; no actualizar automáticamente.
- Lenguaje previsto: GDScript. No se agregaron plugins ni dependencias.
- Renderizador inicial: **Compatibility (OpenGL)**, escogido para priorizar compatibilidad con equipos móviles de gama baja. No se indicó un teléfono Android objetivo y no hay dispositivo conectado, de modo que esta elección sigue pendiente de validación. Compatibility es el modo de menor requisito; Mobile y Forward+ requieren Vulkan, Direct3D 12 o Metal. La selección se debe revisar en hardware antes de incorporar materiales o shaders dependientes del renderizador. [Documentación oficial](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- Orientación prevista: horizontal. Ventana inicial para el editor: 1280 × 720.
- Arte 3D: Blender como fuente editable `.blend`; intercambio con Godot mediante `.glb`. No había modelos en la carpeta al iniciar.
- Estructura creada: `scenes/`, `scripts/`, `resources/`, `art/models/`, `art/materials/`, `art/textures/`, `audio/`, `assets_source/blender/` y `docs/`.
- `scenes/main.tscn` es únicamente una escena raíz vacía para que el proyecto tenga una escena de inicio. No contiene gameplay.

## Estado y límites de esta inicialización

- La carpeta original solo contenía documentos de referencia. Se conservaron en su ubicación.
- Godot no estaba instalado ni disponible en PATH en el entorno inspeccionado; por tanto no se pudo abrir el proyecto en el editor ni comprobar su importación/ejecución.
- No se detectó un dispositivo Android o una cadena de exportación configurada. No se declara compatibilidad probada ni se genera APK.
- Esta entrega prepara el contenedor y decisiones iniciales solamente. No implementa mecánicas, controles, UI, niveles, assets ni contenido de juego.

## Plataformas de desarrollo y prueba

- Android sigue siendo el destino prioritario del juego.
- Windows PC también debe poder ejecutar el juego como plataforma funcional de desarrollo y prueba, no solo como editor. Mantener la lógica de gameplay compartida entre Android y PC; usar controles de teclado/ratón en PC y controles táctiles en Android.
- La versión de PC sirve para iterar y depurar con rapidez. La validación final de rendimiento y controles móviles se hará en el dispositivo Android del usuario cuando el proyecto esté listo.
- Este objetivo queda registrado, pero aún no está implementado ni validado: la escena actual es solo un contenedor vacío.
