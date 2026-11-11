-module(p81_gestion_de_ganado_server).
-behaviour(gen_server).

%% API publica del hato. El proceso es el unico dueno del estado para evitar
%% condiciones de carrera entre registros, pesajes y alertas.
-export([
  start_link/0,
  ping/0,
  state/0,
  registrar_animal/1,
  consultar_animal/1,
  listar_animales/0,
  listar_animales_por_potrero/1,
  registrar_pesaje/2,
  registrar_pesaje/3,
  historial_pesajes/1,
  alertas/0,
  alertas/1,
  actualizar_salud/2,
  mover_animal/2
]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

%% Supuestos del MVP, documentados en README.md:
%% - Una perdida >= 10 % entre pesajes consecutivos se revisa.
%% - Una perdida >= 40 % se marca ademas como posible error de captura.
-define(UMBRAL_PERDIDA_PCT, 10.0).
-define(UMBRAL_ERROR_CAPTURA_PCT, 40.0).
-define(PESO_MAX_KG, 2000).
-define(SALUDES_VALIDAS, [sano, enfermo, en_tratamiento, cuarentena]).

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

ping() ->
  gen_server:call(?MODULE, ping).

state() ->
  gen_server:call(?MODULE, state).

registrar_animal(Datos) when is_map(Datos) ->
  gen_server:call(?MODULE, {registrar_animal, Datos});
registrar_animal(_Datos) ->
  {error, {dato_invalido, animal}}.

consultar_animal(Arete) ->
  gen_server:call(?MODULE, {consultar_animal, Arete}).

listar_animales() ->
  gen_server:call(?MODULE, listar_animales).

listar_animales_por_potrero(Potrero) ->
  gen_server:call(?MODULE, {listar_animales_por_potrero, Potrero}).

registrar_pesaje(Arete, PesoKg) ->
  registrar_pesaje(Arete, PesoKg, ahora()).

registrar_pesaje(Arete, PesoKg, Fecha) ->
  gen_server:call(?MODULE, {registrar_pesaje, Arete, PesoKg, Fecha}).

historial_pesajes(Arete) ->
  gen_server:call(?MODULE, {historial_pesajes, Arete}).

alertas() ->
  gen_server:call(?MODULE, alertas).

alertas(Arete) ->
  gen_server:call(?MODULE, {alertas, Arete}).

actualizar_salud(Arete, Salud) ->
  gen_server:call(?MODULE, {actualizar_salud, Arete, Salud}).

mover_animal(Arete, Potrero) ->
  gen_server:call(?MODULE, {mover_animal, Arete, Potrero}).

%% Estado como mapa para poder agregar campos del dominio sin romper los callbacks.
init([]) ->
  logger:info("~s iniciado", [?MODULE], #{proyecto => p81_gestion_de_ganado}),
  {ok, #{iniciado_en => ahora(), animales => #{}, alertas => []}}.

handle_call(ping, _From, State) ->
  {reply, pong, State};
handle_call(state, _From, State) ->
  {reply, State, State};
handle_call({registrar_animal, Datos}, _From, State) ->
  {Reply, State1} = registrar_animal_en_estado(Datos, State),
  {reply, Reply, State1};
handle_call({consultar_animal, Arete}, _From, State) ->
  {reply, consultar(Arete, State), State};
handle_call(listar_animales, _From, State) ->
  {reply, listar_ordenados(maps:get(animales, State)), State};
handle_call({listar_animales_por_potrero, Potrero}, _From, State) ->
  {reply, listar_por_potrero(Potrero, State), State};
handle_call({registrar_pesaje, Arete, PesoKg, Fecha}, _From, State) ->
  {Reply, State1} = registrar_pesaje_en_estado(Arete, PesoKg, Fecha, State),
  {reply, Reply, State1};
handle_call({historial_pesajes, Arete}, _From, State) ->
  {reply, obtener_historial(Arete, State), State};
handle_call(alertas, _From, State) ->
  {reply, maps:get(alertas, State), State};
handle_call({alertas, Arete}, _From, State) ->
  {reply, alertas_por_arete(Arete, State), State};
handle_call({actualizar_salud, Arete, Salud}, _From, State) ->
  {Reply, State1} = actualizar_salud_en_estado(Arete, Salud, State),
  {reply, Reply, State1};
handle_call({mover_animal, Arete, Potrero}, _From, State) ->
  {Reply, State1} = mover_animal_en_estado(Arete, Potrero, State),
  {reply, Reply, State1}.

handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info(_Info, State) ->
  {noreply, State}.

%% ---------------------------------------------------------------------------
%% Registro y consultas
%% ---------------------------------------------------------------------------

%% Se valida antes de buscar duplicados para no aceptar basura aunque el arete
%% ya exista. El arete duplicado es el caso dificil principal del problema.
registrar_animal_en_estado(Datos, State) ->
  case validar_animal(Datos) of
    {ok, Animal} ->
      Arete = maps:get(arete, Animal),
      Animales = maps:get(animales, State),
      case maps:is_key(Arete, Animales) of
        true ->
          {{error, duplicado}, State};
        false ->
          logger:info("Animal registrado", #{
            arete => Arete,
            potrero => maps:get(potrero, Animal),
            salud => maps:get(salud, Animal)
          }),
          {{ok, Animal}, State#{animales => Animales#{Arete => Animal}}}
      end;
    {error, _Razon} = Error ->
      {Error, State}
  end.

consultar(Arete, State) ->
  case normalizar_arete(Arete) of
    {ok, AreteNormalizado} ->
      case maps:find(AreteNormalizado, maps:get(animales, State)) of
        {ok, Animal} -> {ok, Animal};
        error -> {error, no_encontrado}
      end;
    {error, _Razon} = Error ->
      Error
  end.

listar_por_potrero(Potrero, State) ->
  case normalizar_potrero(Potrero) of
    {ok, PotreroNormalizado} ->
      Animales = [
        Animal
        || Animal <- maps:values(maps:get(animales, State)),
           maps:get(potrero, Animal) =:= PotreroNormalizado
      ],
      listar_ordenados_de_lista(Animales);
    {error, _Razon} = Error ->
      Error
  end.

listar_ordenados(Animales) ->
  listar_ordenados_de_lista(maps:values(Animales)).

listar_ordenados_de_lista(Animales) ->
  lists:sort(
    fun(A, B) -> maps:get(arete, A) =< maps:get(arete, B) end,
    Animales
  ).

%% ---------------------------------------------------------------------------
%% Pesajes e historial
%% ---------------------------------------------------------------------------

registrar_pesaje_en_estado(Arete, PesoKg, Fecha, State) ->
  case {normalizar_arete(Arete), normalizar_peso(PesoKg), normalizar_fecha(Fecha)} of
    {{ok, AreteNormalizado}, {ok, PesoNormalizado}, {ok, FechaNormalizada}} ->
      Animales = maps:get(animales, State),
      case maps:find(AreteNormalizado, Animales) of
        {ok, Animal} ->
          {AnimalActualizado, Alerta} =
            agregar_pesaje(Animal, PesoNormalizado, FechaNormalizada),
          State1 = State#{animales => Animales#{AreteNormalizado => AnimalActualizado}},
          case Alerta of
            none ->
              {{ok, AnimalActualizado}, State1};
            AlertaNueva ->
              logger:warning("Alerta de perdida de peso", #{
                arete => AreteNormalizado,
                severidad => maps:get(severidad, AlertaNueva),
                variacion_pct => maps:get(variacion_pct, AlertaNueva)
              }),
              {{ok, AnimalActualizado, AlertaNueva},
               State1#{alertas => [AlertaNueva | maps:get(alertas, State1)]}}
          end;
        error ->
          {{error, no_encontrado}, State}
      end;
    {{error, Razon}, _Peso, _Fecha} ->
      {{error, Razon}, State};
    {_Arete, {error, Razon}, _Fecha} ->
      {{error, Razon}, State};
    {_Arete, _Peso, {error, Razon}} ->
      {{error, Razon}, State}
  end.

agregar_pesaje(Animal, PesoKg, Fecha) ->
  PesoAnterior = maps:get(peso_kg, Animal),
  Historial = maps:get(historial_pesajes, Animal),
  Pesaje = #{peso_kg => PesoKg, fecha => Fecha},
  AnimalActualizado = Animal#{
    peso_kg => PesoKg,
    historial_pesajes => [Pesaje | Historial],
    actualizado_en => Fecha
  },
  {AnimalActualizado, evaluar_perdida(Animal, PesoAnterior, PesoKg, Fecha)}.

evaluar_perdida(_Animal, PesoAnterior, PesoKg, _Fecha) when PesoKg >= PesoAnterior ->
  none;
evaluar_perdida(Animal, PesoAnterior, PesoKg, Fecha) ->
  VariacionPct = ((PesoAnterior - PesoKg) / PesoAnterior) * 100,
  case VariacionPct >= ?UMBRAL_PERDIDA_PCT of
    false ->
      none;
    true ->
      RevisarCaptura = VariacionPct >= ?UMBRAL_ERROR_CAPTURA_PCT,
      Severidad = case RevisarCaptura of true -> alta; false -> media end,
      #{
        arete => maps:get(arete, Animal),
        tipo => perdida_peso,
        severidad => Severidad,
        fecha => Fecha,
        peso_anterior_kg => PesoAnterior,
        peso_actual_kg => PesoKg,
        variacion_kg => PesoKg - PesoAnterior,
        variacion_pct => redondear(VariacionPct),
        revisar_captura => RevisarCaptura,
        mensaje => mensaje_perdida(VariacionPct)
      }
  end.

obtener_historial(Arete, State) ->
  case consultar(Arete, State) of
    {ok, Animal} -> {ok, maps:get(historial_pesajes, Animal)};
    {error, _Razon} = Error -> Error
  end.

alertas_por_arete(Arete, State) ->
  case normalizar_arete(Arete) of
    {ok, AreteNormalizado} ->
      [
        Alerta
        || Alerta <- maps:get(alertas, State),
           maps:get(arete, Alerta) =:= AreteNormalizado
      ];
    {error, _Razon} = Error ->
      Error
  end.

%% ---------------------------------------------------------------------------
%% Salud y potrero
%% ---------------------------------------------------------------------------

actualizar_salud_en_estado(Arete, Salud, State) ->
  actualizar_campo_en_estado(
    Arete,
    fun normalizar_salud/1,
    Salud,
    fun(Animal, SaludNormalizada) ->
      logger:info("Salud actualizada", #{
        arete => maps:get(arete, Animal),
        salud => SaludNormalizada
      }),
      Animal#{salud => SaludNormalizada, actualizado_en => ahora()}
    end,
    State
  ).

