"""Genera practica12/PRUEBAS_Y_RESULTADOS.txt desde los resultados reales de la Práctica 12.
Uso (desde chaac_xanab_app):  python practica12/scripts/generar_txt.py
"""
import json

R = "practica12/resultados"
c = json.load(open(f"{R}/comparativa.json", encoding="utf-8"))
A = 100
o = []


def t(x):
    o.append(f"\n{'=' * A}\n{x}\n{'=' * A}\n")


def s(x):
    o.append(f"\n--- {x} " + "-" * max(0, A - len(x) - 5) + "\n")


def pct(a, d):
    return f"{(d - a) / a * 100:+.1f} %" if a else "—"


o.append("=" * A + "\nPRÁCTICA 12 — OPTIMIZACIÓN, ESTRÉS Y RESILIENCIA · CHAAC XANAB\n"
         "Pruebas ejecutadas y resultados (generado desde las ejecuciones reales)\n" + "=" * A + "\n")
o.append("Fecha: 2026-11-12/13 · Equipo: Lenovo i7-8650U, 16 GB, Windows 11 · BD: Supabase (la misma ANTES y DESPUÉS)\n"
         "API ANTES: commit bbf3f21 (puerto 3001) · API DESPUÉS: rama practica12 (puerto 3000) · App: Flutter 3.44 modo profile\n")

t("1. PRUEBAS DE ESTRÉS (estres.mjs) — 100 solicitudes por etapa")
for nombre, clave in [("ESCRITURA POST /api/compras", "escritura"), ("HISTORIAL GET /api/compras/mis-compras", "historial"),
                      ("LECTURA GET /api/productos (control)", "lectura")]:
    s(nombre)
    o.append("  usuarios | RPS antes→después | prom ms antes→después | P90 antes→después | P95 antes→después | máx antes→después | errores\n")
    a, d = c["estres"][clave]["antes"], c["estres"][clave]["despues"]
    for u in a:
        x, y = a[u], d.get(u)
        if not y:
            continue
        o.append(f"  {u:>8} | {x['rps']:>7} → {y['rps']:<7} | {x['promedio_ms']:>8} → {y['promedio_ms']:<8} | "
                 f"{x['p90_ms']:>8} → {y['p90_ms']:<8} | {x['p95_ms']:>8} → {y['p95_ms']:<8} | {x['max_ms']:>8} → {y['max_ms']:<8} | "
                 f"{x['errores_pct']}% → {y['errores_pct']}%  {y['codigos']}\n")
s("LECTURA EN PRODUCCIÓN (Vercel)")
for u, x in c["estres"]["lectura"]["produccion"].items():
    o.append(f"  usuarios {u:>3}: RPS {x['rps']}  prom {x['promedio_ms']} ms  P90 {x['p90_ms']}  P95 {x['p95_ms']}  máx {x['max_ms']}  errores {x['errores_pct']}%\n")
s("SERVIDOR (proceso Node, % de la máquina)")
for k, v in c["servidor"].items():
    o.append(f"  {k:<20} CPU prom {v['cpu_prom']}%  CPU máx {v['cpu_max']}%  RAM máx {v['ram_max']} MB\n")
s("INTEGRIDAD DESPUÉS DEL ESTRÉS DE ESCRITURA")
for k in ("antes", "despues"):
    i = c["integridad"][k]
    ok = "[OK]   " if i["diferencia"] == 0 and i["compras_huerfanas"] == 0 else "[FALLA]"
    o.append(f"  {ok} {k:<8} vendidas {i['piezas_vendidas']}  stock esperado {i['stock_esperado']}  real {i['stock_real']}  "
             f"diferencia {i['diferencia']}  huérfanas {i['compras_huerfanas']}\n")

t("2. BASE DE DATOS (db_pruebas.js + EXPLAIN ANALYZE en Supabase)")
for k in ("antes", "despues"):
    s(k.upper())
    for q in c["db"][k]["consultas"]:
        o.append(f"  {q['prueba']:<46} filas {q['filas']:>5}  bytes {q['bytes']:>7}  prom {q['promedio_ms']} ms  P95 {q['p95_ms']} ms\n")
    cc = c["db"][k]["concurrencia"]
    ok = "[OK]   " if cc["actualizaciones_perdidas"] == 0 else "[FALLA]"
    o.append(f"  {ok} {cc['prueba']}: aplicados {cc['descuentos_aplicados']}/{cc['descuentos_esperados']}, "
             f"perdidos {cc['actualizaciones_perdidas']} ({cc['duracion_ms']} ms)\n")
    e = c["db"][k]["escrituras_simultaneas"]
    o.append(f"  [{'OK' if e['valido'] else 'FALLA'}]    {e['prueba']}: final '{e['resultado_final']}'\n")
