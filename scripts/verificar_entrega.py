"""Auditoria offline de la entrega publica; no ejecuta Erlang, SSH ni Git.

Comprueba fuentes validadas, configuracion publica, rutas necesarias y patrones
de secretos. No sustituye una auditoria humana ni una nueva ejecucion ARM64.
"""
from pathlib import Path
import ast
import hashlib
import json
import os
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_DIRS = {'.avh', '.ssh', '.toolchain', '_build', 'evidencias', '__pycache__', 'estado'}
FORBIDDEN_SUFFIXES = {'.beam', '.so', '.dll', '.dylib', '.exe', '.o', '.a', '.pyc', '.pem', '.key', '.p12', '.pfx', '.log', '.cast', '.mp4', '.webm', '.zip', '.gz'}
PATTERNS = {
    'clave_privada': r'-----BEGIN [A-Z ]*PRIVATE KEY-----',
    'token': r'gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]+|AKIA[A-Z0-9]{16}',
    'ip_privada': r'\b(?:10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(?:1[6-9]|2\d|3[01])\.\d+\.\d+)\b',
    'identificador_conexion': r'(?i)\b[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}\b',
    'enlace_asociacion_privado': r'https://asciinema\.org/connect/[A-Za-z0-9_-]+',
    'cookie_distribucion': r'(?m)^\s*-setcookie\s+',
}


def ensure(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    version = json.loads((ROOT / 'VERSION_FUENTES.json').read_text())
    expected = version['validated_file_sha256']
    for relative, digest in expected.items():
        p = ROOT / relative
        ensure(p.is_file() and not p.is_symlink(), 'Falta fuente: ' + relative)
        ensure(hashlib.sha256(p.read_bytes()).hexdigest() == digest, 'Fuente modificada frente a version ARM64: ' + relative)
    checked = 0
    for directory, dirs, names in os.walk(ROOT, followlinks=False):
        if '.git' in dirs:
            dirs.remove('.git')  # Metadatos Git locales, no archivos de entrega.
        for name in dirs:
            p = Path(directory) / name
            ensure(not p.is_symlink(), 'Directorio symlink: ' + str(p.relative_to(ROOT)))
            ensure(name not in FORBIDDEN_DIRS, 'Directorio privado/local presente: ' + str(p.relative_to(ROOT)))
        for name in names:
            p = Path(directory) / name
            rel = p.relative_to(ROOT).as_posix()
            ensure(not p.is_symlink(), 'Archivo symlink: ' + rel)
            ensure(p.suffix.lower() not in FORBIDDEN_SUFFIXES, 'Artefacto/credencial no permitida: ' + rel)
            ensure(name not in {'known_hosts', 'authorized_keys', '.env', 'ssh-config'}, 'Archivo privado: ' + rel)
            ensure(not name.startswith(('id_rsa', 'id_ed25519')), 'Posible clave SSH: ' + rel)
            data = p.read_bytes()
            ensure(not data.startswith((b'\x7fELF', b'MZ')), 'Ejecutable compilado: ' + rel)
            if p.suffix.lower() == '.png':
                ensure(rel.startswith(('design/', 'docs/gist/capturas/')), 'Imagen fuera de assets revisados: ' + rel)
                ensure(data.startswith(b'\x89PNG\r\n\x1a\n'), 'PNG invalido: ' + rel)
            else:
                text = data.decode('utf-8')
                ensure('\0' not in text, 'Binario no permitido: ' + rel)
                for label, pattern in PATTERNS.items():
                    ensure(re.search(pattern, text) is None, 'Patron sensible (' + label + ') en ' + rel)
                if p.suffix == '.py':
                    ast.parse(text, filename=rel)
                if p.suffix == '.sh':
                    r = subprocess.run(['bash', '-n', str(p)], capture_output=True)
                    ensure(r.returncode == 0, 'Sintaxis Bash incorrecta: ' + rel)
            checked += 1
    args = (ROOT / 'config/vm.args').read_text()
    ensure(not re.search(r'(?m)^\s*-(?:name|sname|setcookie)\s+', args), 'vm.args habilita distribucion o incluye una cookie')
    ensure(hashlib.sha256((ROOT / 'config/vm.args').read_bytes()).hexdigest() == version['public_vm_args_sha256'], 'Plantilla publica vm.args modificada; revisar antes de publicar')
    required = [
        'README.md', 'LICENSE', '.gitignore', 'rebar.config', 'rebar.lock',
        'config/sys.config', 'config/vm.args', 'config/avh.ssh.example',
        'priv/static/app.js', 'priv/static/app.css', 'priv/static/panel_general.html',
        'priv/static/ficha_de_animal.html', 'priv/static/historial_y_alertas.html',
        'deploy/systemd/ganado81.service', 'deploy/avh/arrancar.sh', 'deploy/avh/parar.sh',
        'deploy/avh/comprobar_api.py', 'deploy/avh/activar.sh', 'deploy/avh/instalar.sh',
        'deploy/avh/smoke.escript', 'scripts/proyecto.sh', 'scripts/avh.py',
        'scripts/corellium.sh', 'scripts/empaquetar_fuentes.py',
    ]
    for rel in required:
        ensure((ROOT / rel).is_file(), 'Dependencia/archivo necesario ausente: ' + rel)
    ensure(os.access(ROOT / 'scripts/proyecto.sh', os.X_OK), 'Falta permiso de ejecucion de proyecto.sh')
    modules = {p.stem for p in (ROOT / 'src').glob('*.erl')}
    for p in [*(ROOT / 'src').glob('*.erl'), *(ROOT / 'test').glob('*.erl')]:
        for callee in re.findall(r'\b(p81_gestion_de_ganado(?:_[a-z0-9_]+)?):', p.read_text()):
            ensure(callee in modules, 'Modulo del proyecto no entregado: ' + callee)
    readme = (ROOT / 'README.md').read_text()
    for value in ['https://asciinema.org/a/bYBtt76RnTkA6bHm', 'https://drive.google.com/file/d/1dDCL5oyxCtOCQ8UJU8FjWtTI-1CIt2iS/view?usp=sharing', 'https://gist.github.com/Espana-zip/33b8b0434dc3d1cb7d9dbff8e289fde7', './scripts/proyecto.sh servicio iniciar', './scripts/proyecto.sh servicio detener']:
        ensure(value in readme, 'Falta comando/enlace requerido en README')
    print(json.dumps({
        'ok': True, 'tipo': 'auditoria estatica offline; no compilacion ni EUnit',
        'fuentes_iguales_a_version_validada': len(expected),
        'archivos_revisados': checked, 'modulos_aplicacion': len(modules),
        'modulos_eunit': len(list((ROOT / 'test').glob('*.erl'))),
        'dependencias_cowboy_y_recon': 'fijadas en rebar.config/rebar.lock; las resuelve rebar3 en ARM64',
        'secretos_por_patrones': 'sin hallazgos; requiere revision humana antes de publicar',
        'corellium_modificado': False, 'git_ejecutado': False,
    }, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print('VERIFICACION_FALLIDA: ' + str(exc), file=sys.stderr)
        sys.exit(1)
