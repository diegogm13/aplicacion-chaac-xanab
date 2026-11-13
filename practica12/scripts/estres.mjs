// Práctica 12 — Prueba de estrés reproducible (Node >= 18, sin dependencias).
//
//   node practica12/scripts/estres.mjs --base http://localhost:3001/api --tipo lectura \
//        --usuarios 1,5,10,25,50,100 --solicitudes 100 --etiqueta antes
//
//   --tipo lectura   : GET  /productos
//   --tipo escritura : POST /compras (usuario y producto de prueba "P12", ver backend practica12/datos_prueba.js)
//   --idempotencia   : manda un Idempotency-Key único por solicitud (versión optimizada)
//
// Cada etapa reparte N solicitudes entre U "usuarios" concurrentes (bucles que
// envían la siguiente solicitud en cuanto reciben la respuesta anterior).
import { writeFileSync, mkdirSync } from 'node:fs';
import { randomUUID } from 'node:crypto';

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, a, i, arr) => {
  if (a.startsWith('--')) acc.push([a.slice(2), arr[i + 1]?.startsWith('--') || arr[i + 1] === undefined ? 'true' : arr[i + 1]]);
  return acc;
}, []));
const BASE = args.base ?? 'http://localhost:3001/api';
const TIPO = args.tipo ?? 'lectura';
const USUARIOS = (args.usuarios ?? '1,5,10,25,50,100').split(',').map(Number);
const N = Number(args.solicitudes ?? 100);
const ETIQUETA = args.etiqueta ?? 'sin-etiqueta';
const IDEMP = args.idempotencia === 'true';
const TIMEOUT_MS = Number(args.timeout ?? 30000);
const CORREO = 'p12.carga@example.invalid';
const PASSWORD = 'P12carga#2026';
const PRODUCTO = 'P12 PRUEBA DE CARGA (no comprar)';

const r2 = (n) => Math.round(n * 100) / 100;
const pct = (orden, p) => orden[Math.min(Math.ceil(p * orden.length) - 1, orden.length - 1)];

async function preparar() {
  if (TIPO !== 'escritura') return { metodo: 'GET', ruta: '/productos', headers: {} };
  const login = await fetch(`${BASE}/auth/login`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: CORREO, password: PASSWORD }),
  });
  if (!login.ok) throw new Error(`login ${login.status}: ${await login.text()}`);
  const { token } = await login.json();
  const productos = await (await fetch(`${BASE}/productos`)).json();
  const p = productos.find((x) => x.name === PRODUCTO);
  if (!p) throw new Error('No existe el producto de prueba P12 (correr datos_prueba.js crear)');
  return {
    metodo: 'POST', ruta: '/compras', productoId: p.id,
    headers: { authorization: `Bearer ${token}` },
    cuerpo: JSON.stringify({
      items: [{ producto_id: p.id, size: '26', quantity: 1 }],
      direccion: { calle: 'Calle P12', numero_ext: '1', colonia: 'Centro', ciudad: 'Mérida', estado: 'Yucatán', codigo_postal: '97000' },
    }),
  };
}

async function una(ep) {
  const t0 = performance.now();
  try {
    const res = await fetch(BASE + ep.ruta, {
      method: ep.metodo,
      headers: { 'content-type': 'application/json', ...ep.headers, ...(IDEMP ? { 'idempotency-key': randomUUID() } : {}) },
      body: ep.cuerpo,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    const bytes = (await res.arrayBuffer()).byteLength;
    return { status: res.status, ms: performance.now() - t0, bytes };
  } catch (e) {
    return { status: 0, ms: performance.now() - t0, bytes: 0, error: e.name === 'TimeoutError' ? 'timeout' : String(e.cause?.code ?? e.message) };
  }
}

async function etapa(ep, usuarios) {
  let siguiente = 0;
  const res = [];
  const inicio = Date.now();
  const t0 = performance.now();
  await Promise.all(Array.from({ length: usuarios }, async () => {
    while (siguiente < N) { siguiente++; res.push(await una(ep)); }
  }));
  const dur = (performance.now() - t0) / 1000;
  const ms = res.map((r) => r.ms).sort((a, b) => a - b);
  const ok = res.filter((r) => r.status >= 200 && r.status < 300).length;
  const bytes = res.reduce((s, r) => s + r.bytes, 0);
  const e = {
    usuarios, solicitudes: res.length, inicio, fin: Date.now(), duracion_s: r2(dur),
    rps: r2(res.length / dur), exitosas: ok, errores: res.length - ok, errores_pct: r2((100 * (res.length - ok)) / res.length),
    codigos: res.reduce((m, r) => ({ ...m, [r.status]: (m[r.status] ?? 0) + 1 }), {}),
    promedio_ms: r2(ms.reduce((s, x) => s + x, 0) / ms.length), p50_ms: r2(pct(ms, 0.5)), p90_ms: r2(pct(ms, 0.9)),
    p95_ms: r2(pct(ms, 0.95)), p99_ms: r2(pct(ms, 0.99)), min_ms: r2(ms[0]), max_ms: r2(ms.at(-1)),
    kbps: r2((bytes * 8) / dur / 1000), errores_red: [...new Set(res.filter((r) => r.error).map((r) => r.error))],
  };
  console.log(`${TIPO.padEnd(9)} ${ETIQUETA.padEnd(8)} u=${String(usuarios).padStart(3)}  rps=${String(e.rps).padStart(6)}  ` +
    `prom=${String(e.promedio_ms).padStart(8)}  p90=${String(e.p90_ms).padStart(8)}  p95=${String(e.p95_ms).padStart(8)}  ` +
    `max=${String(e.max_ms).padStart(8)}  err=${e.errores_pct}%  ${JSON.stringify(e.codigos)}`);
  return e;
}

const ep = await preparar();
await una(ep); // calentamiento (conexión, caché, JIT); no se cuenta
const salida = {
  fecha: new Date().toISOString(), base: BASE, tipo: TIPO, etiqueta: ETIQUETA, endpoint: `${ep.metodo} ${ep.ruta}`,
  solicitudes_por_etapa: N, idempotencia: IDEMP, timeout_ms: TIMEOUT_MS, etapas: [],
};
for (const u of USUARIOS) {
  salida.etapas.push(await etapa(ep, u));
  await new Promise((r) => setTimeout(r, 2000));
}
mkdirSync('practica12/resultados/estres', { recursive: true });
const archivo = args.salida ?? `practica12/resultados/estres/${TIPO}_${ETIQUETA}.json`;
writeFileSync(archivo, JSON.stringify(salida, null, 2));
console.log('->', archivo);
