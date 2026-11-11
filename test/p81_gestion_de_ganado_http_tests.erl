-module(p81_gestion_de_ganado_http_tests).
-include_lib("eunit/include/eunit.hrl").

http_test_() ->
  {foreach, fun inicio/0, fun fin/1, [
    fun(C) -> ?_test(salud(C)) end,
    fun(_C) -> ?_test(listener_en_loopback()) end,
    fun(C) -> ?_test(alta_consulta_y_filtro(C)) end,
    fun(C) -> ?_test(pesaje_y_alertas(C)) end,
    fun(C) -> ?_test(json_invalido(C)) end,
    fun(C) -> ?_test(validaciones(C)) end,
    fun(C) -> ?_test(consulta_malformada(C)) end,
    fun(C) -> ?_test(arete_unicode(C)) end,
    fun(C) -> ?_test(metodos_y_rutas(C)) end,
    fun(C) -> ?_test(limite_cuerpo(C)) end,
    fun(C) -> ?_test(estaticos(C)) end,
    fun(C) -> ?_test(error_interno_json(C)) end,
    fun(C) -> ?_test(respuestas_json_completas(C)) end,
    fun(C) -> ?_test(error_del_encoder(C)) end
  ]}.

inicio() ->
  {ok, _} = application:ensure_all_started(cowboy),
  {ok, _} = application:ensure_all_started(inets),
  {ok, Sup} = p81_gestion_de_ganado_sup:start_link(),
  unlink(Sup),
  {ok, _} = p81_gestion_de_ganado_http:start_listener(p81_http_test, 0),
  {Sup, "http://127.0.0.1:" ++ integer_to_list(ranch:get_port(p81_http_test))}.

fin({Sup, _}) ->
  ok = p81_gestion_de_ganado_http:stop_listener(p81_http_test),
  Ref = monitor(process, Sup),
  exit(Sup, shutdown),
  receive {'DOWN', Ref, process, Sup, _} -> ok after 5000 -> error(timeout) end.

raw({_, Base}, Method, Path, Body) ->
  Request = case Method of
    post -> {Base ++ Path, [], "application/json", Body};
    _ -> {Base ++ Path, []}
  end,
  {ok, {{_, Status, _}, Headers, Data}} = httpc:request(Method, Request,
    [{timeout, 10000}], [{body_format, binary}]),
  {Status, Headers, Data}.

request(C, Method, Path, Body) ->
  {Status, Headers, Data} = raw(C, Method, Path, Body),
  ?assertEqual("application/json; charset=utf-8", proplists:get_value("content-type", Headers)),
  {Status, json:decode(Data)}.

alta(C) ->
  request(C, post, "/api/animales",
    <<"{\"arete\":\"HTTP-001\",\"peso_kg\":200,\"potrero\":\"Potrero Norte\"}">>).

