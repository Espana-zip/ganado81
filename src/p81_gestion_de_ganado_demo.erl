-module(p81_gestion_de_ganado_demo).

%% Datos ficticios para demostrar los casos de uso. Los aretes llevan el
%% prefijo DEMO- a proposito: no representan animales, ranchos ni cifras reales.
-export([cargar/0, datos/0]).

%% Solo carga sobre un hato vacio para que repetir la demo no duplique pesajes.
cargar() ->
  case p81_gestion_de_ganado_server:listar_animales() of
    [] ->
      Ahora = erlang:system_time(second),
      [cargar_animal(Dato, Ahora) || Dato <- datos()],
      {ok, #{
        animales => length(p81_gestion_de_ganado_server:listar_animales()),
        alertas => length(p81_gestion_de_ganado_server:alertas())
      }};
    _Animales ->
      {error, ya_hay_datos}
  end.

datos() ->
  [
    #{
      arete => <<"DEMO-0001">>,
      peso_kg => 220,
      salud => sano,
      potrero => <<"Potrero Norte">>,
      dias_alta => 90,
      pesajes => [{60, 215}, {30, 190}]
    },
    #{
      arete => <<"DEMO-0002">>,
      peso_kg => 180,
      salud => sano,
      potrero => <<"Potrero Norte">>,
      dias_alta => 90,
      pesajes => [{60, 195}, {30, 205}]
    },
    #{
      arete => <<"DEMO-0003">>,
      peso_kg => 250,
      salud => en_tratamiento,
      potrero => <<"Potrero Sur">>,
      dias_alta => 90,
      pesajes => [{60, 245}, {30, 238}]
    },
    #{
      arete => <<"DEMO-0004">>,
      peso_kg => 210,
      salud => cuarentena,
      potrero => <<"Potrero Sur">>,
      dias_alta => 90,
      %% Caida extrema: el MVP la marca como posible error de captura.
      pesajes => [{60, 205}, {30, 120}]
    }
  ].

cargar_animal(Dato, Ahora) ->
  Arete = maps:get(arete, Dato),
  FechaAlta = Ahora - (maps:get(dias_alta, Dato) * 86400),
  {ok, _Animal} = p81_gestion_de_ganado_server:registrar_animal(#{
    arete => Arete,
    peso_kg => maps:get(peso_kg, Dato),
    salud => maps:get(salud, Dato),
    potrero => maps:get(potrero, Dato),
    fecha_alta => FechaAlta
  }),
  lists:foreach(
    fun({DiasAtras, PesoKg}) ->
      Fecha = Ahora - (DiasAtras * 86400),
      case p81_gestion_de_ganado_server:registrar_pesaje(Arete, PesoKg, Fecha) of
        {ok, _AnimalActualizado} -> ok;
        {ok, _AnimalActualizado, _Alerta} -> ok
      end
    end,
    maps:get(pesajes, Dato)
  ).
