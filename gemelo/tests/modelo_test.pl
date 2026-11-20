
:- begin_tests(modelo).

:- use_module('../hechos.pl').

test(doce_registros) :-
    findall(R, registro(R, _, _), Registros),
    length(Registros, 12).

test(tres_lotes) :-
    setof(L, R^lote(L, R), Lotes),
    length(Lotes, 3).

test(cuatro_potreros) :-
    findall(P, potrero(P), Potreros),
    length(Potreros, 4).

test(registros_en_un_solo_lote) :-
    forall(
        registro(R, _, _),
        (
            findall(L, lote(L, R), Lotes),
            length(Lotes, 1)
        )
    ).

test(ubicaciones_validas) :-
    forall(
        ubicacion(_, P, _),
        potrero(P)
    ).


test(pesajes_lote_1) :-
    forall(
        lote(l1, R),
        (
            lectura(R, peso_kg, _, 30),
            lectura(R, peso_kg, _, 60)
        )
    ).

test(caida_simulada_100kg) :-
    lectura(r01, peso_kg, P1, 30),
    lectura(r01, peso_kg, P2, 60),
    P1 - P2 =:= 100.

:- end_tests(modelo).
