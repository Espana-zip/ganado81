#!/usr/bin/env escript
%%! -noshell -noinput
-mode(compile).

%% Un unico fallo, exclusivamente en una VM nueva y en loopback:18081.
%% La instancia de 8080 solo se observa por HTTP y /proc; nunca se controla.
-define(APP, p81_gestion_de_ganado).
-define(SUP, p81_gestion_de_ganado_sup).
-define(SRV, p81_gestion_de_ganado_server).
-define(PORT, 18081).

main(["--validar"]) ->
  io:format("ESCRIPT_COMPILADO_OK (sin arrancar aplicaciones ni inyectar fallos)~n");
main(["--confirmar-una-falla", Out]) ->
  Root = filename:dirname(filename:dirname(filename:absname(escript:script_name()))),
  Dir = filename:absname(Out),
  try
    true = lists:prefix("aarch64", erlang:system_info(system_architecture)),
    nonode@nohost = node(),
    true = lists:prefix(filename:join(Root,"evidencias") ++ "/", Dir),
    false = lists:member("..", filename:split(Dir)),
    true = filelib:is_dir(Dir),
    %% No reutilizar una carpeta ni repetir una inyeccion tras un fallo parcial.
    write_new(filename:join(Dir,"experimento-iniciado.txt"), <<"Una VM temporal; una inyeccion como maximo.\n">>),
    ok = code:add_paths(filelib:wildcard(filename:join([Root,"_build","default","lib","*","ebin"]))),
    ok = p81_gestion_de_ganado_runtime:comprobar(),
    {ok,_} = application:ensure_all_started(inets),
    {ok,_} = application:ensure_all_started(crypto),
    Production = production_identity(Root),
    Snapshot = production_snapshot(),
    write_json(Dir,"produccion-antes.json",Snapshot),
    io:format("ALCANCE: puerto temporal ~p, VM nueva SO=~s. Produccion 8080 SO=~s solo lectura.~n",
      [?PORT,os:getpid(),maps:get(pid,Production)]),
    ok = application:load(?APP),
    ok = application:set_env(?APP,http_ip,{127,0,0,1}),
    ok = application:set_env(?APP,http_port,?PORT),
    ok = application:set_env(?APP,auto_cargar_demo,false),
    {ok,_} = application:ensure_all_started(?APP),
    probar(Root,Dir,Production,Snapshot)
  catch C:R:S ->
    io:format(standard_error,"PRUEBA_ABORTADA ~p:~p~n~p~nNo se repetira ninguna inyeccion.~n",[C,R,S]),
    halt(1)
  end;
main(_) ->
  io:format(standard_error,"Uso: caos_aislado_avh.escript --confirmar-una-falla evidencias/CARPETA_NUEVA~n",[]),
  halt(1).

probar(Root,Dir,Production,Snapshot) ->
  try
    {{127,0,0,1},?PORT} = ranch:get_addr(p81_gestion_de_ganado_http),
    Before = identities(),
    Old = maps:get(worker,Before),
    [{?SRV,Old,worker,_}] = supervisor:which_children(maps:get(supervisor,Before)),
    pong = ?SRV:ping(),
    request(?PORT,post,"/api/animales",#{arete=><<"DEMO-CAOS-AISLADO">>,
      peso_kg=>200,salud=><<"sano">>,potrero=><<"Prueba temporal">>},201),
    request(?PORT,post,"/api/animales/DEMO-CAOS-AISLADO/pesajes",#{peso_kg=>170},201),
    #{<<"datos">>:=#{<<"animales">>:=1,<<"alertas">>:=1}} =
      request(?PORT,get,"/api/salud",none,200),
    #{<<"datos">>:=#{<<"animal">>:=#{<<"historial_pesajes">>:=[_,_]}}} =
      request(?PORT,get,"/api/animales/DEMO-CAOS-AISLADO",none,200),
    io:format("ANTES supervisor=~p worker=~p cowboy_sup=~p listener=~p~n",[
      maps:get(supervisor,Before),Old,maps:get(cowboy,Before),maps:get(listener,Before)]),
    io:format("Estado temporal antes: 1 animal, 2 pesajes, 1 alerta.~n"),
    Ref = monitor(process,Old),
    write_new(filename:join(Dir,"inyeccion-unica.txt"),
      iolist_to_binary(io_lib:format("exit(~p,kill), VM SO ~s~n",[Old,os:getpid()]))),
    io:format("INYECCION_UNICA: exit(~p, kill). No es un PID Linux.~n",[Old]),
    Start = erlang:monotonic_time(microsecond),
    exit(Old,kill),
    receive {'DOWN',Ref,process,Old,killed} -> ok after 5000 -> error(worker_no_termino) end,
    New = esperar(Old,250),
    After = identities(),
    true = New =/= Old,
    New = maps:get(worker,After),
    %% Se comprueban PID Y vida; no basta volver a obtener un nombre registrado.
    lists:foreach(fun(Key) ->
      P = maps:get(Key,Before), P = maps:get(Key,After), true = is_process_alive(P)
    end,[supervisor,cowboy,ranch,listener]),
    pong = ?SRV:ping(),
    #{<<"datos">>:=#{<<"animales">>:=0,<<"alertas">>:=0}} =
      request(?PORT,get,"/api/salud",none,200),
    #{<<"datos">>:=#{<<"animales">>:=[],<<"total">>:=0}} =
      request(?PORT,get,"/api/animales",none,200),
    request(?PORT,get,"/api/animales/DEMO-CAOS-AISLADO",none,404),
    Production = production_identity(Root),
    SnapshotAfter = production_snapshot(),
    write_json(Dir,"produccion-despues.json",SnapshotAfter),
    Snapshot = SnapshotAfter,
    Elapsed = (erlang:monotonic_time(microsecond)-Start)/1000,
    Report = #{ok=>true,alcance=><<"VM temporal ARM64; NO worker de 8080">>,
      puerto_temporal=>?PORT,puerto_principal=>8080,vm_temporal_so=>list_to_binary(os:getpid()),
      produccion_so=>Production,antes=>json_pids(Before),despues=>json_pids(After),
      inyecciones=>1,supervisor_sin_reinicio=>true,cowboy_sin_reinicio=>true,
      listener_sin_reinicio=>true,estado_temporal_perdido=>true,
      estado_temporal_antes=>#{animales=>1,pesajes=>2,alertas=>1},
      estado_temporal_despues=>#{animales=>0,pesajes=>0,alertas=>0},
      produccion_sin_cambios=>true,produccion_sha256=>digest(Snapshot),
      verificacion_post_fallo_ms=>Elapsed},
    write_json(Dir,"resultado.json",Report),
    io:format("DESPUES supervisor=~p worker=~p cowboy_sup=~p listener=~p~n",[
      maps:get(supervisor,After),New,maps:get(cowboy,After),maps:get(listener,After)]),
    io:format("PERDIDA CONFIRMADA: solo el estado temporal (0 animales / 0 alertas y arete 404).~n"),
    io:format("PRODUCCION 8080: mismo PID SO/starttime y mismos datos; HTTP 200. SHA256=~s~n",[digest(Snapshot)]),
    io:format("CAOS_AISLADO_OK: 1 inyeccion; supervisor, Cowboy y listener sin reinicio.~n")
  after
    %% Limpieza despues de verificar la supervivencia; afecta solo a esta VM.
    application:stop(?APP)
  end,
  io:format("LIMPIEZA: se cierra solo la instancia temporal 18081; 8080 sigue intacto.~n").

