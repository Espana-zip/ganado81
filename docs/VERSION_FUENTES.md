# Versión de fuentes y diferencias de la entrega pública

## Qué se conservó

La referencia es el paquete de fuentes **`v20261110T195311608517Z`**, validado en
Corellium Debian ARM64 con OTP 27.3.4.19 y rebar3 3.25.1. Sus registros históricos
reportan compilación 0, EUnit 0 y **38 pruebas sin fallos**. No se repitieron esas
operaciones para generar esta copia.

- SHA-256 del paquete de referencia:
  `2ac05548da10bff669f5f3aa879e006f28994ce5fe83abc3121430d8cfeb9af9`.
- SHA-256 de su manifest:
  `6d59085d047c617c7fd1d5a2daac9f35541747c8de5cf4ac6902f7156b4f10f4`.
- **46 archivos** coinciden byte por byte: 9 en `src/`, 4 en `test/`, 5 en
  `priv/`, 9 scripts originales, 7 en `deploy/`, 8 en `design/`, `rebar.config`,
  `rebar.lock`, `config/sys.config` y `config/avh.ssh.example`.
- Incluyen todos los módulos de aplicación y todos los grupos EUnit: no es una
  selección parcial de anexos ni una copia de `HEAD` que pierda archivos sin commit.
- `problema/readme.md`, la licencia MIT original y las tres capturas revisadas
  también se conservaron desde sus fuentes locales, sin presentarlos como parte
  de un paquete que no los incluía.

`VERSION_FUENTES.json` contiene los hashes verificables. No se copió el archivo
de despliegue de referencia: contenía configuración que no debe publicarse.

## Cambios deliberados, fuera del backend validado

| Ruta | Cambio público | Impacto |
|---|---|---|
| `config/vm.args` | Nueva plantilla sin cookie ni nombre de nodo | No es idéntica al archivo privado; no la usa el launcher systemd validado |
| `.gitignore` | Exclusiones de credenciales, cachés, builds y evidencias | No modifica la ejecución |
| `README.md`, `docs/` | Manual completo, enlace al Gist publicado, resumen público y matriz | Cambios documentales; no nuevas pruebas |
| `scripts/verificar_entrega.py` | Verificador offline de contenido/versiones y patrones sensibles | Herramienta nueva de revisión; no invoca Erlang, SSH ni Git |

Los originales y la instalación Corellium permanecieron intactos. No se afirma
que la plantilla de relx sea un release validado: el procedimiento operativo
sigue siendo **systemd + build ARM64**, no un release relx autónomo.

## Completitud de dependencias

- Están los ocho módulos Erlang, el descriptor `.app.src`, los cuatro módulos
  EUnit, las cinco piezas runtime de `priv/static/` y los launchers de `deploy/avh/`.
- Cowboy 2.12.0 y recon 2.5.6 están declarados; el lock fija además Ranch 1.8.0
  y Cowlib 2.13.0. **No se incluyen dependencias compiladas**: rebar3 las descarga
  y compila en ARM64 con acceso a sus repositorios.
- El servicio espera el usuario/rutas ARM64 documentados. Otro guest requiere
  provisionar las herramientas o revisar rutas con autorización, no copiar OTP de Fedora.
- SSH se configura de manera privada desde la plantilla de ejemplo. El checkout
  público no incluye la clave ni el archivo de acceso real.
- Los originales Stitch y su adaptador permiten rastrear las copias runtime;
  sus CDN de fuentes/Tailwind siguen siendo dependencias externas.

No falta un módulo o asset conocido del código validado. Esto es una comprobación
estática y de integridad, **no una compilación nueva ni garantía de red/servicio**.

El empaquetador original conserva su lista de fuentes para **transferencia de
build al guest**, no para publicar el repositorio entero. No incluye los nuevos
metadatos de raíz ni la licencia de raíz en ese tar interno. El verificador de
esta entrega se usa sobre el **checkout completo** preparado para Git, no sobre
ese candidato de despliegue. Para entregar/publicar todo, usar Git y conservar
`LICENSE`/`VERSION_FUENTES.json`, no distribuir el tar interno como si fuera el repo.

## Verificación antes de publicar

Desde la raíz de esta copia, incluso en Fedora:

```bash
python3 -B scripts/verificar_entrega.py
```

Comprueba hashes, archivos requeridos, referencias de módulos, sintaxis Python/
Bash y patrones de secretos. No crea `_build/`, no arranca Cowboy, no ejecuta
EUnit y no se conecta a Corellium. La revisión humana de documentos e imágenes
sigue siendo necesaria. Si falla por una fuente cambiada, no falsear sus hashes:
revisar el cambio y obtener una nueva validación ARM64 autorizada.

Los resultados exportados a `RESULTADOS_VERIFICADOS.json` son resúmenes públicos
de registros existentes. No contienen snapshots íntegros del hato ni logs del
proxy, y nunca se presentan como resultados producidos por este verificador.
