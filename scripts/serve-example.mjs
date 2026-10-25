#!/usr/bin/env node
// Builds the showcase and serves example/ on http://localhost:8000 with a tiny static
// server (Node only, no dependencies). The page works from any static server; this
// is just for convenience.
//
//   node scripts/serve-example.mjs [port]

import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createCompiler, describe } from './playground-compiler.mjs';
import { startCalendar, calendarDir } from './lib/calendar.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dir = path.join(root, 'example');
const port = Number(process.argv[2] || 8000);
const playground = createCompiler(root);

if (!process.argv.includes('--no-build')) {
  const build = spawnSync(process.execPath, [path.join(root, 'scripts', 'build-example.mjs')], { stdio: 'inherit' });
  if (build.status !== 0) process.exit(build.status ?? 1);
}

const legacyStore = [path.join(root, 'calendar/server/showcase-data.json'), path.join(calendarDir, 'server/showcase-data.json')].find(file => fs.existsSync(file)) || '';
const calendar = await startCalendar({ prefix: '/calendar-app', db: process.env.KLAR_CALENDAR_SHOWCASE_DB, legacy: process.env.KLAR_CALENDAR_LEGACY_JSON ?? legacyStore });

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
};

const server = http
  .createServer(async (request, response) => {
    const json = (status, value) => { response.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); response.end(JSON.stringify(value)); };
    const requestUrl = new URL(request.url || '/', 'http://localhost');
    if (request.method === 'GET' && requestUrl.pathname === '/favicon.ico') {
      response.writeHead(204); response.end(); return;
    }
    if (requestUrl.pathname === '/calendar-app') {
      response.writeHead(302, { Location: '/calendar-app/' });
      return response.end();
    }
    if (requestUrl.pathname.startsWith('/calendar-app/')) {
      const target = new URL(request.url, calendar.url);
      const upstream = http.request(target, { method: request.method, headers: { ...request.headers, host: target.host } }, result => {
        response.writeHead(result.statusCode, result.headers);
        result.pipe(response);
      });
      upstream.on('error', () => {
        if (!response.headersSent) response.writeHead(502, { 'Content-Type': 'text/plain' });
        response.end('Calendar server unavailable. Restart npm start.');
      });
      request.pipe(upstream);
      return;
    }
    if (requestUrl.pathname.startsWith('/__playground/')) {
      try {
        const origin = request.headers.origin;
        if (origin && ![`http://localhost:${port}`, `http://127.0.0.1:${port}`].includes(origin)) return json(403, { error: 'Use the showcase on this local server.' });
        if (request.method === 'GET' && requestUrl.pathname === '/__playground/describe') return json(200, { targets: describe(root, requestUrl.searchParams.get('component') || '') });
        if (request.method === 'POST' && requestUrl.pathname === '/__playground/compile') {
          if (!(request.headers['content-type'] || '').startsWith('application/json')) return json(415, { error: 'Expected JSON.' });
          let body = '';
          for await (const chunk of request) { body += chunk; if (Buffer.byteLength(body) > 262144) return json(413, { error: 'The playground request exceeds 256 KiB.' }); }
          return json(200, await playground.compile(JSON.parse(body)));
        }
        const preview = /^\/__playground\/preview\/([a-f0-9-]+)\/(main\.js)?$/.exec(requestUrl.pathname);
        if (preview) {
          const artifact = playground.artifact(preview[1]);
          if (!artifact) return json(404, { error: 'This compiled preview expired. Apply the configuration again.' });
          response.writeHead(200, { 'Content-Type': preview[2] ? types['.js'] : types['.html'], 'Cache-Control': 'no-store' });
          if (preview[2]) return fs.createReadStream(artifact).pipe(response);
          return response.end(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/showcase.css"><style>.playground-header,.playground-panel,.playground-preview-toolbar{display:none!important}.playground-layout{display:block}.playground{padding:0}</style></head><body><script src="main.js"></script><script src="/playground.js"></script><script>KlarPlayground.boot(Elm.PlaygroundMain.init(),true)</script></body></html>`);
        }
        return json(404, { error: 'Unknown playground endpoint.' });
      } catch (error) { return json(400, { error: error.message }); }
    }
    const urlPath = decodeURIComponent((request.url || '/').split('?')[0]);
    const relative = urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, '');
    const file = path.normalize(path.join(dir, relative));
    if (!file.startsWith(dir + path.sep) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      response.writeHead(404, { 'Content-Type': 'text/plain' });
      response.end('Not found');
      return;
    }
    response.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    fs.createReadStream(file).pipe(response);
  })
  .listen(port, '127.0.0.1', () => {
    const url = `http://127.0.0.1:${server.address().port}/`;
    console.log(`Klar showcase: ${url}`);
    process.send?.({ type: 'ready', url });
  });

async function shutdown() {
  server.close();
  await calendar.close();
  await playground.close();
  process.exit(0);
}
process.once('SIGINT', shutdown);
process.once('SIGTERM', shutdown);
if (process.send) process.on('message', message => { if (message?.type === 'shutdown') shutdown(); });
