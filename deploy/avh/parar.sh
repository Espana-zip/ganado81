#!/usr/bin/env bash
# systemd entrega su MainPID; nunca se usan PID antiguos ni killall/pkill.
set -euo pipefail
pid=${1:-}
if [[ ! "$pid" =~ ^[0-9]+$ || "$pid" -le 1 || ! -d /proc/$pid ]]; then
  echo 'No hay MainPID vivo que terminar.'
  exit 0
fi
grep -Fq '/ganado81.service' "/proc/$pid/cgroup" || { echo 'PID fuera de ganado81.service; se rechaza la senal.' >&2; exit 1; }
case $(readlink -e "/proc/$pid/cwd") in
  /home/pi/ganado81/despliegues/*) ;;
  *) echo 'PID fuera de las versiones de Ganado81.' >&2; exit 1;;
esac
printf 'Parada controlada de MainPID=%s\n' "$pid"
umask 077
printf 'systemd solicito SIGTERM para %s\n' "$pid" > "/home/pi/ganado81/estado/parada-$pid"
kill -TERM "$pid"
