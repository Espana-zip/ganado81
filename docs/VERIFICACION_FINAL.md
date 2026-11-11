# Revisión final de la entrega y rúbrica

> Registro/procedimiento de preparación anterior a la publicación. El estado
> posterior está en [ESTADO_PUBLICACION.md](ESTADO_PUBLICACION.md). Las menciones
> a recursos pendientes describen la preparación, no el estado del remoto.

## Estado de recursos

- **Gist existente, accesible y comprobado:**
  https://gist.github.com/Espana-zip/33b8b0434dc3d1cb7d9dbff8e289fde7 .
  En su portada figura «Programación lógica y funcional»; se tomó ese dato de
  la publicación del alumno, no se inventó una confirmación institucional.
- **Repositorio independiente:** copia local completa preparada para `Espana-zip`.
  `ganado81` es un nombre propuesto; no se creó ni se confirmó un remoto nuevo.
- No se ejecutaron `git init`, `add`, `commit`, `push` o creación de recursos GitHub.
- No hubo conexión, compilación, prueba, reinicio o modificación en Corellium.
  El último estado remoto conservado no se interpreta como disponibilidad actual.

## Ocho criterios

«Cubierto» indica código/documentación y evidencia histórica identificables, no
una calificación garantizada ni una nueva certificación de ejecución.

| # | Criterio | Evidencia en esta entrega | Estado / límite |
|---|---|---|---|
| 1 | Solución funcional en Erlang | `src/`, reglas de peso/alerta, manual §§01–02/05/07 | Cubierto para el MVP; sin persistencia |
| 2 | Montaje en VM | `deploy/`, `scripts/corellium.sh`, manual §06, diagnóstico resumido | Montaje ARM64 histórico; disponibilidad actual no comprobada aquí |
| 3 | Demostración | Asciinema, Drive y resumen de alta 200→170 kg/15 % | Enlaces incluidos; cast retemporizado, video compartido sin sonido |
| 4 | UI/UX con Stitch | `design/`, `priv/static/`, adaptador, tres capturas del README | Responsive 1440/390 px probado anteriormente; no certificación WCAG |
| 5 | Manual en Gist | Gist ya publicado, copia de trabajo y manual raíz | Cubierto; el enlace al nuevo repositorio se añadirá solo después de publicarlo |
| 6 | Calidad técnica | Behaviours OTP, capas HTTP/API, validaciones, cuatro módulos EUnit, lock | 38 pruebas históricas; no compilación nueva de esta copia |
| 7 | Integración | `fetch`→Cowboy→API→worker, systemd y túnel | Código completo presente; solo Corellium ejecuta backend |
| 8 | Presentación/argumentación | Portada, arquitectura, decisiones, conclusiones y referencias | Ventajas y límites explícitos; licencia/atribución preservadas |

El escenario de 400 animales, campañas y rotación descrito en
`problema/readme.md` es el objetivo original, **no una simulación completa ya
implementada**. No se añade ni se certifica para mejorar artificialmente la rúbrica.

## Controles concretos

| Control | Comprobación |
|---|---|
| Misma fuente ARM64 | 46 archivos idénticos al paquete validado; hashes en `VERSION_FUENTES.json` |
| Código completo | Ocho módulos, `.app.src`, cuatro módulos EUnit, UI, scripts, configuración pública, deploy y diseño |
| Dependencias | Cowboy/recon declarados; Ranch/Cowlib fijados por lock; descarga/build a cargo de rebar3 en ARM64 |
| Evidencias en README | Ambos enlaces reales de Asciinema y Drive, más Stitch y Gist publicado |
| Inicio/parada AVH | `servicio iniciar`, `detener`, `reiniciar`, `estado`, `logs`; órdenes Fedora→SSH, no runtime local |
| Acceso | Túnel en 127.0.0.1:18080; Cowboy solo en loopback 8080 del guest |
| Privacidad | Sin configuración real SSH, cookies de distribución, claves, tokens, dumps, logs o snapshots internos |
| Configuración publicada | `vm.args` nuevo sin secretos; resto de configuración pública original; diferencia documentada |
| No compilados | Sin `.toolchain/`, `_build/`, `.beam`, NIF o binarios ejecutables; `.sh/.py/.escript` son fuentes |
| Capturas | Copias íntegras de UI/datos ficticios ya revisadas; no grabación de escritorio/login |
| Publicación | Pendiente para el repositorio; el Gist existente no se editó |

## Evidencias: interpretación correcta

- Asciinema https://asciinema.org/a/bYBtt76RnTkA6bHm : 180 s de lectura de
  evidencia histórica, no un ensayo nuevo. El original breve se conserva fuera
  de esta entrega; no se modificaron ni subieron grabaciones aquí.
- Drive https://drive.google.com/file/d/1dDCL5oyxCtOCQ8UJU8FjWtTI-1CIt2iS/view?usp=sharing :
  la descarga revisada coincide con la copia sin sonido, no con el MP4 narrado.
  Su original tenía voz sintética identificada; no se atribuye voz al alumno.
- Stitch respondió con la aplicación web genérica; el contenido remoto del
  proyecto no se inspeccionó. El export local es la fuente de diseño revisada.

## Pendientes antes de la entrega remota

1. Autorización de crear el repositorio remoto y de efectuar commit/push.
2. Confirmar nombre disponible, visibilidad y acceso del profesor.
3. Ejecutar y revisar el verificador offline sobre la copia exacta a publicar.
4. Después del push, abrir el repositorio real y revisar enlaces/capturas.
5. Con autorización, añadir esa URL real al Gist ya existente, sin duplicarlo.
6. Antes de una evaluación en vivo, comprobar disponibilidad de Corellium por
   separado. Publicar código no inicia, detiene ni actualiza el despliegue.
