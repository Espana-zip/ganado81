#!/usr/bin/env bash
# Transaccion solo de Ganado81: codigo validado, enlaces atomicos y rollback.
set -euo pipefail
[[ $(uname -m) == aarch64 && $(id -un) == pi ]] || exit 1
BASE=/home/pi/ganado81
UNIT=ganado81.service
[[ $# -ge 2 ]] || exit 1
[[ ${!#} == --confirmar ]] || { echo 'Se requiere --confirmar; reiniciar pierde el estado en memoria.' >&2; exit 1; }
case ${1:-} in
  activar)
    [[ $# == 3 ]] || exit 1
    ID=$2
    [[ "$ID" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ && "$ID" != . && "$ID" != .. ]] || exit 1
    TARGET="$BASE/despliegues/$ID"
    ;;
  rollback)
    [[ $# == 2 ]] || exit 1
    TARGET=$(readlink -e "$BASE/anterior")
    ;;
  *) echo 'Uso: activar.sh activar ID --confirmar | rollback --confirmar' >&2; exit 1;;
esac
[[ -d "$TARGET" && ! -L "$TARGET" && $(readlink -e "$TARGET") == "$TARGET" && "$TARGET" == "$BASE/despliegues/"* ]] || exit 1
exec 9> "$BASE/estado/operacion.lock"
flock -n 9 || { echo 'Hay otra operacion Ganado81 en curso.' >&2; exit 1; }
OLD=$(readlink -e "$BASE/actual")
if [[ "$TARGET" == "$OLD" ]]; then echo "Ya esta activa: $TARGET"; exit 0; fi
(cd -- "$TARGET" && sha256sum --check --status MANIFEST.sha256)
python3 - "$TARGET" <<'CHECK'
import hashlib,json,sys
from pathlib import Path
p=Path(sys.argv[1]);v=json.loads((p/'evidencias/validacion-systemd.json').read_text())
assert v['arquitectura']=='aarch64' and v['compile_exit']==0 and v['eunit_exit']==0 and v['smoke_exit']==0
assert v['manifest_sha256']==hashlib.sha256((p/'MANIFEST.sha256').read_bytes()).hexdigest()
CHECK
RUN="$BASE/estado/operacion-$(date -u +%Y%m%dT%H%M%S%NZ)"
mkdir "$RUN"
printf '%s\n' "$OLD" > "$RUN/version-antes.txt"
printf '%s\n' "$TARGET" > "$RUN/version-propuesta.txt"
journalctl -u "$UNIT" -n 200 --no-pager > "$RUN/journal-antes.log"
for endpoint in animales alertas; do
  set +e
  curl --fail --max-time 5 --silent --show-error "http://127.0.0.1:8080/api/$endpoint" > "$RUN/$endpoint-antes.json" 2> "$RUN/$endpoint-captura.stderr"
  rc=$?
  set -e
  printf '%s\n' "$rc" > "$RUN/$endpoint-captura.exit"
  if [[ "$rc" != 0 ]]; then echo "Aviso: API anterior no disponible ($endpoint, curl $rc); se conserva el error y se permite recuperar codigo."; fi
done
echo 'Activacion autorizada: se conserva codigo anterior, NO se restaura el estado en memoria.'
sudo -n systemctl stop "$UNIT"
ln -s "$TARGET" "$BASE/actual.nuevo.$$"
mv -T -- "$BASE/actual.nuevo.$$" "$BASE/actual"
if sudo -n systemctl start "$UNIT"; then
  ln -s "$OLD" "$BASE/anterior.nuevo.$$"
  mv -T -- "$BASE/anterior.nuevo.$$" "$BASE/anterior"
  printf 'ACTIVACION_OK %s\n' "$TARGET" | tee "$RUN/resultado.txt"
else
  journalctl -u "$UNIT" -n 200 --no-pager > "$RUN/journal-fallo.log"
  sudo -n systemctl stop "$UNIT"
  ln -s "$OLD" "$BASE/actual.recuperacion.$$"
  mv -T -- "$BASE/actual.recuperacion.$$" "$BASE/actual"
  if sudo -n systemctl start "$UNIT"; then
    echo 'ACTIVACION_FALLIDA; codigo anterior recuperado, datos no restaurados.' | tee "$RUN/resultado.txt"
  else
    echo 'ACTIVACION_Y_RECUPERACION_FALLIDAS; revisar journal, sin reintentos en bucle.' | tee "$RUN/resultado.txt"
  fi
  exit 1
fi
journalctl -u "$UNIT" -n 100 --no-pager > "$RUN/journal-despues.log"
