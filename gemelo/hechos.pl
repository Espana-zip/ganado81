
:- module(hechos, [
    ahora/1,
    potrero/1,
    registro/3,
    lote/2,
    comparte_agua/2,
    campana/2,
    colinda/2,
    estado_potrero/2,
    ubicacion/3,
    aplicacion/3,
    aptitud/3,
    lectura/4,
    evento/4
]).
:- discontiguous evento/4.

% PROYECTO 81 - GEMELO DIGITAL
% Escenario ficticio para pruebas academicas.

% Dia actual de la simulacion.
ahora(60).
% Potreros existentes.
potrero(p1).
potrero(p2).
potrero(p3).
potrero(p4).

% Registros del ganado.
% registro(ID, Arete, Categoria).
registro(r01, 'DEMO-0001', becerro).
registro(r02, 'DEMO-0002', becerro).
registro(r03, 'DEMO-0003', vaquilla).
registro(r04, 'DEMO-0004', vaca).

registro(r05, 'DEMO-0005', toro).
registro(r06, 'DEMO-0006', vaca).
% Duplicado intencional para el escenario.
registro(r07, 'DEMO-0003', vaquilla).
registro(r08, 'DEMO-0008', becerro).

registro(r09, 'DEMO-0009', becerro).
% Animal con arete perdido.
registro(r10, sin_arete, vaca).
registro(r11, 'DEMO-0011', vaquilla).
registro(r12, 'DEMO-0012', toro).

% Pertenencia a lotes.
% lote(IDLote, IDRegistro).
lote(l1, r01).
lote(l1, r02).
lote(l1, r03).
lote(l1, r04).

lote(l2, r05).
lote(l2, r06).
lote(l2, r07).
lote(l2, r08).

lote(l3, r09).
lote(l3, r10).
lote(l3, r11).
lote(l3, r12).

% Ubicaciones simuladas desde el dia 0.
% ubicacion(Lote, Potrero, DiaDesde).
ubicacion(l1, p1, 0).
ubicacion(l2, p2, 0).
ubicacion(l3, p3, 0).


% Pesajes simulados del lote 1.
% lectura(Registro, Variable, Valor, Dia).
% Animal con una caida aparente de 100 kg.
lectura(r01, peso_kg, 220, 30).
lectura(r01, peso_kg, 120, 60).

% Otros animales del mismo lote.
lectura(r02, peso_kg, 205, 30).
lectura(r02, peso_kg, 208, 60).

lectura(r03, peso_kg, 240, 30).
lectura(r03, peso_kg, 242, 60).

lectura(r04, peso_kg, 350, 30).
lectura(r04, peso_kg, 353, 60).


% -----------------------------------------
% CASOS ESPECIALES DE PRUEBA
% Datos ficticios intencionales.
% -----------------------------------------
% r06: dos valores diferentes en el dia 60.
lectura(r06, peso_kg, 240, 30).
lectura(r06, peso_kg, 245, 60).
lectura(r06, peso_kg, 225, 60).

% r07: solamente un pesaje disponible.
lectura(r07, peso_kg, 230, 60).


% -----------------------------------------
% SITUACION 1 - CASO r08
% Perdida de peso con causa desconocida.
% Datos ficticios del escenario.
% -----------------------------------------
lectura(r08, peso_kg, 210, 30).
lectura(r08, peso_kg, 205, 60).


% SITUACION 1 - PERDIDA COLECTIVA
% Datos ficticios del lote 3.
lectura(r09, peso_kg, 210, 30).
lectura(r09, peso_kg, 205, 60).

lectura(r10, peso_kg, 310, 30).
lectura(r10, peso_kg, 306, 60).

lectura(r11, peso_kg, 260, 30).
lectura(r11, peso_kg, 254, 60).

lectura(r12, peso_kg, 400, 30).
lectura(r12, peso_kg, 397, 60).


% -----------------------------------------
% SITUACION 2 - ARETE PERDIDO
% Evento ficticio del rancho.
% -----------------------------------------
% evento(Sujeto, Tipo, Detalle, Dia).
evento(r10, arete_perdido, reporte_manual, 50).


% SITUACION 2 - VERIFICACION DE IDENTIDAD
% Evento ficticio de comprobacion presencial.
evento(
    identidad(r01, r02),
    verificacion_identidad,
    animales_distintos,
    55
).

% Verificacion de identidad simulada.
% Dos registros del mismo animal fisico.
evento(
    identidad(r05, r12),
    verificacion_identidad,
    mismo_animal,
    55
).


% -----------------------------------------
% SITUACION 3 - BROTE SANITARIO
% Datos ficticios del escenario.
% -----------------------------------------

% Brote confirmado dentro de la simulacion.
evento(
    r04,
    brote_sanitario,
    confirmado_en_escenario,
    50
).

% Conexion hidrica entre potreros.
comparte_agua(p1, p2).


% -----------------------------------------
% SITUACION 3 - CAMPANAS SANITARIAS
% Datos academicos ficticios.
% -----------------------------------------
% campana(Nombre, DiaProgramado).
campana(campana_demo, 40).

% aplicacion(Animal, Campana, Dia).
aplicacion(r05, campana_demo, 45).


% -----------------------------------------
% SITUACION 4 - SEQUIA Y PASTOREO
% Datos ficticios para la simulacion.
% -----------------------------------------
% Sequia: reduccion del pasto del 50%.
evento(p2, sequia, reduccion_pasto_pct(50), 55).
evento(p3, sequia, reduccion_pasto_pct(50), 55).

% Conexiones entre potreros.
colinda(p3, p2).
colinda(p2, p4).
colinda(p3, p4).

% Evaluacion de recursos del escenario.
aptitud(p2, pasto, insuficiente).
aptitud(p3, pasto, insuficiente).
aptitud(p4, pasto, suficiente).
aptitud(p4, agua, suficiente).

% Potrero disponible y sin descanso
% programado en este escenario.
estado_potrero(p4, disponible).
