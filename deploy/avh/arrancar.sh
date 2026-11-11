#!/usr/bin/env bash
# Solo runtime ARM64 ya compilado: no rebar3, descargas ni build al arrancar.
set -euo pipefail
[[ $(uname -m) == aarch64 ]] || { echo 'Ganado81 solo se ejecuta en Corellium ARM64.' >&2; exit 1; }
BASE=/home/pi/ganado81
ROOT=$(readlink -e "$BASE/actual")
case "$ROOT" in "$BASE/despliegues/"*) ;; *) echo 'Version fuera del directorio autorizado.' >&2; exit 1;; esac
OTP=/home/pi/.asdf/installs/erlang/27.3.4.19/bin/erl
[[ -x "$OTP" ]] || { echo 'Falta el OTP ARM64 instalado.' >&2; exit 1; }
[[ -f "$ROOT/_build/default/lib/p81_gestion_de_ganado/ebin/p81_gestion_de_ganado.app" ]] || {
  echo 'Version sin compilar. Validar en ARM64 antes de activarla.' >&2; exit 1;
}
unset LD_LIBRARY_PATH ERL_LIBS ERL_FLAGS ERL_AFLAGS
export ERL_CRASH_DUMP="$BASE/estado/erl_crash-$(date -u +%Y%m%dT%H%M%S%NZ)-$$.dump"
export GANADO81_STOP_REQUEST_FILE="$BASE/estado/parada-$$"
if [[ -e "$GANADO81_STOP_REQUEST_FILE" ]]; then
  mv -- "$GANADO81_STOP_REQUEST_FILE" "$GANADO81_STOP_REQUEST_FILE-anterior-$(date -u +%Y%m%dT%H%M%S%NZ)"
fi
shopt -s nullglob
EBINS=("$ROOT"/_build/default/lib/*/ebin)
cd -- "$ROOT"
exec "$OTP" -no_dot_erlang -noshell -noinput -pa "${EBINS[@]}" -eval '
  application:load(p81_gestion_de_ganado),
  application:set_env(p81_gestion_de_ganado,http_ip,{127,0,0,1}),
  application:set_env(p81_gestion_de_ganado,http_port,8080),
  case application:ensure_all_started(p81_gestion_de_ganado) of
    {ok,_} ->
      Sup=whereis(p81_gestion_de_ganado_sup),
      Ref=monitor(process,Sup),
      io:format("Ganado81 iniciado: SO=~s supervisor=~p bind=127.0.0.1:8080~n",[os:getpid(),Sup]),
      receive
        {'\''DOWN'\'',Ref,process,Sup,Reason} ->
          case file:read_file_info(os:getenv("GANADO81_STOP_REQUEST_FILE")) of
            {ok,_} ->
              io:format("Parada solicitada por systemd; se permite completar init:stop.~n"),
              receive after infinity -> ok end;
            {error,_} ->
              io:format(standard_error,"Supervisor termino sin solicitud de parada: ~p~n",[Reason]),halt(1)
          end
      end;
    {error,R} -> io:format(standard_error,"Fallo de arranque: ~p~n",[R]),halt(1)
  end.'
