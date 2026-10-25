# Integración de producción — guía técnica para agentes

Redactada el 2026-10-25. Los pasos que tiene que hacer el propietario en las consolas, y lo que debe entregar al agente, están en [`PRODUCTION_HUMAN_CHECKLIST.md`](PRODUCTION_HUMAN_CHECKLIST.md).

## Decisiones del propietario (2026-10-25)

Prevalecen sobre cualquier recomendación posterior de este documento.

| Tema | Decisión |
| --- | --- |
| Región | `us-central1` en Firestore, Functions y Scheduler |
| Paquete | `com.orbitrunner.game`, salvo que cambie el nombre del juego (el propietario revisa si hay competencia con ese nombre). No publicar en Google Play hasta confirmarlo |
| Login | Solo Google al lanzar; Facebook más adelante (Paso 4.5) |
| Edad | Se trata como menor a quien tenga menos de 16 años en el EEE y Reino Unido, y menos de 13 en el resto. Hoy `AgeGate` usa 13 en todos los países: hay que pedir o deducir el país (por ejemplo, la región de la configuración del sistema) |
| Web legal | GitHub Pages para empezar, en lugar de Firebase Hosting o un dominio propio (ver la nota siguiente) |
| Precios | Los actuales de `economy_config.tres`: 0,99 €, 2,49 €, 1,49 € y 0,99 € |

Nota sobre GitHub Pages: `app-ads.txt` tiene que estar en la raíz del dominio que figure como sitio web en la ficha de Google Play. Un sitio de proyecto (`<usuario>.github.io/<repo>/`) no sirve para eso; hace falta un sitio de usuario u organización (repositorio `<usuario>.github.io`) o un dominio propio apuntando a Pages. La política de privacidad y la página de borrado de cuenta sí pueden estar en cualquier ruta. Donde este documento dice Firebase Hosting para las páginas legales, léase GitHub Pages.

## Resumen

Para llevar Orbit Runner a producción hay que sustituir los proveedores simulados por servicios reales y montar un servidor pequeño en Firebase. También hay que crear la app en AdMob y en Google Play Console. El código ya está preparado para el cambio: todo lo externo pasa por interfaces que se crean en un único sitio, `Services.reload()` (`orbit_runner_game/scripts/autoload/services.gd`).

Este documento es la referencia técnica para el agente que haga la integración. Describe también los pasos de consola con detalle, para saber qué esperar del propietario y comprobarlo. Cuando el propietario haya iniciado sesión en Firebase CLI y Google Cloud CLI (lista del propietario, 1.4), el agente hace por línea de comandos todo lo que se pueda: activar API, crear la base de datos de Firestore, registrar la app Android y sus huellas (`firebase apps:create`, `firebase apps:android:sha:create`, `firebase apps:sdkconfig`), crear la cuenta de servicio `play-verifier` y el tema de Pub/Sub, y desplegar reglas, índices, funciones y Hosting. Solo pide al propietario lo que exige su cuenta, su tarjeta o una decisión suya. Los nombres de menú de las consolas cambian con el tiempo; ante una diferencia, manda la documentación oficial.

### Qué está simulado hoy

| Pieza del juego | Archivo actual | Simulado hoy | Servicio real |
| --- | --- | --- | --- |
| Cuenta y login | `scripts/services/simulated_auth.gd` | Login falso con Google o Facebook | Firebase Authentication + Inicio de sesión con Google (Credential Manager) |
| Amigos e invitaciones | `scripts/services/simulated_social.gd` | 4 amigos sacados de los rivales | Firestore + Cloud Functions |
| Ranking de temporada | `scripts/season/leaderboard.gd` | 60 rivales simulados | Firestore + Cloud Functions |
| Calendario de temporadas y economía | `resources/seasons/season_schedule.tres`, `resources/economy/economy_config.tres` | Archivos dentro del APK | Documentos de configuración en Firestore, servidos por una función |
| Hora | `scripts/services/game_clock.gd` | Reloj del teléfono (se puede adelantar) | Hora del servidor |
| Energía | `scripts/economy/energy.gd` | Solo en el teléfono | Estado guardado y validado en el servidor |
| Anuncios recompensados | `scripts/services/simulated_ads.gd` | Cuenta atrás de 5 s | AdMob, configurado para menores |
| Tienda | `scripts/services/simulated_store.gd` | Confirma sin cobrar | Google Play Billing + verificación en el servidor |
| Avisos | `scripts/services/notification_center.gd` + plugin `OrbitNotifications` | Ya son reales (alarmas locales de Android) | Se mantienen; Cloud Messaging es opcional |
| Guardado | `scripts/autoload/save_service.gd` | Solo en el teléfono | Copia en la nube por cuenta |

### Orden de trabajo recomendado

1. Crear las cuentas y pagar las altas (Paso 0).
2. Crear el proyecto de Firebase y Google Cloud con alertas de presupuesto (Paso 1).
3. Crear la clave de firma y registrar la app Android con sus huellas SHA (Paso 2).
4. Integrar los plugins en Godot y cambiar los proveedores en `Services.reload()` (Paso 3).
5. Activar Authentication, Firestore y Cloud Functions (Pasos 4 a 6).
6. Activar App Check y, si se quiere, Cloud Messaging y Crashlytics (Paso 7).
7. Configurar AdMob (Paso 8) y Google Play Billing (Paso 9).
8. Rellenar la ficha y las declaraciones de Play Console, hacer la prueba cerrada y publicar (Pasos 10 y 11).

Los pasos 0 a 3 se hacen una sola vez y en ese orden. Los pasos 4 a 9 se pueden repartir entre varias personas cuando el proyecto de Firebase ya existe.

### Antes de empezar: decisiones pendientes del propietario

- **Precios reales** de los productos de la tienda y del pase de temporada.
- **Facebook Login**: exige crear una app de Meta y pasar su revisión. Recomendación: lanzar solo con Google y añadir Facebook después.
- **Región de los datos**: decidido `us-central1`. La ubicación de Firestore no se puede cambiar después de crearla.
- **Nombre definitivo del juego** y del paquete. `com.orbitrunner.game` no se puede cambiar una vez publicada la app en Google Play.

## Mapa de la arquitectura

```text
Teléfono (Godot 4.7)                 Firebase (us-central1)            Google Play / AdMob
-------------------------------      -----------------------------      -------------------------------
GDScript: Services, CloudApi  --HTTPS-->  Cloud Functions  ---------->  Play Developer API (verifica)
                                           |       ^------------------  RTDN por Pub/Sub (reembolsos)
                                           v       ^------------------  AdMob SSV (anuncio visto)
OrbitNotifications (avisos locales)       Firestore (solo funciones)
OrbitPlay: login Google, App Check -->    Auth y App Check
Play Billing (plugin oficial)  ----------------------------------------> Cobro de Google Play
AdMob (Poing Studios)  ------------------------------------------------> Red de AdMob (familias)
```

El juego llama a Cloud Functions por HTTPS con dos tokens: la sesión de Authentication y el de App Check que da `OrbitPlay`. Solo las funciones leen y escriben Firestore, y son ellas las que verifican compras con la API de Google Play, reciben los reembolsos (RTDN) y la confirmación de anuncios de AdMob (SSV). La compra y el anuncio se muestran con los SDK nativos de Google; Firebase Hosting sirve aparte las páginas legales y `app-ads.txt`.

## Paso 0 — Cuentas y requisitos previos

Hacen falta cinco cuentas, todas ligadas a la misma cuenta de Google del propietario. Créalas en este orden, porque Google Play tarda días en verificar la identidad.

