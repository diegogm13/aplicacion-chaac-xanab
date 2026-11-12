"""Genera practica11/capturas/*.png: salida REAL de cada herramienta (tomada de los
logs/JSON guardados en practica11/resultados y backend/practica11) dibujada como consola.
Uso (desde chaac_xanab_app):  python practica11/scripts/capturas.py
"""
import json
import os
import re

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

R = "practica11/resultados"
B = "../backend-chaac-xanab/practica11"
OUT = "practica11/capturas"
os.makedirs(OUT, exist_ok=True)
MAXC = 118


def leer(ruta):
    with open(ruta, encoding="utf-8-sig", errors="replace") as f:
        return f.read().replace("\r", "").split("\n")


def color(linea):
    if re.search(r"(√|\[OK\]|PASS |All tests passed|passed|No issues found|RECHAZADA|Index Scan|0% perdidos|\(0% )", linea):
        return "#7CD67C"
    if re.search(r"(×|FAIL|critical|high|Severity: high|Seq Scan|DEFECTO|HALLAZGO)", linea):
        return "#F2C14E"
    if linea.startswith(("PS ", "$ ", ">")):
        return "#5FB3F5"
    return "#D4D4D4"


def consola(nombre, comando, lineas, nota):
    lineas = [l[:MAXC] for l in lineas]
    todas = [f"PS C:\\…\\chaac-xanab> {comando}"] + lineas
    alto = 0.62 + 0.165 * len(todas)
    fig = plt.figure(figsize=(9.6, alto), dpi=170)
    fig.patch.set_facecolor("#1E1E1E")
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, 1)
    ax.set_ylim(0, alto)
    ax.axis("off")
    ax.add_patch(plt.Rectangle((0, alto - 0.3), 1, 0.3, color="#323233"))
    ax.text(0.012, alto - 0.15, f"Terminal — {nota}", va="center", fontsize=7.5, color="#BBBBBB", family="DejaVu Sans")
    for i, l in enumerate(todas):
        c = "#5FB3F5" if i == 0 else color(l)
        ax.text(0.012, alto - 0.45 - 0.165 * i, l, va="center", fontsize=6.9, color=c, family="DejaVu Sans Mono")
    fig.savefig(f"{OUT}/{nombre}.png", facecolor=fig.get_facecolor())
    plt.close(fig)


# 1. flutter test
log = leer(f"{R}/flutter_test.log")
vistos, prog = set(), []
for l in log:
    m = re.match(r"^(\d\d:\d\d \+\d+(?: -\d+)?): (?:[A-Z]:/[^:]*/)?test/([^:]+): (.*)$", l.strip())
    if m and m.group(3) not in vistos:
        vistos.add(m.group(3))
        prog.append(f"{m.group(1)}: test/{m.group(2)}: {m.group(3)}")
final = [l for l in log if "All tests passed" in l or "Some tests failed" in l][-1:]
consola("cap01_flutter_test", "flutter test --concurrency=1 --coverage --branch-coverage --reporter expanded",
        prog[:14] + ["   …   (" + str(len(prog) - 28) + " pruebas más)"] + prog[-14:] + [re.sub(r"[A-Z]:/\S+: ", "", final[0]) if final else ""],
        "flutter_test.log")

# 2. cobertura flutter
consola("cap02_cobertura_flutter", "powershell -File practica11/scripts/cobertura.ps1",
        [l for l in leer(f"{R}/cobertura_consola.txt") if l.strip()], "cobertura_consola.txt")

# 3. flutter analyze
consola("cap03_flutter_analyze", "flutter analyze", [l for l in leer(f"{R}/flutter_analyze.txt") if l.strip()], "flutter_analyze.txt")

# 4-5. jest e2e
jl = leer(f"{B}/jest.log")
ini = next(i for i, l in enumerate(jl) if l.startswith("PASS src/practica11"))
fin = next((i for i in range(ini + 1, len(jl)) if re.match(r"^(PASS|FAIL) ", jl[i]) or not jl[i].strip()), len(jl))
bloque = jl[ini:fin]
corte = next(i for i, l in enumerate(bloque) if "500 y errores" in l)
consola("cap04_jest_http_a", "npx jest --coverage --verbose   (src/practica11/http.e2e.spec.ts, parte 1)", bloque[:corte], "jest.log")
consola("cap05_jest_http_b", "npx jest --coverage --verbose   (src/practica11/http.e2e.spec.ts, parte 2)", bloque[corte:], "jest.log")

# 6. jest resumen + cobertura
pas = [l for l in jl if re.match(r"^(PASS|FAIL) ", l)]
cab = [l for l in jl if l.startswith("File ") or l.startswith("All files")][:2]
cov = [l for l in jl if re.search(r"(compras\.(service|controller)|productos\.(service|controller)|roles\.guard|jwt\.strategy)\.ts", l)]
tot = [l for l in jl if re.match(r"^(Test Suites|Tests|Time):", l)]
consola("cap06_jest_resumen", "npx jest --coverage", pas + [""] + cab + cov + [""] + tot, "jest.log")

