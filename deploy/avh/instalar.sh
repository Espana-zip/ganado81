#!/usr/bin/env bash
# Instalacion explicita y unica; aborta si hay un servicio o archivos previos.
set -euo pipefail
[[ $# == 2 && $1 == --confirmar ]] || { echo 'Uso: instalar.sh --confirmar VERSION_INICIAL_ABSOLUTA' >&2; exit 1; }
[[ $(uname -m) == aarch64 && $(id -un) == pi && $HOME == /home/pi ]] || exit 1
SOURCE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
BASE=/home/pi/ganado81
VERSION=$(readlink -e "$2")
[[ "$VERSION" == "$BASE/despliegues/"* && -d "$VERSION" ]] || exit 1
[[ -f "$VERSION/_build/default/lib/p81_gestion_de_ganado/ebin/p81_gestion_de_ganado.app" ]] || exit 1
for path in "$BASE/bin" "$BASE/estado" "$BASE/actual" "$BASE/anterior"; do
  if [[ -e "$path" || -L "$path" ]]; then echo "Existe $path: se requiere revisar, no se sobrescribe." >&2; exit 1; fi
done
sudo -n test ! -e /etc/systemd/system/ganado81.service
[[ $(systemctl show ganado81.service -p LoadState --value) == not-found ]] || exit 1
if ss -H -ltn '( sport = :8080 )' | grep -q .; then
  echo '8080 ocupado: no se termina ningun proceso. Revisar y solicitar autorizacion.' >&2; exit 1
fi
umask 077
mkdir "$BASE/bin" "$BASE/estado"
install -m 755 "$SOURCE/deploy/avh/arrancar.sh" "$BASE/bin/arrancar.sh"
install -m 755 "$SOURCE/deploy/avh/parar.sh" "$BASE/bin/parar.sh"
install -m 644 "$SOURCE/deploy/avh/comprobar_api.py" "$BASE/bin/comprobar_api.py"
install -m 755 "$SOURCE/deploy/avh/activar.sh" "$BASE/bin/activar.sh"
ln -s "$VERSION" "$BASE/actual"
ln -s "$VERSION" "$BASE/anterior"
sudo -n install -m 644 "$SOURCE/deploy/systemd/ganado81.service" /etc/systemd/system/ganado81.service
sudo -n systemd-analyze verify /etc/systemd/system/ganado81.service
sudo -n systemctl daemon-reload
sudo -n systemctl enable --now ganado81.service
systemctl is-enabled ganado81.service
systemctl is-active ganado81.service