mover_animal_en_estado(Arete, Potrero, State) ->
  actualizar_campo_en_estado(
    Arete,
    fun normalizar_potrero/1,
    Potrero,
    fun(Animal, PotreroNormalizado) ->
      logger:info("Animal movido de potrero", #{
        arete => maps:get(arete, Animal),
        potrero => PotreroNormalizado
      }),
      Animal#{potrero => PotreroNormalizado, actualizado_en => ahora()}
    end,
    State
  ).

actualizar_campo_en_estado(Arete, Normalizador, Valor, Actualizador, State) ->
  case {normalizar_arete(Arete), Normalizador(Valor)} of
    {{ok, AreteNormalizado}, {ok, ValorNormalizado}} ->
      Animales = maps:get(animales, State),
      case maps:find(AreteNormalizado, Animales) of
        {ok, Animal} ->
          AnimalActualizado = Actualizador(Animal, ValorNormalizado),
          {{ok, AnimalActualizado},
           State#{animales => Animales#{AreteNormalizado => AnimalActualizado}}};
        error ->
          {{error, no_encontrado}, State}
      end;
    {{error, Razon}, _Valor} ->
      {{error, Razon}, State};
    {_Arete, {error, Razon}} ->
      {{error, Razon}, State}
  end.

%% ---------------------------------------------------------------------------
%% Validacion y normalizacion
%% ---------------------------------------------------------------------------

validar_animal(Datos) ->
  Validadores = [
    {arete, fun normalizar_arete/1},
    {peso_kg, fun normalizar_peso/1},
    {salud, fun normalizar_salud/1},
    {potrero, fun normalizar_potrero/1}
  ],
  case validar_campos(Datos, Validadores, #{}) of
    {ok, Normalizado} ->
      case normalizar_fecha(maps:get(fecha_alta, Datos, ahora())) of
        {ok, FechaAlta} ->
          {ok, #{
            arete => maps:get(arete, Normalizado),
            peso_kg => maps:get(peso_kg, Normalizado),
            salud => maps:get(salud, Normalizado),
            potrero => maps:get(potrero, Normalizado),
            historial_pesajes => [
              #{peso_kg => maps:get(peso_kg, Normalizado), fecha => FechaAlta}
            ],
            creado_en => FechaAlta,
            actualizado_en => FechaAlta
          }};
        {error, _Razon} = Error ->
          Error
      end;
    {error, _Razon} = Error ->
      Error
  end.

validar_campos(_Datos, [], Acc) ->
  {ok, Acc};
validar_campos(Datos, [{Campo, Validador} | Resto], Acc) ->
  case Validador(maps:get(Campo, Datos, undefined)) of
    {ok, Valor} ->
      validar_campos(Datos, Resto, Acc#{Campo => Valor});
    {error, _Razon} = Error ->
      Error
  end.

normalizar_arete(Arete) when is_binary(Arete) ->
  case string:trim(Arete) of
    <<>> ->
      {error, {dato_invalido, arete}};
    Normalizado when byte_size(Normalizado) =< 32 ->
      {ok, Normalizado};
    _ ->
      {error, {dato_invalido, arete}}
  end;
normalizar_arete(Arete) when is_integer(Arete), Arete > 0 ->
  normalizar_arete(integer_to_binary(Arete));
normalizar_arete(_Arete) ->
  {error, {dato_invalido, arete}}.

normalizar_peso(PesoKg) when is_number(PesoKg), PesoKg > 0, PesoKg =< ?PESO_MAX_KG ->
  {ok, PesoKg};
normalizar_peso(_PesoKg) ->
  {error, {dato_invalido, peso_kg}}.

normalizar_salud(Salud) when is_atom(Salud) ->
  case lists:member(Salud, ?SALUDES_VALIDAS) of
    true -> {ok, Salud};
    false -> {error, {dato_invalido, salud}}
  end;
normalizar_salud(_Salud) ->
  {error, {dato_invalido, salud}}.

normalizar_potrero(Potrero) when is_binary(Potrero) ->
  case string:trim(Potrero) of
    <<>> ->
      {error, {dato_invalido, potrero}};
    Normalizado when byte_size(Normalizado) =< 64 ->
      {ok, Normalizado};
    _ ->
      {error, {dato_invalido, potrero}}
  end;
normalizar_potrero(_Potrero) ->
  {error, {dato_invalido, potrero}}.

normalizar_fecha(Fecha) when is_integer(Fecha), Fecha > 0 ->
  {ok, Fecha};
normalizar_fecha(_Fecha) ->
  {error, {dato_invalido, fecha}}.

%% ---------------------------------------------------------------------------
%% Utilidades
%% ---------------------------------------------------------------------------

redondear(Valor) ->
  round(Valor * 100) / 100.

mensaje_perdida(VariacionPct) ->
  iolist_to_binary(
    io_lib:format(
      "Perdida de peso de ~.1f% entre pesajes; revisar salud, agua y pasto.",
      [VariacionPct]
    )
  ).

ahora() ->
  erlang:system_time(second).
