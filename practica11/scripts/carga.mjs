// Práctica 11 — Prueba de carga controlada (alternativa a k6/JMeter, que no
// están instalados). Node >= 18, sin dependencias:
//   node practica11/scripts/carga.mjs [baseUrl]
//
// Escenarios: 1, 5 y 10 usuarios concurrentes, 20 solicitudes por escenario,
// para un endpoint de LECTURA y uno de ESCRITURA.
//   Lectura : GET  /api/productos
//   Escritura: POST /api/auth/login con un correo ficticio inexistente.
//              Recorre ValidationPipe -> AuthService -> SELECT usuarios ->
//              INSERT en bitacora (LOGIN_FALLIDO) -> 401. No crea usuarios.
//              Limpieza:  DELETE FROM bitacora WHERE usuario_email = 'practica11-carga@example.invalid';
import { writeFileSync, mkdirSync } from 'node:fs';
import os from 'node:os';

const BASE = process.argv[2] ?? 'https://backend-chaac-xanab.vercel.app/api';
const CORREO = 'practica11-carga@example.invalid';
const SOLICITUDES = 20;
const USUARIOS = [1, 5, 10];

const endpoints = {
  lectura: { metodo: 'GET', ruta: '/productos', esperado: 200 },
  escritura: {
    metodo: 'POST', ruta: '/auth/login', esperado: 401,
    cuerpo: JSON.stringify({ email: CORREO, password: 'NoExiste#2026' }),
  },
};

function percentil(ordenados, p) {
  return ordenados[Math.min(Math.ceil(p * ordenados.length) - 1, ordenados.length - 1)];
}
const r2 = (n) => Math.round(n * 100) / 100;

async function una(ep) {
  const t0 = performance.now();
  try {
    const res = await fetch(BASE + ep.ruta, {
      method: ep.metodo,
      headers: { 'content-type': 'application/json', 'accept-encoding': 'gzip' },
      body: ep.cuerpo,
    });
    const buf = Buffer.from(await res.arrayBuffer());
    const ms = performance.now() - t0;
    return {
      ok: res.status === ep.esperado, status: res.status, ms, bytes: buf.length,
      region: (res.headers.get('x-vercel-id') ?? '').split('::')[0],
    };
  } catch (e) {
    return { ok: false, status: 0, ms: performance.now() - t0, bytes: 0, error: String(e.cause?.code ?? e.message) };
  }
}

async function escenario(nombre, ep, usuarios) {
  let siguiente = 0;
  const resultados = [];
  const cpu0 = process.cpuUsage();
  const t0 = performance.now();
  await Promise.all(Array.from({ length: usuarios }, async () => {
    while (siguiente < SOLICITUDES) {
      siguiente++;
      resultados.push(await una(ep));
    }
  }));
  const duracion = (performance.now() - t0) / 1000;
  const cpu = process.cpuUsage(cpu0);
  const ms = resultados.map((r) => r.ms).sort((a, b) => a - b);
  const bytes = resultados.reduce((s, r) => s + r.bytes, 0);
  const resumen = {
    endpoint: `${ep.metodo} ${ep.ruta}`, usuarios, solicitudes: resultados.length,
    exitosas: resultados.filter((r) => r.ok).length,
    fallidas: resultados.filter((r) => !r.ok).length,
    codigos: resultados.reduce((m, r) => ({ ...m, [r.status]: (m[r.status] ?? 0) + 1 }), {}),
    promedio_ms: r2(ms.reduce((s, x) => s + x, 0) / ms.length),
    p50_ms: r2(percentil(ms, 0.5)), p95_ms: r2(percentil(ms, 0.95)),
    min_ms: r2(ms[0]), max_ms: r2(ms.at(-1)),
    duracion_s: r2(duracion), solicitudes_por_s: r2(resultados.length / duracion),
    bytes_totales: bytes, tasa_kbps: r2((bytes * 8) / duracion / 1000),
    regiones: [...new Set(resultados.map((r) => r.region).filter(Boolean))],
    cliente_cpu_ms: r2((cpu.user + cpu.system) / 1000),
    cliente_mem_mb: r2(process.memoryUsage().rss / 1024 / 1024),
    errores: resultados.filter((r) => r.error).map((r) => r.error),
  };
  console.log(`${nombre.padEnd(9)} u=${String(usuarios).padStart(2)}  ok=${resumen.exitosas}/${resumen.solicitudes}  ` +
    `prom=${resumen.promedio_ms}ms  p95=${resumen.p95_ms}ms  max=${resumen.max_ms}ms  ${resumen.solicitudes_por_s} req/s`);
  return resumen;
}

const salida = {
  fecha: new Date().toISOString(), base: BASE, solicitudes_por_escenario: SOLICITUDES,
  cliente: { so: `${os.type()} ${os.release()}`, cpu: os.cpus()[0]?.model, nucleos: os.cpus().length, node: process.version },
  nota: 'fetch (undici) reutiliza conexiones keep-alive; la primera solicitud de cada escenario puede incluir TLS.',
  escenarios: [],
};

// Calentamiento: evita medir el arranque en frío de la función serverless.
await una(endpoints.lectura);
for (const [nombre, ep] of Object.entries(endpoints)) {
  for (const u of USUARIOS) {
    salida.escenarios.push({ tipo: nombre, ...(await escenario(nombre, ep, u)) });
    await new Promise((r) => setTimeout(r, 1500)); // pausa entre escenarios
  }
}

mkdirSync('practica11/resultados', { recursive: true });
writeFileSync('practica11/resultados/carga.json', JSON.stringify(salida, null, 2));
console.log('-> practica11/resultados/carga.json');