salud(C) ->
  ?assertMatch({200, #{<<"ok">> := true, <<"datos">> := #{<<"animales">> := 0}}},
    request(C, get, "/api/salud", <<>>)).

listener_en_loopback() ->
  ?assertMatch({{127, 0, 0, 1}, _}, ranch:get_addr(p81_http_test)).

alta_consulta_y_filtro(C) ->
  ?assertMatch({201, #{<<"datos">> := #{<<"animal">> := #{<<"salud">> := <<"sano">>}}}}, alta(C)),
  ?assertMatch({200, #{<<"datos">> := #{<<"total">> := 1}}},
    request(C, get, "/api/animales?potrero=Potrero%20Norte", <<>>)),
  ?assertMatch({200, #{<<"datos">> := #{<<"total">> := 0}}},
    request(C, get, "/api/animales?potrero=Sur", <<>>)),
  ?assertMatch({200, #{<<"datos">> := #{<<"animal">> := #{<<"arete">> := <<"HTTP-001">>}}}},
    request(C, get, "/api/animales/HTTP-001", <<>>)),
  ?assertMatch({409, #{<<"ok">> := false}}, alta(C)).

pesaje_y_alertas(C) ->
  {201, _} = alta(C),
  ?assertMatch({201, #{<<"datos">> := #{<<"alerta">> := #{<<"severidad">> := <<"alta">>}}}},
    request(C, post, "/api/animales/HTTP-001/pesajes", <<"{\"peso_kg\":100}">>)),
  ?assertMatch({200, #{<<"datos">> := #{<<"total">> := 1}}},
    request(C, get, "/api/alertas?arete=HTTP-001", <<>>)),
  ?assertMatch({200, #{<<"datos">> := #{<<"total">> := 0}}},
    request(C, get, "/api/alertas?arete=OTRO", <<>>)),
  ?assertMatch({200, #{<<"datos">> := #{<<"animal">> := #{<<"peso_kg">> := 100,
    <<"historial_pesajes">> := [_, _]}}}}, request(C, get, "/api/animales/HTTP-001", <<>>)).

json_invalido(C) ->
  lists:foreach(fun(Body) ->
    ?assertMatch({400, #{<<"error">> := #{<<"codigo">> := <<"json_invalido">>}}},
      request(C, post, "/api/animales", Body))
  end, [<<>>, <<"{invalido}">>, <<"[]">>, <<"null">>]).

validaciones(C) ->
  {201, _} = alta(C),
  lists:foreach(fun(Body) ->
    ?assertMatch({400, #{<<"error">> := #{<<"campo">> := <<"peso_kg">>}}},
      request(C, post, "/api/animales/HTTP-001/pesajes", Body))
  end, [<<"{}">>, <<"{\"peso_kg\":0}">>, <<"{\"peso_kg\":2001}">>, <<"{\"peso_kg\":\"100\"}">>]),
  ?assertMatch({404, _}, request(C, post, "/api/animales/NO/pesajes", <<"{\"peso_kg\":100}">>)),
  ?assertMatch({404, _}, request(C, get, "/api/animales/NO", <<>>)).

metodos_y_rutas(C) ->
  {405, Headers, Body} = raw(C, get, "/api/animales/HTTP-001/pesajes", <<>>),
  ?assertEqual("POST", proplists:get_value("allow", Headers)),
  ?assertMatch(#{<<"ok">> := false}, json:decode(Body)),
  ?assertMatch({405, _}, request(C, delete, "/api/animales", <<>>)),
  ?assertMatch({404, #{<<"ok">> := false}}, request(C, get, "/api/no-existe", <<>>)).

consulta_malformada(C) ->
  %% httpc rechaza %ZZ antes de enviarlo: usar TCP para verificar al servidor.
  lists:foreach(fun(Path) ->
    ?assertMatch({400, #{<<"error">> := #{<<"codigo">> := <<"consulta_invalida">>}}},
      get_tcp(C, Path))
  end, ["/api/animales?potrero=%ZZ", "/api/animales?potrero=%FF", "/api/animales/%FF"]),
  ?assertMatch({200, _}, request(C, get, "/api/salud", <<>>)).

get_tcp({_, Base}, Path) ->
  #{port := Port} = uri_string:parse(Base),
  {ok, Socket} = gen_tcp:connect({127, 0, 0, 1}, Port, [binary, {active, false}], 5000),
  try
    ok = gen_tcp:send(Socket, ["GET ", Path,
      " HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"]),
    Response = recibir(Socket, <<>>),
    [Head, Body] = binary:split(Response, <<"\r\n\r\n">>),
    [_, Status | _] = binary:split(Head, <<" ">>, [global]),
    {binary_to_integer(Status), json:decode(Body)}
  after gen_tcp:close(Socket) end.

recibir(Socket, Acc) ->
  case gen_tcp:recv(Socket, 0, 5000) of
    {ok, Data} -> recibir(Socket, <<Acc/binary, Data/binary>>);
    {error, closed} -> Acc
  end.

arete_unicode(C) ->
  Body = json:encode(#{<<"arete">> => <<"ARETE-ñ"/utf8>>, <<"peso_kg">> => 220,
    <<"potrero">> => <<"Cañada"/utf8>>}),
  ?assertMatch({201, _}, request(C, post, "/api/animales", iolist_to_binary(Body))),
  ?assertMatch({200, #{<<"datos">> := #{<<"animal">> := #{<<"arete">> := <<"ARETE-ñ"/utf8>>}}}},
    request(C, get, "/api/animales/ARETE-%C3%B1", <<>>)),
  ?assertMatch({200, #{<<"datos">> := #{<<"total">> := 1}}},
    request(C, get, "/api/animales?potrero=Ca%C3%B1ada", <<>>)).

limite_cuerpo(C) ->
  Body = binary:copy(<<"x">>, 1048577),
  ?assertMatch({413, #{<<"error">> := #{<<"codigo">> := <<"cuerpo_demasiado_grande">>}}},
    request(C, post, "/api/animales", Body)).

estaticos(C) ->
  lists:foreach(fun(Path) ->
    {200, _, Body} = raw(C, get, Path, <<>>),
    ?assertNotEqual(nomatch, binary:match(Body, <<"/static/app.js">>)),
    ?assertNotEqual(nomatch, binary:match(Body, <<"/static/app.css">>))
  end, ["/", "/ficha?arete=HTTP-001", "/historial", "/panel-general", "/ficha-de-animal", "/historial-y-alertas"]),
  lists:foreach(fun(Path) ->
    ?assertMatch({200, _, _}, raw(C, get, Path, <<>>))
  end, ["/static/app.js", "/static/app.css"]),
  ?assertMatch({404, _, _}, raw(C, get, "/static/no-existe", <<>>)).

error_interno_json(C) ->
  %% El handler debe devolver una respuesta Cowboy valida aun si falla el dominio.
  ok = supervisor:terminate_child(p81_gestion_de_ganado_sup, p81_gestion_de_ganado_server),
  try
    ?assertMatch({500, #{<<"error">> := #{<<"codigo">> := <<"error_interno">>}}},
      request(C, get, "/api/salud", <<>>))
  after
    {ok, _} = supervisor:restart_child(p81_gestion_de_ganado_sup, p81_gestion_de_ganado_server)
  end.

respuestas_json_completas(C) ->
  lists:foreach(fun(Path) ->
    {200, Headers, Body} = raw(C, get, Path, <<>>),
    ?assert(byte_size(Body) > 0),
    ?assertEqual(byte_size(Body), list_to_integer(proplists:get_value("content-length", Headers))),
    ?assertEqual("application/json; charset=utf-8", proplists:get_value("content-type", Headers)),
    ?assertMatch(#{<<"ok">> := true, <<"datos">> := _}, json:decode(Body))
  end, ["/api/salud", "/api/animales"]).

error_del_encoder(C) ->
  %% Reproducir una excepcion de encode sin descargar/reemplazar stdlib.json
  %% ni agregar mocks: un PID no es representable en JSON.
  {201, _} = alta(C),
  Srv = p81_gestion_de_ganado_server,
  Original = sys:get_state(Srv),
  sys:replace_state(Srv, fun(State) ->
    Herd = maps:get(animales, State),
    Animal = maps:get(<<"HTTP-001">>, Herd),
    State#{animales => Herd#{<<"HTTP-001">> => Animal#{peso_kg => self()}}}
  end),
  try
    {500, Headers, Body} = raw(C, get, "/api/animales", <<>>),
    ?assertEqual("application/json; charset=utf-8", proplists:get_value("content-type", Headers)),
    ?assert(byte_size(Body) > 0),
    ?assertMatch(#{<<"ok">> := false, <<"error">> := #{<<"codigo">> := <<"error_interno">>}},
      json:decode(Body))
  after
    sys:replace_state(Srv, fun(_) -> Original end)
  end,
  ?assertMatch({200, _}, request(C, get, "/api/animales", <<>>)).

app_lifecycle_test() ->
  application:load(p81_gestion_de_ganado),
  application:set_env(p81_gestion_de_ganado, http_port, 0),
  try
    {ok, _} = application:ensure_all_started(p81_gestion_de_ganado),
    Port = ranch:get_port(p81_gestion_de_ganado_http),
    C = {whereis(p81_gestion_de_ganado_sup), "http://127.0.0.1:" ++ integer_to_list(Port)},
    ?assertMatch({200, #{<<"datos">> := #{<<"animales">> := 4, <<"alertas">> := 2}}},
      request(C, get, "/api/salud", <<>>)),
    ok = application:stop(p81_gestion_de_ganado),
    ?assertEqual(undefined, whereis(p81_gestion_de_ganado_server)),
    ?assertError(badarg, ranch:get_port(p81_gestion_de_ganado_http))
  after
    application:stop(p81_gestion_de_ganado),
    application:unset_env(p81_gestion_de_ganado, http_port)
  end.
