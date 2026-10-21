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

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dir = path.join(root, 'example');
const port = Number(process.argv[2] || 8000);

const build = spawnSync('elm', ['make', 'src/Main.elm', '--output=main.js'], { cwd: dir, stdio: 'inherit', shell: true });
if (build.status !== 0) process.exit(build.status ?? 1);

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
};

http
  .createServer((request, response) => {
    const urlPath = decodeURIComponent((request.url || '/').split('?')[0]);
    const relative = urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, '');
    const file = path.normalize(path.join(dir, relative));
    if (!file.startsWith(dir) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      response.writeHead(404, { 'Content-Type': 'text/plain' });
      response.end('Not found');
      return;
    }
    response.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    fs.createReadStream(file).pipe(response);
  })
  .listen(port, () => console.log(`Klar showcase: http://localhost:${port}/`));
