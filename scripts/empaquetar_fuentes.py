"""Archivo reproducible de FUENTES, incluyendo cambios sin commit.

Excluye ejecutables, builds, toolchain, Git, claves y evidencias. No publica.
El argumento de salida es obligatorio y no se sobrescriben archivos.
"""
from pathlib import Path
import gzip
import hashlib
import io
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[1]
ALLOW = ["src", "test", "priv", "config", "scripts", "docs", "design", "deploy",
         "README.md", "rebar.config", "rebar.lock", ".gitignore"]


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Uso: python3 scripts/empaquetar_fuentes.py ARCHIVO.tar.gz")
    dest = Path(sys.argv[1])
    if dest.exists():
        raise SystemExit("La salida ya existe; no se sobrescribe.")
    files = []
    for name in ALLOW:
        p = ROOT / name
        if p.is_dir():
            files.extend(f for f in p.rglob("*") if f.is_file() or f.is_symlink())
        elif p.is_file():
            files.append(p)
    files.sort(key=lambda p: p.relative_to(ROOT).as_posix())
    for p in files:
        if p.is_symlink() or p.suffix in [".beam", ".so", ".pem", ".key", ".cast", ".pyc"] or p.name.startswith("id_"):
            raise SystemExit("Archivo no permitido en paquete: " + str(p.relative_to(ROOT)))
    payload = [(p.relative_to(ROOT).as_posix(), p.read_bytes(), p.stat().st_mode) for p in files]
    manifest = "".join(hashlib.sha256(data).hexdigest() + "  " + path + "\n" for path, data, _ in payload)
    payload.append(("MANIFEST.sha256", manifest.encode(), 0o644))
    dest.parent.mkdir(parents=True, exist_ok=True)
    with dest.open("xb") as output, gzip.GzipFile(fileobj=output, mode="wb", filename="", mtime=0) as gz:
        with tarfile.open(fileobj=gz, mode="w") as archive:
            for name, data, mode in payload:
                info = tarfile.TarInfo("ganado81/" + name)
                info.size = len(data)
                info.mode = 0o755 if mode & 0o111 else 0o644
                info.mtime = 0
                archive.addfile(info, io.BytesIO(data))
    print(hashlib.sha256(dest.read_bytes()).hexdigest() + "  " + str(dest))
    print(str(len(files)) + " archivos fuente; toolchain/builds/credenciales excluidos")


if __name__ == "__main__":
    main()
