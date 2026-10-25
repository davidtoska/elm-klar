#!/usr/bin/env node
// Compiles the showcase application to example/main.js, and each complete example
// program in example/src/Examples/ to example/examples/<name>.js (opened from the
// Examples page of the showcase, or as example/examples/<name>.html).
//
//   node scripts/build-example.mjs              development build
//   node scripts/build-example.mjs --optimize   optimized build (for publishing the demo)

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dir = path.join(root, 'example');
const optimize = process.argv.includes('--optimize');

// Runtime copies of the generated reference, not another hand-written catalog.
// A plain HTML wrapper keeps the Markdown readable offline without a parser or CDN.
const referenceDir = path.join(dir, 'reference');
fs.mkdirSync(referenceDir, { recursive: true });
const referenceFiles = fs.readdirSync(path.join(root, 'ai/modules')).filter(file => /^Klar(?:\.[\w]+)*\.md$/.test(file));
const expectedReferences = new Set(referenceFiles.map(file => file.replace(/\.md$/, '.html')));
for (const file of fs.readdirSync(referenceDir)) {
  if (/^Klar(?:\.[\w]+)*\.html$/.test(file) && !expectedReferences.has(file)) fs.unlinkSync(path.join(referenceDir, file));
}
const escape = text => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
for (const file of referenceFiles) {
  const title = file.slice(0, -3);
  const markdown = fs.readFileSync(path.join(root, 'ai/modules', file), 'utf8');
  fs.writeFileSync(path.join(referenceDir, file.replace(/\.md$/, '.html')), `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escape(title)} reference</title><style>:root{color-scheme:light dark}body{max-width:1000px;margin:24px auto;padding:0 16px}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:14px/1.6 ui-monospace,monospace}</style><p>Generated from the public Elm documentation. Search this page with Ctrl+F.</p><pre>${escape(markdown)}</pre></html>\n`);
}

// Examples.EditForm -> edit-form
const slug = (name) => name.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase();

const builds = [['src/Main.elm', 'main.js']];
for (const file of fs.readdirSync(path.join(dir, 'src', 'Examples')).sort()) {
  if (file.endsWith('.elm')) builds.push([`src/Examples/${file}`, `examples/${slug(file.slice(0, -4))}.js`]);
}

for (const [source, output] of builds) {
  const args = ['make', source, `--output=${output}`];
  if (optimize) args.splice(2, 0, '--optimize');
  const run = spawnSync(['elm', ...args].join(' '), { cwd: dir, stdio: 'inherit', shell: true });
  if (run.status !== 0) process.exit(run.status ?? 1);
}
const calendarArgs = ['make', 'src/Main.elm', '--output=main.js'];
if (optimize) calendarArgs.splice(2, 0, '--optimize');
const calendarBuild = spawnSync(['elm', ...calendarArgs].join(' '), { cwd: path.join(root, 'apps/calendar'), stdio: 'inherit', shell: true });
if (calendarBuild.status !== 0) process.exit(calendarBuild.status ?? 1);
console.log(`Built the showcase, ${builds.length - 1} examples and the calendar. Run: npm start.`);
