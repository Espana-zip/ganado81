# Ganado81 — Corellium AVH: despliegue y evidencia

> **Operación actual:** Corellium es el único runtime y `ganado81.service` es
> el propietario de 8080. Ver [operación systemd](OPERACION_AVH.md). Este documento
> conserva la evidencia previa del despliegue manual: no ejecutar sus comandos
> de servidor/nohup ni usar PID antiguos mientras systemd gestione Ganado81.
>
> Entrega académica actual: [manual completo](../README.md) y
> [Gist publicado](https://gist.github.com/Espana-zip/33b8b0434dc3d1cb7d9dbff8e289fde7).
> Usar esos procedimientos; los siguientes guiones de ejecución son históricos.

## Resultado real y alcance

Verificado el **2026-11-10 UTC**, no una simulación en Fedora:

| Elemento | Comprobado |
|---|---|
| Máquina | RaspberryErlang, Raspberry Pi 5 virtual |
| Guest | Debian GNU/Linux 11 Bullseye, `aarch64` |
| Recursos iniciales | 4 CPU, 7.8 GiB RAM (7.4 GiB disponibles), 25 GiB libres |
| Runtime | OTP 27.3.4.19, ERTS 15.2.7.14, `aarch64-unknown-linux-gnu`, flavor `jit` |
| JSON | `json:encode/1` y `json:decode/1` exportadas; roundtrip real correcto |
| Crypto | SHA-256 correcto; OpenSSL 1.1.1w de Debian |
| Build | rebar3 3.25.1 existente: compile 0; **38 tests, 0 failures**, EUnit 0 |
| HTTP | Cowboy 2.12.0, Ranch 1.8.0, bind comprobado `127.0.0.1:8080` |
| Navegador | Edge 156 desde Fedora, exclusivamente por túnel SSH |

En el **despliegue manual** verificado no se instalaron paquetes, no se cambiaron
perfiles, firewall ni otros servicios del sistema y no se actualizaron
OTP/rebar3. Después se autorizó únicamente la unidad propia `ganado81.service`
(documentada en [OPERACION_AVH.md](OPERACION_AVH.md)). No se copió el runtime
x86_64 de Fedora. Se preservaron los originales de Stitch y las demás prácticas
del usuario.

La captura y las pruebas funcionales iniciales corresponden al snapshot
`/home/pi/ganado81/despliegues/20261110T020217Z`. La copia final, con la misma
lógica verificada y esta documentación, se prepara en:

```text
/home/pi/ganado81/despliegues/20261110-avh-final
```

## Arquitectura

```text
Navegador Fedora :18080 (solo loopback)
    → túnel SSH a través del proxy de Corellium
    → guest Debian ARM64, 127.0.0.1:8080
    → Cowboy → api_h → api → gen_server supervisado
             └→ priv/static/ (copias runtime de Stitch)
```

En aquel despliegue manual no se usó distribución Erlang, cookies compartidas,
systemd ni un puerto público; posteriormente se autorizó el servicio propio.
El dominio continúa en el gen_server original, con supervisor `one_for_one` y
worker `permanent`. El script de demostración crea su propia VM y no se conecta
a nodos ajenos para provocar la falla.

## Acceso y diagnóstico previo

Obtén el destino/proxy desde la sección Connect de tu instancia. Las direcciones
de proxy, identificadores de conexión y credenciales **no van en un Gist ni en
la grabación**. La clave pública debe estar autorizada tanto donde corresponda
en Corellium como en la cuenta `pi` del guest; autenticar el proxy no garantiza
que el guest acepte la misma clave.

Usa la clave privada solo desde tu equipo, no la copies al guest. Verifica las
huellas de host. No uses `StrictHostKeyChecking=no` ni agent forwarding.

En el guest, antes de modificar nada:

```bash
uname -m
cat /etc/os-release
free -h
df -h "$HOME"
ss -ltn '( sport = :8080 )'
```

En este guest, SSH no interactivo no incluía asdf ni rebar3 en PATH. Los binarios
ya existían y se verificaron en:

```text
/home/pi/.asdf/installs/erlang/27.3.4.19/bin/
/home/pi/practica_2_5/rebar3/rebar3
```

`scripts/corellium.sh` selecciona esas rutas solo en su proceso. Si tu guest
usa otras rutas, configura `GANADO81_OTP_BIN` y `GANADO81_REBAR3`. No hace falta
editar `.bashrc`, `.profile` ni reinstalar herramientas. Sus caches y temporales
se guardan en el `_build/` de esta instalación.

## Transferencia de fuentes sin sobrescritura

El proyecto tiene archivos sin commit que son necesarios; **no basta un
`git archive HEAD`**. El empaquetador incluye una lista cerrada de fuentes,
tests, `priv/`, configuración, scripts, documentación y diseño, junto con un
`MANIFEST.sha256`. Rechaza symlinks y artefactos compilados. No incluye `.git/`,
`.toolchain/`, `_build/`, claves ni evidencias.

Desde Fedora, después de obtener autorización para crear un directorio nuevo:

```bash
ID=$(date -u +%Y%m%dT%H%M%SZ)
PAQUETE="$PWD/_build/avh/ganado81-$ID.tar.gz"
python3 scripts/empaquetar_fuentes.py "$PAQUETE"
SHA=$(sha256sum "$PAQUETE" | cut -d ' ' -f 1)

# Completar localmente; no grabar las conexiones/autenticación.
AVH_PROXY='USUARIO_PROXY@HOST_PROXY'
AVH_DESTINO='pi@DESTINO_GUEST'
SSH=(ssh -i "$HOME/.ssh/corellium_ed25519"
     -o StrictHostKeyChecking=yes -o ForwardAgent=no -J "$AVH_PROXY" "$AVH_DESTINO")

"${SSH[@]}" "umask 077; mkdir -p ~/ganado81/paquetes ~/ganado81/despliegues;
  set -C; cat > ~/ganado81/paquetes/$ID.tar.gz" < "$PAQUETE"

"${SSH[@]}" "set -e; cd ~/ganado81/paquetes;
  printf '%s  %s\n' '$SHA' '$ID.tar.gz' | sha256sum --check;
  mkdir ~/ganado81/despliegues/$ID;
  tar -xzf $ID.tar.gz --strip-components=1 --no-same-owner -C ~/ganado81/despliegues/$ID;
  cd ~/ganado81/despliegues/$ID; sha256sum --check MANIFEST.sha256"
```

`set -C` impide sobrescribir el archivo recibido y `mkdir` sin `-p` impide
extraer sobre una instalación existente. Si existe el destino, detenerse;
no borrarlo, resetearlo ni usar opciones de sobrescritura. El paquete usado
para las primeras pruebas tuvo SHA-256:

```text
f9cfa0f36cfd75b958e089b3845850e8632a8bbf87de2930b8d730d9bb97124a
```

El paquete final tiene otro hash porque incluye la documentación posterior;
su hash se conserva junto al paquete y se verifica antes de extraerlo.

## Compilar y probar en la Raspberry Pi

```bash
cd ~/ganado81/despliegues/20261110-avh-final
bash scripts/corellium.sh diagnostico
bash scripts/corellium.sh compile
bash scripts/corellium.sh eunit
```

Se ejecuta el **rebar3 3.25.1 existente**, no uno importado desde Fedora. Es
compatible con este proyecto: resuelve las dependencias fijadas en rebar.lock
y compila con OTP 27. No se justificó una actualización.

Resultado real inicial: **38 tests, 0 failures**, `Finished in 0.291 seconds`.
En la grabación se repitieron: **38 tests, 0 failures**, `0.295 seconds`.
Los mensajes `noproc`, `unsupported_type` y el reinicio de supervisor en EUnit
son intencionales: prueban errores HTTP controlados y recuperación.

## Arranque, túnel y apagado

En el guest, en primer plano:

```bash
bash scripts/corellium.sh servidor
ss -ltnp '( sport = :8080 )'
curl -i http://127.0.0.1:8080/api/salud
```

El resultado de `ss` debe mostrar **127.0.0.1:8080**, no `0.0.0.0:8080` ni
`[::]:8080`. No modificar esto para facilitar la demo.

Desde otra terminal Fedora, con los datos SSH reales configurados localmente:

```bash
ssh -N -T -i ~/.ssh/corellium_ed25519 \
  -o StrictHostKeyChecking=yes -o ForwardAgent=no -o ExitOnForwardFailure=yes \
  -J "$AVH_PROXY" -L 127.0.0.1:18080:127.0.0.1:8080 "$AVH_DESTINO"
```

Abrir **http://127.0.0.1:18080** en Fedora. El túnel no publica 18080 en otras
interfaces. Ctrl+C cierra únicamente ese túnel; no apaga Cowboy.

Para detener el servidor en primer plano, salir en su propia terminal (Ctrl+C,
y `a` si aparece el menú de interrupción). **Ctrl+Z solo lo suspende**.

La instancia final lanzada para esta verificación tiene su PID en
`evidencias/servidor-final.pid` y log en `evidencias/servidor-final.log`. Para
detener exclusivamente esa instancia, desde su directorio:

```bash
pid=$(cat evidencias/servidor-final.pid)
ps -p "$pid" -o pid,stat,args
test "$(readlink -f /proc/$pid/cwd)" = "$PWD"
test "$(cat /proc/$pid/comm)" = beam.smp
kill -TERM "$pid"
ss -ltn '( sport = :8080 )'
```

No usar `killall`, `pkill beam` ni matar VMs de otras prácticas. No se instaló
un servicio persistente: tras reiniciar el guest hay que arrancar Ganado81 y
abrir de nuevo el túnel.

## Verificación funcional real

- GET salud/listado/ficha/alertas: **200**, JSON UTF-8 válido, cuerpos completos.
- Alta `DEMO-AVH-API-001`: **201**, 200 kg; pesaje 170 kg: **201**, alerta media 15 %.
- Duplicado: **409**; peso 0: **400**; arete inexistente: **404**, todos JSON válidos.
- Panel, ficha e historial comprobados a 1440 y 390 px, sin desbordamiento
  horizontal global ni excepciones JavaScript.
- Desde UI se creó `DEMO-AVH-WEB-001` y se registró 200 → 170 kg; la API confirmó
  el peso, los dos pesajes y la alerta. Búsqueda: 3 eventos; filtro peso: 1 alerta.

Los registros de prueba eran ficticios. Esos datos no persisten tras apagar la
VM o ejecutar la prueba de pérdida de estado. La instancia reiniciada vuelve
a los 4 animales y 2 alertas DEMO iniciales.

## Supervisión y Asciinema

> **Con 8080 ya activo, usar el [ensayo aislado en 18081](CAOS_AISLADO_AVH.md).**
> Fue aprobado y verificado posteriormente sin detener 8080. El procedimiento
> de abajo se conserva como evidencia histórica: ocupa 8080 y no debe lanzarse
> contra una instalación activa. Los resultados de ambos ensayos no se mezclan.

**Primero detener solo nuestra instancia en 8080.** La demostración se niega a
arrancar si el puerto ya está ocupado. No ataca un servicio por PID externo:
inicia su propia VM, identifica el worker mediante el supervisor, lo mata y
verifica un PID nuevo, `ping()` y HTTP. No abre distribución Erlang.

```bash
bash scripts/corellium.sh demostracion
```

La ejecución grabada obtuvo worker **`<0.117.0>` → `<0.151.0>`**. Tras la falla:
HTTP 200 con 0 animales/alertas y 404 para el registro perdido. Después se
recargó la demo (4/2). La aplicación se detuvo al terminar la demostración.

Asciinema **2.0.2 ya estaba instalado**. Para repetir la grabación sin publicar:

```bash
mkdir -p evidencias
export ASCIINEMA_CONFIG_HOME="$PWD/evidencias/asciinema-config"
export ASCIINEMA_API_URL=http://127.0.0.1:9
export TERM=xterm
ARCHIVO="evidencias/ganado81-avh-$(date -u +%Y%m%dT%H%M%SZ).cast"
asciinema rec -e TERM -i 2 -t 'Proyecto 81 - Ganado81 en Debian ARM64 / Corellium AVH' \
  -c 'bash scripts/corellium.sh demostracion' "$ARCHIVO"
```

Usar un nombre de archivo explícito: en Asciinema 2 omitirlo puede ofrecer
subir la grabación. No usar `--stdin`, `--overwrite`, `-y` ni `asciinema upload`.
La configuración del grabador queda dentro del proyecto, no en los perfiles.
Grabar solo después del login SSH. Aquí se capturó únicamente TERM, no agentes,
claves, proxy ni contraseñas. No subir `asciinema-config/`.

Archivo realmente creado:

```text
evidencias/ganado81-avh-20261110T020654Z.cast
```

Se validó su formato v2 y 110 eventos de salida, las 38 pruebas y el marcador de
supervisión OK. La ejecución automática dura aproximadamente **1.55 s**;
para verla con calma (y pausar con Espacio):

```bash
asciinema play -s 0.1 evidencias/ganado81-avh-20261110T020654Z.cast
```

Hay una copia descargada en Fedora bajo
`evidencias/corellium-20261110T020217Z/`, con SHA256SUMS, logs HTTP/EUnit,
reporte de supervisión y capturas de las tres pantallas. **No se ha publicado**.

## Guion Loom (2–3 minutos, pendiente de grabar por el usuario)

1. **0:00–0:20:** presentar Proyecto 81 y decir que el backend está en Debian
   ARM64 de Corellium; el navegador usa un túnel, no un servidor público.
2. **0:20–0:50 — Panel:** mostrar censo, peso, potreros y etiquetas DEMO. Explicar
   que los datos se consultan a la API y que aforo/inventario no están registrados.
3. **0:50–1:35 — Ficha:** registrar desde el panel `DEMO-LOOM-001`, 200 kg,
   potrero `Potrero Loom`; abrir su ficha desde historial, registrar 170 kg y
   mostrar dos pesajes, variación y alerta del 15 %.
4. **1:35–2:10 — Historial:** buscar el arete, filtrar peso, abrir de nuevo la
   ficha y mostrar que datos/alertas coinciden. Se pueden enseñar DevTools Network
   con respuestas 200/201, sin headers ni datos de autenticación SSH.
5. **2:10–2:40:** mostrar la evidencia Asciinema de PID antes/después y explicar
   la limitación de memoria. No ejecutar caos sobre el servidor mientras Loom
   necesita los datos. Para otra ejecución se requiere nueva autorización y el
   procedimiento aislado en 18081, sin detener el servicio principal.

Grabar solo la pestaña y, si se desea, una terminal ya autenticada. No mostrar
el panel Connect de Corellium, la clave, el agente ni tokens. No hay grabación
Loom creada por el agente. Incorporar enlaces solo cuando el usuario los aporte
y autorice su publicación.

## Errores y diferencias que realmente se encontraron

- La clave inicialmente autenticaba el proxy pero no `pi`; el usuario autorizó
  su clave pública en el guest. No se pidieron contraseñas por chat.
- OTP/rebar3 no estaban en PATH no interactivo: se seleccionaron rutas existentes.
- Se añadió `-noinput` a los procesos no interactivos para que no consumieran
  el resto de un script enviado por SSH. No se dio por ejecutada una compilación
  hasta observar su salida y el resultado completo de EUnit.
- El código HTTP anterior enlazaba a todas las interfaces; ahora el valor por
  defecto es loopback y hay una prueba que lo verifica.
- Fedora usa OTP compilado para x86_64 y OpenSSL 3.5.9; AVH usa ARM64/JIT y
  OpenSSL 1.1.1w. Nunca se trasladaron NIFs, ejecutables ni `_build/` entre ellos.
- El cliente SSH advirtió negociación no poscuántica; no impidió la conexión.
  No se actualizó SSH ni se desactivó la verificación de host.
- Debian advierte contraseña predeterminada de `pi` activa: el usuario debe
  cambiarla fuera de la grabación. No se modificó automáticamente.

## Limitaciones

Estado en memoria, sin autenticación de aplicación ni persistencia; demo no es
información de un rancho real. La apariencia completa requiere los CDN originales
de Stitch. No hay modo offline, WebSocket, sistema de recetas, reportes SINIIGA
ni inventario real. No se certifica igualdad visual píxel a píxel. Desde el
**2026-11-10** sí existe la unidad propia `ganado81.service` (ver
[operación systemd](OPERACION_AVH.md)); no hay publicación automática de código,
grabaciones ni evidencias, y no se probó el autoarranque reiniciando el guest.
