:- module(reglas, [
    situacion/3,
    estado_caida/3,
    decide/3,
    estado_salida/3
]).

:- use_module('hechos.pl').
:- use_module(library(apply)).
% Permitir clausulas separadas en el archivo.
:- discontiguous situacion/3.
:- discontiguous decide/3.

% -----------------------------------------
% Buscar los dos pesajes mas recientes.
% -----------------------------------------
ultimos_pesajes(Animal, D1, P1, D2, P2) :-
    findall(
        Dia-Peso,
        lectura(Animal, peso_kg, Peso, Dia),
        Pesajes
    ),
    sort(Pesajes, Ordenados),
    reverse(
        Ordenados,
        [D2-P2, D1-P1 | _]
    ),
    D1 < D2.

% Detecta dos pesos diferentes registrados
% para el mismo animal en el mismo dia.
lecturas_contradictorias(Animal, Dia) :-
    lectura(Animal, peso_kg, P1, Dia),
    lectura(Animal, peso_kg, P2, Dia),
    P1 =\= P2,
    !.

% -----------------------------------------
% Evaluar si existe una caida de peso.
% Tres resultados:
% se_cumple / no_se_cumple / no_se_sabe
% ----------------------------------------
estado_caida(Animal, Estado, Evidencia) :-
    registro(Animal, _, _),

    ( lecturas_contradictorias(Animal, Dia)
    ->
        % Hay mediciones incompatibles.
        Estado = no_se_sabe,
        Evidencia = [
            lecturas_contradictorias(Animal, Dia)
        ]

    ; ultimos_pesajes(Animal, D1, P1, D2, P2)
    ->
        % Tenemos dos mediciones validas.
        ( P2 < P1
        ->
            Perdida is P1 - P2,
            Estado = se_cumple,
            Evidencia = [
                pesajes(D1, P1, D2, P2),
                perdida_kg(Perdida)
            ]
        ;
            Cambio is P2 - P1,
            Estado = no_se_cumple,
            Evidencia = [
                pesajes(D1, P1, D2, P2),
                ganancia_o_estabilidad_kg(Cambio)
            ]
        )

    ; lectura(Animal, peso_kg, _, _)
    ->
        % Existe una medicion, pero no dos
        % mediciones de fechas diferentes.
        Estado = no_se_sabe,
        Evidencia = [
            historial_incompleto(Animal)
        ]

    ;
        % No existen mediciones disponibles.
        Estado = no_se_sabe,
        Evidencia = [
            historial_insuficiente_o_ambiguo(Animal)
        ]
    ).

% -----------------------------------------
% Situacion 1:
% Posible error de captura.
% -----------------------------------------
situacion(Animal, posible_error_captura, Evidencia) :-
    lote(Lote, Animal),

    estado_caida(
        Animal,
        se_cumple,
        [pesajes(D1, _, D2, _),
         perdida_kg(Perdida)]
    ),

    findall(
        Otro,
        (lote(Lote, Otro), Otro \== Animal),
        Companeros
    ),

    Companeros \== [],

    maplist(
        companero_sin_perdida(D1, D2),
        Companeros,
        Comparacion
    ),

    Evidencia = [
        perdida_kg(Perdida),
        estado(pendiente_confirmacion),
        comparacion_lote(Lote, Comparacion)
    ].


% -----------------------------------------
% SITUACION 1 - PERDIDA COLECTIVA
%
% Se identifica un patron colectivo cuando
% el animal y todos sus companeros de lote
% presentan perdidas de peso.
% -----------------------------------------
situacion(Animal, perdida_colectiva, Evidencia) :-
    % Identificar el lote del animal.
    lote(Lote, Animal),

    % Comprobar que el animal perdio peso.
    estado_caida(
        Animal,
        se_cumple,
        [pesajes(D1, P1, D2, P2),
         perdida_kg(Perdida)]
    ),

    % Obtener sus companeros de lote.
    findall(
        Otro,
        (lote(Lote, Otro), Otro \== Animal),
        Companeros
    ),

    Companeros \== [],

    % Comprobar que todos perdieron peso
    % durante el mismo periodo.
    maplist(
        companero_con_perdida(D1, D2),
        Companeros,
        Comparacion
    ),

    % Construir una explicacion verificable.
    Evidencia = [
        perdida_kg(Perdida),
        estado(pendiente_revision),
        pesajes(D1, P1, D2, P2),
        comparacion_lote(Lote, Comparacion)
    ].


