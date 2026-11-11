"""Control desde Fedora: solo Python/SSH. Toda ejecucion Erlang ocurre en AVH."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import re
import shlex
import socket
import stat
import subprocess
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / ".avh"
CONFIG = PRIVATE / "ssh-config"
SOCKET = PRIVATE / "t"
BASE = "/home/pi/ganado81"


def identifier(value):
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9._-]*", value) or value in (".", ".."):
        raise ValueError("Identificador de version no permitido")
    return value


def ssh_args():
    if not CONFIG.is_file():
        raise RuntimeError("Falta .avh/ssh-config. Ejecuta: proyecto.sh acceso --desde CONFIG_SSH_EXISTENTE")
    return ["ssh", "-F", str(CONFIG)]


def remote(script, data=None, capture=False):
    command = ssh_args() + ["avh-vm", "bash -c " + shlex.quote("set -euo pipefail\n" + script)]
    return subprocess.run(command, input=data, stdin=None if data is not None else subprocess.DEVNULL,
                          stdout=subprocess.PIPE if capture else None,
                          stderr=subprocess.PIPE if capture else None, check=True)


def validation_script(target, smoke=None):
    # Solo contiene comandos para ejecutarse por SSH en Debian ARM64.
    q = shlex.quote
    smoke = smoke or target + "/deploy/avh/smoke.escript"
    return f'''cd {q(target)}
test "$(uname -m)" = aarch64
sha256sum --check --status MANIFEST.sha256
mkdir -p evidencias
run="evidencias/validacion-$(date -u +%Y%m%dT%H%M%S%NZ)"
mkdir "$run"
run_stage() {{
  local stage=$1; shift
  set +e
  "$@" 2>&1 | tee "$run/$stage.log"
  local codes=("${{PIPESTATUS[@]}}")
  set -e
  printf '%s\\n' "${{codes[0]}}" > "$run/$stage.exit"
  printf '%s_EXIT=%s\\n' "$stage" "${{codes[0]}}"
  test "${{codes[0]}}" -eq 0
  test "${{codes[1]}}" -eq 0
}}
run_stage compile bash scripts/corellium.sh compile
run_stage eunit bash scripts/corellium.sh eunit
run_stage smoke env -u LD_LIBRARY_PATH -u ERL_LIBS -u ERL_FLAGS -u ERL_AFLAGS \
  "$HOME/.asdf/installs/erlang/27.3.4.19/bin/escript" {q(smoke)} --proyecto "$PWD"
python3 - "$run" <<'VALIDADO'
import hashlib,json,os,sys
from pathlib import Path
run=Path(sys.argv[1]);p=Path('evidencias/validacion-systemd.json')
if p.exists(): (run/'validacion-anterior.json').write_bytes(p.read_bytes())
value={{'arquitectura':'aarch64','compile_exit':0,'eunit_exit':0,'smoke_exit':0,
       'manifest_sha256':hashlib.sha256(Path('MANIFEST.sha256').read_bytes()).hexdigest(),
       'logs':str(run)}}
temp=run/'validacion.json';temp.write_text(json.dumps(value,indent=2));os.replace(str(temp),str(p))
print('VERSION_VALIDADA_ARM64: '+str(Path.cwd()))
VALIDADO
'''


def prepare():
    version = "v" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    out = ROOT / "_build" / "avh" / (version + ".tar.gz")
    subprocess.run([sys.executable, str(ROOT / "scripts/empaquetar_fuentes.py"), str(out)], check=True)
    digest = hashlib.sha256(out.read_bytes()).hexdigest()
    target = BASE + "/despliegues/" + version
    script = f'''umask 077
mkdir -p {BASE}/paquetes {BASE}/despliegues
set -o noclobber
cat > {BASE}/paquetes/{version}.tar.gz
printf '%s  %s\\n' {digest} {BASE}/paquetes/{version}.tar.gz | sha256sum --check
python3 - {BASE}/paquetes/{version}.tar.gz <<'ARCHIVO'
import sys,tarfile
from pathlib import PurePosixPath
with tarfile.open(sys.argv[1]) as t:
 for m in t.getmembers():
  p=PurePosixPath(m.name)
  assert m.isfile() and not p.is_absolute() and p.parts[0]=='ganado81' and '..' not in p.parts
ARCHIVO
mkdir {target}
tar -xzf {BASE}/paquetes/{version}.tar.gz --strip-components=1 --no-same-owner -C {target}
cd {target}
sha256sum --check --status MANIFEST.sha256
'''
    remote(script, out.read_bytes())
    remote(validation_script(target))
    metadata = {"version": version, "remote": target, "sha256": digest}
    PRIVATE.mkdir(mode=0o700, exist_ok=True)
    (PRIVATE / "ultima-preparacion.json").write_text(json.dumps(metadata, indent=2))
    print("PREPARADA (NO ACTIVADA): " + version)
    print("Activar requiere: ./scripts/proyecto.sh activar " + version + " --confirmar")


def tunnel(action):
    args = ssh_args()
    control = args + ["-S", str(SOCKET)]
    if action == "cerrar":
        subprocess.run(control + ["-O", "exit", "avh-vm"], check=True)
        print("Tunel cerrado; el servicio AVH no se ha detenido.")
        return
    check = subprocess.run(control + ["-O", "check", "avh-vm"], capture_output=True)
    if action == "estado":
        print((check.stdout + check.stderr).decode().strip())
        if check.returncode:
            raise RuntimeError("Tunel no activo; el estado de Cowboy debe consultarse por SSH.")
    elif action == "iniciar" and check.returncode:
        remote("curl --fail --max-time 5 --silent --show-error http://127.0.0.1:8080/api/salud")
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 18080))
        if len(str(SOCKET).encode()) > 100:
            raise RuntimeError("Ruta demasiado larga para el socket de control SSH.")
        if SOCKET.exists():
            if not stat.S_ISSOCK(SOCKET.lstat().st_mode):
                raise RuntimeError("El archivo de control existente no es un socket; no se modifica.")
            stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
            SOCKET.rename(PRIVATE / ("socket-caducado-" + stamp))
        subprocess.run(args + ["-M", "-S", str(SOCKET), "-f", "-N", "-T",
            "-o", "ExitOnForwardFailure=yes", "-o", "ServerAliveInterval=30",
            "-o", "ServerAliveCountMax=3", "-L", "127.0.0.1:18080:127.0.0.1:8080", "avh-vm"], check=True)
    with urllib.request.urlopen("http://127.0.0.1:18080/api/salud", timeout=8) as r:
        data = json.load(r)
        assert r.status == 200 and data["ok"] and data["datos"]["servicio"] == "p81_gestion_de_ganado"
    print("Tunel y API OK: http://127.0.0.1:18080 (solo loopback)")


def main():
    p = argparse.ArgumentParser(description="Ganado81: Fedora controla por SSH; Erlang se ejecuta solo en AVH.")
    sub = p.add_subparsers(dest="command", required=True)
    access = sub.add_parser("acceso"); access.add_argument("--desde", required=True)
    for cmd in ["diagnostico", "compile", "eunit", "preparar", "servidor"]: sub.add_parser(cmd)
    service = sub.add_parser("servicio")
    service.add_argument("action", choices=["estado", "iniciar", "detener", "reiniciar", "logs"])
    service.add_argument("--seguir", action="store_true")
    t = sub.add_parser("tunel"); t.add_argument("action", choices=["iniciar", "cerrar", "estado"])
    a = sub.add_parser("activar"); a.add_argument("version", type=identifier); a.add_argument("--confirmar", action="store_true", required=True)
    rb = sub.add_parser("rollback"); rb.add_argument("--confirmar", action="store_true", required=True)
    args = p.parse_args()
    if args.command == "acceso":
        data = Path(args.desde).read_bytes()
        if b"PRIVATE KEY" in data: raise RuntimeError("Se espera configuracion SSH, nunca una clave privada.")
        PRIVATE.mkdir(mode=0o700, exist_ok=True)
        if CONFIG.exists():
            if CONFIG.read_bytes() != data: raise RuntimeError("Ya existe una configuracion diferente; no se sobrescribe.")
        else:
            fd = os.open(CONFIG, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "wb") as f: f.write(data)
        print("Acceso local guardado en .avh/ssh-config (ignorado por Git).")
    elif args.command in ["compile", "eunit", "diagnostico"]:
        remote('cd "$(readlink -e /home/pi/ganado81/actual)"\nexec bash scripts/corellium.sh ' + args.command)
    elif args.command == "preparar": prepare()
    elif args.command == "tunel": tunnel(args.action)
    elif args.command in ["activar", "rollback"]:
        suffix = ("activar " + shlex.quote(args.version)) if args.command == "activar" else "rollback"
        remote("exec bash /home/pi/ganado81/bin/activar.sh " + suffix + " --confirmar")
    else:
        action = "iniciar" if args.command == "servidor" else args.action
        if action == "logs":
            remote("exec journalctl -u ganado81.service " + ("-f" if args.seguir else "-n 100 --no-pager"))
        elif action == "estado":
            remote("systemctl status ganado81.service --no-pager\n/usr/bin/python3 /home/pi/ganado81/bin/comprobar_api.py")
        else:
            name = {"iniciar": "start", "detener": "stop", "reiniciar": "restart"}[action]
            remote("exec 9>/home/pi/ganado81/estado/operacion.lock\nflock -n 9\nsudo -n systemctl " + name + " ganado81.service\nsystemctl show ganado81.service -p ActiveState -p SubState -p MainPID")


if __name__ == "__main__":
    try: main()
    except (Exception, KeyboardInterrupt) as exc:
        print("Ganado81 AVH: " + str(exc), file=sys.stderr)
        sys.exit(1)
