-module(p81_gestion_de_ganado_runtime).

%% Rebar compila llamadas remotas aunque el modulo destino no exista.
%% Por eso se valida tambien al iniciar la aplicacion/listener, no en el
%% primer request (donde json:encode/1 rompia incluso la respuesta de error).
-export([comprobar/0, informacion/0, validar/1]).

informacion() ->
  Carga = code:ensure_loaded(json),
  #{otp => erlang:system_info(otp_release),
    erts => erlang:system_info(version),
    json => code:which(json),
    carga => Carga,
    encode => erlang:function_exported(json, encode, 1),
    decode => erlang:function_exported(json, decode, 1)}.

comprobar() ->
  validar(informacion()).

validar(#{otp := Otp, encode := Encode, decode := Decode} = Info) ->
  case otp_compatible(Otp) andalso Encode andalso Decode of
    true -> ok;
    false ->
      {error, {runtime_incompatible, #{
        requisito => <<"Se requiere OTP >= 27 y json:encode/1 + json:decode/1. Use scripts/proyecto.sh.">>,
        detectado => Info
      }}}
  end.

otp_compatible(Otp) ->
  case string:to_integer(Otp) of
    {Major, _} when is_integer(Major), Major >= 27 -> true;
    _ -> false
  end.
