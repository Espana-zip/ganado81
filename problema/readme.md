# #81 — Gestión de ganado: el problema

## Contexto
Un rancho del noroeste maneja cientos de animales en agostaderos extensos y secos, donde la lluvia es poca y el pasto, el recurso mas escaso. Decidir a que potrero mover el hato, cuando vacunar y cuando vender depende de saber lo que le pasa a cada animal. Complementa el proyecto #4 con enfoque en gestion de hato.

## Datos del mundo real
- La **ganancia diaria de peso** de un becerro en pastoreo es de ~0.5-1.0 kg/dia; un becerro destetado a los ~7 meses pesa unos 180-220 kg. Una caida de peso entre pesajes indica enfermedad, sequia o robo.
- Cada animal se identifica con un arete oficial del **SINIIGA**; los movimientos entre predios requieren guia de transito y cumplir campañas sanitarias (brucelosis, tuberculosis, rabia paralitica bovina, entre otras) con calendario de vacunacion.
- El **coeficiente de agostadero** en zonas aridas del noroeste puede requerir muchas hectareas por unidad animal (decenas), por lo que el sobrepastoreo es un riesgo real y degrada el terreno por años.
- El **pastoreo rotacional** divide el predio en potreros y los usa por turnos para dar descanso al pasto; hay que decidir cuando mover el hato segun el pasto disponible y el agua.
- Se pesa en bascula en el corral, a veces cada mes o cada tres meses; los datos se capturan a mano, tarde o con errores.
- Un hato tiene categorias (becerros, vaquillas, vacas, toros) con necesidades y calendarios distintos.

## El problema
Llevar el registro individual y por lote de peso, salud, vacunas y tratamientos de cada animal, detectar a quienes no ganan peso o enferman, programar campañas sanitarias, y proponer rutas/rotaciones de pastoreo segun disponibilidad de pasto y agua en cada potrero, manteniendo la trazabilidad exigida para vender.

## Escenario a simular
- 400 animales, 8 potreros, pesajes mensuales, 3 campañas de vacunacion al año.
- Sequia que reduce el pasto de dos potreros en 50 %.
- Un lote con un brote sanitario que debe aislarse.

## Casos dificiles
- Arete perdido o animal duplicado en el registro.
- Pesaje con error de captura (un animal que "pierde" 100 kg).
- Mover un lote a un potrero con poca agua.

## Preguntas guia
1. ¿Cuando una variacion de peso es una alerta y cuando es ruido?
2. ¿Que informacion necesitas para decidir mover el hato de potrero?

## Que debes entregar (sin que aqui se de la solucion)
- Un diseño OTP explicado brevemente: procesos, supervisores y quien reinicia a quien, justificando cada decision frente a los casos dificiles de arriba.
- La simulacion del escenario descrito, con datos generados y fallas inyectadas.
- Una lista de supuestos propios y de las cifras de este documento que verificaste.
- Una prueba de caos: que mataste, que esperabas y que ocurrio.
- `rebar3 compile` y `rebar3 eunit` en verde; capturas de Stitch y de la app real si hay interfaz.

---
*Las cifras son de referencia (ordenes de magnitud). Verifica la fuente vigente antes de citarlas en tu entrega y anota las que uses en tu README.*
