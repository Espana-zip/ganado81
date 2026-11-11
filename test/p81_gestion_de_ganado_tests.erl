-module(p81_gestion_de_ganado_tests).
-include_lib("eunit/include/eunit.hrl").

-define(SUP, p81_gestion_de_ganado_sup).
-define(SRV, p81_gestion_de_ganado_server).

%% Cada prueba arranca un arbol de supervision limpio para no compartir estado.
all_test_() ->
  {foreach,
   fun inicio/0,
   fun fin/1,
   [
     fun registro_y_consulta/0,
     fun listado_por_potrero/0,
     fun arete_duplicado/0,
     fun datos_invalidos/0,
     fun pesaje_e_historial/0,
     fun alerta_por_perdida_de_peso/0,
     fun alerta_por_posible_error_de_captura/0,
     fun pesaje_invalido/0,
     fun salud_y_potrero/0,
     fun reinicio_del_worker/0,
     fun demo_con_datos_ficticios/0
   ]}.

inicio() ->
  parar_supervisor_si_existe(),
  {ok, Pid} = ?SUP:start_link(),
  unlink(Pid),
  Pid.

fin(Pid) ->
  parar_supervisor(Pid).

parar_supervisor_si_existe() ->
  case whereis(?SUP) of
    undefined -> ok;
    Pid -> parar_supervisor(Pid)
  end.

parar_supervisor(Pid) ->
  MRef = monitor(process, Pid),
  exit(Pid, shutdown),
  receive
    {'DOWN', MRef, process, Pid, _Razon} -> ok
  after 5000 ->
    exit(Pid, kill),
    receive {'DOWN', MRef, process, Pid, _Razon} -> ok after 1000 -> ok end
  end.

animal(Overrides) ->
  maps:merge(
    #{
      arete => <<"AR-001">>,
      peso_kg => 200,
      salud => sano,
      potrero => <<"Potrero Norte">>
    },
    Overrides
  ).

aretes(Animales) ->
  [maps:get(arete, Animal) || Animal <- Animales].

%% ---------------------------------------------------------------------------
%% Registro y consulta
%% ---------------------------------------------------------------------------

