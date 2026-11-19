"""Práctica 12 — consolida las mediciones ANTES/DESPUÉS en practica12/resultados/comparativa.json.
Uso (desde chaac_xanab_app):  python practica12/scripts/comparar.py
"""
import csv
import json
import statistics as st

R = "practica12/resultados"


def j(ruta):
    with open(f"{R}/{ruta}", encoding="utf-8-sig") as f:
        return json.load(f)


def muestras(ruta):
    with open(f"{R}/{ruta}", encoding="utf-8-sig") as f:
        filas = list(csv.DictReader(f))
    cpu = [float(x["cpu_pct"]) for x in filas]
    ram = [float(x["ram_mb"]) for x in filas]
    activos = [c for c in cpu if c > 0.5] or cpu
    return {"muestras": len(filas), "cpu_prom": round(st.mean(cpu), 2), "cpu_prom_activo": round(st.mean(activos), 2),
            "cpu_max": round(max(cpu), 2), "ram_inicial": ram[0], "ram_max": max(ram), "ram_final": ram[-1]}


def perfil(ruta):
    p = j(ruta)
    ops = {k: {"n": len(v), "prom": round(st.mean(v), 1), "min": min(v), "max": max(v)} for k, v in p["operaciones"].items()}
    frames = {k: {"frames": v["frame_count"], "build_prom": round(v["average_frame_build_time_millis"], 2),
                  "build_p90": round(v["90th_percentile_frame_build_time_millis"], 2),
                  "build_p99": round(v["99th_percentile_frame_build_time_millis"], 2),
                  "raster_prom": round(v["average_frame_rasterizer_time_millis"], 2),
                  "raster_p99": round(v["99th_percentile_frame_rasterizer_time_millis"], 2),
                  "frames_lentos": v["missed_frame_build_budget_count"] + v["missed_frame_rasterizer_budget_count"]}
              for k, v in p.items() if k.startswith("frames_")}
    return {"operaciones": ops, "frames": frames}


def etapas(ruta):
    return {e["usuarios"]: {k: e[k] for k in ("rps", "promedio_ms", "p90_ms", "p95_ms", "max_ms", "errores_pct", "codigos")}
            for e in j(ruta)["etapas"]}


def servidor(ruta):
    m = muestras(ruta)
    return {"cpu_prom": m["cpu_prom_activo"], "cpu_max": m["cpu_max"], "ram_max": m["ram_max"]}


out = {
    "estres": {
        "escritura": {"antes": etapas("estres/escritura_antes.json"), "despues": etapas("estres/escritura_despues.json")},
        "lectura": {"antes": etapas("estres/lectura_antes.json"), "despues": etapas("estres/lectura_despues.json"),
                    "produccion": etapas("estres/lectura_produccion.json")},
        "historial": {"antes": etapas("estres/historial_antes.json"), "despues": etapas("estres/historial_despues.json")},
    },
    "servidor": {"escritura_antes": servidor("estres/servidor_escritura_antes.csv"),
                 "escritura_despues": servidor("estres/servidor_escritura_despues.csv"),
                 "lectura_antes": servidor("estres/servidor_lectura_antes.csv"),
                 "lectura_despues": servidor("estres/servidor_lectura_despues.csv")},
    "integridad": {"antes": j("estres/integridad_escritura_antes.json"), "despues": j("estres/integridad_escritura_despues.json")},
    "db": {"antes": j("db/db_antes.json"), "despues": j("db/db_despues.json")},
    "app": {"antes": {**perfil("perfil/perfil_antes.json"), "proceso": muestras("perfil/app_antes.csv")},
            "despues": {**perfil("perfil/perfil_despues.json"), "proceso": muestras("perfil/app_despues.csv")}},
    "resiliencia": {"antes": j("resiliencia/res_antes.json")["resultados"], "despues": j("resiliencia/res_despues.json")["resultados"]},
}
with open(f"{R}/comparativa.json", "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=2)

a, d = out["app"]["antes"], out["app"]["despues"]
print("APP proceso antes:", a["proceso"]); print("APP proceso despues:", d["proceso"])
for k in a["operaciones"]:
    if k in d["operaciones"]:
        print(f"  op {k:<20} {a['operaciones'][k]['prom']:>8} -> {d['operaciones'][k]['prom']:>8}")
for k in a["frames"]:
    print(f"  {k:<22} build_p99 {a['frames'][k]['build_p99']:>6} -> {d['frames'][k]['build_p99']:>6}  frames {a['frames'][k]['frames']} -> {d['frames'][k]['frames']}  lentos {a['frames'][k]['frames_lentos']} -> {d['frames'][k]['frames_lentos']}")
print("SERVIDOR:", json.dumps(out["servidor"]))
