# Proyecto 81 — Ganado81

**Código fuente completo preparado para la cuenta Espana-zip.** Estado al preparar
esta entrega: repositorio remoto sin crear ni publicar desde esta copia.

**Manual académico publicado:** [Gist de Ganado81](https://gist.github.com/Espana-zip/33b8b0434dc3d1cb7d9dbff8e289fde7).

### Sistema de Gestión de Ganado con Erlang/OTP, Corellium AVH y Google Stitch

| Portada académica | Datos |
|---|---|
| **Alumno** | Miguel Ángel España |
| **Número de control** | 25213870 |
| **Profesor** | René Solís Reyes |
| **Materia** | Programación lógica y funcional — según la portada publicada por el alumno en el Gist |
| **Fecha** | Noviembre de 2026 |
| **Repositorio de referencia** | [tectijuana/erlang-proyectos](https://github.com/tectijuana/erlang-proyectos) |
| **Herramientas** | Erlang/OTP, Cowboy, rebar3, Corellium AVH, Google Stitch, OpenCode y Asciinema |

**MVP académico · ejecución exclusivamente ARM64 · datos en memoria.**
Fedora es la estación de desarrollo y acceso remoto, no el servidor del proyecto.

> **Verificación:** los resultados funcionales y de pruebas se respaldan en
> registros del 10 de noviembre de 2026. Esta copia se preparó sin contactar ni
> modificar Corellium y sin ejecutar Erlang en Fedora. No representa una nueva
> compilación o prueba ARM64. Las evidencias históricas no garantizan disponibilidad
> actual: antes de una demostración en vivo, comprobar servicio y túnel.

Fuentes: [src/](src/), [test/](test/), [priv/](priv/), [scripts/](scripts/) y
[deploy/](deploy/). Ver [versión y diferencias públicas](docs/VERSION_FUENTES.md),
[rúbrica final](docs/VERIFICACION_FINAL.md) y [publicación segura](docs/PUBLICACION.md).

---

## 01 · Introducción

El seguimiento manual de animales y pesajes dificulta identificar duplicados,
consultar antecedentes y detectar pérdidas de peso. Ganado81 centraliza estas
operaciones mediante Erlang/OTP, una API REST Cowboy y tres pantallas adaptadas
del diseño de Google Stitch. Los animales `DEMO-*` son **ficticios**, no información
de un rancho real ni diagnósticos veterinarios certificados.

---

## 02 · Objetivo general

Implementar y demostrar el registro, consulta y seguimiento del hato mediante
procesos supervisados, validación de datos e integración HTTP/UI en una Raspberry
Pi 5 virtual de Corellium AVH. Se busca recuperar el proceso ante fallas, sin
confundir **supervisión** con **persistencia**.

---

## 03 · Tecnologías utilizadas

| Tecnología | Versión o estado comprobado | Función |
|---|---|---|
| Erlang/OTP / ERTS | **27.3.4.19 / 15.2.7.14**, JIT | Runtime ARM64 y behaviours OTP |
| JSON nativo | Módulo `json`, OTP ≥ 27 | Codificación/decodificación de API |
| Cowboy / Ranch | **2.12.0 / 1.8.0** | HTTP, rutas y listener |
| rebar3 / EUnit | **3.25.1** / pruebas OTP | Build, dependencias y pruebas |
| Corellium AVH | Raspberry Pi 5 virtual | Entorno de ejecución |
| Debian | **11 Bullseye, aarch64** | Guest verificado |
| systemd / OpenSSH | Servicio propio / túnel | Operación sin publicar 8080 |
| Google Stitch / JavaScript | Export HTML/CSS y cliente `fetch` | UI, formularios, filtros y CSV |
| OpenCode / VS Code | Sin versión auditada | Edición, asistencia y documentación |
| Asciinema | **2.0.2**, asciicast v2 | Evidencia técnica de terminal |

Fuentes: `rebar.lock` y diagnóstico [E3]. No se copiaron runtimes, NIF ni builds
x86_64 desde Fedora. Las recomendaciones generales del repositorio —Debian 13 o
rebar3 3.28— no sustituyen las versiones realmente verificadas de esta instalación.

---

## 04 · Arquitectura del sistema

```text
Fedora: desarrollo + navegador http://127.0.0.1:18080
    │ túnel SSH (loopback, sin puertos públicos)
    ▼
Corellium AVH · Raspberry Pi 5 virtual · Debian ARM64
    └── ganado81.service (usuario pi)
        └── VM Erlang/OTP 27
            ├── application: inicia dominio y listener
            ├── supervisor one_for_one (10 reinicios / 60 s)
            │   └── gen_server del hato (worker permanent)
            │       └── animales, pesajes y alertas EN MEMORIA
            └── Cowboy/Ranch · 127.0.0.1:8080
                ├── cowboy_static → HTML/CSS/JS de Stitch
                └── api_h → api → gen_server
```

- `p81_gestion_de_ganado_server`: **un proceso para todo el hato**, no uno por
  animal; serializa las operaciones sobre el estado.
- `p81_gestion_de_ganado_sup`: reinicia únicamente el worker que falla.
  Cowboy/Ranch tienen su propia supervisión, no son hijos directos de este supervisor.
- `api`: traduce resultados de dominio a HTTP/JSON; `api_h`: transporte;
  `http`: rutas y listener; `application`: ciclo de vida.
- systemd controla la VM del sistema operativo; OTP controla procesos Erlang.
  El servicio verifica API, MainPID y listener antes de declararse listo.

**Justificación:** un worker simplifica la consistencia del MVP, pero concentra
estado y limita paralelismo. No se promete escalabilidad horizontal ni recuperación
de datos después de reiniciarlo.

---

## 05 · Funcionalidades implementadas

| Función | Alcance real |
|---|---|
| Alta por arete | Peso, salud y potrero; validación y rechazo de duplicados |
| Consulta | Animal, listado y filtro por potrero |
| Pesajes | Captura, historial, variación y gráfica |
| Alertas | Pérdida ≥ 10 %: media; ≥ 40 %: alta y revisar captura |
| Panel General | Censo, salud, peso medio, GMD, potreros y alertas |
| Ficha de Animal | Datos, historial y formulario de pesaje |
| Historial y Alertas | Búsqueda, filtros combinables, paginación y CSV |
| Salud y movimiento | Operaciones de **API Erlang**; sin formulario ni endpoint HTTP de actualización |

Los umbrales son **supuestos del MVP**, no normas sanitarias. La aplicación
precarga cuatro animales ficticios al iniciar. Raza, RFID, aforo y tratamientos
detallados no están modelados; se muestran como no registrados. La imagen del
animal es ilustrativa y no existe historial de traslados.

### Diseño UI/UX con Google Stitch

El export original se conserva en `design/stitch_ganado81_dashboard_ganadero/`;
las copias runtime están en `priv/static/`. El sistema «Rancho Contemporáneo»
aporta paleta verde, superficies neutras, Inter/Plus Jakarta Sans y jerarquía
visual. El JS conecta esas pantallas con la API, no con cifras fijas del diseño.

La navegación lateral enlaza panel, ficha e historial; en móvil es desplegable.
Hay estados de carga/vacío/error, reintento, foco visible, Escape y control del
foco en modales. Las pruebas conservadas cubren **1440 y 390 px**, sin desbordamiento
horizontal global y con 0 excepciones JavaScript [E6]. No se certifica conformidad
WCAG ni equivalencia visual píxel a píxel.

---

## 06 · Manual de instalación y ejecución

### Requisitos y primera instalación

- **Fedora:** copia completa del proyecto, Python 3, Bash, OpenSSH y navegador.
- **Guest:** Debian ARM64, usuario `pi`, OTP 27, rebar3, Python 3, systemd,
  `curl`, `ss`, `flock` y acceso a dependencias. Asciinema es opcional para operar.
- El launcher instalado usa `/home/pi/.asdf/installs/erlang/27.3.4.19/bin/erl`.
  `corellium.sh` selecciona herramientas existentes por ruta o mediante
  `GANADO81_OTP_BIN`/`GANADO81_REBAR3`; otra máquina requiere revisar las rutas.
- El diseño completo requiere Internet para sus CDN de fuentes/Tailwind.

**Fuentes completas:** esta copia conserva la estructura del proyecto y los 46
archivos de código/configuración pública/diseño que coinciden con la versión ARM64
validada. No incluye dependencias compiladas: rebar3 las resuelve desde `rebar.lock`
en Corellium. El repositorio del profesor se conserva como referencia y atribución.

**Configuración pública:** `config/vm.args` se sustituyó por una plantilla sin
cookie, nombre de nodo ni distribución Erlang. El original privado no se publica;
el servicio usa `deploy/avh/arrancar.sh`, que no lee ese archivo. No se certifica
un release relx: el procedimiento validado sigue siendo systemd sobre build ARM64.

1. Crear el guest y disponer de las herramientas anteriores. Instalarlas requiere
   autorización administrativa; esta revisión no instala paquetes.
2. Preparar privadamente los aliases con `config/avh.ssh.example`, autorizar la
   clave pública y verificar huellas. No publicar la configuración completada
   ni copiar la clave privada al guest.
3. Desde la raíz del proyecto en Fedora, para un acceso **nuevo**:

   ```bash
   ./scripts/proyecto.sh acceso --desde RUTA_CONFIG_SSH_LOCAL
   ./scripts/proyecto.sh preparar
   ```

   `preparar` transfiere solo fuentes a un directorio nuevo, verifica SHA-256 y
   ejecuta compile, EUnit y smoke **en el candidato ARM64**, sin activar 8080.
4. **Solo en un guest nuevo y con autorización**, dentro de SSH:

   ```bash
   cd /home/pi/ganado81/despliegues/ID_VALIDADO
   bash deploy/avh/instalar.sh --confirmar "$PWD"
   ```

   Crea archivos propios y habilita/inicia la unidad. Aborta ante instalación
   previa o puerto ocupado. **No ejecutar este paso sobre el servicio existente.**

### Acceso y controles habituales

Estos comandos se invocan **desde Fedora**, pero administran Corellium por SSH;
no inician Erlang ni Cowboy en Fedora:

```bash
./scripts/proyecto.sh servicio estado
./scripts/proyecto.sh servicio logs
./scripts/proyecto.sh tunel iniciar
./scripts/proyecto.sh tunel estado
curl --fail --max-time 8 http://127.0.0.1:18080/api/salud
```

Abrir **http://127.0.0.1:18080** mientras el túnel esté activo. Cowboy enlaza solo
a `127.0.0.1:8080` del guest, sin distribución Erlang ni puertos públicos.

```bash
# Controles documentados; NO ejecutados durante esta revisión.
./scripts/proyecto.sh servicio iniciar
./scripts/proyecto.sh servicio detener
./scripts/proyecto.sh servicio reiniciar
./scripts/proyecto.sh servicio logs --seguir
./scripts/proyecto.sh tunel cerrar
```

**Cerrar el túnel no detiene Cowboy. Detener/reiniciar el servicio pierde los
datos en memoria.** La unidad está habilitada para arrancar con Debian; no se
reinició el guest para probarlo en esta revisión. En el guest, consultar logs con
`journalctl -u ganado81.service -n 100 --no-pager`.

### Actualización y rollback

```bash
./scripts/proyecto.sh preparar
# Solo tras validar el candidato y autorizar una breve parada:
./scripts/proyecto.sh activar ID_VALIDADO --confirmar
./scripts/proyecto.sh rollback --confirmar
```

`actual` selecciona la versión y `anterior` conserva el código previo. Se guardan
logs/snapshots; un fallo de arranque intenta recuperar la versión anterior.
**Rollback recupera código, no datos del hato.**

---

## 07 · Manual de usuario

1. **Panel:** abrir la URL del túnel y esperar los datos. Revisar censo, salud,
   potreros y alertas; utilizar sincronización manual cuando corresponda.
2. **Alta:** elegir un arete ficticio nuevo, por ejemplo `DEMO-GIST-001`, capturar
   **200 kg** y `Potrero Escolar`, y guardar. Si existe, elegir otro: el panel
   agrega un pesaje al animal existente, no debe reutilizarse para simular otra alta.
3. **Ficha:** abrir `/ficha?arete=DEMO-GIST-001` y verificar peso y primer pesaje.
4. **Pesaje:** pulsar «Registrar Pesaje», capturar **170 kg** y guardar.
5. **Alerta:** comprobar pérdida de 30 kg y
   **`(200 − 170) / 200 × 100 = 15 %`**, severidad **media**.
6. **Historial y Alertas:** buscar el arete. Sin otros filtros se esperan dos
   pesajes y una alerta; el filtro de anomalías de peso deja una alerta.
7. **Filtros y CSV:** combinar tipo, severidad, potrero, fecha y búsqueda;
   limpiar filtros si falta un evento. Exportar bitácora o pesajes desde sus controles.

Las alertas son **registradas**, no resueltas: no existe resolución almacenada.
La GMD es kg/días; capturas separadas por segundos pueden generar valores extremos
sin significado productivo. El 15 % entre pesos no es una tasa diaria.

| Método | Ruta | Uso |
|---|---|---|
| GET | `/api/salud` | Servicio y conteos |
| GET / POST | `/api/animales` | Listado / alta |
| GET | `/api/animales/:arete` | Ficha, historial y alertas |
| POST | `/api/animales/:arete/pesajes` | Peso y evaluación de alerta |
| GET | `/api/alertas` | Alertas; admite `?arete=` |

Consulta no destructiva desde Fedora:

```bash
curl --fail --max-time 8 http://127.0.0.1:18080/api/animales/DEMO-0001
```

JSON UTF-8: 200 consulta, 201 alta/pesaje, 400 datos inválidos, 404 inexistente,
409 duplicado; también se controlan 405, 413 y 500.

---

## 08 · Compilación y pruebas

```bash
# Fedora solo envía la orden; rebar3 y OTP se ejecutan en Corellium ARM64.
./scripts/proyecto.sh compile
./scripts/proyecto.sh eunit
```

Órdenes para una ejecución autorizada, **no repetidas en esta revisión**. Para
actualizar se prefiere un candidato con `preparar`, no reconstruir la versión activa.

| Resultado ARM64 registrado | Evidencia |
|---|---|
| OTP **27.3.4.19**, ERTS 15.2.7.14, rebar3 **3.25.1** | Resumen público de diagnóstico [E3] |
| Compilación exitosa, salida **0** | Resultado histórico exportado [E4] |
| **38 tests, 0 failures**, salida **0** | Resultado histórico y cuatro módulos EUnit [E4] |
| API JSON y códigos HTTP esperados | Resumen de verificación y pruebas HTTP [E3] |
| Tres pantallas integradas y formularios funcionales | Capturas incluidas [E6], video [E2] |

La suite contiene **11 pruebas de dominio, 7 de API, 15 HTTP/ciclo y 5 de runtime**.
Usa fixtures propios/puertos efímeros; los reportes intencionales `noproc`,
`unsupported_type` y reinicio de worker no equivalen a fallos EUnit.

**Calidad técnica:** separación aplicación/supervisor/dominio/API/handler;
`minimum_otp_vsn` y `warnings_as_errors`; dependencias fijadas en `rebar.lock`;
validación de datos, límite HTTP de 1 MiB y manejo controlado de errores. La salud
usa valores cerrados, sin crear átomos de textos libres. El cliente valida cuerpo
y Content-Type antes de interpretar JSON. No se inventan porcentajes de cobertura
ni mediciones de rendimiento bajo carga.

---

## 09 · Supervisión y tolerancia a fallos

El **10 de noviembre de 2026, 06:25:58 UTC**, se inyectó una sola falla al worker
de una **VM temporal ARM64 en `127.0.0.1:18081`**, no al servicio de 8080 [E5].

| Proceso temporal | Antes | Después |
|---|---|---|
| `gen_server` del hato | `<0.132.0>` | **`<0.153.0>`** |
| Supervisor de dominio | `<0.131.0>` | `<0.131.0>` |
| Cowboy | `<0.127.0>` | `<0.127.0>` |
| Listener Ranch | `<0.133.0>` | `<0.133.0>` |

Tras recuperar el worker, salud/listado respondieron **200** con hato vacío y
la ficha perdida devolvió **404 JSON**. El estado temporal pasó de 1 animal,
2 pesajes y 1 alerta a 0/0/0. Se recuperó el proceso, **no los datos**.

8080 conservó su PID Linux histórico 1363 y los mismos JSON antes/después
(4 animales/2 alertas); snapshots y hashes coinciden. Estos PID son evidencia
de aquel ensayo, no identificadores actuales para enviar señales.

El cast anterior contiene **otra ejecución**, `<0.117.0> → <0.151.0>`, que utilizó
8080 cuando estaba libre. No se mezclan resultados ni se presenta su copia
ampliada como un ensayo nuevo. **No se repitió caos para redactar este manual.**

---

## 10 · Evidencias del proyecto

### Enlaces externos

- **[E1 — Asciinema: lectura técnica de 3 minutos](https://asciinema.org/a/bYBtt76RnTkA6bHm).**
  Evidencia histórica con tiempos ampliados, **no una nueva ejecución en tiempo
  real**. Página pública y procedencia comprobadas: 112 eventos, 180 s, contenido
  del cast original revisado. La página todavía muestra `pi`; no se da por
  completada la vinculación al perfil `Miguel3C`.
- **[E2 — Demostración visual en Google Drive](https://drive.google.com/file/d/1dDCL5oyxCtOCQ8UJU8FjWtTI-1CIt2iS/view?usp=sharing).**
  Panel, alta 200 kg, ficha, pesaje 170 kg, alerta 15 % e historial. **El enlace
  corresponde a la copia sin sonido**: su descarga coincide con el MP4 silencioso
  local de 180 s. El original se produjo con narración sintética identificada,
  pero esa voz **no está en la copia compartida**. No es la voz del alumno ni un
  video alojado en Loom. Página y descarga accesibles sin autenticar; no se afirma
  reproducción audiovisual remota.
- **[Diseño original de Google Stitch](https://stitch.withgoogle.com/projects/16518304779750527711).**
  HTTP 200, pero solo se obtuvo la aplicación web genérica, no el contenido del
  proyecto. Se contrastó el diseño con el export local y su `DESIGN.md`.

### Registros y capturas de respaldo

Los logs, dumps, snapshots completos y grabaciones internas no se distribuyen.
Se entrega un resumen público de los registros revisados y las fuentes de las
pruebas; no se inventa una ejecución nueva ni se sustituyen por datos privados.

| ID | Registro conservado | Comprobación |
|---|---|---|
| E3 | [Resumen público de resultados](docs/RESULTADOS_VERIFICADOS.json) | Diagnóstico ARM64 y HTTP histórico |
| E4 | Resumen público y [pruebas completas](test/) | Compilación 0; 38 pruebas sin fallos; EUnit 0 |
| E5 | Resumen público y [ensayo aislado documentado](docs/CAOS_AISLADO_AVH.md) | Recuperación temporal; servicio principal sin cambios |
| E6 | [Capturas de UI](docs/gist/capturas/) | Tres vistas y datos ficticios |
| E7 | Resumen público, apartado de demostración visual | Alta/pesaje/alerta; datos anteriores intactos |

Las capturas existentes del **Panel**, **Ficha** e **Historial** se conservaron
sin alterarlas en `docs/gist/capturas/`: `panel-general.png`, `ficha-animal.png`
e `historial-alertas.png`. Muestran UI/datos ficticios, no login/proxy.
Estas rutas se renderizarán al publicar el repositorio. El Gist es independiente:
para incrustar imágenes allí, usar enlaces reales de este repositorio una vez
publicado, no rutas locales ni URL inventadas.

**Panel General — datos ficticios de la aplicación:**

![Panel General de Ganado81](docs/gist/capturas/panel-general.png)

**Ficha de Animal — peso final 170 kg y variación del 15 %:**

![Ficha de Animal de Ganado81](docs/gist/capturas/ficha-animal.png)

**Historial y Alertas — filtro del animal de demostración:**

![Historial y Alertas de Ganado81](docs/gist/capturas/historial-alertas.png)

Último estado remoto conservado [E7], **2026-11-10 22:31 UTC**: servicio activo,
PID 500, `Result=success`, `NRestarts=0`, listener loopback y salud 200 por túnel
(5 animales/3 alertas tras la demo). No se hizo una nueva consulta de Corellium
para preparar esta copia; ese registro no garantiza disponibilidad presente.

---

## 11 · Problemas encontrados y soluciones

| Problema | Causa y solución verificada |
|---|---|
| HTTP 500 vacío con OTP 26 | JSON nativo no disponible. Se seleccionó OTP 27, se validan versión/exports antes de abrir HTTP y se agregó un 500 JSON constante ante fallo del encoder. |
| Herramientas fuera de PATH en SSH | El launcher selecciona rutas ARM64 en su propio proceso, sin cambiar perfiles globales. |
| Puerto ocupado / proceso suspendido | No arrancar otro listener ni usar Ctrl+Z; consultar servicio y puerto, sin matar VMs ajenas. En el despliegue validado systemd administra 8080. |
| Proxy/túnel interrumpido | Acceso al proxy no garantiza acceso al guest. Verificar claves públicas/huellas y estado de la VM; recuperar el túnel sin publicar puertos. |
| Arranque manual frágil | Migración autorizada a systemd como `pi`, journal, readiness y reinicios limitados. |
| Stop normal marcado como fallo | El monitor confundía SIGTERM con avería; `ExecStop` identifica la parada solicitada. El ciclo corregido produjo `Result=success`, salida 0. |
| Pérdida de memoria tras falla | Se verificó y documentó; la supervisión no se presentó como recuperación de una base de datos. |

Si el navegador no conecta, consultar `servicio estado`, `tunel estado` y logs.
Un fallo SSH no demuestra una caída del backend. Recuperar primero la VM si
está apagada/pausada; no reiniciar Ganado81 a ciegas. Si la API funciona pero
el estilo falla, revisar acceso a los CDN.

---

## 12 · Limitaciones y mejoras futuras

- **Memoria solamente:** sin PostgreSQL, Mnesia ni restauración automática;
  reiniciar worker/VM/servicio pierde las capturas del usuario.
- **Sin autenticación ni roles:** no exponer el MVP públicamente.
- Sin offline, WebSocket, resolución persistente de alertas, inventario, recetas,
  reportes SINIIGA o historial de movimientos.
- Worker único; supervisores por rancho y procesos por entidad son propuestas.
- Pendientes: PostgreSQL, tiempo real, `/metrics`, diagnóstico integrado con recon
  y release autónomo relx. Configuración/dependencias previstas no prueban su integración.
- Dependencia de CDN; sin certificación de carga masiva, disponibilidad continua
  o accesibilidad integral. GMD no sustituye evaluación veterinaria.

---

## 13 · Conclusiones

Ganado81 integra procesos OTP, API HTTP y UI responsive en ARM64 con acceso por
túnel seguro. La modularidad y las 38 pruebas documentadas permiten argumentar
operaciones y errores, no solo mostrar una maqueta. El ensayo aislado distingue
recuperación del proceso de recuperación del estado: persistencia, autenticación
y observabilidad siguen siendo necesarias antes de manejar información productiva.

---

## 14 · Referencias

1. [Erlang/OTP — principios de diseño](https://www.erlang.org/doc/system/design_principles.html).
2. [Erlang/OTP — gen_server](https://www.erlang.org/doc/apps/stdlib/gen_server.html).
3. [Erlang/OTP — supervisor](https://www.erlang.org/doc/apps/stdlib/supervisor.html).
4. [Erlang/OTP — JSON nativo](https://www.erlang.org/doc/apps/stdlib/json.html).
5. [Cowboy 2.12 — guía oficial](https://ninenines.eu/docs/en/cowboy/2.12/guide/).
6. [rebar3 — documentación](https://rebar3.org/docs/).
7. [Corellium — documentación oficial](https://support.corellium.com/).
8. [Asciinema — documentación](https://docs.asciinema.org/).
9. [Repositorio del profesor: tectijuana/erlang-proyectos](https://github.com/tectijuana/erlang-proyectos).

---

**Estado:** [Gist ya publicado](https://gist.github.com/Espana-zip/33b8b0434dc3d1cb7d9dbff8e289fde7).
Al preparar esta copia no se publicó ni se inicializó con Git. Los comandos
para hacerlo, únicamente con autorización, están en `docs/PUBLICACION.md`.
Un Secret Gist es no listado, no privado: cualquiera con el enlace puede leerlo.
