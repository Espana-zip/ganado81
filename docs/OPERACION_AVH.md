# Ganado81: Corellium es el único entorno de ejecución

## Separación de responsabilidades

| Fedora | Raspberry Pi virtual, Corellium AVH |
|---|---|
| VS Code/OpenCode, edición, empaquetado Python, SSH, navegador | OTP 27.3.4.19 ARM64/JIT, rebar3 3.25.1, compile, EUnit, smoke, Cowboy |
| Nunca ejecuta erl/escript/rebar3 para Ganado81 | `ganado81.service` ejecutado como `pi` |

`scripts/proyecto.sh` es un cliente Python/SSH. Incluso sus comandos `compile`
y `eunit` se ejecutan en el guest. El instalador Fedora quedó deshabilitado y
la `.toolchain/` histórica se conserva sin utilizarla. No se instalaron paquetes.
Los originales Stitch, logs, casts y demás prácticas no se borran ni sobrescriben.

## Archivos propios de esta instalación

- `/etc/systemd/system/ganado81.service`: única unidad instalada.
- Su enlace de habilitación en `multi-user.target.wants`: arranque automático.
- `/home/pi/ganado81/bin/`: launcher runtime, parada, readiness y activación.
- `actual`: enlace a la versión que utiliza systemd; `anterior`: código previo.
- `despliegues/`: versiones de fuentes y builds compilados **en ARM64**.
- `estado/`: locks, marcas de parada, snapshots y logs de operaciones.
- Los directorios de evidencia previos permanecen en sus versiones originales.

La versión inicial fue `/home/pi/ganado81/despliegues/20261110-avh-final`.
Al cierre de la verificación del 2026-11-10, `actual` apuntaba a
`/home/pi/ganado81/despliegues/v20261110T195311608517Z` y `anterior` a
`20261110-avh-final`. La ruta estable para operar es **`/home/pi/ganado81/actual`**;
no asumir que esas rutas siguen siendo las activas después de otra actualización.

## Servicio systemd

La unidad usa `Type=exec`, `User=pi`, `Restart=on-failure`, `RestartSec=5`,
límite de 5 arranques/60 s y parada por SIGTERM con timeout de 30 s.
`KillMode=control-group` solo afecta su cgroup. No inicia rebar3 ni descarga nada
al arrancar: la versión tiene que estar compilada y validada previamente.

El runtime fija **127.0.0.1:8080**, sin nombre de nodo/distribución Erlang. Se
mantiene el JIT; no se activa `MemoryDenyWriteExecute`. Se restringen privilegios,
filesystem y familias de sockets; AF_NETLINK se permite para comprobar `ss`.
Home es de solo lectura en el sandbox del servicio, salvo su directorio `estado/`.

`ExecStartPost` verifica HTTP 200/JSON, MainPID, cwd de la versión y que el único
listener de 8080 sea loopback y pertenezca a esa VM. `systemctl start` no termina
con éxito antes de readiness. Un error de readiness deja evidencia en journal.

Se monitorea el supervisor del dominio: una terminación inesperada de ese
supervisor hace salir a la VM con error para que actúe systemd. Un fallo ordinario
del worker lo resuelve OTP sin necesidad de reiniciar systemd.

### Desde Fedora

```bash
./scripts/proyecto.sh servicio estado
./scripts/proyecto.sh servicio iniciar
./scripts/proyecto.sh servicio detener
./scripts/proyecto.sh servicio reiniciar
./scripts/proyecto.sh servicio logs
./scripts/proyecto.sh servicio logs --seguir
```

`servidor` es un alias de `servicio iniciar`, **no inicia una VM local**. No hay
modo `shell` local. Las operaciones de servicio y activación usan un lock propio
para no mezclar una actualización con una parada concurrente.

### Desde una sesión SSH ya autenticada en Corellium

```bash
sudo systemctl start ganado81.service
sudo systemctl stop ganado81.service
sudo systemctl restart ganado81.service
systemctl status ganado81.service --no-pager
systemctl is-enabled ganado81.service
systemctl show ganado81.service -p MainPID -p ActiveState -p Result
journalctl -u ganado81.service -n 100 --no-pager
journalctl -u ganado81.service -f
ss -ltnp '( sport = :8080 )'
```

No usar PID antiguos de `evidencias/servidor-final.pid`, `killall`, `pkill beam`
ni arrancar otro `corellium.sh servidor` cuando systemd está activo. No ejecutar
operaciones manuales concurrentes durante una activación.

