#!/usr/bin/env bash
# Usa exclusivamente el OTP ARM64 y rebar3 existentes; no instala paquetes,
# no lee .toolchain/ de Fedora ni modifica perfiles del usuario.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ $(uname -m) != aarch64 ]]; then
  echo 'Este lanzador es para el guest Debian ARM64 de Corellium.' >&2
  exit 1
fi
OTP_BIN=${GANADO81_OTP_BIN:-"$HOME/.asdf/installs/erlang/27.3.4.19/bin"}
REBAR=${GANADO81_REBAR3:-"$HOME/practica_2_5/rebar3/rebar3"}
for tool in erl erlc escript; do
  [[ -x "$OTP_BIN/$tool" ]] || { echo "No existe $OTP_BIN/$tool; configura GANADO81_OTP_BIN." >&2; exit 1; }
done
[[ -x "$REBAR" ]] || { echo 'Configura GANADO81_REBAR3 con el rebar3 ARM64 ya instalado.' >&2; exit 1; }
export PATH="$OTP_BIN:$PATH"
unset LD_LIBRARY_PATH ERL_LIBS ERL_FLAGS ERL_AFLAGS
export REBAR_CACHE_DIR="$ROOT/_build/cache/rebar3" HEX_HOME="$ROOT/_build/cache/hex"
export XDG_CACHE_HOME="$ROOT/_build/cache" TMPDIR="$ROOT/_build/tmp"
export ERL_CRASH_DUMP="$ROOT/_build/erl_crash.dump"
mkdir -p "$REBAR_CACHE_DIR" "$HEX_HOME" "$TMPDIR"
cd -- "$ROOT"
case ${1:-diagnostico} in
  diagnostico)
    printf 'Proyecto 81 - Ganado81 / diagnostico ARM64\n'
    uname -m
    cat /etc/os-release
    getconf _NPROCESSORS_ONLN
    free -h
    df -h .
    command -v erl erlc escript
    "$REBAR" --version
    erl -noshell -noinput -eval '
      io:format("OTP=~s ERTS=~s ARCH=~s JIT/FLAVOR=~p~n",[erlang:system_info(otp_release),erlang:system_info(version),erlang:system_info(system_architecture),erlang:system_info(emu_flavor)]),
      {ok,V}=file:read_file(filename:join([code:root_dir(),"releases",erlang:system_info(otp_release),"OTP_VERSION"])),io:format("OTP_VERSION=~s",[V]),
      {module,json}=code:ensure_loaded(json),true=erlang:function_exported(json,encode,1),true=erlang:function_exported(json,decode,1),
      #{<<"ok">>:=true}=json:decode(iolist_to_binary(json:encode(#{ok=>true}))),
      {ok,_}=application:ensure_all_started(ssl),32=byte_size(crypto:hash(sha256,<<"Ganado81 AVH">>)),
      io:format("JSON y crypto OK: ~p~n",[crypto:info_lib()]),halt().'
    ;;
  servidor)
    if systemctl is-active --quiet ganado81.service; then
      echo 'Ganado81 ya esta gestionado por systemd; usa systemctl, no otra VM manual.' >&2
      exit 1
    fi
    "$REBAR" compile
    exec erl -pa _build/default/lib/*/ebin -noshell -noinput -eval '
      application:load(p81_gestion_de_ganado),
      application:set_env(p81_gestion_de_ganado,http_ip,{127,0,0,1}),
      application:set_env(p81_gestion_de_ganado,http_port,8080),
      case application:ensure_all_started(p81_gestion_de_ganado) of
        {ok,_}->io:format("Ganado81 PID SO=~s HTTP=127.0.0.1:8080~n",[os:getpid()]),receive detener->ok end;
        {error,R}->io:format(standard_error,"No se pudo iniciar: ~p~n",[R]),halt(1)
      end.'
    ;;
  demo)
    shift
    exec escript scripts/demo_avh.escript "$@"
    ;;
  demostracion)
    printf 'Proyecto escolar 81 - Gestion de Ganado\nEvidencia real en Corellium AVH\n'
    bash scripts/corellium.sh diagnostico
    printf '\n$ rebar3 compile\n'
    "$REBAR" compile
    printf '\n$ rebar3 eunit\n'
    "$REBAR" eunit
    printf '\n$ escript scripts/demo_avh.escript\n'
    exec escript scripts/demo_avh.escript
    ;;
  compile|eunit|shell)
    exec "$REBAR" "$@"
    ;;
  *)
    echo 'Uso: corellium.sh diagnostico|compile|eunit|shell|servidor|demo|demostracion' >&2
    exit 1
    ;;
esac
