
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_json)).
:- use_module(library(apply)).

:- use_module('hechos.pl').
:- use_module('reglas.pl').
:- use_module('integracion.pl').

:- http_handler(
    root('api/decision'),
    api_decision,
    []
).

:- http_handler(
    root('api/lote'),
    api_lote,
    []
).

:- http_handler(
    root('grafica/pesajes'),
    api_grafica,
    []
).

:- http_handler(
    root('api/escenarios'),
    api_escenarios,
    []
).

:- http_handler(
    root(.),
    pagina_inicio,
    []
).

:- initialization(main, main).

main(_Argv) :-
    http_server(
        http_dispatch,
        [port(localhost:8081)]
    ),
    writeln('Gemelo digital: http://localhost:8081'),
    thread_get_message(_).


% -----------------------------------------
% CONSULTAR DECISION DE UN ANIMAL
% -----------------------------------------

api_decision(Request) :-
    http_parameters(
        Request,
        [animal(Animal, [atom])]
    ),

    ( registro(Animal, _, _),
      once(decide(Animal, Decision, Evidencia))
    ->
        term_string(Decision, Texto),
        maplist(term_string, Evidencia, Detalles),

        reply_json_dict(_{
            animal: Animal,
            decision: Texto,
            evidencia: Detalles
        })
    ;
        reply_json_dict(
            _{error:"Animal sin decision disponible"},
            [status(404)]
        )
    ).


% -----------------------------------------
% CONSULTAR RETENCION DE UN LOTE
% -----------------------------------------

api_lote(Request) :-
    http_parameters(
        Request,
        [lote(Lote, [atom])]
    ),

    ( memberchk(Lote, [l1, l2, l3]),
      once(decide(Lote, retener_lote, E))
    ->
        maplist(term_string, E, Detalles),

        reply_json_dict(_{
            lote: Lote,
            decision: "retener_lote",
            evidencia: Detalles
        })
    ;
        reply_json_dict(
            _{error:"Sin retencion registrada"},
            [status(404)]
        )
    ).


% -----------------------------------------
% GENERAR GRAFICA CON JANUS
% -----------------------------------------

api_grafica(Request) :-
    http_parameters(
        Request,
        [animal(Animal, [atom])]
    ),

    ( grafica_pesajes(Animal, SVG)
    ->
        format(
            'Content-type: image/svg+xml; charset=UTF-8~n~n~w',
            [SVG]
        )
    ;
        reply_json_dict(
            _{error:"No existen pesajes"},
            [status(404)]
        )
    ).


% -----------------------------------------
% PANEL PRINCIPAL
% -----------------------------------------
pagina_inicio(Request) :-
    http_reply_file(
        'gemelo/web/index.html',
        [unsafe(true)],
        Request
    ).

% -----------------------------------------
% API - CINCO ESCENARIOS
% -----------------------------------------
api_escenarios(_) :-
    findall(
        _{
            id: Id,
            nombre: Nombre,
            conclusion: Conclusion,
            evidencia: Textos
        },
        (
            escenario(Id, Nombre, Conclusion, E),
            maplist(term_string, E, Textos)
        ),
        Escenarios
    ),
    reply_json_dict(_{
        escenarios: Escenarios
    }).

% 1. Variaciones de peso.
escenario(1, "Variaciones de peso",
         "Revisar posible error de captura", E) :-
    once(situacion(
        r01, posible_error_captura, E
    )).

% 2. Identificacion.
escenario(2, "Identificacion de animales",
         "Identidad no determinada", E) :-
    once(situacion(
        identidad(r03, r07),
        identidad_no_determinada,
        E
    )).

% 3. Brote sanitario.
escenario(3, "Brote sanitario",
         "Aislar lote 2 por precaucion", E) :-
    once(decide(
        l2, aislar_por_precaucion, E
    )).

% 4. Movimiento interno de pastoreo.
escenario(4, "Rutas de pastoreo",
         "Proponer traslado a potrero 4", E) :-
    once(decide(
        l3, mover_a(p4, [p3, p4]), E
    )).

% 5. Salida del rancho.
escenario(5, "Salida del ganado",
         "Retener lote 3", E) :-
    once(decide(
        l3, retener_lote, E
    )).
