#!/usr/bin/env bash
# No compila ni reinicia la instancia activa. Solo ejecuta una VM temporal.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ $# -ne 2 || $1 != --confirmar-una-falla ]]; then
  echo 'Uso: caos_aislado_avh.sh --confirmar-una-falla evidencias/CARPETA_NUEVA' >&2
  exit 1
fi
[[ $(uname -m) == aarch64 ]] || { echo 'La prueba real se ejecuta en ARM64.' >&2; exit 1; }
OTP_BIN=${GANADO81_OTP_BIN:-"$HOME/.asdf/installs/erlang/27.3.4.19/bin"}
[[ -x "$OTP_BIN/escript" ]] || { echo 'Configura GANADO81_OTP_BIN con el OTP ARM64 existente.' >&2; exit 1; }
export PATH="$OTP_BIN:$PATH"
unset LD_LIBRARY_PATH ERL_LIBS ERL_FLAGS ERL_AFLAGS
cd -- "$ROOT"
exec "$OTP_BIN/escript" scripts/caos_aislado_avh.escript "$@"
