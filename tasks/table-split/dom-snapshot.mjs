// Capture the table roots on every showcase route with dependency-free headless Chrome.
// node tasks/table-split/dom-snapshot.mjs <output-directory> [baseline-directory]
// Set CHROME_PATH if Chrome is installed somewhere else.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const example = path.join(root, 'example');
const output = path.resolve(process.argv[2]);
const baseline = process.argv[3] && path.resolve(process.argv[3]);
const chrome = process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const catalog = fs.readFileSync(path.join(example, 'src/Page/Gallery/Catalog.elm'), 'utf8');
const slugs = [...catalog.split('slug section =')[1].split('fromSlug :')[0].matchAll(/"([a-z-]+)"/g)].map(m => m[1]);
const pages = [
  ...['', 'orders', 'products', 'components', ...slugs.map(s => `components/${s}`)].map(route => ({
    name: route.replaceAll('/', '-') || 'overview', url: `/index.html#/${route}`,
  })),
  ...fs.readdirSync(path.join(example, 'examples')).filter(f => f.endsWith('.html')).sort().map(file => ({
    name: `example-${file.slice(0, -5)}`, url: `/examples/${file}`,
  })),
];
const marker = 'klar-dom-snapshot';
const capture = `<script>setTimeout(function capture(){var e=document.createElement('pre');e.id='${marker}';e.textContent=JSON.stringify(Array.from(document.querySelectorAll('.klar-table'),function(t){return t.outerHTML}));document.body.appendChild(e)},3500)</script>`;
const server = http.createServer((request, response) => {
  const pathname = new URL(request.url, 'http://localhost').pathname;
  const file = path.resolve(example, '.' + pathname);
  if (!file.startsWith(example + path.sep) || !fs.existsSync(file)) {
    response.writeHead(404).end();
    return;
  }
  const html = file.endsWith('.html');
  response.setHeader('Content-Type', html ? 'text/html; charset=utf-8' : file.endsWith('.js') ? 'application/javascript' : 'text/css');
  let content = fs.readFileSync(file);
  if (html) content = content.toString('utf8').replace('</body>', capture + '</body>');
  response.end(content);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const port = server.address().port;
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'klar-table-chrome-'));
fs.mkdirSync(output, { recursive: true });
const manifest = [];
try {
  for (const page of pages) {
    const dom = await new Promise((resolve, reject) => {
      const child = spawn(chrome, ['--headless=new', '--dump-dom', '--no-first-run', '--no-default-browser-check', '--disable-background-networking', '--disable-extensions', '--disable-features=Translate', '--run-all-compositor-stages-before-draw', '--disable-renderer-backgrounding', '--disable-background-timer-throttling', '--window-size=1440,1000', '--virtual-time-budget=6000', `--user-data-dir=${profile}`, `http://127.0.0.1:${port}${page.url}`], { windowsHide: true });
      let stdout = '';
      let stderr = '';
      const timeout = setTimeout(() => { child.kill(); reject(new Error(`Chrome timed out: ${page.name}`)); }, 45000);
      child.stdout.on('data', chunk => { stdout += chunk; });
      child.stderr.on('data', chunk => { stderr += chunk; });
      child.on('error', reject);
      child.on('close', code => {
        clearTimeout(timeout);
        if (code !== 0) reject(new Error(`Chrome failed (${code}): ${stderr.slice(-1500)}`));
        else resolve(stdout);
      });
    });
    const encoded = new RegExp(`<pre id="${marker}">([\\s\\S]*?)</pre>`).exec(dom)?.[1];
    if (!encoded) {
      fs.writeFileSync(path.join(output, page.name + '-failed.html'), dom);
      throw new Error(`No animation-frame capture on ${page.name}`);
    }
    const decoded = encoded.replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&amp;', '&');
    const tables = JSON.parse(decoded);
    const snapshot = JSON.stringify(tables, null, 2) + '\n';
    const filename = page.name + '.json';
    fs.writeFileSync(path.join(output, filename), snapshot);
    manifest.push({ page: page.name, tables: tables.length });
    if (baseline && fs.readFileSync(path.join(baseline, filename), 'utf8') !== snapshot) {
      throw new Error(`DOM differs: ${page.name}`);
    }
    console.log(`${page.name}: ${tables.length} table(s)${baseline ? ', identical' : ''}`);
  }
  const manifestText = JSON.stringify(manifest, null, 2) + '\n';
  fs.writeFileSync(path.join(output, 'manifest.json'), manifestText);
  if (baseline && fs.readFileSync(path.join(baseline, 'manifest.json'), 'utf8') !== manifestText) throw new Error('Route manifest differs');
  const count = manifest.reduce((sum, page) => sum + page.tables, 0);
  if (count === 0) throw new Error('No tables captured');
  console.log(`Captured ${count} tables across ${pages.length} pages.`);
} finally {
  server.close();
  // Chrome can briefly retain files in its temporary profile after exiting on Windows.
  try { fs.rmSync(profile, { recursive: true, force: true, maxRetries: 4, retryDelay: 150 }); } catch {}
}
