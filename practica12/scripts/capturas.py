"""Práctica 12 — capturas de consola con la salida real (desde PRUEBAS_Y_RESULTADOS.txt y logs).
Uso (desde chaac_xanab_app):  python practica12/scripts/capturas.py
"""
import os
import re

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = "practica12/capturas"
os.makedirs(OUT, exist_ok=True)
MAXC = 130


def color(l):
    if re.search(r"\[FALLA\]|✘|FALLA", l):
        return "#F2C14E"
    if re.search(r"\[OK\]|passed|diferencia 0|perdidos 0|8/8|All tests|No issues", l):
        return "#7CD67C"
    return "#D4D4D4"


def consola(nombre, comando, lineas, nota):
    lineas = [l.rstrip()[:MAXC] for l in lineas]
    todas = [f"PS C:\\…\\chaac-xanab> {comando}"] + lineas
    alto = 0.62 + 0.165 * len(todas)
    fig = plt.figure(figsize=(10.6, alto), dpi=170)
    fig.patch.set_facecolor("#1E1E1E")
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, 1); ax.set_ylim(0, alto); ax.axis("off")
    ax.add_patch(plt.Rectangle((0, alto - 0.3), 1, 0.3, color="#323233"))
    ax.text(0.012, alto - 0.15, f"Terminal — {nota}", va="center", fontsize=7.5, color="#BBBBBB")
    for i, l in enumerate(todas):
        ax.text(0.012, alto - 0.45 - 0.165 * i, l, va="center", fontsize=6.6,
                color="#5FB3F5" if i == 0 else color(l), family="DejaVu Sans Mono")
    fig.savefig(f"{OUT}/{nombre}.png", facecolor=fig.get_facecolor())
    plt.close(fig)


txt = open("practica12/PRUEBAS_Y_RESULTADOS.txt", encoding="utf-8").read().split("\n")


def bloque(desde, hasta=None):
    i = next(n for n, l in enumerate(txt) if desde in l)
    j = next((n for n in range(i + 1, len(txt)) if hasta and hasta in txt[n]), len(txt))
    return [l for l in txt[i:j] if not set(l.strip()) <= {"=", "-"} or not l.strip()]


consola("p12_c01_estres_escritura", "node practica12/scripts/estres.mjs --tipo escritura (antes :3001 / después :3000 --idempotencia)",
        bloque("--- ESCRITURA POST", "--- HISTORIAL"), "estres/escritura_antes.json · escritura_despues.json")
consola("p12_c02_historial_lectura", "node practica12/scripts/estres.mjs --tipo historial | lectura (antes / después / producción)",
        bloque("--- HISTORIAL", "--- SERVIDOR"), "estres/*.json")
consola("p12_c03_servidor_integridad", "muestrear.ps1 -Puerto 3001|3000 · node practica12/integridad.js",
        bloque("--- SERVIDOR", "2. BASE DE DATOS"), "estres/servidor_*.csv · integridad_*.json")
consola("p12_c04_base_datos", "node practica12/db_pruebas.js antes|despues · EXPLAIN ANALYZE (Supabase)",
        bloque("--- ANTES", "3. RESILIENCIA"), "db/db_antes.json · db_despues.json")
consola("p12_c05_resiliencia", "flutter test test_resiliencia/res_antes_test.dart | res_despues_test.dart (proxy de fallas :3100)",
        bloque("3. RESILIENCIA", "4. PROFILING"), "resiliencia/res_antes.json · res_despues.json")
consola("p12_c06_profiling", "flutter drive --profile -d windows --target=integration_test/perfil_test.dart  +  muestrear.ps1",
        bloque("4. PROFILING", "5. SUITES"), "perfil/perfil_*.json · app_*.csv")
jest = [l for l in open("../backend-chaac-xanab/practica12/jest_p12.log", encoding="utf-8-sig", errors="replace").read().replace("\r", "").split("\n")
        if re.match(r"^(PASS|FAIL) |^(Tests|Test Suites|Time):", l)]
consola("p12_c07_suites", "npx jest --runInBand  (backend, rama practica12)  ·  flutter test --concurrency=1  (app)",
        jest + ["", "flutter test --concurrency=1  ->  00:11 +111: All tests passed!", "flutter analyze           ->  No issues found!"],
        "backend/practica12/jest_p12.log")
consola("p12_c08_resumen", "python practica12/scripts/comparar.py && python practica12/scripts/generar_txt.py",
        bloque("RESUMEN ANTES"), "comparativa.json")
print(sorted(os.listdir(OUT)))
