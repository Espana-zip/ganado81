# Ganado81 — caos controlado aislado, manteniendo 8080 activo

> Con systemd, la identidad de la instancia activa se consulta mediante su
> `MainPID`; los archivos PID manuales se conservan como historia y no se usan
> para detener servicios. El script actualizado soporta esa consulta. Esta
> migración no volvió a ejecutar la inyección de caos.

## Alcance autorizado

El usuario aprobó una **instancia temporal del mismo código ARM64** en
`127.0.0.1:18081`. La VM activa de `127.0.0.1:8080` se observó únicamente con
HTTP GET y `/proc`: no se mató su worker, no se reinició su supervisor y no se
abrió distribución Erlang ni un endpoint administrativo.

La prueba se ejecutó una sola vez el **2026-11-10 06:25:58 UTC**. No requiere
instalar paquetes ni modificar configuraciones del sistema. No confundir el
PID Linux de una VM con el PID Erlang de un worker. Los PID Erlang que siguen
pertenecen a la **VM temporal**, no a la de 8080.

## Build y EUnit realmente repetidos en ARM64

Directorio: `/home/pi/ganado81/despliegues/20261110-avh-final`.
Runtime existente: Debian 11 aarch64, OTP 27.3.4.19, ERTS 15.2.7.14, rebar3 3.25.1.

| Comando | Resultado observado |
|---|---|
| `bash scripts/corellium.sh compile` | `rebar3 compile`, código **0** |
| `bash scripts/corellium.sh eunit` | **38 tests, 0 failures**, código **0** |
| Tiempo de esa ejecución EUnit | **0.567 seconds** |
| `bash scripts/caos_aislado_avh.sh ...` | `CAOS_AISLADO_OK`, código **0** |

Se guardaron `compile.exit`, `eunit.exit` y `caos.exit`, todos con valor 0.
EUnit ejecuta sus propias pruebas de reinicio en fixtures/VM de prueba;
son independientes de la única inyección de este ensayo y de la instancia activa.
Los reportes `noproc`, `unsupported_type` y el reinicio provocado durante EUnit
son esperados, no fallos de la suite.

## Procesos identificados y resultado

Supervisor del dominio: **`p81_gestion_de_ganado_sup`**.
Worker gen_server: **`p81_gestion_de_ganado_server`**.
Política: `one_for_one`, worker `permanent`, intensidad **10 reinicios / 60 s**.

| Proceso de la VM temporal (PID Linux 2815) | Antes | Después de la falla |
|---|---|---|
| Supervisor del dominio | `<0.131.0>` | `<0.131.0>` |
| Worker de ganado | **`<0.132.0>`** | **`<0.153.0>`** |
| Supervisor Cowboy | `<0.127.0>` | `<0.127.0>` |
| Supervisor Ranch | `<0.123.0>` | `<0.123.0>` |
| Listener Ranch/Cowboy | `<0.133.0>` | `<0.133.0>` |

El script obtuvo el worker mediante `whereis/1` y comprobó que era hijo del
supervisor mediante `supervisor:which_children/1`. Luego ejecutó exactamente:

```erlang
Ref = monitor(process, Old),
exit(Old, kill),
receive {'DOWN', Ref, process, Old, killed} -> ok after 5000 -> error(timeout) end.
```

Se esperó un PID nuevo durante un máximo de 5 segundos **sin volver a inyectar
fallos**. Se verificaron `ping()`, los PID estables de supervisor/Cowboy/Ranch/
listener, su estado vivo y respuestas HTTP completas con JSON válido.

**No se usó `kill`, `killall`, `pkill`, SIGTERM ni SIGKILL de Linux.** La única
llamada `exit(Old, kill)` pertenece a esta VM temporal, sin distribución Erlang.

## Datos y recuperación HTTP

Antes del fallo se creó mediante la API temporal `DEMO-CAOS-AISLADO`, con 200 kg,
y un pesaje de 170 kg: **1 animal, 2 pesajes y 1 alerta media**.

Tras el reinicio del worker, sin parar el listener:

| Consulta temporal | Resultado |
|---|---|
| `GET :18081/api/salud` | **200**, 0 animales / 0 alertas |
| `GET :18081/api/animales` | **200**, lista vacía |
| `GET :18081/api/animales/DEMO-CAOS-AISLADO` | **404**, JSON válido |

**Sí se perdieron los datos en memoria de la instancia temporal**, incluidos
los pesajes y la alerta. El supervisor recupera el proceso, no su estado. No se
recargó la demo para ocultar esta pérdida: se verificó el hato vacío y después
se limpió la instancia temporal.

En la instancia activa de **8080**:

- Se conservó el PID Linux **1363** y su `starttime` de `/proc` (17518 ticks).
- Salud, listado y alertas dieron **HTTP 200** antes y después.
- Los objetos JSON completos se compararon por igualdad, no solo sus conteos:
  **4 animales y 2 alertas**, sin cambios en pesos, historial ni fechas.
- Huella SHA-256 determinista de esos objetos:
  `FA138C5165DE6AB8BF3B25BFB00F5A86CA0C50C167EFFE644B2CC3DAEA66992A`.

