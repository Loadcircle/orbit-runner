# Orbit Runner — Lo que necesito de ti para producción

Redactada el 2026-10-25. Copia del documento compartido [*Orbit Runner — Lo que necesito de ti para producción*](https://claude.ai/artifact/QKWc5tGWuH9x2gWtGjFsmR); si cambia allí, actualiza esta copia.

El agente hace toda la integración: código del juego, plugins, servidor, reglas y despliegues. Esta guía solo recoge lo que tiene que hacer una persona en las consolas, porque necesita tu cuenta, tu tarjeta o una decisión tuya, y qué tienes que pasarme al terminar cada bloque. Orden: Firebase, AdMob y, al final, Google Play. La guía técnica para agentes está en [`PRODUCTION_INTEGRATION.md`](PRODUCTION_INTEGRATION.md).

## Decisiones tomadas (2026-10-25)

| Tema | Decisión |
| --- | --- |
| Región de los datos | `us-central1` (no se puede cambiar después) |
| Nombre del paquete | `com.orbitrunner.game`, salvo que cambie el nombre del juego. **Pendiente**: comprobar que no hay competencia con ese nombre antes de crear la app en Google Play |
| Login social | Solo Google al lanzar; Facebook más adelante |
| Edad | Menor de 16 en Europa y Reino Unido; menor de 13 en el resto |
| Web legal | GitHub Pages para empezar; dominio propio más adelante |
| Precios | Los actuales (0,99 €, 2,49 €, 1,49 €, 0,99 €); se ajustan con datos |

## Bloque 1 — Firebase (unos 45 minutos)

Con este bloque hecho, el agente puede crear la base de datos, el servidor, el login y las páginas legales sin volver a pedirte nada, salvo el paso 1.6.

### 1.1 Crear los dos proyectos

Uno para pruebas y otro para la versión publicada, así las pruebas no ensucian los rankings reales.

1. Abre [console.firebase.google.com](https://console.firebase.google.com) con la cuenta de Google que será propietaria del juego.
2. **Crear un proyecto** → nombre `orbit-runner-dev` → continúa.
3. Cuando pregunte por **Google Analytics**, desactívalo (el público incluye menores; se puede activar más adelante).
4. **Crear proyecto** y espera a que termine.
5. Repite con `orbit-runner-prod`.
6. Si Firebase añade un sufijo al ID (por ejemplo `orbit-runner-prod-a1b2c`), apúntalo: es lo que tienes que pasarme.

### 1.2 Activar la facturación (plan Blaze)

El servidor del juego (Cloud Functions) solo existe en el plan de pago por uso. Incluye una cuota gratuita amplia: con pocos miles de jugadores al día el coste esperado es de 0 a 5 € al mes ([precios](https://firebase.google.com/pricing)).

1. En cada proyecto, abajo a la izquierda, pulsa **Actualizar** junto a "Spark".
2. Elige **Blaze**. Si no tienes cuenta de facturación, el asistente te pide crear una con tu tarjeta.
3. Cuando ofrezca una alerta de presupuesto, acéptala con un importe bajo: 10 € en `dev` y 20 € en `prod`. La alerta solo avisa por correo, no corta el servicio.

### 1.3 Activar el login

En **cada** proyecto:

1. Menú izquierdo → **Compilación → Authentication → Comenzar**.
2. Pestaña **Método de acceso** → **Anónimo** → activar → Guardar.
3. **Agregar proveedor nuevo → Google** → activar. Nombre público: `Orbit Runner`. Correo de asistencia: el tuyo. Guardar.
4. Vuelve a abrir **Google** y despliega **Configuración del SDK web**. Copia el **ID de cliente web** (termina en `.apps.googleusercontent.com`) y pásamelo.

### 1.4 Dar acceso al agente desde la terminal

Así el agente puede desplegar y configurar sin que hagas cada paso en la consola.

1. Instala [Node.js 22 LTS](https://nodejs.org) (instalador de Windows, opciones por defecto).
2. Instala [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) (instalador de Windows, opciones por defecto).
3. Cierra y vuelve a abrir Claude Code. En el chat escribe, uno por uno:
   - `! npm install -g firebase-tools`
   - `! firebase login` (se abre el navegador: entra con la cuenta propietaria y acepta)
   - `! gcloud auth login` (lo mismo)
4. Escríbeme "acceso listo". Con eso el agente activa las API, crea la base de datos en la región elegida y registra la app Android.

### 1.5 Pantalla de consentimiento de Google — cuando te avise

Es la ventana que ve el jugador al elegir su cuenta de Google. Necesita las páginas de privacidad, que el agente publicará antes; te pasaré las URL y un logotipo de 120 × 120 px.

1. [console.cloud.google.com/auth/overview](https://console.cloud.google.com/auth/overview) con el proyecto `orbit-runner-prod` seleccionado arriba.
2. **Branding**: nombre `Orbit Runner`, tu correo de asistencia, el logotipo, la página principal, la política de privacidad, las condiciones y el dominio autorizado (todo te lo paso yo). Guardar.
3. **Público**: tipo **Externo** → **Publicar app**, para que pase de "Prueba" a "En producción".
4. Si Google pide verificar la marca, sigue el asistente: solo hace falta para que se vean el nombre y el logotipo. El juego no pide permisos sensibles.

### 1.6 Crear la clave de subida

Es la clave con que se firma cada versión que se sube a Google Play. Tiene una contraseña que **solo tú** debes conocer. Si ya subiste el juego a Google Play alguna vez, usa la clave que tengas y salta al punto 3.

1. En tu propia terminal de PowerShell (no en el chat), dentro de una carpeta fuera del repositorio, por ejemplo `D:\claves\`:

   ```
   & "$env:JAVA_HOME\bin\keytool.exe" -genkeypair -v -keystore orbit_runner_upload.keystore -alias orbit_upload -keyalg RSA -keysize 4096 -validity 10000
   ```

2. Pide una contraseña y unos datos (nombre, organización, país). Usa una contraseña larga, guárdala en un gestor de contraseñas y haz dos copias del archivo `.keystore` (por ejemplo, un USB y una nube cifrada). Si se pierde, actualizar el juego en Google Play se complica mucho.
3. Deja la clave configurada para Godot con estas tres líneas (en tu PowerShell, con tus valores):

   ```
   setx GODOT_ANDROID_KEYSTORE_RELEASE_PATH "D:\claves\orbit_runner_upload.keystore"
   setx GODOT_ANDROID_KEYSTORE_RELEASE_USER "orbit_upload"
   setx GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD "<tu contraseña>"
   ```

4. Saca las huellas, que son públicas, y pásame las líneas `SHA1:` y `SHA256:`:

   ```
   & "$env:JAVA_HOME\bin\keytool.exe" -list -v -keystore D:\claves\orbit_runner_upload.keystore -alias orbit_upload
   ```

### 1.7 Web en GitHub Pages

Aloja la política de privacidad, la página de borrado de cuenta y, más adelante, `app-ads.txt`. AdMob exige que `app-ads.txt` esté en la raíz del sitio, así que usa un sitio de **usuario u organización**, no uno de proyecto.

1. En [github.com/new](https://github.com/new), crea un repositorio **público** llamado exactamente `<tu-usuario>.github.io` (o `<organización>.github.io`).
2. **Settings → Pages**: Source = **Deploy from a branch**, rama `main`, carpeta `/ (root)` → Save.
3. Pásame la URL (`https://<tu-usuario>.github.io`). El agente prepara las páginas; tú las subes al repositorio, o me das acceso con `! gh auth login` para que las suba yo.

### Qué me pasas al terminar el Bloque 1

- [ ] La URL de GitHub Pages (1.7)
- [ ] Los IDs de los dos proyectos
- [ ] El ID de cliente web de cada proyecto (1.3)
- [ ] "Acceso listo" (1.4)
- [ ] Las huellas SHA-1 y SHA-256 de la clave de subida (1.6)

## Bloque 2 — AdMob (unos 30 minutos)

El juego solo usa anuncios recompensados: +2 de energía, como máximo 5 al día. Como hay jugadores menores, los anuncios serán no personalizados y aptos para todos los públicos; esa parte la configura el agente en el código. Tú creas la app y fijas los controles de la cuenta.

### 2.1 Cuenta y pagos

1. Entra en [admob.google.com](https://admob.google.com) con la cuenta propietaria → **Empezar** (si aún no tienes cuenta) → país y zona horaria.
2. **Pagos → Configuración de pagos**: datos fiscales y cuenta bancaria para cobrar los ingresos.

### 2.2 Crear la app y el bloque de anuncios

1. **Apps → Agregar app** → plataforma **Android** → "¿La app está publicada en una tienda?": **No** → nombre `Orbit Runner` → Agregar.
2. Copia el **ID de la app**, con forma `ca-app-pub-1234567890123456~1234567890`.
3. En la app: **Bloques de anuncios → Agregar bloque de anuncios → Bonificado**.
4. Nombre `energia_recompensado`. Recompensa: cantidad `2`, artículo `energy`. **Crear bloque**.
5. Copia el **ID del bloque**, con forma `ca-app-pub-1234567890123456/1234567890`.

No toques los anuncios reales en tu teléfono: el agente usará los de prueba de Google en las versiones de desarrollo. Hacer clic en tus propios anuncios reales puede suspender la cuenta.

### 2.3 Controles para un público con menores

1. **Controles de bloqueo → Todas las apps → Contenido**: **Clasificación máxima del contenido de los anuncios** → **G** (todos los públicos) → Guardar.
2. En la misma sección, **Categorías sensibles**: bloquea las que no quieras ver junto al juego (citas, apuestas, alcohol, religión, política…).

### 2.4 Mensaje de consentimiento para Europa

En Europa y Reino Unido hay que pedir consentimiento a los adultos para los anuncios. El juego mostrará el formulario; tú lo creas aquí.

1. **Privacidad y mensajes → Normativas europeas → Crear mensaje**.
2. Elige la app `Orbit Runner`, idiomas español e inglés y, en socios publicitarios, deja solo los de Google.
3. Te pedirá la URL de la política de privacidad: pon la que te pase el agente en el Bloque 1.
4. **Publicar**.

### 2.5 Cuando te avise

Estos pasos dependen de cosas que hará el agente o de que la app ya esté en Google Play:

- **Verificación en el servidor**: en el bloque `energia_recompensado` → **Configuración avanzada → Verificación del lado del servidor** → pega la URL que te pase → **Verificar URL**.
- **Dispositivo de prueba**: **Configuración → Dispositivos de prueba → Agregar** con el identificador que te pase del registro de tu teléfono.
- **`app-ads.txt`**: **Apps → Ver todas las apps → app-ads.txt** → copia la línea y pásamela; el agente la publica en la web.
- **Vincular con Google Play**: cuando la app esté publicada, **Configuración de la app → Vincular con tienda**.

### Qué me pasas al terminar el Bloque 2

- [ ] ID de la app de AdMob
- [ ] ID del bloque recompensado
- [ ] Confirmación de que la clasificación máxima es G y el mensaje de consentimiento está publicado

## Bloque 3 — Google Play (al final)

Se hace cuando el agente tenga el juego conectado y te pase el primer archivo `.aab` (formato que exige Google Play). Ya tienes cuenta de desarrollador; todo pasa en [play.google.com/console](https://play.google.com/console).

### 3.1 La app y el perfil de pagos

1. Si la app no existe: **Todas las apps → Crear app** → nombre `Orbit Runner`, idioma Español (España), **Juego**, **Gratis** → acepta las declaraciones → Crear.
2. **Configuración → Perfil de pagos**: comprueba que existe y está activo. Sin él no se pueden vender productos.

### 3.2 Primera subida y huellas de Google

1. **Probar y publicar → Pruebas → Prueba interna → Crear versión**.
2. Acepta **Play App Signing** (Google guarda la clave de firma final; tú conservas la de subida).
3. Sube el `.aab` que te pase el agente y publica la versión en la pista de prueba interna. En **Testers**, añade tu correo y abre el enlace de inscripción en el teléfono.
4. **Probar y publicar → Integridad de la app → Firma de apps**: copia las huellas **SHA-1** y **SHA-256** de la "clave de firma de apps" y pásamelas.
5. En la misma página, sección **API de Play Integrity → Vincular proyecto de Cloud** → elige `orbit-runner-prod`.

### 3.3 Crear los productos

**Monetizar con Play → Productos → Productos de compra única → Crear producto**. El ID tiene que ser exactamente este:

| ID del producto | Nombre | Precio |
| --- | --- | --- |
| `energy_10` | 10 de energía | 0,99 € |
| `energy_30` | 30 de energía | 2,49 € |
| `unlimited_60` | Energía ilimitada 1 hora | 1,49 € |
| `sparks_1000` | 1000 chispas | 0,99 € |

En cada uno: nombre y descripción (te paso los textos en español e inglés), opción de compra "Comprar" con el precio en euros, **Actualizar precios con tipo de cambio** para los demás países, y **Activar**. El pase de temporada queda fuera hasta que se decida su contenido y precio.

### 3.4 Permiso para verificar compras

El agente crea una cuenta de servicio llamada `play-verifier` y te pasa su correo.

1. **Usuarios y permisos** (menú de la cuenta, no de la app) → **Invitar a usuarios nuevos** → pega ese correo.
2. Pestaña **Permisos de la app** → **Agregar app** → Orbit Runner → marca **Ver datos financieros** y **Gestionar pedidos y suscripciones** → Aplicar → **Invitar usuario**.

### 3.5 Avisos de reembolsos

El agente crea el tema de mensajes y te pasa su nombre (`projects/orbit-runner-prod/topics/play-billing`).

1. **Monetizar con Play → Configuración de monetización** → marca **Habilitar notificaciones en tiempo real**.
2. Pega el nombre del tema → elige **Recibir todas las notificaciones de suscripciones y productos de compra única**.
3. **Enviar mensaje de prueba** → Guardar cambios. Dime si el mensaje salió bien.

### 3.6 Compras de prueba

**Configuración → Pruebas de licencia** → añade los correos de Gmail de quienes vayan a probar. Esas cuentas compran con tarjetas de prueba y no se les cobra.

### 3.7 Ficha, declaraciones y publicación

El agente te prepara en un archivo los textos de la ficha, las capturas y las respuestas de cada formulario (clasificación IARC, público objetivo, seguridad de los datos, ID de publicidad, borrado de cuenta). Tú los copias en **Crecimiento → Presencia en Play Store** y **Política → Contenido de la app**.

Si tu cuenta de desarrollador es **personal** y se creó después de noviembre de 2023, antes de producción hace falta una prueba cerrada con **al menos 12 testers durante 14 días seguidos** ([requisito](https://support.google.com/googleplay/android-developer/answer/14151465)). Conviene empezar a reunir testers pronto. Al incluir menores, la revisión de la primera versión suele tardar una semana o más.

### Qué me pasas al terminar el Bloque 3

- [ ] Huellas SHA-1 y SHA-256 de la clave de firma de apps (3.2)
- [ ] Confirmación de que Play Integrity está vinculado a `orbit-runner-prod`
- [ ] Productos creados y activos
- [ ] Invitación a `play-verifier` enviada
- [ ] Resultado del mensaje de prueba de notificaciones
- [ ] Si la cuenta es personal o de organización

## Resumen de entregas

Todo lo que me pasas son identificadores públicos: viajan dentro de la app y se pueden pegar en el chat.

| Qué | De dónde sale | Bloque |
| --- | --- | --- |
| URL de GitHub Pages | GitHub | 1.7 |
| IDs de los proyectos `dev` y `prod` | Consola de Firebase | 1.1 |
| ID de cliente web de Google (uno por proyecto) | Authentication → Google → Configuración del SDK web | 1.3 |
| "Acceso listo" (Firebase CLI y Google Cloud CLI con sesión iniciada) | Tu terminal, desde el chat con `!` | 1.4 |
| SHA-1 y SHA-256 de la clave de subida | `keytool -list` | 1.6 |
| ID de la app de AdMob y del bloque recompensado | AdMob | 2.2 |
| SHA-1 y SHA-256 de la clave de firma de Google | Play Console → Integridad de la app | 3.2 |
| Tipo de cuenta de Play (personal u organización) | Play Console | 3.7 |

**No me pases nunca** la contraseña de la clave de subida ni el archivo `.keystore`, la contraseña de tu cuenta de Google, los datos de la tarjeta ni códigos de verificación. La contraseña de la clave queda solo en tus variables de entorno (1.6).
