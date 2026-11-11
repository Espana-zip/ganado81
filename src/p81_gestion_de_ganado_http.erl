-module(p81_gestion_de_ganado_http).

%% Arranque del listener HTTP. La aplicacion lo inicia despues del supervisor
%% del dominio para que un puerto ocupado no deje procesos huerfanos. Las rutas
%% estaticas salen de priv/static; las rutas /api las atiende un unico handler.
-export([
  start/0,
  stop/0,
  start_listener/2,
  stop_listener/1,
  puerto/0,
  rutas/0
]).

-define(LISTENER, p81_gestion_de_ganado_http).

start() ->
  start_listener(?LISTENER, puerto()).

stop() ->
  stop_listener(?LISTENER).

start_listener(Ref, Puerto) ->
  case p81_gestion_de_ganado_runtime:comprobar() of
    ok -> iniciar_listener(Ref, Puerto);
    {error, _} = Error -> Error
  end.

iniciar_listener(Ref, Puerto) ->
  Dispatch = cowboy_router:compile([{'_', rutas()}]),
  cowboy:start_clear(
    Ref,
    [{ip, application:get_env(p81_gestion_de_ganado, http_ip, {127, 0, 0, 1})},
     {port, Puerto}],
    #{env => #{dispatch => Dispatch}}
  ).

stop_listener(Ref) ->
  try cowboy:stop_listener(Ref) of
    ok -> ok;
    {error, not_found} -> ok;
    Otra -> Otra
  catch
    _:_ -> ok
  end.

puerto() ->
  application:get_env(p81_gestion_de_ganado, http_port, 8080).

rutas() ->
  [
    {"/api/salud", p81_gestion_de_ganado_api_h, salud},
    {"/api/animales", p81_gestion_de_ganado_api_h, animales},
    {"/api/animales/:arete/pesajes", p81_gestion_de_ganado_api_h, pesajes},
    {"/api/animales/:arete", p81_gestion_de_ganado_api_h, animal},
    {"/api/alertas", p81_gestion_de_ganado_api_h, alertas},
    {"/api/[...]", p81_gestion_de_ganado_api_h, no_encontrado},
    {"/static/[...]", cowboy_static, {priv_dir, p81_gestion_de_ganado, "static"}},
    {"/", cowboy_static, {priv_file, p81_gestion_de_ganado, "static/panel_general.html"}},
    {"/index.html", cowboy_static, {priv_file, p81_gestion_de_ganado, "static/panel_general.html"}},
    {"/panel-general", cowboy_static, {priv_file, p81_gestion_de_ganado, "static/panel_general.html"}},
    {"/ficha", cowboy_static, {priv_file, p81_gestion_de_ganado, "static/ficha_de_animal.html"}},
    {"/ficha-de-animal", cowboy_static, {priv_file, p81_gestion_de_ganado, "static/ficha_de_animal.html"}},
    {"/historial", cowboy_static, {priv_file, p81_gestion_de_ganado, "static/historial_y_alertas.html"}},
    {"/historial-y-alertas", cowboy_static, {priv_file, p81_gestion_de_ganado, "static/historial_y_alertas.html"}}
  ].
