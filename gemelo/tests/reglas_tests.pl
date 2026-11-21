
:- begin_tests(reglas_peso).

:- use_module('../reglas.pl').
:- use_module('../hechos.pl').

% Debe detectar un indicio de posible error.
test(posible_error_captura_r01, [nondet]) :-
    situacion(r01, posible_error_captura, Evidencia),
    member(perdida_kg(100), Evidencia),
    member(estado(pendiente_confirmacion), Evidencia),
    member(
        comparacion_lote(l1, [
            companero(r02, 205, 208),
            companero(r03, 240, 242),
            companero(r04, 350, 353)
        ]),
        Evidencia
    ).

% No debe clasificar como perdida un aumento.
test(sin_indicio_en_r02, [fail]) :-
    situacion(r02, posible_error_captura, _).


% Verificar los tres estados logicos.
test(caida_r01_se_cumple) :-
    estado_caida(r01, se_cumple, Evidencia),
    memberchk(perdida_kg(100), Evidencia).

test(caida_r02_no_se_cumple) :-
    estado_caida(r02, no_se_cumple, Evidencia),
    memberchk(
        ganancia_o_estabilidad_kg(3),
        Evidencia
    ).

test(caida_r05_no_se_sabe) :-
    estado_caida(r05, no_se_sabe, Evidencia),
    memberchk(
        historial_insuficiente_o_ambiguo(r05),
        Evidencia
    ).

% Verificar decisiones explicadas.
test(decision_r01) :-
    decide(r01, revisar_posible_error_captura, E),
    memberchk(
        estado(pendiente_confirmacion),
        E
    ).

test(decision_r05) :-
    decide(r05, informacion_insuficiente, _).


% Situacion con datos contradictorios.
test(pesajes_contradictorios_r06) :-
    estado_caida(r06, no_se_sabe, Evidencia),
    memberchk(
        lecturas_contradictorias(r06, 60),
        Evidencia
    ).

% Situacion con una sola medicion.
test(historial_incompleto_r07) :-
    estado_caida(r07, no_se_sabe, Evidencia),
    memberchk(
        historial_incompleto(r07),
        Evidencia
    ).


% Un animal presenta perdida de peso,
% pero faltan datos de sus companeros.
test(caida_r08_se_cumple) :-
    estado_caida(r08, se_cumple, Evidencia),
    memberchk(perdida_kg(5), Evidencia).

% No debe atribuirse un error de captura
% cuando no existe evidencia suficiente.
test(decision_r08_sin_causa_determinada) :-
    decide(r08, perdida_sin_causa_determinada,
           Explicacion),
    memberchk(estado(pendiente_revision),
              Explicacion),
    memberchk(perdida_kg(5), Explicacion).

% Identificar una perdida colectiva del lote 3.
test(perdida_colectiva_lote3) :-
    situacion(r09, perdida_colectiva, Evidencia),
    memberchk(perdida_kg(5), Evidencia),
    memberchk(
        comparacion_lote(l3, [
            companero(r10, 310, 306),
            companero(r11, 260, 254),
            companero(r12, 400, 397)
        ]),
        Evidencia
    ).

% La decision debe reflejar el patron
% colectivo y solicitar una revision.
test(decision_perdida_colectiva) :-
    decide(r09, revisar_perdida_colectiva,
           Explicacion),
    memberchk(
        estado(pendiente_revision),
        Explicacion
    ).


% La decision debe identificar los problemas
% de los companeros del lote.
test(r08_explica_datos_faltantes) :-
    decide(r08,
           perdida_sin_causa_determinada,
           Explicacion),

    memberchk(
        problemas_companeros(l2, [
            sin_pesajes(r05),
            lecturas_contradictorias(r06, 60),
            historial_incompleto(r07)
        ]),
        Explicacion
    ).


% -----------------------------------------
% SITUACION 2 - IDENTIFICACION
% -----------------------------------------
% Dos registros con el mismo arete
% no confirman por si solos la identidad.
test(duplicado_pendiente_confirmacion) :-
    registro(r03, Arete, _),
    registro(r07, Arete, _),

    once(
        situacion(
            identidad(r03, r07),
            identidad_no_determinada,
            Evidencia
        )
    ),

    memberchk(
        arete_compartido('DEMO-0003'),
        Evidencia
    ),

    memberchk(
        estado(pendiente_verificacion),
        Evidencia
    ).

% Compartir arete no es suficiente
% para afirmar que son el mismo animal.
test(duplicado_no_confirma_identidad, [fail]) :-
    situacion(
        identidad(r03, r07),
        mismo_animal,
        _
    ).


% Buscar todos los pares con aretes compartidos.
% No deben aparecer pares consigo mismos
% ni la misma pareja en orden inverso.
test(pares_identidad_sin_duplicados) :-
    findall(
        R1-R2,
        situacion(
            identidad(R1, R2),
            identidad_no_determinada,
            _
        ),
        Pares
    ),
    assertion(Pares == [r03-r07]).


