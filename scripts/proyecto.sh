#!/usr/bin/env bash
# Fedora es SOLO cliente de desarrollo: no se ejecuta erl/escript/rebar3 aqui.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
exec python3 "$ROOT/scripts/avh.py" "$@"
