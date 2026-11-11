-module(p81_gestion_de_ganado_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
  case p81_gestion_de_ganado_runtime:comprobar() of
    ok -> iniciar();
    {error, Razon} = Error ->
      logger:error("Runtime incompatible; no se abrira HTTP: ~p", [Razon]),
      Error
  end.

iniciar() ->
  case p81_gestion_de_ganado_sup:start_link() of
    {ok, SupPid} ->
      cargar_demo_si_corresponde(),
      case p81_gestion_de_ganado_http:start() of
        {ok, _ListenerPid} ->
          {ok, SupPid};
        {error, Razon} ->
          logger:error("No se pudo iniciar HTTP: ~p", [Razon]),
          exit(SupPid, shutdown),
          {error, {http, Razon}}
      end;
    Error ->
      Error
  end.

stop(_State) ->
  p81_gestion_de_ganado_http:stop(),
  ok.

%% El MVP no tiene persistencia. En arranque normal precargamos los casos
%% ficticios DEMO-* para que el panel tenga datos; se puede desactivar con
%% application:set_env(p81_gestion_de_ganado, auto_cargar_demo, false).
cargar_demo_si_corresponde() ->
  case application:get_env(p81_gestion_de_ganado, auto_cargar_demo, true) of
    true ->
      case p81_gestion_de_ganado_demo:cargar() of
        {ok, Resumen} ->
          logger:info("Datos DEMO cargados", Resumen);
        {error, ya_hay_datos} ->
          ok
      end;
    false ->
      ok
  end.
