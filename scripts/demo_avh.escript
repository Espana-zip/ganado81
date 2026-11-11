#!/usr/bin/env escript
%%! -noshell -noinput
-mode(compile).

%% Demo aislada: arranca su propia VM, no se conecta a nodos ni procesos ajenos.
%% Requiere que 127.0.0.1:8080 este libre. Solo mata el worker que acaba de crear.
main([]) ->
  true = lists:prefix("aarch64", erlang:system_info(system_architecture)),
  Root = filename:dirname(filename:dirname(filename:absname(escript:script_name()))),
  ok = code:add_paths(filelib:wildcard(filename:join([Root,"_build","default","lib","*","ebin"]))),
  application:load(p81_gestion_de_ganado),
  application:set_env(p81_gestion_de_ganado, http_ip, {127,0,0,1}),
  application:set_env(p81_gestion_de_ganado, http_port, 8080),
  try
    {ok,_} = application:ensure_all_started(p81_gestion_de_ganado),
    {ok,_} = application:ensure_all_started(inets),
    io:format("~nCowboy iniciado SOLO en 127.0.0.1:8080. VM SO=~s~n",[os:getpid()]),
    {{127,0,0,1},8080} = ranch:get_addr(p81_gestion_de_ganado_http),
    request(get,"/api/salud",none,200),
    request(get,"/api/animales",none,200),
    request(get,"/api/animales/DEMO-0001",none,200),
    request(post,"/api/animales",#{arete=><<"DEMO-AVH-CAST">>,peso_kg=>200,
      salud=><<"sano">>,potrero=><<"Potrero AVH">>},201),
    #{<<"datos">>:=#{<<"alerta">>:=#{<<"severidad">>:=<<"media">>}}} =
      request(post,"/api/animales/DEMO-AVH-CAST/pesajes",#{peso_kg=>170},201),
    #{<<"datos">>:=#{<<"total">>:=1}} = request(get,"/api/alertas?arete=DEMO-AVH-CAST",none,200),
    Old = whereis(p81_gestion_de_ganado_server),
    [{p81_gestion_de_ganado_server,Old,worker,_}] = supervisor:which_children(p81_gestion_de_ganado_sup),
    io:format("~nCAOS CONTROLADO: worker antes=~p. Solo se mata este worker de esta VM.~n",[Old]),
    Ref=monitor(process,Old),
    exit(Old,kill),
    receive {'DOWN',Ref,process,Old,killed}->ok after 5000->error(worker_no_termino) end,
    New=esperar(Old,250),
    true=is_pid(New), true=New=/=Old,
    pong=p81_gestion_de_ganado_server:ping(),
    io:format("Worker despues=~p; supervisor reinicio el proceso.~n",[New]),
    #{<<"datos">>:=#{<<"animales">>:=0,<<"alertas">>:=0}} = request(get,"/api/salud",none,200),
    request(get,"/api/animales/DEMO-AVH-CAST",none,404),
    io:format("LIMITACION MVP: se perdio el estado en memoria; HTTP y supervisor siguen vivos.~n"),
    {ok,#{animales:=4,alertas:=2}}=p81_gestion_de_ganado_demo:cargar(),
    request(get,"/api/salud",none,200),
    io:format("Demo ficticia recargada. PRUEBA FUNCIONAL Y DE SUPERVISION: OK~n"),
    ok=application:stop(p81_gestion_de_ganado),
    io:format("Cowboy de esta demostracion detenido; no se deja un servicio publicado.~n")
  catch C:R:S ->
    io:format(standard_error,"DEMO FALLIDA ~p:~p~n~p~n",[C,R,S]),
    application:stop(p81_gestion_de_ganado),
    halt(1)
  end;
main(_) ->
  io:format(standard_error,"Uso: escript scripts/demo_avh.escript (puerto 8080 libre)~n",[]),
  halt(1).

request(Method,Path,Body,Expected) ->
  URL="http://127.0.0.1:8080"++Path,
  Req=case Body of none->{URL,[]};_->{URL,[],"application/json",iolist_to_binary(json:encode(Body))} end,
  {ok,{{_,Status,_},Headers,Binary}}=httpc:request(Method,Req,[{timeout,10000}],[{body_format,binary}]),
  io:format("~n~s ~s -> HTTP ~p~nContent-Type: ~s~n~ts~n",[string:uppercase(atom_to_list(Method)),Path,Status,proplists:get_value("content-type",Headers,""),Binary]),
  Expected=Status,
  "application/json; charset=utf-8"=proplists:get_value("content-type",Headers),
  json:decode(Binary).

esperar(_Old,0)->error(worker_no_reinicio);
esperar(Old,N)->
  case whereis(p81_gestion_de_ganado_server) of
    P when is_pid(P),P=/=Old->P;
    _->timer:sleep(20),esperar(Old,N-1)
  end.
