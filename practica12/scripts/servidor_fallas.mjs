// Práctica 12 — Proxy de fallas controladas entre la app y el backend.
//   node practica12/scripts/servidor_fallas.mjs --puerto 3100 --destino http://localhost:3001
// La app (o el arnés de pruebas) apunta a http://localhost:3100/api.
// El modo se cambia en caliente:  GET http://localhost:3100/__modo?m=<modo>
//   normal            reenvía todo al backend
//   reset             corta la conexión TCP en cuanto llega la petición (pérdida de red)
//   colgado           acepta la conexión y nunca responde (servidor sin respuesta)
//   lento:<ms>        espera <ms> y luego reenvía (respuesta tardía)
//   500 | 401 | 403   responde ese código con un cuerpo JSON estilo NestJS
//   cortar-despues    reenvía, el backend PROCESA la operación, y se corta antes de responder
//   apagado:<ms>      deja de aceptar conexiones <ms> milisegundos (ECONNREFUSED) y vuelve
// Contadores: GET /__estado  ->  peticiones reenviadas al backend por método+ruta.
import http from 'node:http';

const arg = (n, d) => { const i = process.argv.indexOf(`--${n}`); return i > 0 ? process.argv[i + 1] : d; };
const PUERTO = Number(arg('puerto', 3100));
const DESTINO = new URL(arg('destino', 'http://localhost:3001'));
let modo = 'normal';
const reenviadas = {};
const sockets = new Set();

function reenviar(req, res, cortarAlFinal = false) {
  const clave = `${req.method} ${req.url.split('?')[0]}`;
  reenviadas[clave] = (reenviadas[clave] ?? 0) + 1;
  const sal = http.request({ host: DESTINO.hostname, port: DESTINO.port, path: req.url, method: req.method, headers: { ...req.headers, host: DESTINO.host } }, (r) => {
    if (cortarAlFinal) {
      r.resume();
      r.on('end', () => req.socket.destroy()); // el backend ya procesó; la respuesta nunca llega
      return;
    }
    res.writeHead(r.statusCode ?? 502, r.headers);
    r.pipe(res);
  });
  sal.on('error', () => { res.writeHead(502); res.end(); });
  req.pipe(sal);
}

const servidor = http.createServer((req, res) => {
  if (req.url.startsWith('/__modo')) {
    modo = new URL(req.url, 'http://x').searchParams.get('m') ?? 'normal';
    if (modo.startsWith('apagado:')) {
      const ms = Number(modo.split(':')[1]);
      res.end(JSON.stringify({ modo }));
      setTimeout(() => {
        servidor.close();
        for (const s of sockets) s.destroy();
        setTimeout(() => { modo = 'normal'; servidor.listen(PUERTO); }, ms);
      }, 50);
      return;
    }
    return res.end(JSON.stringify({ modo }));
  }
  if (req.url.startsWith('/__estado')) return res.end(JSON.stringify({ modo, reenviadas }));

  if (modo === 'reset') return req.socket.destroy();
  if (modo === 'colgado') return; // nunca responde
  if (['500', '401', '403'].includes(modo)) {
    const mensajes = { 500: 'Internal server error', 401: 'Unauthorized', 403: 'No tienes permisos para esta acción' };
    res.writeHead(Number(modo), { 'content-type': 'application/json; charset=utf-8' });
    return res.end(JSON.stringify({ statusCode: Number(modo), message: mensajes[modo] }));
  }
  if (modo.startsWith('lento:')) return setTimeout(() => reenviar(req, res), Number(modo.split(':')[1]));
  if (modo === 'cortar-despues') return reenviar(req, res, true);
  return reenviar(req, res);
});
servidor.on('connection', (s) => { sockets.add(s); s.on('close', () => sockets.delete(s)); });
servidor.listen(PUERTO, () => console.log(`proxy de fallas :${PUERTO} -> ${DESTINO.origin}`));
