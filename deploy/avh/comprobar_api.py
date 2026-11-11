"""Readiness del servicio. Se ejecuta solo en el guest, nunca arranca Erlang."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time
import urllib.request

p = argparse.ArgumentParser()
p.add_argument("--esperar", type=float, default=0)
args = p.parse_args()
deadline = time.monotonic() + args.esperar
last = "sin respuesta"
while True:
    try:
        pid = int(subprocess.check_output([
            "/usr/bin/systemctl", "show", "ganado81.service", "-p", "MainPID", "--value"
        ], text=True).strip())
        assert pid > 1, "sin MainPID"
        root = Path("/home/pi/ganado81/actual").resolve(strict=True)
        assert Path(os.readlink("/proc/%d/cwd" % pid)) == root, "MainPID no corresponde a la version activa"
        sockets = subprocess.check_output([
            "/usr/bin/ss", "-H", "-ltnp", "( sport = :8080 )"
        ], text=True).splitlines()
        assert len(sockets) == 1, "numero inesperado de listeners 8080"
        assert sockets[0].split()[3] == "127.0.0.1:8080", "bind no es loopback"
        assert re.search(r"pid=%d[,)]" % pid, sockets[0]), "listener de otra VM"
        with urllib.request.urlopen("http://127.0.0.1:8080/api/salud", timeout=2) as r:
            assert r.status == 200
            assert "application/json" in r.headers.get("Content-Type", "")
            data = json.load(r)
            assert data["ok"] is True
            assert data["datos"]["servicio"] == "p81_gestion_de_ganado"
        print("Ganado81 READY: MainPID=%d; version=%s; HTTP 200 JSON; solo loopback" % (pid, root.name))
        break
    except Exception as exc:
        last = str(exc)
        if time.monotonic() >= deadline:
            raise SystemExit("Ganado81 no esta listo: " + last)
        time.sleep(0.25)
