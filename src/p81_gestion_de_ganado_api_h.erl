-module(p81_gestion_de_ganado_api_h).

%% Handler de Cowboy. Solo traduce HTTP <-> la capa p81_gestion_de_ganado_api;
%% no contiene reglas de negocio ni acceso directo al gen_server.
-export([init/2]).

-define(MAX_BODY, 1048576).

init(Req0, Accion) ->
  try
    Req = manejar(Accion, Req0),
    {ok, Req, Accion}
  catch
    throw:consulta_invalida ->
      ReqError = responder({400, error_payload(<<"consulta_invalida">>,
        <<"Los parametros de consulta no son validos.">>)}, Req0),
      {ok, ReqError, Accion};
    Clase:Razon:Stack ->
      logger:error("Fallo en API HTTP: ~p", [{Clase, Razon, Stack}]),
      %% No volver a usar el encoder que pudo causar esta misma excepcion.
      %% Es un unico documento JSON constante, no un codec alternativo.
      ReqError = cowboy_req:reply(500, #{
        <<"content-type">> => <<"application/json; charset=utf-8">>,
        <<"cache-control">> => <<"no-store">>
      }, <<"{\"ok\":false,\"error\":{\"codigo\":\"error_interno\",\"mensaje\":\"Ocurrio un error interno.\"}}">>, Req0),
      {ok, ReqError, Accion}
  end.

manejar(salud, Req0) ->
  case metodo(Req0) of
    <<"GET">> -> responder(p81_gestion_de_ganado_api:salud(), Req0);
    _ -> metodo_no_permitido(<<"GET">>, Req0)
  end;
manejar(animales, Req0) ->
  case metodo(Req0) of
    <<"GET">> ->
      Potrero = parametro(<<"potrero">>, Req0),
      responder(p81_gestion_de_ganado_api:listar_animales(Potrero), Req0);
    <<"POST">> ->
      con_json(Req0, fun(Body, Req1) ->
        responder(p81_gestion_de_ganado_api:registrar_animal(Body), Req1)
      end);
    _ ->
      metodo_no_permitido(<<"GET, POST">>, Req0)
  end;
manejar(animal, Req0) ->
  case metodo(Req0) of
    <<"GET">> ->
      Arete = texto_utf8(cowboy_req:binding(arete, Req0)),
      responder(p81_gestion_de_ganado_api:consultar_animal(Arete), Req0);
    _ ->
      metodo_no_permitido(<<"GET">>, Req0)
  end;
manejar(pesajes, Req0) ->
  case metodo(Req0) of
    <<"POST">> ->
      Arete = texto_utf8(cowboy_req:binding(arete, Req0)),
      con_json(Req0, fun(Body, Req1) ->
        responder(p81_gestion_de_ganado_api:registrar_pesaje(Arete, Body), Req1)
      end);
    _ ->
      metodo_no_permitido(<<"POST">>, Req0)
  end;
manejar(alertas, Req0) ->
  case metodo(Req0) of
    <<"GET">> ->
      Arete = parametro(<<"arete">>, Req0),
      responder(p81_gestion_de_ganado_api:alertas(Arete), Req0);
    _ ->
      metodo_no_permitido(<<"GET">>, Req0)
  end;
manejar(no_encontrado, Req0) ->
  responder({404, error_payload(<<"no_encontrado">>,
    <<"No existe esa ruta de API.">>)}, Req0).

metodo(Req) ->
  cowboy_req:method(Req).

parametro(Nombre, Req) ->
  Parametros = try cowboy_req:parse_qs(Req) catch
    _:_ -> throw(consulta_invalida)
  end,
  case lists:keyfind(Nombre, 1, Parametros) of
    {Nombre, Valor} when is_binary(Valor), Valor =/= <<>> -> texto_utf8(Valor);
    _ -> undefined
  end.

texto_utf8(Valor) ->
  case unicode:characters_to_list(Valor, utf8) of
    Lista when is_list(Lista) -> Valor;
    _ -> throw(consulta_invalida)
  end.

con_json(Req0, Continuacion) ->
  case leer_cuerpo(Req0) of
    {ok, Cuerpo, Req1} ->
      case decodificar(Cuerpo) of
        {ok, Body} ->
          Continuacion(Body, Req1);
        error ->
          responder({400, error_payload(<<"json_invalido">>,
            <<"El cuerpo no contiene JSON valido.">>)}, Req1)
      end;
    {error, demasiado_grande, Req1} ->
      responder({413, error_payload(<<"cuerpo_demasiado_grande">>,
        <<"El cuerpo supera el limite permitido.">>)}, Req1)
  end.

decodificar(Cuerpo) when byte_size(Cuerpo) > 0 ->
  try
    case json:decode(Cuerpo) of
      Body when is_map(Body) -> {ok, Body};
      _ -> error
    end
  catch
    _:_ -> error
  end;
decodificar(_Cuerpo) ->
  error.

leer_cuerpo(Req) ->
  leer_cuerpo(Req, <<>>, 0).

leer_cuerpo(Req, Acumulado, Leido) ->
  case cowboy_req:read_body(Req, #{length => 65536, period => 5000}) of
    {ok, Datos, Req1} ->
      Total = Leido + byte_size(Datos),
      case Total =< ?MAX_BODY of
        true -> {ok, <<Acumulado/binary, Datos/binary>>, Req1};
        false -> {error, demasiado_grande, Req1}
      end;
    {more, Datos, Req1} ->
      Total = Leido + byte_size(Datos),
      case Total < ?MAX_BODY of
        true -> leer_cuerpo(Req1, <<Acumulado/binary, Datos/binary>>, Total);
        false -> {error, demasiado_grande, Req1}
      end
  end.

respuesta(Status, Payload, ExtraHeaders) ->
  Cabeceras = maps:merge(#{
    <<"content-type">> => <<"application/json; charset=utf-8">>,
    <<"cache-control">> => <<"no-store">>
  }, ExtraHeaders),
  {Status, Cabeceras, json:encode(Payload)}.

responder({Status, Payload}, Req) ->
  {Status, Cabeceras, Cuerpo} = respuesta(Status, Payload, #{}),
  cowboy_req:reply(Status, Cabeceras, Cuerpo, Req).

metodo_no_permitido(Permitidos, Req) ->
  Payload = error_payload(<<"metodo_no_permitido">>,
    <<"Metodo HTTP no permitido para esta ruta.">>),
  {405, Cabeceras, Cuerpo} = respuesta(405, Payload, #{
    <<"allow">> => Permitidos
  }),
  cowboy_req:reply(405, Cabeceras, Cuerpo, Req).

error_payload(Codigo, Mensaje) ->
  #{ok => false, error => #{
    codigo => Codigo,
    mensaje => Mensaje
  }}.