registro_y_consulta() ->
  {ok, Animal} = ?SRV:registrar_animal(animal(#{})),
  ?assertEqual(<<"AR-001">>, maps:get(arete, Animal)),
  ?assertEqual(200, maps:get(peso_kg, Animal)),
  ?assertEqual(sano, maps:get(salud, Animal)),
  ?assertEqual(<<"Potrero Norte">>, maps:get(potrero, Animal)),
  ?assertMatch([#{peso_kg := 200}], maps:get(historial_pesajes, Animal)),
  {ok, Consulta} = ?SRV:consultar_animal(<<"AR-001">>),
  ?assertEqual(200, maps:get(peso_kg, Consulta)),
  ?assertEqual({error, no_encontrado}, ?SRV:consultar_animal(<<"NO-EXISTE">>)),
  ?assertEqual(1, length(?SRV:listar_animales())).

listado_por_potrero() ->
  {ok, _} = ?SRV:registrar_animal(animal(#{arete => <<"AR-002">>})),
  {ok, _} = ?SRV:registrar_animal(animal(#{arete => <<"AR-001">>})),
  {ok, _} = ?SRV:registrar_animal(animal(#{arete => <<"AR-003">>, potrero => <<"Potrero Sur">>})),
  ?assertEqual(
    [<<"AR-001">>, <<"AR-002">>, <<"AR-003">>],
    aretes(?SRV:listar_animales())
  ),
  ?assertEqual(
    [<<"AR-001">>, <<"AR-002">>],
    aretes(?SRV:listar_animales_por_potrero(<<"Potrero Norte">>))
  ),
  ?assertEqual(
    [<<"AR-003">>],
    aretes(?SRV:listar_animales_por_potrero(<<"Potrero Sur">>))
  ).

arete_duplicado() ->
  {ok, _} = ?SRV:registrar_animal(animal(#{peso_kg => 200})),
  ?assertEqual(
    {error, duplicado},
    ?SRV:registrar_animal(animal(#{peso_kg => 220}))
  ),
  {ok, Original} = ?SRV:consultar_animal(<<"AR-001">>),
  ?assertEqual(200, maps:get(peso_kg, Original)),
  ?assertEqual(1, length(?SRV:listar_animales())).

datos_invalidos() ->
  SinArete = maps:remove(arete, animal(#{})),
  ?assertEqual({error, {dato_invalido, arete}}, ?SRV:registrar_animal(SinArete)),
  ?assertEqual(
    {error, {dato_invalido, arete}},
    ?SRV:registrar_animal(animal(#{arete => <<"   ">>}))
  ),
  ?assertEqual(
    {error, {dato_invalido, peso_kg}},
    ?SRV:registrar_animal(animal(#{peso_kg => 0}))
  ),
  ?assertEqual(
    {error, {dato_invalido, peso_kg}},
    ?SRV:registrar_animal(animal(#{peso_kg => -10}))
  ),
  ?assertEqual(
    {error, {dato_invalido, peso_kg}},
    ?SRV:registrar_animal(animal(#{peso_kg => <<"200">>}))
  ),
  ?assertEqual(
    {error, {dato_invalido, salud}},
    ?SRV:registrar_animal(animal(#{salud => desconocido}))
  ),
  ?assertEqual(
    {error, {dato_invalido, potrero}},
    ?SRV:registrar_animal(animal(#{potrero => <<>>}))
  ),
  ?assertEqual({error, {dato_invalido, animal}}, ?SRV:registrar_animal(no_es_mapa)),
  ?assertEqual([], ?SRV:listar_animales()).

%% ---------------------------------------------------------------------------
%% Pesajes, historial y alertas
%% ---------------------------------------------------------------------------

pesaje_e_historial() ->
  {ok, _} = ?SRV:registrar_animal(animal(#{peso_kg => 200})),
  {ok, Actualizado} = ?SRV:registrar_pesaje(<<"AR-001">>, 205),
  ?assertEqual(205, maps:get(peso_kg, Actualizado)),
  ?assertMatch(
    {ok, [#{peso_kg := 205}, #{peso_kg := 200}]},
    ?SRV:historial_pesajes(<<"AR-001">>)
  ),
  ?assertEqual([], ?SRV:alertas()).

alerta_por_perdida_de_peso() ->
  {ok, _} = ?SRV:registrar_animal(animal(#{peso_kg => 200})),
  {ok, Actualizado, Alerta} = ?SRV:registrar_pesaje(<<"AR-001">>, 170),
  ?assertEqual(170, maps:get(peso_kg, Actualizado)),
  ?assertMatch(
    #{
      arete := <<"AR-001">>,
      tipo := perdida_peso,
      severidad := media,
      revisar_captura := false
    },
    Alerta
  ),
  ?assertEqual(15.0, maps:get(variacion_pct, Alerta)),
  Alertas = ?SRV:alertas(),
  ?assertEqual(1, length(Alertas)),
  ?assertEqual(1, length(?SRV:alertas(<<"AR-001">>))),
  ?assertEqual([], ?SRV:alertas(<<"AR-002">>)).

alerta_por_posible_error_de_captura() ->
  {ok, _} = ?SRV:registrar_animal(animal(#{peso_kg => 200})),
  {ok, _Actualizado, Alerta} = ?SRV:registrar_pesaje(<<"AR-001">>, 100),
  ?assertEqual(alta, maps:get(severidad, Alerta)),
  ?assertEqual(true, maps:get(revisar_captura, Alerta)),
  ?assertEqual(50.0, maps:get(variacion_pct, Alerta)),
  ?assertMatch(<<"Perdida de peso", _/binary>>, maps:get(mensaje, Alerta)).

pesaje_invalido() ->
  {ok, _} = ?SRV:registrar_animal(animal(#{peso_kg => 200})),
  ?assertEqual(
    {error, {dato_invalido, peso_kg}},
    ?SRV:registrar_pesaje(<<"AR-001">>, 0)
  ),
  ?assertEqual(
    {error, {dato_invalido, peso_kg}},
    ?SRV:registrar_pesaje(<<"AR-001">>, -5)
  ),
  ?assertEqual(
    {error, {dato_invalido, peso_kg}},
    ?SRV:registrar_pesaje(<<"AR-001">>, 2001)
  ),
  ?assertEqual(
    {error, {dato_invalido, peso_kg}},
    ?SRV:registrar_pesaje(<<"AR-001">>, <<"200">>)
  ),
  ?assertEqual(
    {error, {dato_invalido, fecha}},
    ?SRV:registrar_pesaje(<<"AR-001">>, 200, 0)
  ),
  ?assertEqual(
    {error, no_encontrado},
    ?SRV:registrar_pesaje(<<"NO-EXISTE">>, 200)
  ),
  ?assertMatch({ok, [#{peso_kg := 200}]}, ?SRV:historial_pesajes(<<"AR-001">>)),
  ?assertEqual([], ?SRV:alertas()).

%% ---------------------------------------------------------------------------
%% Salud, potrero y supervision
%% ---------------------------------------------------------------------------

salud_y_potrero() ->
  {ok, _} = ?SRV:registrar_animal(animal(#{})),
  {ok, Enfermo} = ?SRV:actualizar_salud(<<"AR-001">>, enfermo),
  ?assertEqual(enfermo, maps:get(salud, Enfermo)),
  ?assertEqual(
    {error, {dato_invalido, salud}},
    ?SRV:actualizar_salud(<<"AR-001">>, desconocido)
  ),
  {ok, Movido} = ?SRV:mover_animal(<<"AR-001">>, <<"Potrero Sur">>),
  ?assertEqual(<<"Potrero Sur">>, maps:get(potrero, Movido)),
  ?assertEqual(
    {error, {dato_invalido, potrero}},
    ?SRV:mover_animal(<<"AR-001">>, <<>>)
  ),
  ?assertEqual(
    {error, no_encontrado},
    ?SRV:mover_animal(<<"NO-EXISTE">>, <<"Potrero Sur">>)
  ),
  ?assertEqual(
    [<<"AR-001">>],
    aretes(?SRV:listar_animales_por_potrero(<<"Potrero Sur">>))
  ).

reinicio_del_worker() ->
  SupPid = whereis(?SUP),
  [{?SRV, WorkerPid, worker, _Modulos}] =
    [Child || Child = {?SRV, _Pid, _Tipo, _Modulos} <- supervisor:which_children(SupPid)],
  ?assert(is_pid(WorkerPid)),
  exit(WorkerPid, kill),
  NuevoWorker = esperar_worker(WorkerPid, 100),
  ?assert(is_pid(NuevoWorker)),
  ?assert(WorkerPid =/= NuevoWorker),
  ?assertEqual(pong, ?SRV:ping()).

esperar_worker(_Anterior, 0) ->
  whereis(?SRV);
esperar_worker(Anterior, Intentos) ->
  case whereis(?SRV) of
    Pid when is_pid(Pid), Pid =/= Anterior ->
      Pid;
    _ ->
      timer:sleep(20),
      esperar_worker(Anterior, Intentos - 1)
  end.

%% ---------------------------------------------------------------------------
%% Datos simulados
%% ---------------------------------------------------------------------------

demo_con_datos_ficticios() ->
  {ok, Resumen} = p81_gestion_de_ganado_demo:cargar(),
  ?assertEqual(4, maps:get(animales, Resumen)),
  ?assertEqual(2, maps:get(alertas, Resumen)),
  ?assertEqual(4, length(?SRV:listar_animales())),
  ?assertEqual(2, length(?SRV:alertas())),
  ?assertEqual(
    [<<"DEMO-0003">>, <<"DEMO-0004">>],
    aretes(?SRV:listar_animales_por_potrero(<<"Potrero Sur">>))
  ),
  ?assertEqual({error, ya_hay_datos}, p81_gestion_de_ganado_demo:cargar()).