% -----------------------------------------
% SITUACION 2 - ARETE PERDIDO
% -----------------------------------------
% Detectar un arete ausente con un evento
% de perdida registrado.
test(arete_perdido_r10) :-
    once(
        situacion(
            r10,
            arete_perdido,
            Evidencia
        )
    ),
    memberchk(
        arete(sin_arete),
        Evidencia
    ),
    memberchk(
        evento_arete_perdido(50),
        Evidencia
    ),
    memberchk(
        estado(pendiente_verificacion),
        Evidencia
    ).

% Un animal con su arete registrado
% no debe clasificarse como arete perdido.
test(arete_conservado_r09, [fail]) :-
    situacion(
        r09,
        arete_perdido,
        _
    ).


% Dos registros verificados presencialmente
% corresponden a animales distintos.
test(identidad_distinta_confirmada) :-
    once(
        situacion(
            identidad(r01, r02),
            animales_distintos,
            Evidencia
        )
    ),

    memberchk(
        verificacion_presencial(55),
        Evidencia
    ),

    memberchk(
        estado(confirmado),
        Evidencia
    ).


test(identidad_mismo_animal_confirmada) :-
    once(
        situacion(
            identidad(r05, r12),
            mismo_animal,
            Evidencia
        )
    ),
    memberchk(verificacion_presencial(55), Evidencia),
    memberchk(estado(confirmado), Evidencia).

:- end_tests(reglas_peso).


:- begin_tests(brote).
:- use_module('../reglas.pl').
test(brote_documentado_l1) :-
    once(situacion(l1, brote_documentado, E)),
    memberchk(foco(r04), E),
    memberchk(brote_dia(50), E).

test(exposicion_l2_por_agua) :-
    once(situacion(l2, exposicion_por_agua, E)),
    memberchk(conexion_agua(p1, p2), E),
    memberchk(estado(precaucion), E).

test(sin_evidencia_agua_l3, [fail]) :-
    situacion(l3, exposicion_por_agua, _).

test(decision_aislamiento_l1) :-
    once(decide(l1, aislar_por_brote, E)),
    memberchk(foco(r04), E).

test(decision_precaucion_l2) :-
    once(decide(l2, aislar_por_precaucion, E)),
    memberchk(estado(precaucion), E).


% -----------------------------------------
% PRUEBAS - CAMPANAS SANITARIAS
% -----------------------------------------
test(campana_registrada_r05) :-
    once(situacion(
        r05,
        campana_registrada(campana_demo),
        E
    )),
    memberchk(aplicacion_fecha(45), E),
    memberchk(estado(registrada), E).

test(campana_desconocida_r06) :-
    once(situacion(
        r06,
        campana_sin_dato(campana_demo),
        E
    )),
    memberchk(estado(no_se_sabe), E).

test(r05_no_tiene_dato_faltante, [fail]) :-
    situacion(
        r05,
        campana_sin_dato(campana_demo),
        _
    ).

test(lote2_requiere_revision_vacunacion) :-
    once(situacion(
        l2,
        revision_vacunacion(campana_demo),
        E
    )),
    memberchk(
        animales_sin_constancia([r06, r07, r08]),
        E
    ).

% -----------------------------------------
% PRUEBAS - BROTE HIPOTETICO
% -----------------------------------------
test(hipotesis_brote_potrero3) :-
    once(situacion(
        l3,
        brote_hipotetico(p3),
        E
    )),
    memberchk(
        estado(aislamiento_hipotetico),
        E
    ).

test(hipotesis_no_es_brote_confirmado, [fail]) :-
    situacion(l3, brote_documentado, _).

:- end_tests(brote).



:- begin_tests(sequia).

:- use_module('../reglas.pl').

% La sequia afecta al potrero del lote 3.
test(sequia_documentada_l3) :-
    once(situacion(l3, sequia_potrero, E)),
    memberchk(potrero(p3), E),
    memberchk(reduccion_pasto_pct(50), E).

% Existe una ruta directa segura a p4.
test(destino_p4_l3) :-
    once(situacion(
        l3,
        ruta_pastoreo(p4),
        E
    )),
    memberchk(ruta([p3, p4]), E).

% Prolog propone el traslado del lote.
test(decision_mover_l3) :-
    once(decide(
        l3,
        mover_a(p4, [p3, p4]),
        E
    )),
    memberchk(
        estado(pendiente_autorizacion),
        E
    ).

% No proponer un potrero ocupado
% y sanitariamente restringido.
test(potrero2_no_elegible, [fail]) :-
    situacion(l3, ruta_pastoreo(p2), _).

% El lote con brote no puede trasladarse.
test(lote1_no_mover, [fail]) :-
    decide(l1, mover_a(_, _), _).

% El lote bajo precaucion tampoco.
test(lote2_no_mover, [fail]) :-
    decide(l2, mover_a(_, _), _).

:- end_tests(sequia).


:- begin_tests(salida).

:- use_module('../reglas.pl').

test(lote3_arete_faltante) :-
    once(situacion(
        l3,
        impedimento_salida,
        [motivo(arete_faltante(r10)),
         estado(no_puede_salir)]
    )).

test(lote1_brote_documentado) :-
    once(situacion(
        l1,
        impedimento_salida,
        [motivo(brote_documentado),
         estado(no_puede_salir)]
    )).