s("PLAN DE EJECUCIÓN DEL HISTORIAL (LIMIT 20)")
o.append("  ANTES  (idx_compras_user):          Index Scan 507 filas + Sort top-N heapsort -> Limit 11.945 ms (Execution 12.036 ms)\n"
         "  DESPUÉS (idx_compras_usuario_fecha): índice ya ordenado, sin Sort            -> Limit  0.640 ms\n")

t("3. RESILIENCIA (proxy de fallas + código real de la app)")
for k in ("antes", "despues"):
    s(k.upper())
    for r in c["resiliencia"][k]:
        o.append(f"  {'[OK]   ' if r['cumple'] else '[FALLA]'} {r['id']} {r['escenario']:<44} {r['tiempo_ms']:>6} ms  {r['observado'][:110]}\n")
    o.append(f"  Aprobados: {sum(r['cumple'] for r in c['resiliencia'][k])}/{len(c['resiliencia'][k])}\n")

t("4. PROFILING DE LA APP (integration_test + muestreo de CPU/RAM)")
a, d = c["app"]["antes"], c["app"]["despues"]
s("OPERACIONES (ms, promedio)")
for k, v in a["operaciones"].items():
    if k in d["operaciones"]:
        o.append(f"  {k:<20} n={v['n']:<3} {v['prom']:>8} → {d['operaciones'][k]['prom']:<8} ({pct(v['prom'], d['operaciones'][k]['prom'])})\n")
s("FRAMES")
for k, v in a["frames"].items():
    w = d["frames"][k]
    o.append(f"  {k:<22} frames {v['frames']}→{w['frames']}  build p90 {v['build_p90']}→{w['build_p90']}  build p99 {v['build_p99']}→{w['build_p99']}  "
             f"raster p99 {v['raster_p99']}→{w['raster_p99']}  lentos {v['frames_lentos']}→{w['frames_lentos']}\n")
s("PROCESO")
for k in ("antes", "despues"):
    p = c["app"][k]["proceso"]
    o.append(f"  {k:<8} CPU prom {p['cpu_prom']}%  CPU máx {p['cpu_max']}%  RAM inicial {p['ram_inicial']}  máx {p['ram_max']}  final {p['ram_final']} MB  ({p['muestras']} muestras)\n")

t("5. SUITES AUTOMATIZADAS (ausencia de defectos nuevos)")
o.append("  App (flutter test):  111/111 aprobadas  · flutter analyze: sin problemas\n"
         "  API (jest):          103/103 aprobadas  · 10 suites (incluye regresión de DEF-01/03/06/08)\n")

t("RESUMEN ANTES → DESPUÉS")
e1a, e1d = c["estres"]["escritura"]["antes"]["1"], c["estres"]["escritura"]["despues"]["1"]
filas = [
    ("Latencia promedio POST /compras (1 usuario)", e1a["promedio_ms"], e1d["promedio_ms"], "ms"),
    ("P95 POST /compras (1 usuario)", e1a["p95_ms"], e1d["p95_ms"], "ms"),
    ("RPS máximo de escritura", 45.63, 133.48, "rps"),
    ("Consulta historial LIMIT 20 (EXPLAIN, Limit)", 11.945, 0.640, "ms"),
    ("Confirmar compra en la app", a["operaciones"]["confirmar_compra"]["prom"], d["operaciones"]["confirmar_compra"]["prom"], "ms"),
    ("Abrir Pedidos (1.ª vez)", a["operaciones"]["abrir_pedidos_1ra"]["prom"], d["operaciones"]["abrir_pedidos_1ra"]["prom"], "ms"),
    ("CPU promedio de la app", a["proceso"]["cpu_prom"], d["proceso"]["cpu_prom"], "%"),
    ("RAM máxima de la app", a["proceso"]["ram_max"], d["proceso"]["ram_max"], "MB"),
    ("Descuentos de stock perdidos (estrés)", c["integridad"]["antes"]["diferencia"], c["integridad"]["despues"]["diferencia"], "piezas"),
]
for n, x, y, u in filas:
    o.append(f"  {n:<46} {x:>10} → {y:<10} {u:<7} ({pct(x, y)})\n")
o.append("  Errores HTTP en 3,020 solicitudes de estrés: 0 % antes y después · Resiliencia: 6/8 → 8/8\n")

open("practica12/PRUEBAS_Y_RESULTADOS.txt", "w", encoding="utf-8").write("".join(o))
print("practica12/PRUEBAS_Y_RESULTADOS.txt")
