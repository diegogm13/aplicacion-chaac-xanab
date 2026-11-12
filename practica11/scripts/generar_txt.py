"""Genera practica11/PRUEBAS_Y_RESULTADOS.txt a partir de los resultados REALES:
  - practica11/resultados/flutter_test.json   (flutter test --reporter json)
  - ../backend-chaac-xanab/practica11/jest_resultados.json (jest --json)
  - practica11/resultados/{db_metricas,supabase_integridad,supabase_explain,red,carga}.json
Uso (desde chaac_xanab_app):  python practica11/scripts/generar_txt.py
"""
import json
import os
from collections import OrderedDict

R = "practica11/resultados"
JEST = "../backend-chaac-xanab/practica11/jest_resultados.json"
SALIDA = "practica11/PRUEBAS_Y_RESULTADOS.txt"
ANCHO = 100


def cargar(ruta):
    with open(ruta, encoding="utf-8-sig") as f:
        return json.load(f)


def titulo(txt, car="="):
    return f"\n{car * ANCHO}\n{txt}\n{car * ANCHO}\n"


def subtitulo(txt):
    return f"\n--- {txt} " + "-" * max(0, ANCHO - len(txt) - 5) + "\n"


# ── Flutter ─────────────────────────────────────────────────────────────────
suites, tests, flutter = {}, {}, OrderedDict()
with open(f"{R}/flutter_test.json", encoding="utf-8-sig") as f:
    for linea in f:
        linea = linea.strip()
        if not linea.startswith("{"):
            continue
        e = json.loads(linea)
        if e.get("type") == "suite":
            suites[e["suite"]["id"]] = os.path.basename(e["suite"]["path"])
        elif e.get("type") == "testStart":
            tests[e["test"]["id"]] = e["test"]
        elif e.get("type") == "testDone" and not e.get("hidden"):
            t = tests[e["testID"]]
            archivo = suites.get(t["suiteID"], "?")
            flutter.setdefault(archivo, []).append((t["name"], e["result"], e.get("skipped", False)))

# ── Jest ────────────────────────────────────────────────────────────────────
jest = cargar(JEST)
api_unit, api_http, api_db = OrderedDict(), OrderedDict(), OrderedDict()
for suite in jest["testResults"]:
    archivo = suite["name"].replace("\\", "/").split("/src/")[-1]
    for a in suite["assertionResults"]:
        grupo = " > ".join(a["ancestorTitles"][1:]) or "(general)"
        fila = (a["title"], a["status"], a.get("duration") or 0)
        if "practica11/http.e2e" in archivo:
            destino = api_db if ("DB-06" in grupo or "ComprasService.create" in grupo) else api_http
            destino.setdefault(grupo, []).append(fila)
        else:
            api_unit.setdefault(archivo, []).append(fila)


def marca(res):
    return "[OK]   " if res in ("success", "passed") else ("[SKIP] " if res == "skipped" else "[FALLA]")


def bloque_flutter(archivos, out):
    total = ok = 0
    for archivo in archivos:
        if archivo not in flutter:
            continue
        out.append(subtitulo(f"test/{archivo}"))
        for nombre, res, _ in flutter[archivo]:
            total += 1
            ok += res == "success"
            out.append(f"  {marca(res)} {nombre}\n")
    return total, ok


def bloque_jest(grupos, out, prefijo=""):
    total = ok = 0
    for grupo, filas in grupos.items():
        out.append(subtitulo(prefijo + grupo))
        for nombre, res, ms in filas:
            total += 1
            ok += res == "passed"
            out.append(f"  {marca(res)} {nombre}  ({ms} ms)\n")
    return total, ok


red = cargar(f"{R}/red.json")
carga = cargar(f"{R}/carga.json")
dbm = cargar(f"{R}/db_metricas.json")
integ = cargar(f"{R}/supabase_integridad.json")
expl = cargar(f"{R}/supabase_explain.json")

