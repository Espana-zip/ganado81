-module(p81_gestion_de_ganado_api_tests).
-include_lib("eunit/include/eunit.hrl").

-define(API, p81_gestion_de_ganado_api).

api_test_() ->
  {foreach, fun inicio/0, fun fin/1, [
    fun consulta_vacia/0,
    fun alta_y_filtro/0,
    fun duplicado/0,
    fun validacion_json/0,
    fun pesaje_con_alerta/0,
    fun pesaje_sin_alerta/0,
    fun errores_de_consulta/0
  ]}.

inicio() ->
  {ok, Pid} = p81_gestion_de_ganado_sup:start_link(),
  unlink(Pid),
  Pid.

fin(Pid) ->
  Ref = monitor(process, Pid),
  exit(Pid, shutdown),
  receive {'DOWN', Ref, process, Pid, _} -> ok after 5000 -> error(timeout) end.

animal() ->
  #{<<"arete">> => <<"API-001">>, <<"peso_kg">> => 200,
    <<"potrero">> => <<"Norte">>}.

consulta_vacia() ->
  ?assertMatch({200, #{ok := true, datos := #{total := 0, animales := []}}},
    ?API:listar_animales(undefined)),
  ?assertMatch({200, #{datos := #{animales := 0, alertas := 0}}}, ?API:salud()),
  ?assertMatch({200, #{datos := #{alertas := []}}}, ?API:alertas(undefined)).

alta_y_filtro() ->
  ?assertMatch({201, #{datos := #{animal := #{salud := sano}}}},
    ?API:registrar_animal(animal())),
  ?assertMatch({200, #{datos := #{animal := #{arete := <<"API-001">>}}}},
    ?API:consultar_animal(<<"API-001">>)),
  ?assertMatch({200, #{datos := #{total := 1}}}, ?API:listar_animales(<<"Norte">>)),
  ?assertMatch({200, #{datos := #{total := 0}}}, ?API:listar_animales(<<"Sur">>)).

duplicado() ->
  {201, _} = ?API:registrar_animal(animal()),
  ?assertMatch({409, #{ok := false, error := #{codigo := <<"duplicado">>}}},
    ?API:registrar_animal(animal())).

validacion_json() ->
  ?assertMatch({400, _}, ?API:registrar_animal([])),
  ?assertMatch({400, _}, ?API:registrar_pesaje(<<"API-001">>, null)),
  lists:foreach(fun({Key, Value}) ->
    ?assertMatch({400, #{error := #{codigo := <<"dato_invalido">>}}},
      ?API:registrar_animal((animal())#{Key => Value}))
  end, [{<<"arete">>, <<" ">>}, {<<"arete">>, binary:copy(<<"x">>, 33)},
    {<<"peso_kg">>, 0}, {<<"peso_kg">>, 2001}, {<<"peso_kg">>, <<"200">>},
    {<<"salud">>, <<"desconocido">>}, {<<"potrero">>, <<>>}]),
  ?assertMatch({200, #{datos := #{total := 0}}}, ?API:listar_animales(undefined)).

pesaje_con_alerta() ->
  {201, _} = ?API:registrar_animal(animal()),
  ?assertMatch({201, #{datos := #{animal := #{peso_kg := 100},
    alerta := #{severidad := alta, revisar_captura := true}}}},
    ?API:registrar_pesaje(<<"API-001">>, #{<<"peso_kg">> => 100})),
  ?assertMatch({200, #{datos := #{total := 1}}}, ?API:alertas(<<"API-001">>)),
  {200, #{datos := #{alertas := [Alerta]}}} = ?API:alertas(<<"API-001">>),
  ?assertEqual(nomatch, binary:match(maps:get(mensaje, Alerta), <<"%%">>)),
  ?assertMatch({200, #{datos := #{total := 0}}}, ?API:alertas(<<"OTRO">>)).

pesaje_sin_alerta() ->
  {201, _} = ?API:registrar_animal(animal()),
  ?assertMatch({201, #{datos := #{alerta := null}}},
    ?API:registrar_pesaje(<<"API-001">>, #{<<"peso_kg">> => 205.5})),
  ?assertMatch({400, _}, ?API:registrar_pesaje(<<"API-001">>, #{})),
  ?assertMatch({200, #{datos := #{animal := #{peso_kg := 205.5,
    historial_pesajes := [_, _]}}}}, ?API:consultar_animal(<<"API-001">>)).

errores_de_consulta() ->
  ?assertMatch({404, _}, ?API:consultar_animal(<<"NO-EXISTE">>)),
  ?assertMatch({400, _}, ?API:consultar_animal(<<" ">>)),
  ?assertMatch({400, _}, ?API:listar_animales(<<" ">>)),
  ?assertMatch({400, _}, ?API:alertas(<<" ">>)),
  ?assertMatch({404, _}, ?API:registrar_pesaje(<<"NO-EXISTE">>, #{<<"peso_kg">> => 100})).
