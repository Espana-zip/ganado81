-module(p81_gestion_de_ganado_runtime_tests).
-include_lib("eunit/include/eunit.hrl").

-define(RT, p81_gestion_de_ganado_runtime).

runtime_real_test() ->
  ?assertEqual(ok, ?RT:comprobar()),
  ?assertMatch(#{carga := {module, json}, encode := true, decode := true},
    ?RT:informacion()).

otp26_rechazado_test() ->
  %% Incluso un codec ajeno llamado json no vuelve compatible OTP 26.
  ?assertMatch({error, {runtime_incompatible, _}},
    ?RT:validar(#{otp => "26", encode => true, decode => true})).

json_ausente_rechazado_test() ->
  ?assertMatch({error, {runtime_incompatible, #{detectado := #{carga := {error, nofile}}}}},
    ?RT:validar(#{otp => "27", encode => false, decode => false,
      json => non_existing, carga => {error, nofile}})).

funcion_no_exportada_test() ->
  lists:foreach(fun({Encode, Decode}) ->
    ?assertMatch({error, {runtime_incompatible, _}},
      ?RT:validar(#{otp => "27", encode => Encode, decode => Decode}))
  end, [{false, true}, {true, false}]).

json_roundtrip_test() ->
  %% No basta compilar llamadas remotas: ejecutar ambas funciones realmente.
  Datos = #{ok => true, datos => #{arete => <<"DEMO-ñ"/utf8>>,
    salud => sano, peso_kg => 205.5, alerta => null, valores => [1, false]}},
  Binary = iolist_to_binary(json:encode(Datos)),
  ?assertMatch(#{<<"ok">> := true, <<"datos">> := #{
    <<"arete">> := <<"DEMO-ñ"/utf8>>, <<"salud">> := <<"sano">>,
    <<"peso_kg">> := 205.5, <<"alerta">> := null, <<"valores">> := [1, false]}},
    json:decode(Binary)).