o = []
o.append("=" * ANCHO + "\n")
o.append("PRÁCTICA 11 — PRUEBAS WHITE BOX · CHAAC XANAB\n")
o.append("Listado de pruebas ejecutadas y sus resultados (generado desde las ejecuciones reales)\n")
o.append("=" * ANCHO + "\n")
o.append(
    "Fecha de ejecución : 2026-11-11 (UTC-6)\n"
    "Equipo cliente     : Lenovo 20L7002CUS · i7-8650U · 16 GB · Windows 11 Pro 10.0.26200 · Wi-Fi\n"
    "App móvil          : chaac_xanab_app 1.0.0+1 · Flutter 3.44.0 / Dart 3.12.0 · commit 2272970\n"
    "API (servicio web) : backend-chaac-xanab commit bbf3f21 (pruebas en c700802, rama practica11-whitebox)\n"
    f"Servidor           : {red['api']} (Vercel, región iad1)\n"
    "Base de datos      : PostgreSQL en Supabase (servidor) · SQLite 3.53.4 (local en la app)\n"
    "Nota               : [OK] = la prueba pasó. Las pruebas cuyo nombre empieza con DEFECTO/HALLAZGO\n"
    "                     pasan porque DEMUESTRAN el defecto (ver INFORME.md §6).\n"
)

resumen = []

# 1. MÓVIL
o.append(titulo("1. APLICACIÓN MÓVIL (Flutter) — lógica, validación, comunicación, conectividad, rendimiento"))
t, k = bloque_flutter(["validaciones_test.dart", "api_client_test.dart", "conectividad_test.dart",
                       "rendimiento_test.dart", "widget_test.dart"], o)
resumen.append(("Móvil (Flutter)", t, k))
o.append(subtitulo("Cobertura de módulos críticos (flutter test --coverage --branch-coverage)"))
o.append("  Instrucciones: 269/270 = 99.6 %    Ramas: 112/116 = 96.6 %   (detalle: resultados/cobertura_flutter.csv)\n")

# 2. WEB / API
o.append(titulo("2. SERVICIO WEB / API (NestJS) — endpoints, códigos HTTP, autenticación y autorización"))
t1, k1 = bloque_jest(api_http, o, "HTTP e2e › ")
t2, k2 = bloque_jest(api_unit, o, "Unitarias › ")
resumen.append(("Web / API (Jest)", t1 + t2, k1 + k2))
o.append(subtitulo("Códigos HTTP comprobados contra PRODUCCIÓN (curl)"))
for c in red["codigos"]:
    o.append(f"  {c['code']}  {c['caso']:<34} {c['cuerpo'][:60]}\n")
o.append(subtitulo("Cobertura de módulos críticos (jest --coverage)"))
o.append("  Instrucciones: 158/160 = 98.8 %    Ramas: 44/52 = 84.6 %\n")

# 3. BASE DE DATOS
o.append(titulo("3. BASE DE DATOS — móvil (SQLite), API (lógica de persistencia) y servidor (Supabase)"))
o.append("\n>> 3.1 MÓVIL — SQLite local (mismo motor y código que en el teléfono)\n")
t, k = bloque_flutter(["db_test.dart"], o)
resumen.append(("Base de datos móvil (SQLite)", t, k))
o.append(subtitulo("Tiempos y planes de ejecución SQLite (1,000 usuarios / 200 renglones)"))
for nombre, c in dbm["consultas"].items():
    o.append(f"  {c['promedio_ms_50_ejecuciones']:>7.3f} ms  {nombre:<38} plan: {'; '.join(c['plan'])}\n")
ca = dbm["concurrencia_agregar"]
o.append(f"  Concurrencia agregar(): {ca['excepcion']} · filas={ca['filas_resultantes']} · "
         f"cantidad final={ca['cantidad_final']} (esperada {ca['cantidad_esperada']})\n")

o.append("\n>> 3.2 API — persistencia de compras (transacciones y concurrencia)\n")
t, k = bloque_jest(api_db, o, "HTTP e2e › ")
resumen.append(("Base de datos vía API", t, k))

