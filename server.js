// Serves the Flutter web build and proxies /api_v2 to deliveric.net
// (avoids browser CORS; also tolerates deliveric.net's incomplete cert chain).
const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const TARGET = 'deliveric.net';
const WEB = path.join(__dirname, 'web');
const PORT = process.env.PORT || 10000;
const agent = new https.Agent({ rejectUnauthorized: false, keepAlive: true });
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'application/javascript', '.mjs': 'application/javascript',
  '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.wasm': 'application/wasm',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.mp3': 'audio/mpeg', '.map': 'application/json',
};

function proxy(req, res) {
  const headers = { ...req.headers, host: TARGET };
  delete headers.origin; delete headers.referer; delete headers['accept-encoding'];
  const up = https.request(
    { host: TARGET, port: 443, path: req.url, method: req.method, headers, agent, servername: TARGET },
    (r) => { res.writeHead(r.statusCode, r.headers); r.pipe(res); }
  );
  up.on('error', (e) => { res.writeHead(502, { 'content-type': 'application/json' }); res.end(JSON.stringify({ status: false, message: 'Proxy error: ' + e.message })); });
  req.pipe(up);
}

function serve(req, res) {
  let p = decodeURIComponent(req.url.split('?')[0]);
  let file = path.normalize(path.join(WEB, p));
  if (!file.startsWith(WEB)) { res.writeHead(403); return res.end(); }
  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) file = path.join(WEB, 'index.html');
    fs.readFile(file, (e, buf) => {
      if (e) { res.writeHead(404); return res.end('Not found'); }
      const ext = path.extname(file).toLowerCase();
      res.writeHead(200, {
        'content-type': TYPES[ext] || 'application/octet-stream',
        'cache-control': ext === '.html' || file.endsWith('flutter_service_worker.js') ? 'no-cache' : 'public, max-age=3600',
      });
      res.end(buf);
    });
  });
}

http.createServer((req, res) => {
  if (req.url.startsWith('/api_v2/') || req.url.startsWith('/templates/')) return proxy(req, res);
  if (req.url === '/healthz') { res.writeHead(200); return res.end('ok'); }
  serve(req, res);
}).listen(PORT, () => console.log('Shipper Deliveric web on :' + PORT));