El servicio está habilitado para el siguiente arranque de Debian. No se reinicia
el guest para probarlo, porque eso afectaría a otras prácticas. La habilitación
no mantiene una VM funcionando si Corellium la apaga, pausa o elimina.

### Resultados verificados (2026-11-10 UTC)

Instalación autorizada a las **19:39:21 GMT**: unidad `enabled` y `active`,
`MainPID=3001`, readiness HTTP 200/JSON y un único listener en
`127.0.0.1:8080`. También se comprobaron `User=pi`, `ProtectHome=read-only`,
`ProtectSystem=strict`, `NoNewPrivileges=yes`, `KillMode=control-group`,
`UMask=0077`, `LimitCORE=0`, `Restart=on-failure`, `RestartUSec=5s` y
`TimeoutStopUSec=30s`.

| Prueba | Resultado real | Evidencia en el guest |
|---|---|---|
| Primer stop | **Rechazado**: terminó con código 1 por el monitor del supervisor; se corrigió, no se ocultó | `estado/ciclo-20261110T194143Z/` |
| Ciclo corregido | stop: `MainPID=0`, `inactive`, `Result=success`, `ExecMainStatus=0`; start: PID `3648`; restart: PID `3699`; READY tras cada arranque | `estado/ciclo-corregido-20261110T194448263775718Z/` |
| Candidato ARM64 | `compile=0`, **38 tests, 0 failures**, `smoke=0`; manifest y archivo verificados por SHA-256 | `despliegues/v20261110T195311608517Z/evidencias/` |
| Activación y rollback | `candidato → 20261110-avh-final → candidato`; tres `ACTIVACION_OK`; `actual`=candidato, `anterior`=final | `estado/operacion-20261110T195423124222467Z/`, `...195427828850992Z/`, `...195432500529615Z/` |
| Versión inválida | Rechazada con código 1; `MainPID` `4656` antes y después, sin cambios | `estado/evidencia-systemd-20261110T202537Z/prueba-rechazo.json` |
| UI por túnel | 3 pantallas × 1440/390 px; 4 animales, 2 potreros, DEMO-0001 190 kg, 2 alertas; sin desbordamiento; 0 excepciones JavaScript | `estado/evidencia-visual-20261110T202501Z/` (PNG, resultado y `SHA256SUMS`) |
| Túnel | abrir/estado/cerrar/reabrir; API 200 JSON; cerrar el túnel no detiene Cowboy | socket y configuración en `.avh/` local, ignorado |

Al final de la verificación: `MainPID=4656`, `NRestarts=0`, versión activa
`v20261110T195311608517Z`. La UI se cargó con Edge headless en Fedora
exclusivamente por el túnel. La única entrada de consola fue el 404 automático de
`/favicon.ico` (recurso ausente), no una excepción JavaScript. En Fedora,
`ps -C beam.smp` no mostró ningún proceso Erlang.

## Túnel sencillo desde Fedora

La configuración privada se guarda en **`.avh/ssh-config`**, fuera de Git y del
paquete de fuentes. Usa los aliases `avh-vm` y `avh-proxy`, clave local, host keys
verificadas y `ForwardAgent=no`. No copia claves privadas al guest.

El acceso de esta copia ya está configurado. Para otra copia, completar una copia
de `config/avh.ssh.example` con los datos Connect de Corellium y ejecutar:

```bash
./scripts/proyecto.sh acceso --desde RUTA_A_LA_CONFIGURACION_LOCAL
```

No versionar ese archivo completado. La clave debe estar en el agente local si
necesita desbloqueo; no pegar contraseñas en chats ni grabaciones.

```bash
./scripts/proyecto.sh tunel iniciar
./scripts/proyecto.sh tunel estado
./scripts/proyecto.sh tunel cerrar
```

Abrir **http://127.0.0.1:18080**. El túnel también enlaza solo a loopback.
Se usa un socket de control propio `.avh/t`: cerrar termina exclusivamente ese
cliente SSH, nunca Cowboy. No se instalan autossh ni servicios en Fedora.

Los keepalives detectan desconexiones, pero no evitan caducidad del proxy ni
pausas de AVH. Si se corta, consultar el servicio y volver a abrir el túnel.
Un puerto 18080 ocupado por otro proceso causa error; no se mata al propietario.
Un socket propio caducado se conserva con otro nombre, no se borran archivos ajenos.