% -----------------------------------------
% SITUACION 2 - ARETE PERDIDO
%
% Identifica animales cuyo arete esta
% ausente y tienen un evento de perdida.
% -----------------------------------------
situacion(Animal, arete_perdido, Evidencia) :-

    % Comprobar que existe el registro
    % y que actualmente no tiene arete.
    registro(Animal, sin_arete, _),

    % Buscar el evento documentado.
    evento(
        Animal,
        arete_perdido,
        Detalle,
        Dia
    ),

    % Comprobar que el evento no sucede
    % despues del dia actual simulado.
    ahora(DiaActual),
    Dia =< DiaActual,

    % Construir la explicacion.
    Evidencia = [
        registro(Animal),
        arete(sin_arete),
        evento_arete_perdido(Dia),
        detalle(Detalle),
        estado(pendiente_verificacion)
    ].


% SITUACION 2 - ANIMALES DISTINTOS
% Identidad confirmada mediante un evento
% de verificacion del escenario ficticio.
situacion(
    identidad(R1, R2),
    animales_distintos,
    Evidencia
) :-
    evento(
        identidad(R1, R2),
        verificacion_identidad,
        animales_distintos,
        Dia
    ),

    registro(R1, _, _),
    registro(R2, _, _),
    R1 \== R2,

    ahora(DiaActual),
    Dia =< DiaActual,

    Evidencia = [
        verificacion_presencial(Dia),
        estado(confirmado)
    ].


% -----------------------------------------
% SITUACION 3 - BROTE DOCUMENTADO
% -----------------------------------------
situacion(Lote, brote_documentado, E) :-
    foco_brote(Lote, Animal, Potrero, Dia),
    E = [
        foco(Animal),
        ubicacion_foco(Lote, Potrero),
        brote_dia(Dia),
        estado(aislamiento)
    ].


% -----------------------------------------
% APLICACION SANITARIA REGISTRADA
% -----------------------------------------
situacion(Animal, campana_registrada(C), E) :-
    registro(Animal, _, _),
    campana(C, DiaCampana),
    aplicacion(Animal, C, DiaAplicacion),
    ahora(Actual),

    DiaCampana =< DiaAplicacion,
    DiaAplicacion =< Actual,

    E = [
        campana(C),
        aplicacion_fecha(DiaAplicacion),
        estado(registrada)
    ].

% -----------------------------------------
% INFORMACION SANITARIA DESCONOCIDA
% -----------------------------------------
situacion(Animal, campana_sin_dato(C), E) :-
    registro(Animal, _, _),
    campana(C, DiaCampana),
    ahora(Actual),
    DiaCampana =< Actual,

    \+ (
        aplicacion(Animal, C, Dia),
        Dia >= DiaCampana,
        Dia =< Actual
    ),

    E = [
        campana(C),
        estado(no_se_sabe),
        falta(registro_aplicacion)
    ].

% -----------------------------------------
% REVISION SANITARIA DE LOTE EXPUESTO
% -----------------------------------------
situacion(Lote, revision_vacunacion(C), E) :-
    situacion(Lote, exposicion_por_agua, _),

    findall(
        Animal,
        (
            lote(Lote, Animal),
            situacion(
                Animal,
                campana_sin_dato(C),
                _
            )
        ),
        SinConstancia
    ),

    SinConstancia \== [],

    E = [
        campana(C),
        animales_sin_constancia(SinConstancia),
        estado(pendiente_verificacion)
    ].


% -----------------------------------------
% SEQUIA DOCUMENTADA EN EL POTRERO
% -----------------------------------------
situacion(Lote, sequia_potrero, E) :-
    ubicacion(Lote, Potrero, _),
    evento(
        Potrero,
        sequia,
        reduccion_pasto_pct(Porcentaje),
        Dia
    ),
    ahora(Actual),
    Dia =< Actual,
    E = [
        potrero(Potrero),
        reduccion_pasto_pct(Porcentaje),
        estado(requiere_revision)
    ].


% Verificar presencia en un potrero
% durante una fecha simulada.
presente_en(Lote, Potrero, Dia) :-
    estancia(Lote, Potrero, Desde, Hasta),
    Desde =< Dia,
    Dia =< Hasta.