o.append("\n>> 3.3 SERVIDOR — PostgreSQL real en Supabase (SQL Editor)\n")
o.append(subtitulo("Integridad (sentencias inválidas, todo revertido)"))
for r in integ["resultados"]:
    o.append(f"  [{'OK' if r['resultado'].startswith('RECHAZADA') else 'FALLA'}]   {r['prueba']:<34} {r['resultado']}\n")
resumen.append(("Integridad Supabase", len(integ["resultados"]),
                sum(r["resultado"].startswith("RECHAZADA") for r in integ["resultados"])))
o.append(subtitulo("EXPLAIN (ANALYZE, BUFFERS)"))
for clave, q in expl.items():
    if not isinstance(q, dict):
        continue
    plan = next((p.strip() for p in q["plan"] if "Scan" in p), "")
    o.append(f"  {clave:<26} planning {q['planning_ms']:>6.3f} ms · execution {q['execution_ms']:>6.3f} ms · {plan[:70]}\n")
o.append("  Bitácora: 0 filas de las 60 LOGIN_FALLIDO de la prueba de carga -> DEFECTO DEF-12\n")

# 4. CONECTIVIDAD
o.append(titulo("4. CONECTIVIDAD Y RENDIMIENTO (mediciones reales contra producción)"))
p = red["ping"]
o.append(f"  Ping {p['host']}: {p['recibidos']}/{p['enviados']} · pérdida {p['perdida_pct']} % · "
         f"mín {p['ms']['min']} · prom {p['ms']['promedio']} · máx {p['ms']['max']} · σ {p['ms']['desviacion']} ms\n")
o.append(subtitulo("10 solicitudes GET /api/productos (conexión nueva cada vez)"))
o.append("  #   código   tiempo(ms)   bytes   dns    tcp    tls    ttfb\n")
for s in red["http_10"]["solicitudes"]:
    o.append(f"  {s['n']:<3} {s['code']:<8} {s['total']:>9}   {s['bajada']:>6}  {s['dns']:>5}  {s['tcp']:>5}  {s['tls']:>5}  {s['ttfb']:>6}\n")
h = red["http_10"]["total_ms"]
o.append(f"  Promedio {h['promedio']} ms · mín {h['min']} · máx {h['max']} · σ {h['desviacion']} · "
         f"keep-alive {red['http_keepalive']['total_ms']['promedio']} ms\n")
o.append(subtitulo("Tasa de transferencia"))
for d in red["descarga"]:
    o.append(f"  Bajada  intento {d['intento']}  {d['bytes']:>6} B  {d['tiempo_s']} s  {d['mbps_total']} Mbps  {d['recurso'][:55]}\n")
for s in red["subida"]:
    o.append(f"  Subida  intento {s['intento']}  {s['bytes']:>6} B  {s['tiempo_s']} s  {s['mbps_total']} Mbps  (HTTP {s['code']})\n")
o.append(subtitulo("Carga controlada (20 solicitudes por escenario)"))
o.append("  tipo       usuarios  ok/total  prom(ms)  p95(ms)  máx(ms)  req/s\n")
for e in carga["escenarios"]:
    o.append(f"  {e['tipo']:<10} {e['usuarios']:>8}  {e['exitosas']:>2}/{e['solicitudes']:<5}  {e['promedio_ms']:>8}  "
             f"{e['p95_ms']:>7}  {e['max_ms']:>7}  {e['solicitudes_por_s']:>5}\n")
o.append("  Pérdida de conexión / recuperación: ver conectividad_test.dart en la sección 1 (NET-05, NET-06, DEF-01).\n")

# RESUMEN
o.append(titulo("RESUMEN"))
tt = tk = 0
for nombre, t, k in resumen:
    tt, tk = tt + t, tk + k
    o.append(f"  {nombre:<32} {k:>4} / {t:<4} aprobadas\n")
o.append(f"  {'TOTAL':<32} {tk:>4} / {tt:<4} aprobadas\n")
o.append("  Defectos documentados: DEF-01 … DEF-12 (detalle, pasos y corrección en INFORME.md §6)\n")

with open(SALIDA, "w", encoding="utf-8") as f:
    f.write("".join(o))
print(SALIDA, f"{tk}/{tt}")
