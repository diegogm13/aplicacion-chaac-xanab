// Práctica 12 — prueba de humo de la compra idempotente contra el backend optimizado.
//   node practica12/scripts/humo.mjs http://localhost:3000/api
const BASE = process.argv[2] ?? 'http://localhost:3000/api';
const { token } = await (await fetch(`${BASE}/auth/login`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ email: 'p12.carga@example.invalid', password: 'P12carga#2026' }),
})).json();
const p = (await (await fetch(`${BASE}/productos`)).json()).find((x) => x.name.startsWith('P12 PRUEBA'));
const llave = `humo-p12-${Date.now()}`;
for (const intento of [1, 2]) {
  const r = await fetch(`${BASE}/compras`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${token}`, 'idempotency-key': llave },
    body: JSON.stringify({ items: [{ producto_id: p.id, size: '26', quantity: 1 }] }),
  });
  const c = await r.json();
  console.log(`envío ${intento}: HTTP ${r.status}  Idempotent-Replayed=${r.headers.get('idempotent-replayed')}  compra=${c.id}  total=${c.total}  items=${c.items?.length}`);
}
const r409 = await fetch(`${BASE}/compras`, {
  method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
  body: JSON.stringify({ items: [{ producto_id: p.id, size: '26', quantity: 99999999 }] }),
});
console.log(`stock insuficiente: HTTP ${r409.status} ${(await r409.json()).message}`);
const pag = await (await fetch(`${BASE}/compras/mis-compras?limite=20`, { headers: { authorization: `Bearer ${token}` } })).json();
console.log(`mis-compras?limite=20 -> ${pag.length} compras`);