% Reconstruir una cadena de exposicion
% por agua compartida en la fecha del brote.
situacion(Lote, cadena_exposicion, E) :-
    evento(
        Foco,
        brote_sanitario,
        confirmado_en_escenario,
        Dia
    ),
    lote(LoteFoco, Foco),

    presente_en(LoteFoco, P1, Dia),
    presente_en(Lote, P2, Dia),
    Lote \== LoteFoco,

    conexion_agua(P1, P2),

    findall(
        Animal,
        lote(Lote, Animal),
        Animales
    ),

    findall(
        estado_campana(Animal, Estado),
        (
            member(Animal, Animales),
            (
                situacion(
                    Animal,
                    campana_registrada(campana_demo),
                    _
                )
            ->
                Estado = registrada
            ;
                Estado = sin_constancia
            )
        ),
        Campanas
    ),

    E = [
        cadena([
            foco(Foco),
            lote(LoteFoco),
            potrero(P1),
            agua_compartida(P1, P2),
            lote(Lote)
        ]),
        animales_expuestos(Animales),
        estado_campanas(Campanas),
        estado(precaucion)
    ].

% Si falta el historial temporal,
% no podemos descartar la exposicion.
situacion(Lote, contacto_no_determinable, E) :-
    setof(Animal, lote(Lote, Animal), _),
    \+ estancia(Lote, _, _, _),

    E = [
        estado(no_se_sabe),
        falta(historial_estancias(Lote))
    ].


% -----------------------------------------
% RUTA DE PASTOREO PROPUESTA
% -----------------------------------------
situacion(Lote, ruta_pastoreo(Destino), E) :-
    situacion(Lote, sequia_potrero, _),
    \+ lote_restringido(Lote),

    ubicacion(Lote, Origen, _),
    potrero(Destino),
    Destino \== Origen,

    % Comprobar condiciones del destino.
    aptitud(Destino, pasto, suficiente),
    aptitud(Destino, agua, suficiente),
    estado_potrero(Destino, disponible),
    \+ ubicacion(_, Destino, _),

    % Buscar una ruta sin cruzar
    % potreros sanitariamente restringidos.
    ruta_segura(Origen, Destino, Ruta),

    E = [
        origen(Origen),
        destino(Destino),
        ruta(Ruta),
        recursos(suficientes),
        estado(pendiente_autorizacion)
    ].


% -----------------------------------------
% RESTRICCIONES SANITARIAS
% -----------------------------------------
lote_restringido(Lote) :-
    situacion(Lote, brote_documentado, _).

lote_restringido(Lote) :-
    situacion(Lote, exposicion_por_agua, _).

potrero_restringido(Potrero) :-
    ubicacion(Lote, Potrero, _),
    lote_restringido(Lote).

% -----------------------------------------
% CONEXIONES ENTRE POTREROS
% -----------------------------------------
vecino(A, B) :-
    colinda(A, B).

vecino(A, B) :-
    colinda(B, A).

% -----------------------------------------
% BUSQUEDA DE CAMINO SIN CICLOS
% -----------------------------------------
ruta_segura(Origen, Destino, Ruta) :-
    camino_seguro(
        Origen,
        Destino,
        [Origen],
        Inversa
    ),
    reverse(Inversa, Ruta).

camino_seguro(Destino, Destino,
              Visitados, Visitados).

camino_seguro(Actual, Destino,
              Visitados, Ruta) :-
    vecino(Actual, Siguiente),
    \+ memberchk(Siguiente, Visitados),
    \+ potrero_restringido(Siguiente),

    camino_seguro(
        Siguiente,
        Destino,
        [Siguiente | Visitados],
        Ruta
    ).


% -----------------------------------------
% BROTE HIPOTETICO EN OTRO POTRERO
% No modifica los hechos originales.
% -----------------------------------------
situacion(Lote, brote_hipotetico(Potrero), E) :-
    potrero(Potrero),
    ubicacion(Lote, Potrero, Desde),
    ahora(Actual),
    Desde =< Actual,

    \+ situacion(Lote, brote_documentado, _),

    E = [
        supuesto(brote_en(Potrero)),
        ubicacion_actual(Lote, Potrero),
        estado(aislamiento_hipotetico)
    ].