## Actualizar sin pisar versiones existentes

Desde Fedora:

```bash
./scripts/proyecto.sh preparar
```

El cliente toma las fuentes actuales (incluidos cambios sin commit), genera un
tar.gz y manifest SHA-256, excluyendo `.git/`, `.avh/`, `.toolchain/`, `_build/`,
claves y evidencias. El archivo recibido es exclusivo; se extrae en un directorio
nuevo. Se verifican hash, miembros del archivo y manifest antes de ejecutar código.

En ese candidato **ARM64** se ejecutan, con logs/códigos de salida:

1. `rebar3 compile`.
2. `rebar3 eunit`.
3. Smoke funcional del candidato en una VM temporal con puerto efímero/loopback:
   API, tres HTML, alta, pesaje y alerta. No provoca caos y no toca 8080.

Solo con los tres códigos 0 se crea `evidencias/validacion-systemd.json`, ligado
al hash del manifest. Un fallo deja el candidato y sus logs para diagnóstico,
**sin cambiar ni reiniciar el servicio activo**. El comando muestra el ID validado.

```bash
./scripts/proyecto.sh activar ID_VALIDADO --confirmar
```

La activación exige marker, arquitectura y hashes válidos. Con lock exclusivo:
guarda journal y snapshots HTTP anteriores en `estado/operacion-*`, detiene solo
Ganado81, cambia `actual` mediante renombrado atómico y arranca el servicio. Tras
readiness, `anterior` conserva la versión que funcionaba.

Si el nuevo arranque falla, restaura el enlace anterior y trata de arrancarlo
una vez, dejando el fallo visible y devolviendo código no cero. No hay bucles
infinitos ni borrado de versiones. Un servicio anterior sin API no impide intentar
recuperación: los errores de la captura HTTP quedan registrados, no se ocultan.

### Rollback explícito

```bash
./scripts/proyecto.sh rollback --confirmar
```

Valida la versión anterior y aplica la misma transacción. Los enlaces alternan,
de modo que puede reactivarse el candidato si el operador lo decide.

**Rollback restaura código, NO memoria.** Un reinicio pierde registros/pesajes y
alertas capturados desde el último arranque. Los snapshots son evidencia y no se
reinyectan automáticamente. Sin PostgreSQL no se promete recuperación de datos.

## Logs y evidencia

El journal persistente de Debian ya existía; no se cambió su configuración global.
Se usan stdout/stderr de la unidad con identificador `ganado81`. La retención es
la que establece el sistema; exportar evidencia importante antes de que rote:

```bash
journalctl -u ganado81.service --no-pager > ARCHIVO_NUEVO.log
```

Operaciones de versión exportan automáticamente journal anterior/posterior y
errores a su carpeta propia de `estado/`. Dumps Erlang tienen nombre único por
arranque; no publicarlos porque pueden contener datos. Los casts/logs anteriores
siguen en sus carpetas, no se mueven ni borran al cambiar `actual`.

La verificación visual conserva sus capturas y hashes en
`estado/evidencia-visual-20261110T202501Z/`; la copia de trabajo local está en
`.avh/evidencia-visual/`, que Git ignora. El proxy SSH y su socket de control
también viven en `.avh/`; no forman parte del paquete de fuentes.

## Incidencia encontrada y corregida durante la instalación

El primer ciclo detectó una parada normal por SIGTERM que salía con código 1:
el monitor de supervisor confundía el shutdown del servicio con una avería.
Ese resultado **se rechazó**, y su journal/unidad/launcher originales se conservaron.

La corrección introduce `ExecStop`: valida MainPID/cgroup/cwd y marca la parada
de **ese PID** antes de SIGTERM. El runtime distingue esa solicitud y permite
completar el cierre normal. Una salida inesperada sin marca continúa siendo error;
no se usó `SuccessExitStatus=1` ni se suprimieron fallos.

En el ciclo corregido se comprobó `inactive`, `Result=success`, `ExecMainStatus=0`
tras stop, puerto cerrado, y API/readiness correctos tras start y restart.
La verificación de unidades también advierte un `KillMode=none` en Plymouth
del sistema: no se modificó ese servicio ajeno; Ganado81 usa control-group.

Las compilaciones y pruebas de esta migración se hicieron exclusivamente en AVH.
No se repitió el ensayo aislado de caos; EUnit conserva sus fixtures normales.
No se publicó código, grabaciones ni puertos y no se realizaron commits ni push.
