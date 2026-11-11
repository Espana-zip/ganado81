# Publicar el repositorio y mantener el Gist existente

> Registro/procedimiento de preparación anterior a la publicación. El estado
> posterior está en [ESTADO_PUBLICACION.md](ESTADO_PUBLICACION.md). Las menciones
> a recursos pendientes describen la preparación, no el estado del remoto.

## Estado y separación del despliegue

El Gist **ya está publicado**:
https://gist.github.com/Espana-zip/33b8b0434dc3d1cb7d9dbff8e289fde7 .
Se verificó que contiene el manual y ambas evidencias. No es necesario crear
otro Gist para entregar el código completo.

El repositorio completo está preparado localmente, **sin `.git` propio y sin
remoto creado**. `Espana-zip/ganado81` es un destino propuesto, no una publicación
confirmada. No se incluye CI/CD, hook ni orden automática de despliegue.

Los pasos siguientes son para cuando el alumno **autorice expresamente** crear
el repositorio, hacer commit y publicar. No fueron ejecutados por el agente.
No utilizar contraseñas o tokens en las URL, comandos o documentos.

## 1. Copiar la entrega fuera del catálogo original

Desde la raíz del proyecto original, donde existe `entrega/ganado81/`:

```bash
# Solo después de autorizar estas operaciones locales.
ORIGEN="$PWD/entrega/ganado81"
DESTINO="$HOME/Proyectos/ganado81-publicacion"
test -f "$ORIGEN/README.md" || exit 1
test ! -e "$DESTINO" || { echo 'El destino ya existe: revisar, no sobrescribir.'; exit 1; }
mkdir -p "$HOME/Proyectos"
cp -a -- "$ORIGEN" "$DESTINO"
cd -- "$DESTINO"
python3 -B scripts/verificar_entrega.py
```

Si recibiste solo la carpeta del repositorio, colócala en un directorio nuevo
fuera del catálogo original y ejecuta allí el verificador. No vuelvas a anidarla
ni copies `.avh/` desde la estación de desarrollo.

## 2. Crear el repositorio local, revisar y hacer commit

**No ejecutar Git desde la raíz del catálogo original.** La copia de entrega
puede estar dentro de otro repositorio y heredar su contexto hasta inicializar
el suyo. Trabajar solo en el destino independiente del paso anterior:

```bash
# Solo después de autorizar git init/add/commit.
git init -b main
RAIZ=$(pwd -P)
test "$(git rev-parse --show-toplevel)" = "$RAIZ" || exit 1
git status --short --untracked-files=all
python3 -B scripts/verificar_entrega.py
git add -- README.md LICENSE .gitignore VERSION_FUENTES.json rebar.config rebar.lock src test priv scripts config deploy design problema docs
git diff --cached --stat
git diff --cached --name-only
git diff --cached --check
# Revisar los nombres y el contenido antes de confirmar:
git diff --cached
git commit -m "Entrega Ganado81: fuentes ARM64 validadas y configuración pública"
```

Usar la identidad Git propia ya configurada. Si falta, configurarla localmente
con los datos elegidos por el alumno, sin inventarlos ni alterar la configuración
global. Si se detectan archivos extraños o avisos de formato, detenerse y revisar;
no borrar archivos ajenos ni modificar fuentes validadas silenciosamente.

## 3. Crear el remoto en la cuenta Espana-zip

1. Iniciar sesión en https://github.com/new fuera de cualquier grabación.
2. Elegir propietario **Espana-zip** y un nombre libre, por ejemplo `ganado81`.
   Si ya existe, no reutilizarlo sin revisar su contenido ni sobrescribirlo.
3. Elegir conscientemente **Public** o **Private**. Para Private, dar acceso al
   profesor mediante los permisos de GitHub; no enviarle credenciales.
4. Crear el repositorio **vacío**, sin README/licencia/gitignore remotos, porque
   la copia local ya los contiene. Esta creación requiere la autorización pendiente.
5. Copiar su URL HTTPS real. La siguiente URL es solo la propuesta si ese nombre
   se creó correctamente; sustituirla si se eligió otro:

```bash
# Solo después de autorizar la publicación y crear el remoto vacío.
git remote -v
git remote add origin https://github.com/Espana-zip/ganado81.git
git ls-remote --heads origin
# Si muestra ramas existentes, detenerse y revisar. No usar --force.
git push -u origin main
```

Autenticar con los mecanismos normales de GitHub, sin pegar tokens en el chat
ni en comandos. No agregar claves privadas o configuración real de Corellium.
Si falla la autenticación, resolverla fuera de la grabación; no cambiar permisos
de aplicación ni del guest.

## 4. Verificar la publicación

- Abrir la URL real y revisar que estén `src/`, `test/`, `priv/`, `scripts/`,
  `deploy/`, `design/`, configuración pública, documentación y licencia.
- Verificar que el README renderice las tres capturas y enlace Asciinema/Drive.
- Revisar que no aparezcan `.avh/`, `.toolchain/`, `_build/`, grabaciones, logs,
  claves o snapshots privados. El ignore no elimina un secreto ya comprometido:
  si ocurre un incidente, detener publicación y revisar revocación/historial.
- No ejecutar `preparar`, `activar`, `rollback`, `servicio detener/reiniciar` ni
  `instalar.sh` como parte de publicar Git. Esas son operaciones distintas sobre AVH.

## 5. Actualizar el Gist que ya existe

Con autorización para editar el Gist, entrar al enlace actual y pulsar **Edit**.
Su archivo publicado se llama `proyecto 81.md`. No se modifica automáticamente
ni se cambia su visibilidad. Añadir el enlace al repositorio **solo después de
comprobar que fue publicado**, por ejemplo:

```markdown
## Código fuente completo

[Repositorio de Ganado81](URL_REAL_DEL_REPOSITORIO_PUBLICADO)

Incluye módulos OTP, pruebas, UI, scripts, configuración pública y licencia.
```

Sustituir el marcador por la URL comprobada; no guardar ese ejemplo literalmente.
Para imágenes en el Gist usar enlaces reales a los archivos del repositorio ya
publicado, nunca `file://`, rutas de Fedora o un remoto que aún no existe.
El Gist puede seguir como manual/resumen y el repositorio como código completo;
no es necesario copiar todos los archivos dentro del Markdown.

Si excepcionalmente se quisiera **otro** Gist, abrir https://gist.github.com/,
usar la descripción de `docs/gist/GIST_DESCRIPTION.txt`, nombrar el archivo
`README.md` y pegar una versión revisada. **Create secret gist** requiere una
decisión expresa: «Secret» es no listado, **no privado**, y cualquiera con el
enlace puede leerlo. En esta entrega se recomienda mantener el Gist existente.

## Por qué publicar no afecta Corellium

Git actúa sobre la copia de Fedora y GitHub. El servicio del guest usa su propia
versión compilada en `/home/pi/ganado81/actual`. Ninguno de los comandos Git
anteriores envía fuentes por SSH, cambia ese enlace ni ejecuta systemd. No hay
activación automática incluida. No mezclar esta publicación con un despliegue.