% -----------------------------------------
% EXPOSICION POR AGUA COMPARTIDA
% -----------------------------------------
situacion(LoteDestino, exposicion_por_agua, E) :-
    foco_brote(
        LoteOrigen,
        Animal,
        PotreroOrigen,
        Dia
    ),

    ubicacion(LoteDestino, PotreroDestino, Desde),

    LoteDestino \== LoteOrigen,
    Desde =< Dia,

    conexion_agua(
        PotreroOrigen,
        PotreroDestino
    ),

    E = [
        foco(Animal),
        lote_foco(LoteOrigen),
        conexion_agua(
            PotreroOrigen,
            PotreroDestino
        ),
        brote_dia(Dia),
        estado(precaucion)
    ].


    % Aislamiento del lote con foco documentado.
decide(Lote, aislar_por_brote, Evidencia) :-
    situacion(Lote, brote_documentado, Evidencia).

% Precaucion por conexion de agua.

decide(Lote, aislar_por_precaucion, Evidencia) :-
    situacion(
        Lote,
        cadena_exposicion,
        Evidencia
    ).


% Encontrar un foco documentado y vigente
% en el tiempo del escenario simulado.
foco_brote(Lote, Animal, Potrero, Dia) :-
    evento(
        Animal,
        brote_sanitario,
        confirmado_en_escenario,
        Dia
    ),
    lote(Lote, Animal),
    ubicacion(Lote, Potrero, Desde),
    Desde =< Dia,
    ahora(Actual),
    Dia =< Actual.

% Compartir agua es una relacion simetrica.

conexion_agua(A, B) :-
    comparte_agua(A, B).

conexion_agua(A, B) :-
    comparte_agua(B, A).


% Identidad confirmada en el escenario.
situacion(
    identidad(R1, R2),
    mismo_animal,
    Evidencia
) :-
    evento(
        identidad(R1, R2),
        verificacion_identidad,
        mismo_animal,
        Dia
    ),
    registro(R1, _, _),
    registro(R2, _, _),
    R1 @< R2,
    ahora(Actual),
    Dia =< Actual,
    Evidencia = [
        registros(R1, R2),
        verificacion_presencial(Dia),
        estado(confirmado)
    ].


% -----------------------------------------
% SITUACION 2 - IDENTIDAD DEL GANADO
% Deteccion de aretes compartidos.
% -----------------------------------------
situacion(
    identidad(Registro1, Registro2),
    identidad_no_determinada,
    Evidencia
) :-
    % Primero identificar los registros.
    registro(Registro1, Arete, _),
    registro(Registro2, Arete, _),

    % Evitar comparar un registro consigo mismo
    % y repetir parejas en orden inverso.
    Registro1 @< Registro2,
    % Verificar que el arete sea conocido.
    atom(Arete),
    Arete \== sin_arete,

    % Construir la evidencia.
    Evidencia = [
        registros(Registro1, Registro2),
        arete_compartido(Arete),
        estado(pendiente_verificacion)
    ].


% Verifica que un companero tenga dos
% pesajes unicos, una perdida registrada.
companero_con_perdida(
    D1, D2, Animal,
    companero(Animal, P1, P2)
) :-
    findall(P, lectura(Animal, peso_kg, P, D1), [P1]),
    findall(P, lectura(Animal, peso_kg, P, D2), [P2]),
    P2 < P1.


companero_sin_perdida(
    D1, D2, Animal,
    companero(Animal, P1, P2)
) :-
    findall(P, lectura(Animal, peso_kg, P, D1), [P1]),
    findall(P, lectura(Animal, peso_kg, P, D2), [P2]),
    P2 >= P1.


% -----------------------------------------
% SITUACION 5 - SALIDA DEL GANADO
% -----------------------------------------
% Identificacion faltante.
motivo_bloqueo(Lote, arete_faltante(Animal)) :-
    lote(Lote, Animal),
    registro(Animal, sin_arete, _).

% Brote documentado.
motivo_bloqueo(Lote, brote_documentado) :-
    situacion(Lote, brote_documentado, _).

% Exposicion sanitaria.
motivo_bloqueo(Lote, exposicion_por_agua) :-
    situacion(Lote, exposicion_por_agua, _).

% Inferencia de un impedimento.
situacion(Lote, impedimento_salida, E) :-
    motivo_bloqueo(Lote, Motivo),
    E = [
        motivo(Motivo),
        estado(no_puede_salir)
    ].

