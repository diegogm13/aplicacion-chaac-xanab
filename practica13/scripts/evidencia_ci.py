"""Prácticas 13-14 — descarga la evidencia de GitHub Actions con `gh` y la guarda en
practica13/resultados/ci.json (corridas, pasos, duraciones y resumen de pruebas).
Uso (desde chaac_xanab_app):  python practica13/scripts/evidencia_ci.py
"""
import json
import re
import subprocess
from datetime import datetime

REPOS = {"app": "diegogm13/aplicacion-chaac-xanab", "backend": "diegogm13/backend-chaac-xanab"}


def gh(*args):
    r = subprocess.run(["gh", *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    return r.stdout


def seg(a, b):
    if not a or not b:
        return None
    f = lambda s: datetime.fromisoformat(s.replace("Z", "+00:00"))
    return round((f(b) - f(a)).total_seconds(), 1)


salida = {}
for clave, repo in REPOS.items():
    corridas = json.loads(gh("run", "list", "--repo", repo, "--branch", "practica13", "--limit", "20", "--json",
                             "databaseId,displayTitle,event,conclusion,status,createdAt,updatedAt,headSha,url,workflowName"))
    detalle = []
    for c in sorted(corridas, key=lambda x: x["createdAt"]):
        v = json.loads(gh("run", "view", str(c["databaseId"]), "--repo", repo, "--json", "jobs"))
        pasos = [{"paso": s["name"], "resultado": s["conclusion"], "segundos": seg(s.get("startedAt"), s.get("completedAt"))}
                 for j in v["jobs"] for s in j["steps"]]
        log = gh("run", "view", str(c["databaseId"]), "--repo", repo, "--log")
        tabla = [re.sub(r"^.*?\d{2}Z ", "", l) for l in log.splitlines()
                 if re.search(r"\| (Prácticas 13-14|Suite completa|\d+/\d+) ", l) and "out" not in l]
        fallidas = sorted({re.sub(r"^.*?\d{2}Z - ", "", l) for l in log.splitlines()
                           if re.search(r"\d{2}Z - (AUT|CORREGIDO|DEFECTO|[A-Z])", l) and "'" not in l})
        detalle.append({**c, "duracion_s": seg(c["createdAt"], c["updatedAt"]), "pasos": pasos,
                        "resumen": sorted(set(tabla)), "pruebas_fallidas": fallidas})
        print(f"{clave:<8} #{c['databaseId']} {c['event']:<12} {c['conclusion'] or c['status']:<10} "
              f"{detalle[-1]['duracion_s']} s  {c['displayTitle'][:60]}")
        for t in sorted(set(tabla)):
            print("           ", t)
    salida[clave] = detalle

with open("practica13/resultados/ci.json", "w", encoding="utf-8") as f:
    json.dump(salida, f, ensure_ascii=False, indent=2)
print("-> practica13/resultados/ci.json")