test(lote2_exposicion_sanitaria) :-
    once(situacion(
        l2,
        impedimento_salida,
        [motivo(exposicion_por_agua),
         estado(no_puede_salir)]
    )).

test(decision_retener_lote3) :-
    once(decide(l3, retener_lote, E)),
    memberchk(impedimentos(Motivos), E),
    memberchk(arete_faltante(r10), Motivos).

test(decision_retener_lote1) :-
    once(decide(l1, retener_lote, E)),
    memberchk(impedimentos(Motivos), E),
    memberchk(brote_documentado, Motivos).

:- end_tests(salida).



:- begin_tests(exposicion_temporal).

:- use_module('../reglas.pl').

test(cadena_del_foco_al_lote2) :-
    once(situacion(l2, cadena_exposicion, E)),
    memberchk(
        cadena([
            foco(r04),
            lote(l1),
            potrero(p1),
            agua_compartida(p1, p2),
            lote(l2)
        ]),
        E
    ).

test(animales_expuestos_lote2) :-
    once(situacion(l2, cadena_exposicion, E)),
    memberchk(
        animales_expuestos([r05,r06,r07,r08]),
        E
    ).

test(campanas_en_cadena) :-
    once(situacion(l2, cadena_exposicion, E)),
    memberchk(
        estado_campanas([
            estado_campana(r05, registrada),
            estado_campana(r06, sin_constancia),
            estado_campana(r07, sin_constancia),
            estado_campana(r08, sin_constancia)
        ]),
        E
    ).

test(historial_desconocido_lote3) :-
    once(situacion(
        l3,
        contacto_no_determinable,
        E
    )),
    memberchk(estado(no_se_sabe), E).

test(decision_lote2_con_cadena) :-
    once(decide(l2, aislar_por_precaucion, E)),
    memberchk(
        animales_expuestos([r05,r06,r07,r08]),
        E
    ).

:- end_tests(exposicion_temporal).



:- begin_tests(evaluacion_potreros).

:- use_module('../reglas.pl').

test(p2_descartado_por_pasto_y_ocupacion) :-
    once(situacion(l3, evaluacion_destino(p2), E)),
    memberchk(estado(no_apto), E),
    memberchk(bloqueos(B), E),
    memberchk(pasto_insuficiente, B),
    memberchk(ocupado_por(l2), B).

test(p2_agua_sin_verificar) :-
    once(situacion(l3, evaluacion_destino(p2), E)),
    memberchk(falta_verificar(F), E),
    memberchk(agua, F).

test(p4_destino_apto) :-
    once(situacion(l3, evaluacion_destino(p4), E)),
    memberchk(estado(apto), E),
    memberchk(bloqueos([]), E),
    memberchk(falta_verificar([]), E).

test(l1_sin_destino_confirmado) :-
    once(situacion(l1, sin_destino_confirmado, E)),
    memberchk(estado(no_apto), E).

test(l3_tiene_destino, [fail]) :-
    situacion(l3, sin_destino_confirmado, _).

:- end_tests(evaluacion_potreros).


:- begin_tests(elegibilidad_salida).
:- use_module('../reglas.pl').

test(l3_retenido_por_arete) :-
    once(situacion(l3, evaluacion_salida, E)),
    memberchk(estado(no_puede_salir), E),
    memberchk(impedimentos(B), E),
    memberchk(arete_faltante(r10), B).

test(l3_guia_sin_autorizacion) :-
    once(situacion(l3, evaluacion_salida, E)),
    memberchk(falta_verificar(F), E),
    memberchk(
        guia_sin_autorizacion_verificada,
        F
    ).

test(l2_campana_pendiente) :-
    once(situacion(l2, evaluacion_salida, E)),
    memberchk(falta_verificar(F), E),
    memberchk(
        campana_sin_constancia(r06, campana_demo),
        F
    ).

test(l2_identidad_pendiente) :-
    once(situacion(l2, evaluacion_salida, E)),
    memberchk(falta_verificar(F), E),
    memberchk(
        identidad_pendiente(r07, r03),
        F
    ).

test(l3_contacto_sin_historial) :-
    once(situacion(l3, evaluacion_salida, E)),
    memberchk(falta_verificar(F), E),
    memberchk(
        historial_contacto_no_verificado,
        F
    ).

test(decision_salida_l3) :-
    once(decide(l3, salida(no_puede_salir), E)),
    memberchk(estado(no_puede_salir), E).

:- end_tests(elegibilidad_salida).


:- begin_tests(estados_salida).
:- use_module('../reglas.pl').

test(salida_bloqueada) :-
    estado_salida(
        [arete_faltante(r10)],
        [guia_sin_autorizacion_verificada],
        no_puede_salir
    ).

test(salida_desconocida) :-
    estado_salida(
        [],
        [guia_sin_autorizacion_verificada],
        no_se_sabe
    ).

test(salida_con_requisitos_completos) :-
    estado_salida(
        [],
        [],
        puede_salir
    ).

test(lote3_continua_retenido) :-
    once(
        decide(
            l3,
            salida(no_puede_salir),
            _
        )
    ).

:- end_tests(estados_salida).