| Cuenta | Enlace | Coste | Tiempo de alta | Para qué |
| --- | --- | --- | --- | --- |
| Cuenta de Google del proyecto | [accounts.google.com](https://accounts.google.com/signup) | Gratis | Minutos | Será propietaria de todo lo demás |
| Google Play Console | [play.google.com/console/signup](https://play.google.com/console/signup) | 25 USD, un solo pago | De 2 a 7 días (verificación de identidad) | Publicar la app y vender productos |
| Perfil de pagos de Google (comerciante) | [pay.google.com](https://pay.google.com) y Play Console → Configuración → Perfil de pagos | Gratis | Minutos, más la revisión fiscal | Cobrar las compras dentro de la app |
| Google Cloud + cuenta de facturación | [console.cloud.google.com/billing](https://console.cloud.google.com/billing) | Gratis; se paga solo lo que se use | Minutos (pide una tarjeta) | Necesaria para Cloud Functions (plan Blaze) |
| Firebase | [console.firebase.google.com](https://console.firebase.google.com) | Gratis | Minutos | Login, base de datos y servidor |
| AdMob | [admob.google.com](https://admob.google.com) | Gratis | Minutos, más la revisión de la app | Anuncios recompensados |

### 0.1 Cuenta de Google del proyecto

1. Usa una cuenta dedicada al juego (por ejemplo `orbitrunner.studio@gmail.com`), no una cuenta personal de uso diario. Así se puede dar acceso a otros desarrolladores sin compartir el correo personal.
2. Activa la verificación en dos pasos: [myaccount.google.com/security](https://myaccount.google.com/security). Google Play y Google Cloud la exigen para varias acciones.
3. Guarda los códigos de recuperación en un gestor de contraseñas, nunca en el repositorio.

### 0.2 Google Play Console

1. Entra en [play.google.com/console/signup](https://play.google.com/console/signup) con la cuenta del proyecto.
2. Elige el tipo de cuenta:
   - **Personal**: la más rápida. Desde noviembre de 2023 obliga a hacer una **prueba cerrada con al menos 12 testers durante 14 días seguidos** antes de poder publicar en producción ([requisito oficial](https://support.google.com/googleplay/android-developer/answer/14151465)).
   - **Organización**: exige un número D-U-N-S de la empresa ([solicitud gratuita](https://www.dnb.com/duns-number/get-a-duns.html), tarda semanas). No tiene el requisito de los 12 testers.
3. Paga los 25 USD con tarjeta.
4. Completa la verificación de identidad: documento oficial, dirección y teléfono. El nombre y la dirección del desarrollador se muestran públicamente en la ficha de Google Play.
5. Cuando la cuenta esté verificada, ve a **Configuración → Perfil de pagos** y crea el perfil de comerciante con los datos fiscales. Sin él no se pueden crear productos de pago.

### 0.3 Google Cloud y facturación

1. Entra en [console.cloud.google.com](https://console.cloud.google.com) con la cuenta del proyecto y acepta las condiciones.
2. Ve a **Facturación → Crear cuenta** ([enlace directo](https://console.cloud.google.com/billing/create)), añade la tarjeta y elige el país de facturación.
3. No crees todavía ningún proyecto: Firebase lo creará en el Paso 1 y aparecerá aquí solo.

### 0.4 AdMob

1. Entra en [admob.google.com](https://admob.google.com) con la cuenta del proyecto y pulsa **Empezar**.
2. Indica país y zona horaria. Después se piden los datos de pago para recibir los ingresos (Pagos → Configuración de pagos).
3. La app se añade en el Paso 8. AdMob solo la aprueba del todo cuando ya está publicada en Google Play.

### 0.5 Un sitio web del desarrollador

Google Play pide una política de privacidad pública y un enlace para borrar la cuenta. AdMob pide un archivo `app-ads.txt` en el sitio web del desarrollador. Lo más sencillo es:

- comprar un dominio (por ejemplo `orbitrunner.com`, unos 10–15 € al año);
- alojar tres páginas gratis en **Firebase Hosting** (Paso 1): `/privacidad`, `/borrar-cuenta` y `/app-ads.txt`.

Sin dominio propio se puede usar la dirección gratuita `https://<proyecto>.web.app`, pero un dominio propio da más confianza y es lo que AdMob espera para `app-ads.txt`.

### 0.6 Acceso para otros desarrolladores

Invita a cada persona con su propio correo, nunca compartiendo la contraseña del proyecto:

- **Firebase**: ⚙ Configuración del proyecto → Usuarios y permisos → Agregar miembro (rol Editor para desarrolladores).
- **Google Cloud**: IAM y administración → IAM → Conceder acceso.
- **Play Console**: Usuarios y permisos → Invitar a usuarios nuevos (marca solo los permisos de la app que necesite).
- **AdMob**: Configuración → Acceso y autorización → Agregar usuario.

## Paso 1 — Proyecto de Firebase y Google Cloud

Un proyecto de Firebase **es** un proyecto de Google Cloud con una consola más sencilla encima. Todo lo que se cree en una consola aparece en la otra. Conviene tener dos proyectos: uno de desarrollo y otro de producción, para que las pruebas no ensucien los rankings reales.

| Proyecto | Nombre sugerido | Uso |
| --- | --- | --- |
| Desarrollo | `orbit-runner-dev` | Editor de Godot, APK de depuración, pruebas internas |
| Producción | `orbit-runner-prod` | Versión publicada en Google Play |

Repite los pasos 1.1 a 1.5 en los dos proyectos.

### 1.1 Crear el proyecto

1. Abre [console.firebase.google.com](https://console.firebase.google.com) y pulsa **Crear un proyecto**.
2. Nombre: `orbit-runner-prod`. Firebase propone un ID; apúntalo, porque aparece en todas las URL (por ejemplo `orbit-runner-prod`). El ID no se puede cambiar.
3. **Google Analytics**: desactívalo de momento. El público incluye menores de 13 años y Analytics exige configuración extra (ver Paso 7). Se puede activar después.
4. Pulsa **Crear proyecto** y espera un minuto.

### 1.2 Pasar al plan Blaze

Cloud Functions solo existe en el plan Blaze (pago por uso). Blaze incluye las mismas cuotas gratuitas que el plan Spark, así que un juego pequeño suele costar 0 € al mes ([precios](https://firebase.google.com/pricing)).

1. En la consola de Firebase, abajo a la izquierda, pulsa **Actualizar** junto a "Spark".
2. Elige **Blaze** y selecciona la cuenta de facturación creada en el Paso 0.3.
3. Firebase ofrece crear una alerta de presupuesto: acepta y pon un importe bajo, por ejemplo 10 €.

### 1.3 Alertas de presupuesto

Una alerta **no corta el servicio**: solo avisa por correo. Crea varias para enterarte a tiempo de un fallo que dispare el gasto.

1. Ve a [console.cloud.google.com/billing/budgets](https://console.cloud.google.com/billing/budgets) y elige la cuenta de facturación.
2. **Crear presupuesto** → Nombre `orbit-runner-prod` → Proyectos: solo `orbit-runner-prod`.
3. Importe: 20 € al mes. Umbrales: 25 %, 50 %, 90 % y 100 %.
4. Marca "Enviar alertas por correo a los administradores de facturación".

### 1.4 Activar las API de Google Cloud

La mayoría se activan solas al usar cada producto en la consola de Firebase, pero conviene comprobarlas. Ve a **APIs y servicios → Biblioteca** ([enlace](https://console.cloud.google.com/apis/library)), busca cada una y pulsa **Habilitar**:

| API | Para qué |
| --- | --- |
| Identity Toolkit API | Firebase Authentication |
| Token Service API | Renovar las sesiones de usuario |
| Cloud Firestore API | Base de datos |
| Cloud Functions API, Cloud Run Admin API, Cloud Build API, Artifact Registry API, Eventarc API | Desplegar y ejecutar las funciones (2.ª generación) |
| Cloud Scheduler API | Tareas programadas: cierre de temporadas |
| Cloud Pub/Sub API | Notificaciones de compras de Google Play |
| Secret Manager API | Guardar claves privadas fuera del código |
| Google Play Android Developer API | Verificar compras desde el servidor |
| Firebase App Check API | Comprobar que las peticiones vienen de la app real |
| Play Integrity API | Proveedor de App Check en Android |

### 1.5 Elegir la región

Usa la misma región en todo para reducir latencia y coste:

- **Firestore**: `nam5` (multirregión de EE. UU., más disponibilidad) o `us-central1` (Iowa, más barata). Decidido: `us-central1`.
- **Cloud Functions y Cloud Scheduler**: `us-central1`.

La ubicación de Firestore **no se puede cambiar**. Si el público principal está en América, usa `us-central1` en todo.

### 1.6 Firebase Hosting para las páginas legales

1. Consola de Firebase → **Compilación → Hosting → Comenzar**.
2. Instala las herramientas en el PC (necesitas [Node.js 22 LTS](https://nodejs.org)): `npm install -g firebase-tools`, y después `firebase login`.
3. En una carpeta nueva del repositorio, por ejemplo `backend/`, ejecuta `firebase init` y marca Hosting, Firestore y Functions. Elige el proyecto existente.
4. Pon en `backend/public/` las páginas `privacidad.html`, `borrar-cuenta.html` y, cuando exista, `app-ads.txt`.
5. Publica con `firebase deploy --only hosting`.
6. Para el dominio propio: Hosting → **Agregar dominio personalizado** y sigue las instrucciones de DNS. El certificado HTTPS es gratuito y automático.

### 1.7 Alias de proyectos en el repositorio

En `backend/.firebaserc` deja los dos proyectos con alias, para no desplegar en producción por error:

```json
{
  "projects": {
    "dev": "orbit-runner-dev",
    "prod": "orbit-runner-prod"
  }
}
```

Después se despliega con `firebase deploy --project dev` o `firebase deploy --project prod`.

## Paso 2 — Firma de la app y registro de Android en Firebase

Google identifica la app por dos datos: el **nombre del paquete** (`com.orbitrunner.game`, en `orbit_runner_game/export_presets.cfg`) y la **huella del certificado** con que se firma. El login con Google, App Check y la verificación de compras fallan si falta alguna huella.

### 2.1 Las tres claves que existen

| Clave | Quién la guarda | Dónde sale su huella | Se usa para |
| --- | --- | --- | --- |
| Depuración | Godot, en `%APPDATA%\Godot\keystores\debug.keystore` | `keytool` (abajo) | APK de pruebas instalados por cable |
| Subida (*upload key*) | Tú, en un lugar seguro fuera del repositorio | `keytool` (abajo) | Firmar el AAB que subes a Play Console |
| Firma de la app (*app signing key*) | Google, con Play App Signing | Play Console → Probar y publicar → Integridad de la app → Firma de apps | La versión que descargan los jugadores |

Las tres huellas SHA-1 y SHA-256 se registran en Firebase (2.4). Si se olvida la de la clave de Google, el login funciona en tus pruebas pero falla en la versión descargada de Google Play.

### 2.2 Crear la clave de subida

`keytool` viene con el JDK 17 que ya usa el proyecto para compilar el plugin de avisos. En una terminal:

```
keytool -genkeypair -v -keystore orbit_runner_upload.keystore -alias orbit_upload -keyalg RSA -keysize 4096 -validity 10000
```

1. Pide una contraseña, tu nombre y la organización. Usa una contraseña larga y guárdala en un gestor de contraseñas.
2. Guarda el archivo `.keystore` **fuera del repositorio** y haz dos copias de seguridad (por ejemplo, un USB y un almacenamiento en la nube cifrado).
3. Si se pierde la clave de subida se puede pedir a Google que la cambie, pero tarda días. Si se pierde sin Play App Signing, la app ya no se puede actualizar.

### 2.3 Sacar las huellas

```
keytool -list -v -keystore orbit_runner_upload.keystore -alias orbit_upload
keytool -list -v -keystore "%APPDATA%\Godot\keystores\debug.keystore" -alias androiddebugkey -storepass android
```

Copia las líneas `SHA1:` y `SHA256:` de cada una. La huella de la clave de Google aparece en Play Console cuando subes el primer AAB (Paso 10).

### 2.4 Registrar la app Android en Firebase

1. Consola de Firebase → ⚙ **Configuración del proyecto → General → Tus apps → Agregar app → Android**.
2. Nombre del paquete: `com.orbitrunner.game` (exactamente igual que en `export_presets.cfg`).
3. Apodo: `Orbit Runner Android`.
4. Certificado SHA-1: pega el de depuración (en `orbit-runner-dev`) o el de subida (en `orbit-runner-prod`).
5. Pulsa **Registrar app** y descarga `google-services.json`.
6. Vuelve a **Configuración del proyecto → Tus apps → Orbit Runner Android → Agregar huella digital** y añade el resto de huellas: SHA-1 y SHA-256 de las tres claves.
7. Salta los pasos del asistente sobre Gradle: con Godot se hace distinto (Paso 3).

### 2.5 Qué datos del `google-services.json` usa el juego

El archivo contiene identificadores públicos, no secretos: se pueden distribuir dentro de la app. El juego necesita estos cuatro valores:

| Campo en `google-services.json` | Nombre en el juego | Ejemplo |
| --- | --- | --- |
| `project_info.project_id` | `project_id` | `orbit-runner-prod` |
| `client[0].api_key[0].current_key` | `api_key` | `AIzaSy...` |
| `client[0].client_info.mobilesdk_app_id` | `app_id` | `1:1234567890:android:abc123` |
| `project_info.project_number` | `sender_id` | `1234567890` |

Guárdalos en un recurso por entorno, por ejemplo `orbit_runner_game/resources/online/firebase_dev.tres` y `firebase_prod.tres` (clase `FirebaseConfig`, a crear). La clave de API de Firebase identifica el proyecto; la seguridad real la dan las reglas de Firestore y App Check.

### 2.6 Restringir la clave de API

1. Google Cloud → **APIs y servicios → Credenciales** ([enlace](https://console.cloud.google.com/apis/credentials)).
2. Abre la clave "Android key (auto created by Firebase)".
3. **Restricciones de aplicación**: Apps de Android → añade `com.orbitrunner.game` con cada SHA-1.
4. **Restricciones de API**: limita la clave a Identity Toolkit API, Token Service API, Firebase App Check API, Cloud Firestore API y Firebase Installations API.

Con la clave restringida a apps Android, cada llamada REST que haga el juego debe llevar dos cabeceras: `X-Android-Package: com.orbitrunner.game` y `X-Android-Cert: <SHA-1 sin los dos puntos>`. El cliente REST del Paso 3 las añade siempre. Para desarrollo en PC crea una segunda clave en `orbit-runner-dev` sin restricción de aplicación, y no la uses nunca en producción.

### 2.7 Configurar la firma en Godot

Godot lee la clave de publicación de variables de entorno, así la contraseña no queda en `export_presets.cfg` (que sí está en el repositorio):

```
setx GODOT_ANDROID_KEYSTORE_RELEASE_PATH "D:\claves\orbit_runner_upload.keystore"
setx GODOT_ANDROID_KEYSTORE_RELEASE_USER "orbit_upload"
setx GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD "<la contraseña>"
```

Cierra y vuelve a abrir Godot después de definirlas. No escribas la contraseña en el diálogo de exportación si ese preset se va a subir a git.

## Paso 3 — Integrar los servicios en Godot

Recomendación: **Firebase por REST desde GDScript y solo tres piezas nativas** (login con Google, App Check, anuncios y compras). El juego usa Godot 4.7.2 con exportación Gradle, `targetSdk` 36 y `minSdk` 24 (`orbit_runner_game/android/build/config.gradle`). Ya tiene un plugin Android propio (`OrbitNotifications`), así que el camino para añadir código nativo está probado.

### 3.1 Qué herramienta para cada servicio

| Servicio | Herramienta recomendada | Tipo | Por qué |
| --- | --- | --- | --- |
| Firebase Authentication | API REST de Identity Toolkit desde GDScript (`HTTPRequest`) | GDScript | Funciona igual en el editor de PC y en Android; no depende de plugins de terceros |
| Datos, ranking, amigos, energía | Cloud Functions *callable* por HTTPS desde GDScript | GDScript | El servidor decide; el cliente nunca escribe directamente en Firestore |
| Inicio de sesión con Google | Plugin propio `OrbitPlay` con Credential Manager (Java) | Nativo | Devuelve el *ID token* de Google que se canjea en Firebase |
| App Check (Play Integrity) | El mismo plugin `OrbitPlay` con `firebase-appcheck-playintegrity` | Nativo | La atestación solo existe en el SDK de Android |
| Anuncios | [Poing Studios AdMob](https://github.com/poingstudios/godot-admob-plugin) (Godot 4.5+) | Plugin de terceros | El más usado; incluye recompensados y el formulario de consentimiento (UMP) |
| Compras | [GodotGooglePlayBilling](https://github.com/godot-sdk-integrations/godot-google-play-billing) | Plugin oficial de la organización Godot | Mantenido junto al motor |
| Avisos | `OrbitNotifications` (ya existe) | Nativo | Se mantiene tal cual |

Alternativas descartadas: [GodotFirebaseAndroid](https://github.com/syntaxerror247/GodotFirebaseAndroid) (su autor marca la versión como inestable) y [GodotFirebase de GodotNuts](https://github.com/GodotNuts/GodotFirebase) (REST, válido, pero añade mucho código que el juego no usa). Para el login con Google existe [GodotGoogleSignIn](https://github.com/NiqueWrld/GodotGoogleSignIn) (versión 1.0.0); es una opción si no se quiere escribir Java, pero tiene poco recorrido.

Antes de instalar un plugin de terceros, comprueba en su página de versiones que es compatible con Godot 4.7 y que la de compras usa **Play Billing Library 8 o posterior**: desde el 31 de agosto de 2026 Google Play rechaza versiones nuevas con bibliotecas anteriores ([aviso oficial](https://developer.android.com/google/play/billing/getting-ready)).

### 3.2 Instalar los plugins de terceros

1. **AdMob**: descarga `poing-godot-admob-v*.zip` de [Releases](https://github.com/poingstudios/godot-admob-plugin/releases), descomprímelo en `orbit_runner_game/` (crea `addons/admob/`), y activa el plugin en **Proyecto → Configuración del proyecto → Plugins**. Después, en **Proyecto → Herramientas → AdMob Manager → Android → Download & Install** descarga las dependencias nativas.
2. **Compras**: descarga la última versión de [Releases](https://github.com/godot-sdk-integrations/godot-google-play-billing/releases), copia la carpeta a `orbit_runner_game/addons/GodotGooglePlayBilling/` y activa el plugin. La API está documentada en [su web](https://godot-sdk-integrations.github.io/godot-google-play-billing).
3. Exportación Android: `gradle_build/use_gradle_build=true` ya está activado en `export_presets.cfg`.
4. Añade al `.gitignore` las carpetas de binarios descargados que no deban versionarse, si el plugin lo indica.

### 3.3 El plugin propio `OrbitPlay`

Se crea igual que `OrbitNotifications`: fuente Java en `orbit_runner_game/android/plugins/orbit_play/` y addon en `orbit_runner_game/addons/orbit_play/`. Expone tres métodos a GDScript:

| Método (`@UsedByGodot`) | Qué hace | Señal de respuesta |
| --- | --- | --- |
| `initFirebase(appId, apiKey, projectId)` | Inicializa `FirebaseApp` a mano con `FirebaseOptions`, sin el plugin de Gradle `google-services`, e instala `PlayIntegrityAppCheckProviderFactory` | — |
| `signInWithGoogle(webClientId, filterAuthorized)` | Pide la credencial con `GetGoogleIdOption` (o `GetSignInWithGoogleOption` al pulsar el botón) | `google_signed_in(id_token)` / `google_sign_in_failed(code, message)` |
| `getAppCheckToken(forceRefresh)` | `FirebaseAppCheck.getInstance().getAppCheckToken(...)` | `app_check_token(token, expires_ms)` / `app_check_failed(message)` |

El `EditorExportPlugin` del addon declara las dependencias de Maven con `_get_android_dependencies()`:

```
androidx.credentials:credentials:<última estable>
androidx.credentials:credentials-play-services-auth:<última estable>
com.google.android.libraries.identity.googleid:googleid:<última estable>
com.google.firebase:firebase-appcheck-playintegrity:<última estable>
```

Consulta las versiones en las [notas de Credential Manager](https://developer.android.com/jetpack/androidx/releases/credentials) y las [notas de Firebase Android](https://firebase.google.com/support/release-notes/android). La guía de plugins de Godot 4.7 está en [docs.godotengine.org](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html). Se compila igual que el de avisos: `../../build/gradlew.bat -p . assembleRelease` con `JAVA_HOME` en el JDK 17.

### 3.4 Archivos GDScript nuevos

| Archivo | Clase | Responsabilidad |
| --- | --- | --- |
| `scripts/online/firebase_config.gd` | `FirebaseConfig` (Resource) | `project_id`, `api_key`, `app_id`, `web_client_id`, `region`, `android_cert_sha1` |
| `scripts/online/firebase_session.gd` | `FirebaseSession` | Login anónimo, canje del token de Google, renovación del token, cierre y borrado (REST) |
| `scripts/online/cloud_api.gd` | `CloudApi` | Llama a las funciones con `Authorization: Bearer <idToken>` y `X-Firebase-AppCheck: <token>`; reintenta y guarda la hora del servidor |
| `scripts/services/firebase_auth.gd` | `FirebaseAuth` extends `AuthProvider` | Sustituye a `SimulatedAuth` |
| `scripts/services/online_social.gd` | `OnlineSocial` extends `SocialProvider` | Amigos e invitaciones por `CloudApi` |
| `scripts/services/admob_ads.gd` | `AdMobAds` extends `AdsProvider` | Carga y muestra el recompensado, siempre en modo familias |
| `scripts/services/play_store.gd` | `PlayStore` extends `StoreProvider` | Precios reales, compra y entrega tras verificar en el servidor |

Los proveedores simulados se conservan: sirven para jugar sin conexión en PC y para los bots validadores.

### 3.5 El cambio en `Services.reload()`

Hoy `reload()` crea siempre los simulados. Pasa a elegir según la plataforma y un argumento de línea de comandos:

```gdscript
var online := OS.has_feature("android") or OS.get_cmdline_user_args().has("online=1")
if online:
	var config: FirebaseConfig = load("res://resources/online/firebase_%s.tres" % ("prod" if not OS.is_debug_build() else "dev"))
	cloud = CloudApi.new(config)
	add_child(cloud)
	auth = FirebaseAuth.new(account, cloud)
	social = OnlineSocial.new(account, cloud)
	ads = AdMobAds.new(config, is_child())
	store = PlayStore.new(cloud)
else:
	ads = SimulatedAds.new(economy.simulated_ad_seconds)
	store = SimulatedStore.new()
	auth = SimulatedAuth.new(account)
	social = SimulatedSocial.new(account)
```

Con esto el resto del juego (tienda, energía, pantalla de amigos, temporada) no cambia: ya llama a las interfaces.

### 3.6 Hora del servidor

`GameClock.now()` suma `offset_seconds`. `CloudApi` lo ajusta con la hora que devuelve cada respuesta del servidor (`serverTime` en milisegundos): `GameClock.offset_seconds = server_seconds - Time.get_unix_time_from_system()`. Así la energía y las temporadas dejan de depender del reloj del teléfono sin tocar a quien llama a `GameClock`. El argumento de pruebas `clock_hours=N` debe ignorarse en las versiones de producción.

## Paso 4 — Authentication

Todo jugador recibe una **cuenta anónima** de Firebase al abrir el juego por primera vez. Los mayores de 13 años pueden vincularla después a Google (y más adelante a Facebook) sin perder el progreso. Los menores se quedan siempre en la cuenta anónima, como ya hace el juego hoy (`Services.is_child()`).

### 4.1 Activar los métodos de acceso

1. Consola de Firebase → **Compilación → Authentication → Comenzar**.
2. Pestaña **Método de acceso**:
   - **Anónimo** → Habilitar → Guardar.
   - **Google** → Habilitar. Nombre público: `Orbit Runner`. Correo de asistencia: el del proyecto. Guardar.
3. Vuelve a abrir el proveedor **Google** y despliega **Configuración del SDK web**. Copia el **ID de cliente web** (termina en `.apps.googleusercontent.com`). Va en `FirebaseConfig.web_client_id`: es el `serverClientId` que pide Credential Manager.
4. Pestaña **Configuración → Vinculación de cuentas de usuario**: deja "Vincular cuentas que usan el mismo correo".

### 4.2 Pantalla de consentimiento de Google (Google Auth Platform)

Es la ventana que ve el jugador al elegir su cuenta de Google. Sin configurarla, el login solo funciona para las cuentas de prueba.

1. Google Cloud → **Google Auth Platform** ([enlace](https://console.cloud.google.com/auth/overview)) del proyecto `orbit-runner-prod`.
2. **Branding**: nombre `Orbit Runner`, correo de asistencia, logotipo de 120 × 120 px, página principal, política de privacidad y condiciones (las páginas del Paso 1.6) y el dominio autorizado (`orbitrunner.com` o `orbit-runner-prod.web.app`).
3. **Público**: tipo **Externo** y pulsa **Publicar app** para pasar de "Prueba" a "En producción".
4. **Acceso a datos**: solo los permisos básicos `openid`, `email` y `profile`. Al no pedir permisos sensibles no hace falta la revisión de seguridad; sí la verificación de marca para que aparezcan el nombre y el logotipo ([ayuda](https://support.google.com/cloud/answer/13463073)).
5. **Clientes**: comprueba que existe un cliente **Android** con el paquete `com.orbitrunner.game` y la SHA-1 de cada clave (Firebase lo crea al registrar las huellas) y un cliente **Web** (el del punto 4.1.3). Si falta el Android, créalo con **Crear cliente → Android**.

### 4.3 Flujo de sesión por REST

Todas las llamadas llevan `?key=<api_key>` y las cabeceras de Android del Paso 2.6.

| Momento | Petición | Cuerpo |
| --- | --- | --- |
| Primera apertura | `POST https://identitytoolkit.googleapis.com/v1/accounts:signUp` | `{"returnSecureToken": true}` |
| Vincular con Google | `POST https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp` | `{"postBody": "id_token=<token de Google>&providerId=google.com", "requestUri": "http://localhost", "idToken": "<idToken anónimo>", "returnSecureToken": true, "returnIdpCredential": true}` |
| Entrar con Google en otro teléfono | La misma, sin el campo `idToken` | — |
| Renovar la sesión (el token dura 1 h) | `POST https://securetoken.googleapis.com/v1/token` | `grant_type=refresh_token&refresh_token=<refreshToken>` (formulario) |
| Borrar la cuenta | La función `deleteAccount` del Paso 6, que también borra los datos | — |

La respuesta trae `idToken`, `refreshToken`, `localId` (el `uid` del jugador) y `expiresIn`. Guarda `refreshToken` y `localId` en la sección `services.account` del guardado y nunca el `idToken` (caduca en una hora). El `uid` sustituye al `user_id` local que genera hoy `Services.reload()`.

Si Google responde `FEDERATED_USER_ID_ALREADY_LINKED`, esa cuenta de Google ya tiene otro progreso. El juego debe preguntar cuál conservar: el de este teléfono o el de la nube. No mezcles los dos en silencio.

Referencia completa: [Firebase Auth REST API](https://firebase.google.com/docs/reference/rest/auth).

### 4.4 Menores de 13 años

- El juego ya guarda solo el grupo de edad (`AgeGate`). Envíalo al servidor en el primer `syncProfile` para que las funciones lo apliquen: sin amigos por nombre libre, sin login social y anuncios para familias.
- Nunca pidas el correo, el nombre real ni la fecha exacta de nacimiento.
- La cuenta anónima de un menor se pierde si desinstala el juego. Es aceptable; el juego puede mostrar un aviso neutro en Ajustes.

### 4.5 Facebook Login (opcional, después del lanzamiento)

Requiere una app de Meta y el SDK de Facebook dentro de `OrbitPlay`. Pasos:

1. [developers.facebook.com/apps](https://developers.facebook.com/apps) → **Crear app** → caso de uso "Autenticar y solicitar datos a usuarios con Inicio de sesión con Facebook".
2. Copia el **ID de la app** y la **clave secreta** (Configuración de la app → Básica).
3. Firebase → Authentication → Método de acceso → **Facebook** → pega ambos y copia la **URI de redireccionamiento OAuth** que muestra.
4. En Meta: Inicio de sesión con Facebook → Configuración → pega esa URI en "URI de redireccionamiento de OAuth válidos".
5. En Meta: Configuración → Básica → **Agregar plataforma → Android**: paquete `com.orbitrunner.game`, clase `com.godot.game.GodotApp` y los *key hashes* (la SHA-1 de cada clave en Base64).
6. Rellena icono, categoría, URL de la política de privacidad y URL de eliminación de datos; después pasa la app a modo **Activo**.
7. En el juego: el SDK de Facebook devuelve un *access token*, que se canjea con `signInWithIdp` y `postBody: "access_token=<token>&providerId=facebook.com"`.

El SDK de Facebook no debe cargarse nunca para menores ni para jugadores de edad desconocida (política de Familias, ver Paso 10).

## Paso 5 — Firestore

Firestore guarda el progreso en la nube, la energía, los rankings, los amigos y las compras. **El juego no escribe nunca directamente**: todo pasa por las funciones del Paso 6, que validan cada cambio. Las reglas de seguridad solo permiten leer la configuración y los rankings.

### 5.1 Crear la base de datos

1. Consola de Firebase → **Compilación → Firestore Database → Crear base de datos**.
2. Edición: **Standard**. ID: `(default)`.
3. Ubicación: `us-central1` (o la elegida en el Paso 1.5). No se puede cambiar después.
4. Reglas iniciales: **Modo de producción** (todo cerrado). Las reglas reales se despliegan desde el repositorio (5.3).
5. En **Recuperación ante desastres**, activa las copias de seguridad diarias con 7 días de retención. Tienen coste por GB guardado, pequeño con pocos datos.

### 5.2 Colecciones

| Ruta | Contenido | Quién escribe |
| --- | --- | --- |
| `users/{uid}` | Nombre visible, `nameGenerated`, `ageGroup`, traje, código de invitación, fecha de alta | Funciones |
| `users/{uid}/private/save` | Copia del guardado: progreso de campaña, maestría, chispas, misiones | Funciones (`syncProfile`) |
| `users/{uid}/private/energy` | `points`, `updatedAt` (hora del servidor), `unlimitedUntil`, `adsToday`, `adsDay` | Funciones |
| `users/{uid}/friends/{friendUid}` | Desde cuándo son amigos | Funciones (`redeemInvite`) |
| `users/{uid}/purchases/{purchaseToken}` | Producto, estado, hora y orden de Google Play | Funciones (`verifyPurchase`, RTDN) |
| `invites/{code}` | `uid` del dueño del código `ORB-XXXX` | Funciones |
| `seasons/{seasonId}` | Número, inicio, fin, dificultad y los 20 niveles (semilla, reparaciones, medallas, hash de ruta) | Herramienta de publicación (Admin SDK) |
| `seasons/{seasonId}/scores/{uid}` | Puntos, niveles completados, suma de mejores tiempos, mejor resultado por nivel, nombre y traje | Funciones (`submitRun`) |
| `dailies/{fecha}` | Semilla validada, reparaciones y medallas del desafío diario | Herramienta de publicación |
| `config/economy` | Los valores de `EconomyConfig`: energía máxima, recarga, anuncios por día, premios de temporada | Consola o herramienta |
| `config/store` | Productos activos: id, tipo, cantidad | Consola o herramienta |
| `processedMessages/{messageId}` | Mensajes de Google Play ya procesados, con caducidad de 30 días | Funciones |

Para publicar temporadas y diarios, añade una herramienta que lea la salida de `tools/generate_levels.tscn` (el mismo JSON que hoy acaba en `season_schedule.tres` y `daily_seeds.tres`) y la suba con el Admin SDK, por ejemplo `backend/scripts/publish_season.ts`. El juego mantiene los `.tres` como respaldo sin conexión.

### 5.3 Reglas de seguridad

Archivo `backend/firestore.rules`:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Configuración y calendario: lectura para cualquier jugador con sesión.
    match /config/{doc} { allow read: if request.auth != null; }
    match /seasons/{seasonId} { allow read: if request.auth != null; }
    match /dailies/{day} { allow read: if request.auth != null; }
    // Rankings: lectura con sesión; escritura solo desde funciones.
    match /seasons/{seasonId}/scores/{uid} { allow read: if request.auth != null; }
    // Todo lo demás, cerrado. Las funciones usan el Admin SDK y no pasan por estas reglas.
    match /{document=**} { allow read, write: if false; }
  }
}
```

Despliega con `firebase deploy --only firestore:rules --project prod`. Prueba las reglas antes en el emulador local (`firebase emulators:start`) o en **Firestore → Reglas → Zona de pruebas de reglas**.

### 5.4 Índices

El ranking ordena por puntos, después por niveles completados y desempata por la suma de tiempos, igual que `Leaderboard` hoy. Archivo `backend/firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "scores",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "points", "order": "DESCENDING" },
        { "fieldPath": "levels", "order": "DESCENDING" },
        { "fieldPath": "timeSum", "order": "ASCENDING" }
      ]
    }
  ]
}
```

Despliega con `firebase deploy --only firestore:indexes --project prod`. La posición del jugador se calcula con una consulta de conteo (`count()`) de quienes tienen más puntos: cuesta una lectura por cada 1000 documentos contados.

### 5.5 Caducidad automática

Firestore → **Políticas de TTL** → Crear política: grupo de colecciones `processedMessages`, campo `expireAt`. Borra solos los registros viejos y evita pagar almacenamiento inútil.

## Paso 6 — Cloud Functions

Las funciones son el servidor del juego: deciden la hora, la energía, las puntuaciones válidas y qué compras se entregan. Se escriben en TypeScript, viven en `backend/functions/` y se despliegan con un comando. Usa la 2.ª generación, Node.js 22 y la región `us-central1`.

### 6.1 Preparar el proyecto de funciones

1. En `backend/`, si no lo hiciste en el Paso 1.6: `firebase init functions` → TypeScript → ESLint sí → instalar dependencias sí.
2. En `backend/functions/package.json` comprueba `"engines": { "node": "22" }`.
3. Dependencias adicionales: `npm install googleapis` (API de Google Play) dentro de `backend/functions/`.
4. Opciones globales al principio de `src/index.ts`:

```ts
import { setGlobalOptions } from "firebase-functions/v2";
setGlobalOptions({ region: "us-central1", maxInstances: 10 });
```

`maxInstances` limita cuántas copias se ejecutan a la vez: protege contra un pico de gasto si algo falla.

### 6.2 Funciones que necesita el juego

| Función | Tipo | La llama | Qué hace |
| --- | --- | --- | --- |
| `bootstrap` | *callable* | El juego al abrir | Devuelve `serverTime`, `config/economy`, `config/store`, las temporadas activas y próximas y el diario de hoy |
| `syncProfile` | *callable* | Al abrir y al salir de un nivel | Fusiona el guardado local con la copia en la nube; guarda el grupo de edad |
| `startAttempt` | *callable* | `SceneRouter.play_level()` y `play_generated()` | Recalcula la recarga con la hora del servidor y descuenta 1 de energía; responde si se puede jugar |
| `submitRun` | *callable* | Pantalla de resultados | Valida tiempo, gemas y chispas y actualiza `seasons/{id}/scores/{uid}` y los récords |
| `getLeaderboard` | *callable* | Pantalla de temporada | Top 50, la posición del jugador y la pestaña de amigos |
| `redeemInvite`, `listFriends` | *callable* | Pantalla de amigos | Canjea `ORB-XXXX` y lista amigos con su estado; rechaza si el jugador es menor sin puerta parental superada |
| `claimAdReward` | *callable* | Tras un anuncio | Comprueba el límite diario y suma la energía tras la confirmación del servidor de AdMob |
| `admobSsv` | HTTPS (*onRequest*) | Servidores de AdMob | Recibe la verificación del lado del servidor del anuncio recompensado (Paso 8.5) |
| `verifyPurchase` | *callable* | Tras una compra | Comprueba el token con la API de Google Play, entrega el producto y lo consume (Paso 9) |
| `playRtdn` | Pub/Sub (*onMessagePublished*) | Google Play | Procesa reembolsos y cancelaciones (Paso 9.5) |
| `closeSeasons` | Programada (*onSchedule*), cada día a las 00:05 UTC | Cloud Scheduler | Fija la posición final, paga las chispas y deja el aviso de resultado |
| `deleteAccount` | *callable* | Ajustes → Borrar cuenta | Borra `users/{uid}`, sus puntuaciones y la cuenta de Authentication |

Todas las *callable* llevan `enforceAppCheck: true` en cuanto App Check esté activado (Paso 7.3), y comprueban `request.auth` antes de hacer nada.

### 6.3 Ejemplo: descontar energía en el servidor

```ts
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";

export const startAttempt = onCall({ enforceAppCheck: true }, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Sin sesión");
  const db = getFirestore();
  const econ = (await db.doc("config/economy").get()).data()!;
  const ref = db.doc(`users/${req.auth.uid}/private/energy`);
  const now = Date.now();
  return db.runTransaction(async (tx) => {
    const e = (await tx.get(ref)).data() ?? { points: econ.energyMax, updatedAt: now };
    let points = e.points;
    if (points < econ.energyMax) {
      const gained = Math.floor((now - e.updatedAt) / (econ.energyRechargeSeconds * 1000));
      points = Math.min(econ.energyMax, points + gained);
    }
    const unlimited = (e.unlimitedUntil ?? 0) > now;
    if (!unlimited && points < econ.energyPerAttempt) {
      return { ok: false, points, serverTime: now };
    }
    if (!unlimited) points -= econ.energyPerAttempt;
    tx.set(ref, { ...e, points, updatedAt: now }, { merge: true });
    return { ok: true, points, serverTime: now };
  });
});
```

El cálculo de recarga debe dar lo mismo que `scripts/economy/energy.gd`. Si la recarga guarda el resto de tiempo parcial en el cliente, haz lo mismo aquí.

### 6.4 Cómo llama el juego a una función

Las *callable* aceptan un POST normal, así que `CloudApi` las llama con `HTTPRequest`:

```
POST https://us-central1-orbit-runner-prod.cloudfunctions.net/startAttempt
Content-Type: application/json
Authorization: Bearer <idToken>
X-Firebase-AppCheck: <token de App Check>

{"data": {"levelId": "w1_l3"}}
```

La respuesta es `{"result": {...}}` si va bien o `{"error": {"status": "UNAUTHENTICATED", "message": "..."}}` si no. Con `401`, renueva el `idToken` (Paso 4.3) y repite una vez.

### 6.5 Validar las marcas (`submitRun`)

Fase 1, para el lanzamiento: comprobaciones de plausibilidad.

- El nivel existe en la temporada activa y está desbloqueado para ese jugador.
- El tiempo no es menor que el del bot perfecto para ese nivel menos un margen (por ejemplo, el 85 %). El dato sale de la validación por bots que ya se hace al generar la temporada; súbelo junto a las medallas.
- Gemas ≤ 3, chispas ≤ las del nivel y la hora de envío dentro de la temporada.
- Como máximo, un envío cada 10 s por jugador.

Fase 2, después: verificar la repetición. El juego ya graba repeticiones deterministas (`scripts/replay/`, unos 18 KB por minuto) y la documentación confirma que reproducirlas da el mismo tiempo en PC. Se podría subir la repetición de los mejores puestos a Cloud Storage y reproducirla con Godot sin pantalla en un trabajo de Cloud Run. Antes hay que comprobar que la física da el mismo resultado en ARM (teléfono) y en x86 (servidor).

### 6.6 Desplegar y vigilar

1. Prueba en local con `firebase emulators:start` (Authentication, Firestore y Functions). El juego en el editor puede apuntar al emulador cambiando las URL base en `FirebaseConfig`.
2. Despliega: `firebase deploy --only functions --project dev`; cuando funcione, `--project prod`.
3. Registros: consola de Firebase → Functions → Registros, o [Cloud Logging](https://console.cloud.google.com/logs).
4. Crea una alerta en **Cloud Monitoring → Alertas** para errores de funciones por encima de 10 por minuto.

### 6.7 Claves sin archivos JSON

No descargues claves JSON de cuentas de servicio: son el secreto más fácil de filtrar. Para la API de Google Play se crea una cuenta de servicio dedicada, `play-verifier@<proyecto>.iam.gserviceaccount.com`, y las funciones la **suplantan** (*impersonation*) con `Impersonated` de `google-auth-library`, pidiendo el permiso `https://www.googleapis.com/auth/androidpublisher`. Los pasos están en el Paso 9.3. Si algún día hace falta un secreto de verdad, guárdalo con `firebase functions:secrets:set NOMBRE` (Secret Manager).

## Paso 7 — App Check, configuración remota, avisos y diagnóstico

De estos servicios, **App Check es obligatorio** para producción. Los demás se pueden dejar para después del lanzamiento.

| Servicio | ¿Para el lanzamiento? | Motivo |
| --- | --- | --- |
| App Check (Play Integrity) | Sí | Sin él, cualquiera puede llamar a las funciones con un script y falsear rankings o energía |
| Remote Config | No hace falta | La configuración ya vive en `config/*` de Firestore y la sirve `bootstrap` |
| Cloud Messaging (FCM) | Opcional | Los avisos de energía, temporada y diario ya funcionan con alarmas locales (`OrbitNotifications`) |
| Crashlytics | Opcional | Android vitals de Play Console ya registra cierres y ANR sin instalar nada |
| Google Analytics | Después, con cuidado | Público con menores: exige desactivar el identificador de publicidad y declararlo |

### 7.1 App Check: enlazar Play Integrity

1. **Play Console** → la app → **Probar y publicar → Integridad de la app → API de Play Integrity → Vincular proyecto de Cloud**. Elige `orbit-runner-prod`. Necesitas ser propietario del proyecto. Esta opción aparece cuando la app ya existe en Play Console (Paso 10.1).
2. **Consola de Firebase** → **Seguridad → App Check → Apps** → Orbit Runner Android → **Play Integrity** → pega la huella **SHA-256** de la clave de firma de Google (y la de subida si instalas versiones firmadas por ti) → Guardar.
3. Duración del token: deja 1 hora (valor por defecto).
4. En la misma pantalla, **configuración avanzada**: exige `PLAY_RECOGNIZED` (la app es la de Google Play) y la integridad básica del dispositivo. Exigir `LICENSED` impide jugar a quien instaló la app fuera de Google Play.

Guía oficial: [App Check con Play Integrity](https://firebase.google.com/docs/app-check/android/play-integrity-provider).

### 7.2 App Check en desarrollo

El editor de Godot y el emulador no pasan Play Integrity. Para ellos:

1. En `orbit-runner-dev`, el plugin `OrbitPlay` instala `DebugAppCheckProviderFactory` cuando la versión es de depuración.
2. Al arrancar, el registro de Android (`adb logcat`) imprime un *debug token*.
3. Consola de Firebase → App Check → Apps → ⋮ → **Administrar tokens de depuración** → pega el token.
4. En PC (REST, sin plugin) no hay App Check: deja la aplicación de App Check desactivada en `orbit-runner-dev`, o usa el emulador local de Functions.

### 7.3 Activar la aplicación de App Check

No la actives el primer día: primero publica la versión que envía tokens y mira las métricas.

1. Firebase → App Check → **APIs** → Cloud Firestore → mira el porcentaje de peticiones verificadas durante unos días.
2. Cuando casi todo esté verificado, pulsa **Aplicar** en Cloud Firestore.
3. En las funciones, `enforceAppCheck: true` en cada `onCall` y despliega.

### 7.4 Cloud Messaging (opcional)

Sirve para mensajes que no se pueden programar en el teléfono, por ejemplo "ha empezado una temporada especial".

1. Añade `com.google.firebase:firebase-messaging` a `OrbitPlay` y un servicio `FirebaseMessagingService` que muestre la notificación con el mismo canal de `OrbitNotifications`.
2. Suscribe a todos al tema `season` (`FirebaseMessaging.getInstance().subscribeToTopic("season")`).
3. Envía desde Firebase → **Interacción → Messaging → Nueva campaña**, o desde una función con el Admin SDK.
4. El permiso `POST_NOTIFICATIONS` ya se pide tras la pantalla de edad.
5. Con menores: solo mensajes informativos del juego, nunca ofertas de compra.

### 7.5 Diagnóstico de errores

- **Android vitals** (Play Console → Supervisar y mejorar → Android vitals): cierres, ANR, consumo de batería y frames lentos. Está activo sin instalar nada. Para ver la pila de los cierres del motor, sube los símbolos nativos en cada versión (App Bundle Explorer → la versión → Descargas → Símbolos de depuración nativos).
- **Crashlytics** (opcional): necesita el SDK nativo. [Godotx Firebase](https://godotengine.org/asset-library/asset/4475) lo ofrece para Godot 4.7, junto con Analytics y Messaging. Revisa su compatibilidad con el plugin `OrbitPlay` antes de mezclarlos, porque ambos inicializarían Firebase.

### 7.6 Analytics (después del lanzamiento)

Si se activa con público infantil:

- desactiva el identificador de publicidad: `google_analytics_adid_collection_enabled = false` en el manifiesto;
- desactiva la personalización de anuncios: `google_analytics_default_allow_ad_personalization_signals = false`;
- decláralo en la sección de Seguridad de los datos (Paso 10.5).

Mientras tanto, las muertes por motivo (`Level.deaths_by_motif`) se pueden enviar como un campo más de `submitRun`. Sirven para calibrar la dificultad (tarea A12) sin añadir otro SDK.

## Paso 8 — AdMob

El juego solo usa **anuncios recompensados** (+2 de energía, como máximo 5 al día, valores de `EconomyConfig`). Como el público incluye menores, todos los anuncios deben ser **no personalizados y aptos para niños**, y solo de redes autocertificadas para Familias. AdMob lo está; no añadas mediación con otras redes sin comprobarlo en el [programa de SDK de anuncios autocertificados para Familia](https://support.google.com/googleplay/android-developer/answer/9900633)s.

### 8.1 Crear la app y el bloque de anuncios

1. [admob.google.com](https://admob.google.com) → **Apps → Agregar app** → Android → "¿Está publicada en una tienda?": **No** por ahora (se vincula después, en 8.7).
2. Nombre: `Orbit Runner`. Desactiva las métricas de usuario si no las vas a usar.
3. Copia el **ID de la app** (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`). Va en la configuración del plugin de AdMob.
4. **Bloques de anuncios → Agregar bloque → Bonificado**. Nombre: `energia_recompensado`. Recompensa: cantidad `2`, artículo `energy`.
5. Copia el **ID del bloque** (`ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`). Va en `FirebaseConfig` o en un recurso `AdsConfig`.

### 8.2 Anuncios de prueba

Mientras se desarrolla, usa siempre los identificadores de prueba de Google. Hacer clic en anuncios reales propios puede suspender la cuenta.

| Uso | ID de prueba |
| --- | --- |
| ID de la app | `ca-app-pub-3940256099942544~3347511713` |
| Bloque recompensado | `ca-app-pub-3940256099942544/5224354917` |

Añade también tu teléfono como dispositivo de prueba: AdMob → **Configuración → Dispositivos de prueba → Agregar dispositivo de prueba**. Elige qué IDs usar según `OS.is_debug_build()`.

### 8.3 Configuración para menores

En el código, antes de inicializar el SDK de anuncios, `AdMobAds` aplica esta configuración de solicitud (mediante el plugin):

| Ajuste | Valor | Efecto |
| --- | --- | --- |
| Tratamiento por edad (`setAgeRestrictedTreatment`) | `CHILD` si `Services.is_child()`; si no, sin especificar | Sin identificador de publicidad, sin anuncios por intereses ni remarketing |
| Clasificación máxima (`setMaxAdContentRating`) | `G` para todos | Solo anuncios aptos para todos los públicos |

Las etiquetas antiguas `tagForChildDirectedTreatment` y `tagForUnderAgeOfConsent` están obsoletas; `CHILD` equivale a ambas ([guía oficial](https://developers.google.com/admob/android/targeting)). Comprueba en la documentación del plugin de Poing Studios qué método de GDScript expone cada ajuste.

En la interfaz de AdMob, ajusta también:

1. **Controles de bloqueo → Contenido → Clasificación máxima del contenido de los anuncios**: **G**.
2. **Controles de bloqueo → Categorías confidenciales**: bloquea citas, apuestas, alcohol y similares.

### 8.4 Quitar el identificador de publicidad

La forma más segura en un juego de público mixto es que la app no pueda leer el identificador de publicidad (AAID) de nadie. En `orbit_runner_game/android/build/AndroidManifest.xml`, dentro de `<manifest>`:

```xml
<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove" />
```

(Comprueba que la etiqueta `<manifest>` declara `xmlns:tools="http://schemas.android.com/tools"`.) Después responde en Play Console que la app **no** usa el ID de publicidad (Paso 10.6). Coste: los anuncios para adultos también serán no personalizados y pagan algo menos.

### 8.5 Verificación en el servidor (SSV)

Así la energía del anuncio la da el servidor solo cuando AdMob confirma que se vio entero.

1. AdMob → el bloque `energia_recompensado` → **Configuración avanzada → Verificación del lado del servidor** → URL: `https://us-central1-orbit-runner-prod.cloudfunctions.net/admobSsv`.
2. Pulsa **Verificar URL** para enviar una llamada de prueba.
3. En el juego, antes de mostrar el anuncio, se fija `user_id = uid` y `custom_data = "energy"` (opciones de verificación del lado del servidor, si el plugin las expone).
4. `admobSsv` comprueba la firma ECDSA con las claves de `https://www.gstatic.com/admob/reward/verifier-keys.json` (caché máximo de 24 h), descarta `transaction_id` repetidos, comprueba el límite de 5 al día y suma la energía.
5. El juego llama después a `claimAdReward`, que devuelve la energía actual.

Si el plugin no permite fijar `user_id`, `claimAdReward` suma la energía tras el evento de recompensa del cliente y el servidor solo controla el límite diario. Es más fácil de engañar, pero el premio es pequeño. Guía oficial: [SSV de AdMob](https://developers.google.com/admob/android/ssv).

### 8.6 Consentimiento (RGPD) con UMP

En el Espacio Económico Europeo y el Reino Unido hay que pedir consentimiento para anuncios a los adultos.

1. AdMob → **Privacidad y mensajes → Normativas europeas → Crear mensaje**. Elige la app, idiomas español e inglés, y los socios publicitarios (deja solo Google).
2. Publica el mensaje.
3. En el juego, para adultos, `AdMobAds` pide la actualización del consentimiento al iniciar y muestra el formulario si hace falta (el plugin incluye UMP).
4. Añade en Ajustes un botón "Opciones de privacidad de anuncios" que vuelva a abrir el formulario: es obligatorio cuando el formulario aplica.
5. Para menores no se muestra el formulario: con `CHILD` ya no hay personalización.

### 8.7 Vincular con Google Play y `app-ads.txt`

1. Cuando la app esté publicada (aunque sea en prueba abierta), AdMob → Apps → Orbit Runner → **Configuración de la app → Vincular con tienda**.
2. AdMob → Apps → **Ver todas las apps → app-ads.txt** → copia la línea, del tipo `google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`.
3. Pon esa línea en `backend/public/app-ads.txt` y publica con `firebase deploy --only hosting`.
4. El sitio web de la ficha de Google Play (Paso 10.2) debe ser ese mismo dominio. AdMob tarda hasta 24 h en comprobarlo.
5. La app queda en "Preparación" hasta que AdMob la revisa. Hasta entonces sirve pocos anuncios.

## Paso 9 — Google Play Billing

La tienda vende productos consumibles: se compran, el servidor los entrega y se **consumen** para poder comprarlos otra vez. La regla de oro: **el producto lo entrega el servidor después de verificar el token con Google**, nunca el teléfono por sí solo. Hoy el reparto está en `Services.buy()` y la puerta parental ya va delante.

### 9.1 Requisitos

- Perfil de pagos creado (Paso 0.2).
- Una versión de la app **con el plugin de compras** subida a cualquier pista, aunque sea la de prueba interna (Paso 10.7). Hasta entonces Play Console no deja crear productos.
- Play Billing Library 8 o posterior dentro del plugin (obligatorio desde el 31 de agosto de 2026).

### 9.2 Crear los productos

Play Console → la app → **Monetizar con Play → Productos → Productos de compra única** → **Crear producto**. El ID debe coincidir exactamente con `StoreProduct.id` de `resources/economy/economy_config.tres`:

| ID del producto | Contenido | Precio orientativo actual (`price_hint`) |
| --- | --- | --- |
| `energy_10` | 10 de energía | 0,99 € |
| `energy_30` | 30 de energía (destacado) | 2,49 € |
| `unlimited_60` | Energía ilimitada 60 min | 1,49 € |
| `sparks_1000` | 1000 chispas | 0,99 € |
| `season_pass` | Pase de temporada | Sin definir ("Próximamente") |

Por cada producto:

1. ID, nombre y descripción en español e inglés (los mismos textos que `PRODUCT_*` de `localization/strings.csv`).
2. **Opción de compra**: tipo "Comprar", precio en euros y **Actualizar precios con tipo de cambio** para el resto de países.
3. **Activar**.

El pase de temporada se decide aparte: puede ser un producto de compra única por temporada (`season_pass_s5`) o una suscripción. Una suscripción exige gestionar renovaciones y cancelaciones (Paso 9.5).

En el juego, `PlayStore.price()` debe mostrar el precio que devuelve Google (`query_product_details`), no `price_hint`, que solo usa la tienda simulada.

### 9.3 Cuenta de servicio para verificar compras

1. Google Cloud → **IAM y administración → Cuentas de servicio → Crear cuenta de servicio** ([enlace](https://console.cloud.google.com/iam-admin/serviceaccounts)). Nombre: `play-verifier`. No le des roles del proyecto. No crees claves.
2. Abre `play-verifier` → **Permisos → Conceder acceso** → principal: la cuenta con que se ejecutan las funciones (`<número de proyecto>-compute@developer.gserviceaccount.com`) → rol **Creador de tokens de cuenta de servicio**.
3. Play Console (nivel de cuenta, no de la app) → **Usuarios y permisos → Invitar a usuarios nuevos** → correo `play-verifier@orbit-runner-prod.iam.gserviceaccount.com`.
4. Pestaña **Permisos de la app** → Orbit Runner → marca **Ver datos financieros** y **Gestionar pedidos y suscripciones** → Invitar usuario.
5. Los permisos tardan hasta 24 h en aplicarse. Si las primeras llamadas responden `401` o `403`, espera.

En la función:

```ts
import { GoogleAuth, Impersonated } from "google-auth-library";
import { google } from "googleapis";

const source = await new GoogleAuth().getClient();
const auth = new Impersonated({
  sourceClient: source,
  targetPrincipal: "play-verifier@orbit-runner-prod.iam.gserviceaccount.com",
  targetScopes: ["https://www.googleapis.com/auth/androidpublisher"],
  lifetime: 3600,
});
const play = google.androidpublisher({ version: "v3", auth });
```

### 9.4 Flujo de una compra

1. El jugador pulsa comprar → `ParentalGate.check()` (ya existe).
2. `PlayStore.purchase()` lanza el flujo de Google con el ID del producto y `obfuscatedAccountId` = un hash del `uid`. Así la compra queda ligada a la cuenta.
3. Google devuelve la compra con su `purchaseToken`.
4. El juego llama a `verifyPurchase` con `productId` y `purchaseToken`.
5. La función:
   1. consulta `purchases.products.get` (paquete, producto, token);
   2. exige `purchaseState == 0` (comprada) y que `obfuscatedExternalAccountId` coincida con el jugador;
   3. en una transacción, comprueba que `users/{uid}/purchases/{token}` no existe, lo crea y entrega el producto: energía en `private/energy`, chispas en el guardado;
   4. llama a `purchases.products.consume` para consumirla en el servidor.
6. El juego recibe la energía o las chispas nuevas y muestra el aviso de compra.

Si la app se cierra a mitad, al abrir de nuevo `PlayStore` consulta las compras pendientes (`query_purchases`) y repite el paso 4. **Una compra que no se reconoce ni se consume en 3 días se reembolsa sola.**

### 9.5 Notificaciones en tiempo real (RTDN)

Avisan de reembolsos y cancelaciones, para retirar lo entregado.

1. Google Cloud → **Pub/Sub → Temas → Crear tema** ([enlace](https://console.cloud.google.com/cloudpubsub/topic/list)). ID: `play-billing`.
2. En el tema → **Permisos → Agregar principal** → `google-play-developer-notifications@system.gserviceaccount.com` → rol **Publicador de Pub/Sub**.
3. La función `playRtdn` usa `onMessagePublished("play-billing")`; al desplegarla se crea sola la suscripción.
4. Play Console → la app → **Monetizar con Play → Configuración de monetización** → marca **Habilitar notificaciones en tiempo real** → tema `projects/orbit-runner-prod/topics/play-billing`.
5. Elige **Recibir todas las notificaciones de suscripciones y productos de compra única** → **Enviar mensaje de prueba** → Guardar.
6. `playRtdn` descarta mensajes repetidos por `messageId` (colección `processedMessages`), y ante `ONE_TIME_PRODUCT_CANCELED` o `voidedPurchaseNotification` marca la compra como anulada y resta lo entregado si aún se puede.

Referencia: [preparar Play Billing](https://developer.android.com/google/play/billing/getting-ready) y [formato de RTDN](https://developer.android.com/google/play/billing/rtdn-reference).

### 9.6 Probar compras sin pagar

1. Play Console (nivel de cuenta) → **Configuración → Pruebas de licencia** → añade los correos de Gmail de quienes prueban.
2. Instala la app desde la pista de prueba interna (no por cable): Google solo deja comprar a versiones instaladas desde Play.
3. Al comprar aparecen tarjetas de prueba: "aprobar siempre", "rechazar siempre" y "aprobar con retraso". Prueba las tres, y también cerrar la app a mitad de compra.
4. Reembolsa una compra de prueba en **Gestión de pedidos** y comprueba que llega el RTDN y se retira el producto.

## Paso 10 — Google Play Console

Aquí se crea la ficha, se responden las declaraciones obligatorias y se publica por fases: prueba interna, prueba cerrada y producción. Al incluir menores de 13 años, el juego entra en la **política de Familias** y la revisión es más estricta y más lenta.

### 10.1 Crear la app

1. [play.google.com/console](https://play.google.com/console) → **Todas las apps → Crear app**.
2. Nombre: `Orbit Runner` (máximo 30 caracteres; se puede cambiar después). Idioma predeterminado: Español (España) – `es-ES`.
3. App o juego: **Juego**. Gratis o de pago: **Gratis** (una app gratuita no puede pasar a ser de pago después).
4. Acepta las declaraciones (políticas del programa para desarrolladores y leyes de exportación de EE. UU.) → **Crear app**.

El panel muestra una lista de tareas "Configura tu app". Esta sección las recorre en orden.

### 10.2 Ficha de Play Store

**Crecimiento → Presencia en Play Store → Ficha principal de Play Store**:

| Campo | Requisito | Qué poner |
| --- | --- | --- |
| Descripción breve | Máx. 80 caracteres | Una frase sobre carrera, saltos y el yo-yo cinético |
| Descripción completa | Máx. 4000 caracteres | Mundos, temporadas semanales, desafío diario, Torre del Viento; menciona anuncios opcionales y compras |
| Icono | PNG 512 × 512, máx. 1 MB | A partir de `art/ui/icon.png`, sin texto ni insignias |
| Gráfico de funciones | PNG o JPG 1024 × 500 | Protagonista y un paisaje del juego |
| Capturas de teléfono | 2 a 8, horizontal 16:9, lado corto ≥ 1080 px recomendado | Capturas reales del juego, no ilustraciones conceptuales |
| Vídeo (opcional) | Enlace de YouTube | 30–60 s de juego real |

Traduce la ficha al inglés con **Agregar traducciones**.

En **Presencia en Play Store → Configuración de la tienda**: categoría **Juegos → Acción** (o Aventura), etiquetas (Plataformas, Casual), correo de contacto y **sitio web** (el dominio del Paso 0.5, necesario para `app-ads.txt`).

### 10.3 Contenido de la app (declaraciones)

**Política → Contenido de la app**. Cada apartado se rellena una vez y se actualiza si cambia la app:

| Apartado | Respuesta para Orbit Runner |
| --- | --- |
| Política de privacidad | URL de `/privacidad` (Paso 1.6) |
| Anuncios | **Sí, contiene anuncios** |
| Acceso a la app | Toda la funcionalidad está disponible sin acceso especial (el login es opcional) |
| Clasificación del contenido | Cuestionario IARC (10.4) |
| Público objetivo y contenido | Grupos de edad (10.5) |
| Seguridad de los datos | Formulario (10.6) |
| ID de publicidad | **No** usa el ID de publicidad, si se quitó el permiso en el Paso 8.4 |
| Apps gubernamentales, funciones financieras, salud, noticias | No |
| Eliminación de la cuenta | URL de `/borrar-cuenta` (sección de privacidad) |

### 10.4 Clasificación del contenido (IARC)

1. Correo de contacto y categoría **Juego**.
2. Responde con sinceridad. Para Orbit Runner: sin violencia realista, sin miedo, sin lenguaje, sin juego con dinero real.
3. "¿Los usuarios pueden interactuar o intercambiar contenido?": hay rankings y amigos, pero los nombres salen de una lista segura y no hay chat. Respóndelo así.
4. "¿Compras digitales?": **Sí**.
5. Resultado esperado: PEGI 3 / ESRB Everyone, con la indicación "Compras dentro de la app".

### 10.5 Público objetivo

1. Marca los grupos de edad reales del juego. El propietario decidió que **incluye menores de 13**: por ejemplo 6–8, 9–12, 13–15, 16–17 y 18+.
2. Al incluir menores, Play aplica la [política de Familias](https://support.google.com/googleplay/android-developer/answer/9893335). Lo que exige y cómo lo cumple el juego:

| Exigencia | Cómo se cumple |
| --- | --- |
| Pantalla de edad neutra en apps de público mixto | `AgeGate` ya existe y no sugiere una edad |
| Sin AAID ni otros identificadores de menores o edad desconocida | Permiso `AD_ID` eliminado (8.4); el juego trata como menor a quien no responde |
| Solo SDK de anuncios certificados para Familias, sin anuncios personalizados | AdMob con `CHILD` y clasificación G (8.3) |
| Recompensados cerrables tras 5 s y anuncios claramente distintos del juego | El recompensado solo se ve si el jugador pulsa "Ver anuncio" |
| Funciones sociales: aviso de seguridad y acción de un adulto antes de intercambiar datos | Puerta parental para invitaciones de menores (`ParentalGate`); añadir un aviso de seguridad en la pantalla de amigos |
| SDK no aprobados para niños, solo tras la pantalla de edad | El SDK de Facebook (si se añade) solo para mayores |

3. "¿La app atrae involuntariamente a niños?" ya no aplica: el público los incluye a propósito.

### 10.6 Seguridad de los datos

Declara todo lo que recogen el juego **y** los SDK. Borrador para Orbit Runner (revísalo cuando esté integrado):

| Tipo de dato | ¿Recogido? | ¿Compartido? | Finalidad | Notas |
| --- | --- | --- | --- | --- |
| ID de usuario (uid de Firebase) | Sí | No | Funcionalidad, gestión de la cuenta | Obligatorio para jugar en línea |
| Correo y nombre (solo con Google) | Sí, opcional | No | Gestión de la cuenta | Solo mayores de 13 |
| Actividad en la app (progreso, puntuaciones, tiempos) | Sí | No | Funcionalidad | Rankings y guardado en la nube |
| Historial de compras | Sí | No | Funcionalidad | Verificación de compras |
| ID de dispositivo u otros (App Check, instalación de Firebase, AdMob) | Sí | Sí, con Google para anuncios | Prevención de fraude, publicidad | Consulta la [guía de AdMob para este formulario](https://developers.google.com/admob/android/privacy/play-data-disclosure) |
| Diagnóstico (si se añade Crashlytics) | Sí | No | Analítica | Solo si se integra |

Según la guía de AdMob, su SDK recoge y comparte por su cuenta la dirección IP (ubicación aproximada), las interacciones con la app y datos de diagnóstico, además de identificadores del dispositivo. Decláralos como recogidos y compartidos para publicidad, analítica y prevención de fraude.

Y en las preguntas generales: los datos se cifran en tránsito (**Sí**, todo va por HTTPS) y el usuario puede pedir que se borren (**Sí**, con el enlace de `/borrar-cuenta`).

### 10.7 Prueba interna

Es la pista más rápida (hasta 100 testers, sin revisión larga) y la que desbloquea los productos de compra.

1. **Probar y publicar → Pruebas → Prueba interna → Crear versión**.
2. La primera vez, acepta **Play App Signing** (Google genera la clave de firma de la app).
3. Sube el `.aab` del Paso 11. Nombre de versión: `1.0.0 (1)`. Notas de la versión en español.
4. Pestaña **Testers** → crea una lista de correos → copia el **enlace para unirse** y mándalo.
5. Copia las huellas SHA-1 y SHA-256 de **Integridad de la app → Firma de apps** y añádelas en Firebase (Paso 2.4) y en App Check (Paso 7.1).

### 10.8 Prueba cerrada (obligatoria en cuentas personales)

1. **Pruebas → Prueba cerrada → Crear canal** → testers por un Grupo de Google (más fácil de gestionar que una lista).
2. Sube la misma versión y envíala a revisión.
3. Consigue **al menos 12 testers que sigan apuntados 14 días seguidos**. Si alguien se da de baja y vuelve, su cuenta reinicia.
4. Pide comentarios y corrige errores durante esas dos semanas: el formulario de acceso a producción pregunta qué cambiaste.
5. Panel → **Solicitar acceso a producción** → responde los tres apartados. La revisión suele tardar 7 días o menos.

### 10.9 Producción

1. **Producción → Países y regiones**: elige dónde se publica. Empieza por pocos países si quieres medir antes.
2. **Crear versión** → la versión probada → **Lanzamiento gradual** al 10 %, después 50 % y 100 % si Android vitals no muestra problemas.
3. Revisa el **informe previo al lanzamiento** (Probar y publicar → Pruebas → Informe previo al lanzamiento): Google prueba la app en varios teléfonos reales.
4. Las apps con menores tardan más en revisarse. Cuenta con una semana o más para la primera.

## Paso 11 — Exportar desde Godot para producción

Google Play solo acepta **Android App Bundle** (`.aab`), no APK. El preset `Android` de `orbit_runner_game/export_presets.cfg` exporta hoy APK de depuración (`gradle_build/export_format=0`).

### 11.1 Ajustes del preset de publicación

En **Proyecto → Exportar → Android** (o duplicando el preset como `Android Release`):

| Opción | Valor | Motivo |
| --- | --- | --- |
| `gradle_build/use_gradle_build` | Activado (ya lo está) | Necesario para los plugins |
| `gradle_build/export_format` | **Export AAB** (`1`) | Formato que exige Google Play |
| `architectures/arm64-v8a` | Activado (ya lo está) | Teléfonos actuales |
| `architectures/armeabi-v7a` | Activar si se quiere llegar a teléfonos de 32 bits | Opcional; aumenta el tamaño |
| `version/code` | Número entero que **sube en cada subida** (1, 2, 3…) | Play rechaza un código repetido |
| `version/name` | `1.0.0`, `1.0.1`… | El que ve el jugador |
| `package/unique_name` | `com.orbitrunner.game` | No se puede cambiar tras publicar |
| `package/signed` | Activado | Con la clave de subida del Paso 2.7 |
| `gradle_build/target_sdk` | Vacío (usa 36 de la plantilla) | Play exige API 36 desde el 31 de agosto de 2026 |
| `permissions/*` | Solo las necesarias: vibrar, internet (lo añaden los plugins) | Cada permiso aparece en la ficha |

El nivel de API objetivo está en `orbit_runner_game/android/build/config.gradle` (`targetSdk: 36`) y cumple el [requisito de 2026](https://developer.android.com/google/play/requirements/target-sdk). El año que viene subirá a 37: revisa ese valor cuando actualices Godot.

### 11.2 Exportar

1. Comprueba que las variables de entorno de la clave de subida existen (Paso 2.7).
2. **Proyecto → Exportar → Android Release → Exportar proyecto**, desmarca **Exportar con depuración** y guarda como `build/android/orbit_runner_1.0.0_1.aab`.
3. O por línea de comandos:

```
"C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path orbit_runner_game --export-release "Android Release" build/android/orbit_runner_1.0.0_1.aab
```

4. Prueba el AAB antes de subirlo con [bundletool](https://developer.android.com/tools/bundletool): `bundletool build-apks --bundle=orbit_runner_1.0.0_1.aab --output=prueba.apks --connected-device` y después `bundletool install-apks --apks=prueba.apks`.

### 11.3 Antes de cada versión

- Sube `version/code`.
- Cambia los IDs de anuncios de prueba por los reales solo en la versión de publicación (`OS.is_debug_build()` falso).
- Comprueba que `FirebaseConfig` apunta a `orbit-runner-prod`.
- Regenera `daily_seeds.tres` y el calendario de temporadas si se van a usar como respaldo sin conexión.
- Desactiva el argumento de pruebas `clock_hours=N` en producción.
- Guarda los símbolos nativos para subirlos a Play Console (Paso 7.5).
- Etiqueta el commit en git: `git tag v1.0.0-1`.

### 11.4 Datos que no van nunca al repositorio

- El archivo `.keystore` de subida y su contraseña.
- Claves JSON de cuentas de servicio (no deberían existir; ver Paso 6.7).
- Secretos de Meta (clave secreta de la app de Facebook): van solo en la consola de Firebase.

Sí pueden ir: `google-services.json`, la clave de API de Firebase, los IDs de AdMob y el ID de cliente web. Son identificadores públicos que viajan dentro de la app.

## Privacidad y cumplimiento

Esta sección resume obligaciones legales conocidas; **no es asesoramiento jurídico**. Con público infantil y venta en Europa, conviene que un abogado revise la política de privacidad antes del lanzamiento.

### Leyes que aplican

| Norma | Dónde | Qué exige en la práctica |
| --- | --- | --- |
| COPPA | EE. UU., menores de 13 | No recoger datos personales de menores sin consentimiento verificable de los padres. Un identificador persistente solo para el funcionamiento interno (guardado, ranking, fraude) está permitido; para publicidad comportamental, no |
| RGPD (GDPR) | UE y EEE | Base legal para cada dato, política clara, derecho de acceso y borrado. Los menores por debajo de la edad de consentimiento digital necesitan el permiso de los padres para lo que dependa del consentimiento (anuncios personalizados) |
| LOPDGDD | España | La edad de consentimiento digital es **14 años**, no 13 |
| UK Age Appropriate Design Code | Reino Unido | Ajustes de privacidad altos por defecto para menores de 18 |
| Política de Familias de Google Play | Todo el mundo | Ver Paso 10.5 |

Consecuencia para el código: el umbral de `AgeGate` es hoy 13 años en todos los países. Para España (14) y otros países de la UE con umbrales de 14 a 16, lo más sencillo es tratar como menor a quien tenga menos de 16 en el EEE, o simplemente no pedir nunca el consentimiento de anuncios personalizados (ya ocurre si se quita el permiso `AD_ID`). Es una decisión del propietario.

### Política de privacidad

Página pública en `/privacidad`, en español e inglés, enlazada desde la ficha de Play y desde Ajustes en el juego. Debe decir:

1. Quién es el responsable (nombre del desarrollador tal como aparece en Google Play) y un correo de contacto.
2. Qué datos se recogen: identificador de cuenta, grupo de edad (nunca la fecha), progreso y puntuaciones, compras, correo y nombre solo si se conecta Google, y datos técnicos de los SDK (App Check, AdMob).
3. Para qué: funcionamiento del juego, rankings, prevención de fraude, anuncios no personalizados.
4. Con quién se comparten: Google (Firebase, AdMob, Google Play) como encargados del tratamiento.
5. Dónde se guardan (`us-central1`) y cuánto tiempo.
6. Cómo trata a los menores: sin login social, nombres de una lista segura, sin anuncios personalizados, puerta parental para compras e invitaciones.
7. Derechos del usuario y cómo ejercerlos, incluido el borrado.

### Borrado de cuenta

Google Play lo exige cuando la app permite crear cuentas ([requisito](https://support.google.com/googleplay/android-developer/answer/13327111)):

- **Dentro del juego**: Ajustes → Cuenta → **Borrar cuenta y datos**, con confirmación. Llama a `deleteAccount`, que borra `users/{uid}` y sus subcolecciones, las entradas en `seasons/*/scores/{uid}`, el código de invitación y la cuenta de Authentication. Después el juego borra el guardado local y vuelve a la pantalla de edad.
- **En la web**: página `/borrar-cuenta` que explique el proceso y permita pedirlo sin la app (por ejemplo, un formulario o un correo con el código `ORB-XXXX` del jugador, que aparece en la pantalla de amigos).
- Los registros de compras pueden guardarse el tiempo que exija la ley fiscal; dílo en la política.

### Avisos dentro del juego

- Aviso de seguridad en la pantalla de amigos (exigido por Familias para funciones sociales).
- Botón "Opciones de privacidad de anuncios" en Ajustes para adultos (UMP, Paso 8.6).
- Enlace a la política de privacidad en Ajustes y en la pantalla de edad.

## Costes estimados y límites gratuitos

Con menos de unos pocos miles de jugadores diarios, el servidor debería costar **entre 0 y 5 € al mes**. Los costes fijos reales son el alta en Google Play y el dominio.

### Costes fijos

| Concepto | Coste |
| --- | --- |
| Alta en Google Play Console | 25 USD, una vez |
| Dominio propio | \~10–15 € al año |
| Número D-U-N-S (solo cuenta de organización) | Gratis |
| Comisión de Google Play sobre las ventas | 15 % del primer millón de USD de ingresos al año; 30 % por encima |

### Cuotas gratuitas de Firebase incluidas en Blaze

Datos de la [página de precios](https://firebase.google.com/pricing), por proyecto:

| Producto | Gratis |
| --- | --- |
| Firestore | 50 000 lecturas, 20 000 escrituras y 20 000 borrados al día; 1 GiB guardado; 10 GiB de salida al mes |
| Cloud Functions | 2 millones de invocaciones, 400 000 GB-s y 200 000 CPU-s al mes |
| Authentication | 50 000 usuarios activos al mes |
| Hosting | 10 GB guardados y 360 MB de transferencia al día |
| App Check, Cloud Messaging, Crashlytics, Analytics | Sin coste (App Check tiene cuotas por proveedor) |
| Remote Config | 100 000 peticiones al día (no se usa en esta guía) |

### Estimación para 1000 jugadores diarios

Suponiendo, por jugador y día, unas 15 llamadas a funciones y unas 200 lecturas de Firestore (cada vista del ranking lee unos 50 documentos):

- Funciones: \~450 000 invocaciones al mes, dentro de lo gratuito.
- Firestore: \~200 000 lecturas al día; unas 150 000 por encima de lo gratuito, del orden de 1–3 € al mes.

Para bajar las lecturas, `closeSeasons` u otra función programada cada 5 minutos puede guardar el top 50 en un solo documento (`seasons/{id}/cache/top`). Así cada vista del ranking cuesta 1 lectura en vez de 50. Añade en \`firestore.rules\` una regla de lectura para esa ruta.

### Costes pequeños que se olvidan

- **Artifact Registry**: cada despliegue de funciones guarda una imagen. Al desplegar, acepta la **política de limpieza** que propone `firebase deploy` (por ejemplo, borrar imágenes de más de 1 día).
- **Copias de seguridad de Firestore**: se cobran por GB guardado; con pocos datos son céntimos.
- **Cloud Scheduler**: 3 tareas gratis por cuenta de facturación; cada función programada usa una.
- **Cloud Logging**: 50 GiB al mes gratis; no registres cada petición con todo su contenido.

## Lista final antes de publicar

Marca cada punto cuando esté hecho y comprobado en un teléfono real con la versión instalada desde Google Play.

**Cuentas y proyecto**

- [ ] Play Console verificada y perfil de pagos activo
- [ ] Proyectos `orbit-runner-dev` y `orbit-runner-prod` en plan Blaze, con alertas de presupuesto
- [ ] Región `us-central1` en Firestore, Functions y Scheduler
- [ ] Clave de subida guardada fuera del repositorio con dos copias
- [ ] Huellas SHA-1 y SHA-256 de depuración, subida y firma de Google registradas en Firebase

**Juego**

- [ ] Plugins `OrbitPlay`, AdMob y GodotGooglePlayBilling compilados con Godot 4.7.2 y Billing Library ≥ 8
- [ ] `Services.reload()` usa los proveedores reales en Android
- [ ] `GameClock` toma la hora del servidor; `clock_hours` desactivado en producción
- [ ] Rivales simulados retirados del ranking cuando haya jugadores reales (filtrar `simulated` en `Leaderboard`), o siempre marcados como simulados
- [ ] Botón de borrar cuenta, enlace a la política de privacidad y opciones de privacidad de anuncios en Ajustes
- [ ] Aviso de seguridad en la pantalla de amigos
- [ ] El juego sigue funcionando sin conexión (campaña, tutorial) y muestra un aviso claro cuando falla la red

**Servidor**

- [ ] Reglas de Firestore desplegadas y probadas: un cliente no puede escribir nada
- [ ] Índice del ranking desplegado
- [ ] Todas las funciones con `request.auth` comprobado y `enforceAppCheck: true`
- [ ] App Check en modo aplicación en Firestore y Functions tras revisar métricas
- [ ] Primera temporada y diarios publicados en `seasons/` y `dailies/`
- [ ] `closeSeasons` probada adelantando el fin de una temporada en `orbit-runner-dev`
- [ ] Alerta de errores de funciones en Cloud Monitoring

**Monetización**

- [ ] Productos creados y activos con los IDs de `economy_config.tres`
- [ ] Compra, cierre a mitad de compra y reembolso probados con cuentas de prueba de licencia
- [ ] RTDN con mensaje de prueba correcto
- [ ] Anuncio recompensado con IDs reales solo en la versión de publicación, `CHILD` para menores y clasificación G
- [ ] SSV de AdMob verificada desde la interfaz de AdMob
- [ ] Mensaje de consentimiento (UMP) publicado para el EEE y Reino Unido
- [ ] `app-ads.txt` publicado en el dominio de la ficha y comprobado por AdMob

**Google Play**

- [ ] Ficha completa en español e inglés con capturas reales
- [ ] Clasificación IARC, público objetivo, seguridad de los datos, ID de publicidad y borrado de cuenta declarados
- [ ] Prueba cerrada con 12 testers durante 14 días (cuenta personal) y acceso a producción aprobado
- [ ] Informe previo al lanzamiento sin errores graves
- [ ] Lanzamiento gradual empezando en el 10 %

## Fuentes consultadas

Páginas oficiales abiertas al redactar esta guía (octubre de 2026). Las consolas cambian de nombre y de menú con frecuencia: ante una diferencia, manda la documentación oficial.

- [Precios de Firebase](https://firebase.google.com/pricing)
- [App Check con Play Integrity en Android](https://firebase.google.com/docs/app-check/android/play-integrity-provider)
- [Firebase Auth REST API](https://firebase.google.com/docs/reference/rest/auth)
- [Inicio de sesión con Google mediante Credential Manager](https://developer.android.com/identity/sign-in/credential-manager-siwg)
- [Preparar Google Play Billing](https://developer.android.com/google/play/billing/getting-ready)
- [Referencia de notificaciones en tiempo real (RTDN)](https://developer.android.com/google/play/billing/rtdn-reference)
- [Requisito de nivel de API objetivo de Google Play](https://developer.android.com/google/play/requirements/target-sdk)
- [Requisitos de prueba para cuentas personales nuevas](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Política de Familias de Google Play](https://support.google.com/googleplay/android-developer/answer/9893335)
- [Programa de SDK de anuncios autocertificados para Familias](https://support.google.com/googleplay/android-developer/answer/9900633)
- [Requisito de borrado de cuenta](https://support.google.com/googleplay/android-developer/answer/13327111)
- [AdMob: configuración de segmentación y menores](https://developers.google.com/admob/android/targeting)
- [AdMob: verificación del lado del servidor](https://developers.google.com/admob/android/ssv)
- [AdMob: datos para el formulario de Seguridad de los datos](https://developers.google.com/admob/android/privacy/play-data-disclosure)
- [Plugins de Android en Godot 4.7](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html)
- [Plugin de AdMob de Poing Studios](https://github.com/poingstudios/godot-admob-plugin)
- [GodotGooglePlayBilling](https://github.com/godot-sdk-integrations/godot-google-play-billing)
- [GodotFirebase (GodotNuts)](https://github.com/GodotNuts/GodotFirebase) y [GodotFirebaseAndroid](https://github.com/syntaxerror247/GodotFirebaseAndroid), alternativas valoradas
- [Godot Google Sign-In](https://godotengine.org/asset-library/asset/4578) y [Godotx Firebase](https://godotengine.org/asset-library/asset/4475), plugins citados como opción

Código del proyecto revisado: `orbit_runner_game/scripts/autoload/services.gd`, `scripts/services/*.gd`, `scripts/economy/store_product.gd`, `resources/economy/economy_config.tres`, `export_presets.cfg`, `android/build/config.gradle` y `docs/LIVE_SERVICE.md`.