% Reunir los impedimentos del lote.
decide(Lote, retener_lote, E) :-
    findall(
        Motivo,
        motivo_bloqueo(Lote, Motivo),
        MotivosEncontrados
    ),
    sort(MotivosEncontrados, Motivos),
    Motivos \== [],
    E = [
        impedimentos(Motivos),
        estado(no_puede_salir)
    ].


% -----------------------------------------
% IDENTIFICAR DATOS FALTANTES DEL LOTE
% -----------------------------------------
% Animal sin ningun pesaje.
problema_companero(Animal, sin_pesajes(Animal)) :-
    \+ lectura(Animal, peso_kg, _, _),
    !.

% Animal con mediciones contradictorias.
problema_companero(
    Animal,
    lecturas_contradictorias(Animal, Dia)
) :-
    lecturas_contradictorias(Animal, Dia),
    !.

% Animal con historial incompleto.
problema_companero(
    Animal,
    historial_incompleto(Animal)
) :-
    \+ ultimos_pesajes(Animal, _, _, _, _).


% Reunir los problemas de los companeros.
problemas_de_lote(Animal, Lote, Problemas) :-
    lote(Lote, Animal),
    findall(
        Problema,
        (
            lote(Lote, Otro),
            Otro \== Animal,
            problema_companero(Otro, Problema)
        ),
        Problemas
    ).


% -----------------------------------------
% MOTOR DE DECISIONES - SITUACION 1
% -----------------------------------------
decide(Animal, Decision, Explicacion) :-
    estado_caida(Animal, Estado, Evidencia),
    ( Estado == no_se_sabe ->
        Decision = informacion_insuficiente,
        Explicacion = Evidencia

    ; Estado == no_se_cumple ->
        Decision = sin_caida_registrada,
        Explicacion = Evidencia

    ; situacion(Animal, perdida_colectiva, Colectiva) ->
        Decision = revisar_perdida_colectiva,
        Explicacion = Colectiva

    ; situacion(Animal, posible_error_captura, Indicios) ->
        Decision = revisar_posible_error_captura,
        Explicacion = Indicios

    ;
        Decision = perdida_sin_causa_determinada,

        ( problemas_de_lote(Animal, Lote, Problemas),
          Problemas \== []
        ->
            Explicacion = [
                estado(pendiente_revision),
                problemas_companeros(Lote, Problemas)
                | Evidencia
            ]
        ;
            Explicacion = [
                estado(pendiente_revision)
                | Evidencia
            ]
        )
    ).


% -----------------------------------------
% PROPUESTA DE MOVIMIENTO DE LOTE
% -----------------------------------------

decide(Lote, mover_a(Destino, Ruta), E) :-
    situacion(
        Lote,
        ruta_pastoreo(Destino),
        E
    ),
    memberchk(ruta(Ruta), E).



% -----------------------------------------
% EVALUACION DE DESTINOS DE PASTOREO
% -----------------------------------------

% Motivos comprobados para descartar.

bloqueo_destino(L, P, origen_actual) :-
    ubicacion(L, P, _).

bloqueo_destino(L, P, ocupado_por(Otro)) :-
    ubicacion(Otro, P, _),
    Otro \== L.

bloqueo_destino(_, P, pasto_insuficiente) :-
    aptitud(P, pasto, insuficiente).

bloqueo_destino(_, P, agua_insuficiente) :-
    aptitud(P, agua, insuficiente).

bloqueo_destino(_, P, potrero_en_descanso) :-
    estado_potrero(P, descanso).

bloqueo_destino(_, P, restriccion_sanitaria) :-
    potrero_restringido(P).

bloqueo_destino(L, _, lote_restringido) :-
    lote_restringido(L).

bloqueo_destino(L, P, sin_ruta_segura) :-
    ubicacion(L, Origen, _),
    \+ ruta_segura(Origen, P, _).

% Datos que no estan registrados.
% Falta de dato NO significa insuficiencia.

falta_destino(P, pasto) :-
    \+ aptitud(P, pasto, _).

falta_destino(P, agua) :-
    \+ aptitud(P, agua, _).

falta_destino(P, estado_potrero) :-
    \+ estado_potrero(P, _).

% Tres estados posibles para un destino.