Solo al terminar todas las comprobaciones se cerró la aplicación temporal de
18081. Eso fue limpieza de la VM de prueba, **no una caída de Cowboy durante
el fallo ni un apagado de 8080**. Se comprobó después que únicamente 8080 seguía
escuchando y respondiendo.

## Evidencias conservadas

En la Raspberry Pi:

```text
/home/pi/ganado81/despliegues/20261110-avh-final/evidencias/caos-aislado-20261110T062150Z/
```

También se descargaron en Fedora, dentro del proyecto:

```text
evidencias/caos-aislado-20261110T062150Z/
```

Archivos: `compile.log`, `compile.exit`, `eunit.log`, `eunit.exit`, `caos.log`,
`caos.exit`, `resultado.json`, `experimento-iniciado.txt`, `inyeccion-unica.txt`,
`produccion-antes.json`, `produccion-despues.json` y `SHA256SUMS` local.
Los snapshots completos permiten verificar la igualdad del estado. No publicar
estos JSON si en otra ejecución contienen animales reales. `evidencias/` está
ignorado por Git. **No hubo push, publicación ni grabación Asciinema nueva.**

## Repetir únicamente con nueva aprobación

No reutilizar la carpeta ejecutada. El escript exige confirmación explícita y
crea archivos exclusivos; si ya existe `experimento-iniciado.txt`, se aborta
antes de abrir la aplicación y antes de cualquier inyección. No hay bucle de
fallos ni reintentos automáticos. El bucle de espera solo observa el registro
del nuevo worker.

Una ejecución futura aprobada, en el guest ARM64:

```bash
cd ~/ganado81/actual
umask 077
RUN="evidencias/caos-aislado-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir "$RUN"  # si falla, NO continuar ni sobrescribir
bash scripts/caos_aislado_avh.sh --confirmar-una-falla "$RUN"
```

Requisitos: 8080 sano, `ganado81.service` activo con su MainPID válido
(o archivo PID vigente solo en el antiguo modo manual),
18081 libre, código compilado en ARM64 y permiso para una nueva falla temporal.
No hay que liberar 8080. No ejecutar `corellium.sh demostracion` ni
`demo_avh.escript` para este caso: esos scripts históricos ocupan 8080.

Si cambia legítimamente el estado de 8080 mientras se toman las dos instantáneas,
la prueba de igualdad falla y **no** certifica invariancia. No repetir la inyección
a ciegas: revisar los logs y pedir aprobación de otro ensayo. Un error posterior
al fallo no autoriza una segunda inyección en la misma carpeta.

## Preparación de Asciinema para después

El ensayo actual solo generó logs. Los siguientes pasos son para **una ejecución
futura aprobada** y producirían otra única falla en una VM nueva. La instancia
activa de 8080 seguirá fuera del control del script.

Desde la sesión SSH ya autenticada, preparar una carpeta nueva:

```bash
cd ~/ganado81/actual
umask 077
export RUN="evidencias/caos-grabado-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir "$RUN"  # detenerse si ya existe
export ASCIINEMA_CONFIG_HOME="$PWD/$RUN/recorder-config"
export ASCIINEMA_API_URL=http://127.0.0.1:9
export SHELL=/bin/bash TERM=xterm
asciinema rec -e TERM -i 2 -t 'Ganado81 ARM64: caos aislado 18081, servicio 8080 intacto' "$RUN/grabacion.cast"
```

Dentro de la nueva shell que abre el grabador, ejecutar este bloque. Se capturan
los códigos reales del comando y de `tee`; cualquier fallo detiene la secuencia
antes de continuar a la siguiente etapa:

```bash
set -euo pipefail
run_logged() {
  local stage=$1
  shift
  test ! -e "$RUN/$stage.log"
  test ! -e "$RUN/$stage.exit"
  set +e
  "$@" 2>&1 | tee "$RUN/$stage.log"
  local codes=("${PIPESTATUS[@]}")
  set -e
  printf '%s\n' "${codes[0]}" > "$RUN/$stage.exit"
  printf '%s_EXIT=%s\n' "$stage" "${codes[0]}"
  test "${codes[0]}" -eq 0
  test "${codes[1]}" -eq 0
}
bash scripts/corellium.sh diagnostico
run_logged compile bash scripts/corellium.sh compile
run_logged eunit bash scripts/corellium.sh eunit
run_logged caos bash scripts/caos_aislado_avh.sh --confirmar-una-falla "$RUN"
exit
```

Asciinema volverá a la shell anterior y guardará el archivo local. Revisar que
aparecen `CAOS_AISLADO_OK`, una sola `INYECCION_UNICA` y `caos.exit = 0`.
Para reproducirlo: `asciinema play "$RUN/grabacion.cast"`.

No grabar el login, proxy ni agentes. No usar `--stdin`, `-y`, `--overwrite` ni
`asciinema upload`; no publicar `recorder-config/` ni snapshots de datos reales.
La configuración del grabador se limita a la carpeta de evidencia del proyecto.
