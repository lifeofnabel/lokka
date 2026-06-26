// Tiny static file server for the freshly built Flutter web release bundle.
// Serves build/web with SPA fallback to index.html so go_router deep-links work.
// Used only by the Claude preview harness for responsive screenshot QA.
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..', 'build', 'web');
const PORT = 8765;

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.gif': 'image/gif', '.svg': 'image/svg+xml', '.webp': 'image/webp',
  '.wasm': 'application/wasm', '.ttf': 'font/ttf', '.otf': 'font/otf',
  '.woff': 'font/woff', '.woff2': 'font/woff2', '.ico': 'image/x-icon',
  '.bin': 'application/octet-stream', '.symbols': 'application/octet-stream',
};

function send(res, status, body, type) {
  res.writeHead(status, {
    'Content-Type': type || 'text/plain',
    'Cache-Control': 'no-cache, no-store, must-revalidate',
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  let urlPath = decodeURIComponent(req.url.split('?')[0]);
  if (urlPath === '/') urlPath = '/index.html';
  let filePath = path.join(ROOT, urlPath);
  if (!filePath.startsWith(ROOT)) return send(res, 403, 'Forbidden');

  fs.stat(filePath, (err, stat) => {
    if (err || !stat.isFile()) {
      // SPA fallback — let the Flutter router resolve the deep-link.
      const index = path.join(ROOT, 'index.html');
      return fs.readFile(index, (e, buf) =>
        e ? send(res, 404, 'Not found') : send(res, 200, buf, TYPES['.html']));
    }
    fs.readFile(filePath, (e, buf) => {
      if (e) return send(res, 500, 'Read error');
      send(res, 200, buf, TYPES[path.extname(filePath)] || 'application/octet-stream');
    });
  });
});

server.listen(PORT, '127.0.0.1', () =>
  console.log('preview-server: serving build/web on http://127.0.0.1:' + PORT));