identities() ->
  Result = #{supervisor=>whereis(?SUP),worker=>whereis(?SRV),
    cowboy=>whereis(cowboy_sup),ranch=>whereis(ranch_sup),
    listener=>proplists:get_value(pid,ranch:info(p81_gestion_de_ganado_http))},
  maps:foreach(fun(_,P)->true=is_pid(P),true=is_process_alive(P) end,Result),
  Result.

production_identity(Root) ->
  Pid = case string:trim(os:cmd("systemctl show ganado81.service -p LoadState --value 2>/dev/null")) of
    "loaded" -> string:trim(os:cmd("systemctl show ganado81.service -p MainPID --value"));
    _ ->
      {ok,PidBin} = file:read_file(filename:join([Root,"evidencias","servidor-final.pid"])),
      string:trim(binary_to_list(PidBin))
  end,
  {Number,[]} = string:to_integer(Pid), true = Number > 1,
  {ok,Cwd} = file:read_link("/proc/"++Pid++"/cwd"),
  Root = Cwd,
  {ok,Comm} = file:read_file("/proc/"++Pid++"/comm"),
  <<"beam.smp">> = string:trim(Comm),
  {ok,Stat} = file:read_file("/proc/"++Pid++"/stat"),
  [{End,_}|_] = lists:reverse(binary:matches(Stat,<<") ">>)),
  Rest = binary:part(Stat,End+2,byte_size(Stat)-End-2),
  Fields = string:lexemes(binary_to_list(Rest)," "),
  #{pid=>list_to_binary(Pid),starttime_ticks=>list_to_binary(lists:nth(20,Fields))}.

production_snapshot() ->
  #{salud=>request(8080,get,"/api/salud",none,200),
    animales=>request(8080,get,"/api/animales",none,200),
    alertas=>request(8080,get,"/api/alertas",none,200)}.

request(Port,Method,Path,Body,Expected) ->
  URL="http://127.0.0.1:"++integer_to_list(Port)++Path,
  Req=case Body of none->{URL,[]};_->{URL,[],"application/json",iolist_to_binary(json:encode(Body))} end,
  {ok,{{_,Status,_},Headers,Binary}} = httpc:request(Method,Req,[{timeout,5000}],[{body_format,binary}]),
  io:format("HTTP ~p ~s ~s -> ~p (~p bytes)~n",[Port,atom_to_list(Method),Path,Status,byte_size(Binary)]),
  Expected = Status,
  "application/json; charset=utf-8" = proplists:get_value("content-type",Headers),
  json:decode(Binary).

esperar(_Old,0) -> error(worker_no_reinicio);
esperar(Old,N) ->
  case whereis(?SRV) of
    P when is_pid(P), P=/=Old -> P;
    _ -> timer:sleep(20),esperar(Old,N-1)
  end.

json_pids(Pids) -> maps:map(fun(_,P)->list_to_binary(pid_to_list(P)) end,Pids).
digest(Term) -> binary:encode_hex(crypto:hash(sha256,term_to_binary(Term,[deterministic]))).
write_json(Dir,Name,Value) -> write_new(filename:join(Dir,Name),iolist_to_binary(json:encode(Value))).
write_new(Path,Data) ->
  {ok,F} = file:open(Path,[write,binary,exclusive]),
  try ok=file:write(F,Data) after file:close(F) end.