% -----------------------------------------
% EVALUACION DE DESTINOS DE PASTOREO
% -----------------------------------------
situacion(L, evaluacion_destino(P), E) :-
    once(lote(L, _)),
    potrero(P),

    % Identificar impedimentos.
    findall(
        B,
        bloqueo_destino(L, P, B),
        Bloqueos0
    ),
    sort(Bloqueos0, Bloqueos),

    % Identificar informacion faltante.
    findall(
        F,
        falta_destino(P, F),
        Faltantes0
    ),
    sort(Faltantes0, Faltantes),

    % Clasificacion propia de potreros.
    ( Bloqueos \== []
    ->
        Estado = no_apto

    ; Faltantes \== []
    ->
        Estado = no_se_sabe

    ;
        Estado = apto
    ),

    E = [
        bloqueos(Bloqueos),
        falta_verificar(Faltantes),
        estado(Estado)
    ].


% Explicar cuando no existe un destino
% completamente validado.

situacion(L, sin_destino_confirmado, E) :-
    once(lote(L, _)),

    findall(
        destino(P, Estado, Bloqueos, Faltantes),
        (
            potrero(P),
            situacion(L, evaluacion_destino(P), R),
            memberchk(estado(Estado), R),
            memberchk(bloqueos(Bloqueos), R),
            memberchk(falta_verificar(Faltantes), R)
        ),
        Revision
    ),

    \+ member(
        destino(_, apto, _, _),
        Revision
    ),

    ( member(destino(_, no_se_sabe, _, _), Revision)
    ->
        EstadoFinal = no_se_sabe
    ;
        EstadoFinal = no_apto
    ),

    E = [
        destinos_evaluados(Revision),
        estado(EstadoFinal)
    ].


% -----------------------------------------
% SITUACION 5 - REQUISITOS PENDIENTES
% -----------------------------------------
% Falta constancia de una campana
% correspondiente al escenario.
falta_salida(Lote, campana_sin_constancia(Animal, C)) :-
    lote(Lote, Animal),
    campana(C, DiaCampana),
    ahora(Actual),
    DiaCampana =< Actual,
    \+ (
        aplicacion(Animal, C, Dia),
        Dia >= DiaCampana,
        Dia =< Actual
    ).

% No existe una guia autorizada
% documentada y vigente en la simulacion.
falta_salida(Lote, guia_sin_autorizacion_verificada) :-
    once(lote(Lote, _)),
    \+ (
        evento(Lote, guia_transito, autorizada, Dia),
        ahora(Actual),
        Dia =< Actual
    ).

% Coincidencia de arete sin identidad
% confirmada entre dos registros.
falta_salida(Lote, identidad_pendiente(Animal, Otro)) :-
    lote(Lote, Animal),
    situacion(
        identidad(R1, R2),
        identidad_no_determinada,
        _
    ),
    (
        (Animal = R1, Otro = R2)
    ;
        (Animal = R2, Otro = R1)
    ).

% Historial de contacto insuficiente.
falta_salida(Lote, historial_contacto_no_verificado) :-
    situacion(Lote, contacto_no_determinable, _).

% -----------------------------------------
% EVALUACION DE SALIDA DEL LOTE
% -----------------------------------------
situacion(Lote, evaluacion_salida, E) :-
    once(lote(Lote, _)),

    findall(
        B,
        motivo_bloqueo(Lote, B),
        Bloqueos0
    ),
    sort(Bloqueos0, Bloqueos),

    findall(
        F,
        falta_salida(Lote, F),
        Faltantes0
    ),
    sort(Faltantes0, Faltantes),

    ( Bloqueos \== []
    ->
        Estado = no_puede_salir
    ; Faltantes \== []
    ->
        Estado = no_se_sabe
    ;
        Estado = puede_salir
    ),

    E = [
        impedimentos(Bloqueos),
        falta_verificar(Faltantes),
        estado(Estado)
    ].

% Consulta explicita de elegibilidad.
decide(Lote, salida(Estado), E) :-
    situacion(Lote, evaluacion_salida, E),
    memberchk(estado(Estado), E).


% -----------------------------------------
% ESTADOS DE AUTORIZACION DE SALIDA
% -----------------------------------------
% Existe al menos un impedimento.
estado_salida([_|_], _, no_puede_salir) :- !.

% No hay impedimentos, pero falta evidencia.
estado_salida([], [_|_], no_se_sabe) :- !.

% Todos los requisitos modelados cumplen.
estado_salida([], [], puede_salir).
