-module(p81_gestion_de_ganado_api).

%% Capa HTTP/JSON delgada sobre el gen_server del hato. Mantener aqui el
%% mapeo de errores de dominio a codigos HTTP permite probar la API sin abrir
%% un socket y deja al handler de Cowboy ocupado solo del transporte.
-export([
  salud/0,
  listar_animales/1,
  consultar_animal/1,
  registrar_animal/1,
  registrar_pesaje/2,
  alertas/1
]).

-define(SRV, p81_gestion_de_ganado_server).

salud() ->
  Animales = ?SRV:listar_animales(),
  Alertas = ?SRV:alertas(),
  {200, ok(#{
    servicio => <<"p81_gestion_de_ganado">>,
    animales => length(Animales),
    alertas => length(Alertas)
  })}.

listar_animales(undefined) ->
  Animales = ?SRV:listar_animales(),
  {200, ok(#{animales => Animales, total => length(Animales)})};
listar_animales(<<>>) ->
  listar_animales(undefined);
listar_animales(Potrero) when is_binary(Potrero) ->
  case ?SRV:listar_animales_por_potrero(Potrero) of
    Animales when is_list(Animales) ->
      {200, ok(#{animales => Animales, total => length(Animales)})};
    {error, Razon} ->
      error_http(Razon)
  end.

consultar_animal(Arete) ->
  case ?SRV:consultar_animal(Arete) of
    {ok, Animal} ->
      Alertas = case ?SRV:alertas(Arete) of
        Lista when is_list(Lista) -> Lista;
        _ -> []
      end,
      {200, ok(#{animal => Animal, alertas => Alertas})};
    {error, Razon} ->
      error_http(Razon)
  end.

registrar_animal(Body) when is_map(Body) ->
  case salud_de_json(maps:get(<<"salud">>, Body, <<"sano">>)) of
    {ok, Salud} ->
      Datos = #{
        arete => maps:get(<<"arete">>, Body, undefined),
        peso_kg => maps:get(<<"peso_kg">>, Body, undefined),
        salud => Salud,
        potrero => maps:get(<<"potrero">>, Body, undefined)
      },
      case ?SRV:registrar_animal(Datos) of
        {ok, Animal} -> {201, ok(#{animal => Animal})};
        {error, Razon} -> error_http(Razon)
      end;
    {error, Razon} ->
      error_http(Razon)
  end;
registrar_animal(_Body) ->
  {400, error_payload(<<"solicitud_invalida">>,
    <<"El cuerpo debe ser un objeto JSON.">>, #{})}.

registrar_pesaje(Arete, Body) when is_map(Body) ->
  PesoKg = maps:get(<<"peso_kg">>, Body, undefined),
  case ?SRV:registrar_pesaje(Arete, PesoKg) of
    {ok, Animal} ->
      {201, ok(#{animal => Animal, alerta => null})};
    {ok, Animal, Alerta} ->
      {201, ok(#{animal => Animal, alerta => Alerta})};
    {error, Razon} ->
      error_http(Razon)
  end;
registrar_pesaje(_Arete, _Body) ->
  {400, error_payload(<<"solicitud_invalida">>,
    <<"El cuerpo debe ser un objeto JSON.">>, #{})}.

alertas(undefined) ->
  Alertas = ?SRV:alertas(),
  {200, ok(#{alertas => Alertas, total => length(Alertas)})};
alertas(<<>>) ->
  alertas(undefined);
alertas(Arete) when is_binary(Arete) ->
  case ?SRV:alertas(Arete) of
    Alertas when is_list(Alertas) ->
      {200, ok(#{alertas => Alertas, total => length(Alertas)})};
    {error, Razon} ->
      error_http(Razon)
  end.

%% ---------------------------------------------------------------------------
%% Errores
%% ---------------------------------------------------------------------------

error_http(duplicado) ->
  {409, error_payload(<<"duplicado">>,
    <<"Ya existe un animal con ese arete.">>, #{})};
error_http(no_encontrado) ->
  {404, error_payload(<<"no_encontrado">>,
    <<"No se encontro el recurso solicitado.">>, #{})};
error_http({dato_invalido, Campo}) ->
  {400, error_payload(<<"dato_invalido">>,
    mensaje_campo(Campo), #{campo => atom_to_binary(Campo, utf8)})};
error_http(Otra) ->
  logger:error("Error de API no controlado: ~p", [Otra]),
  {500, error_payload(<<"error_interno">>,
    <<"Ocurrio un error interno.">>, #{})}.

mensaje_campo(arete) ->
  <<"El arete es obligatorio y debe tener hasta 32 caracteres.">>;
mensaje_campo(peso_kg) ->
  <<"El peso debe ser un numero mayor que 0 y menor o igual a 2000 kg.">>;
mensaje_campo(salud) ->
  <<"La salud debe ser sano, enfermo, en_tratamiento o cuarentena.">>;
mensaje_campo(potrero) ->
  <<"El potrero es obligatorio y debe tener hasta 64 caracteres.">>;
mensaje_campo(fecha) ->
  <<"La fecha debe ser un entero positivo en segundos Unix.">>;
mensaje_campo(_Campo) ->
  <<"Uno de los datos enviados no es valido.">>.

error_payload(Codigo, Mensaje, Extra) ->
  #{ok => false, error => maps:merge(#{
    codigo => Codigo,
    mensaje => Mensaje
  }, Extra)}.

ok(Datos) ->
  #{ok => true, datos => Datos}.

salud_de_json(<<"sano">>) -> {ok, sano};
salud_de_json(<<"enfermo">>) -> {ok, enfermo};
salud_de_json(<<"en_tratamiento">>) -> {ok, en_tratamiento};
salud_de_json(<<"cuarentena">>) -> {ok, cuarentena};
salud_de_json(_Otro) -> {error, {dato_invalido, salud}}.
