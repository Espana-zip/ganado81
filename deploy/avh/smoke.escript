#!/usr/bin/env escript
%%! -noshell -noinput
-mode(compile).

%% Verificacion funcional en VM ARM64 temporal y puerto efimero; sin caos.
main([]) ->
  Root=filename:dirname(filename:dirname(filename:dirname(filename:absname(escript:script_name())))),
  probar(Root);
main(["--proyecto",Root]) -> probar(filename:absname(Root));
main(_) -> halt(1).

probar(Root) ->
  true=lists:prefix("aarch64",erlang:system_info(system_architecture)),
  ok=code:add_paths(filelib:wildcard(filename:join([Root,"_build","default","lib","*","ebin"]))),
  application:load(p81_gestion_de_ganado),
  application:set_env(p81_gestion_de_ganado,http_ip,{127,0,0,1}),
  application:set_env(p81_gestion_de_ganado,http_port,0),
  try
    {ok,_}=application:ensure_all_started(p81_gestion_de_ganado),
    {ok,_}=application:ensure_all_started(inets),
    {{127,0,0,1},Port}=ranch:get_addr(p81_gestion_de_ganado_http),
    Base="http://127.0.0.1:"++integer_to_list(Port),
    req(Base,get,"/api/salud",none,200),
    req(Base,get,"/api/animales",none,200),
    lists:foreach(fun(Path)->
      {ok,{{_,200,_},_,Body}}=httpc:request(get,{Base++Path,[]},[{timeout,5000}],[{body_format,binary}]),
      true=binary:match(Body,<<"/static/app.js">>)=/=nomatch
    end,["/","/ficha?arete=DEMO-0001","/historial"]),
    req(Base,post,"/api/animales",#{arete=><<"DEMO-VALIDACION">>,peso_kg=>200,potrero=><<"Temporal">>},201),
    #{<<"datos">>:=#{<<"alerta">>:=#{<<"variacion_pct">>:=15.0}}}=
      req(Base,post,"/api/animales/DEMO-VALIDACION/pesajes",#{peso_kg=>170},201),
    req(Base,get,"/api/animales/DEMO-VALIDACION",none,200),
    io:format("SMOKE_OK: API, tres HTML, alta, pesaje y alerta en puerto efimero ARM64; sin caos.~n")
  after application:stop(p81_gestion_de_ganado) end.

req(Base,Method,Path,Body,Status) ->
  Request=case Body of none->{Base++Path,[]};_->{Base++Path,[],"application/json",iolist_to_binary(json:encode(Body))} end,
  {ok,{{_,Status,_},Headers,Binary}}=httpc:request(Method,Request,[{timeout,5000}],[{body_format,binary}]),
  "application/json; charset=utf-8"=proplists:get_value("content-type",Headers),
  json:decode(Binary).