# 7. npm audit
au = [l for l in leer(f"{B}/npm_audit.txt") if l.strip()]
sev = [l for l in au if l.startswith("Severity") or re.match(r"^[a-z@][\w@/.-]+\s+[<>=0-9*]", l)]
consola("cap07_npm_audit", "npm audit --omit=dev", sev[:30] + [""] + au[-5:], "npm_audit.txt")

# 8. ping
consola("cap08_ping", "ping -n 20 backend-chaac-xanab.vercel.app", [l for l in leer(f"{R}/ping.txt") if l.strip()], "ping.txt")

# 9. códigos HTTP en producción
red = json.load(open(f"{R}/red.json", encoding="utf-8-sig"))
lin = [f"{'HTTP':<5} {'caso':<34} cuerpo de la respuesta", "-" * 110]
lin += [f"{c['code']:<5} {c['caso']:<34} {c['cuerpo'][:70]}" for c in red["codigos"]]
lin += ["", "10 x GET /api/productos (conexión nueva):", f"{'#':<3} {'code':<5} {'total ms':>9} {'bytes':>7} {'dns':>6} {'tcp':>6} {'tls':>6} {'ttfb':>7}"]
lin += [f"{s['n']:<3} {s['code']:<5} {s['total']:>9} {s['bajada']:>7} {s['dns']:>6} {s['tcp']:>6} {s['tls']:>6} {s['ttfb']:>7}" for s in red["http_10"]["solicitudes"]]
h = red["http_10"]["total_ms"]
lin += [f"promedio {h['promedio']} ms · mín {h['min']} · máx {h['max']} · σ {h['desviacion']}"]
consola("cap09_http_produccion", "powershell -File practica11/scripts/medir_red.ps1", lin, "red.json (curl -w contra producción)")

# 10. carga
ca = json.load(open(f"{R}/carga.json", encoding="utf-8-sig"))
lin = [f"{e['tipo']:<9} u={e['usuarios']:>2}  ok={e['exitosas']}/{e['solicitudes']}  prom={e['promedio_ms']}ms  "
       f"p95={e['p95_ms']}ms  max={e['max_ms']}ms  {e['solicitudes_por_s']} req/s  regiones={','.join(e['regiones'])}"
       for e in ca["escenarios"]] + ["-> practica11/resultados/carga.json"]
consola("cap10_carga", "node practica11/scripts/carga.mjs", lin, "carga.json")

# 11. SQLite
dbm = json.load(open(f"{R}/db_metricas.json", encoding="utf-8-sig"))
lin = [f"SQLite {dbm['motor']}  (1,000 usuarios / 200 renglones de carrito, promedio de 50 ejecuciones)", ""]
for n, c in dbm["consultas"].items():
    lin += [f"{n}", f"   {c['sql']}", f"   EXPLAIN QUERY PLAN -> {'; '.join(c['plan'])}", f"   tiempo promedio: {c['promedio_ms_50_ejecuciones']} ms", ""]
cc = dbm["concurrencia_agregar"]
lin += ["DB-06 concurrencia — dos CarritoService.agregar() simultáneos:", f"   {cc['detalle'][:105]}",
        f"   filas={cc['filas_resultantes']}  cantidad final={cc['cantidad_final']}  (esperada {cc['cantidad_esperada']})  -> DEFECTO DEF-03"]
consola("cap11_sqlite", "flutter test test/db_test.dart", lin, "db_metricas.json")

# 12-13. Supabase
ig = json.load(open(f"{R}/supabase_integridad.json", encoding="utf-8-sig"))
lin = [f"{'prueba':<34} resultado", "-" * 110] + [f"{r['prueba']:<34} {r['resultado'][:80]}" for r in ig["resultados"]]
consola("cap12_supabase_integridad", "Supabase SQL Editor: SELECT prueba, pg_temp.intentar(sentencia) …", lin, "supabase_integridad.json")
ex = json.load(open(f"{R}/supabase_explain.json", encoding="utf-8-sig"))
lin = ["QUERY PLAN (Q3 — historial de compras)"] + ex["Q3_historial"]["plan"] + ["", "Resumen Q1–Q4:"]
lin += [f"  {k:<26} planning {q['planning_ms']} ms · execution {q['execution_ms']} ms" for k, q in ex.items() if isinstance(q, dict)]
consola("cap13_supabase_explain", "Supabase SQL Editor: EXPLAIN (ANALYZE, BUFFERS) …", lin, "supabase_explain.json")
print("capturas en", OUT, sorted(os.listdir(OUT)))
