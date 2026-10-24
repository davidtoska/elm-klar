#!/usr/bin/env node
// The showcase application in example/ must use the library the way a user of the
// package does: through the exposed modules only. This script fails when
// example/src (or tests/, apart from the tests of internals) imports a Klar module
// that is not in "exposed-modules" of elm.json. The complete programs in
// example/src/Examples/ are what an application copies, so they may not use a class
// or a style of their own either.
//
//   node scripts/check-example-imports.mjs

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const outline = JSON.parse(fs.readFileSync(path.join(root, 'elm.json'), 'utf8'));
const exposed = new Set(
  Array.isArray(outline['exposed-modules']) ? outline['exposed-modules'] : Object.values(outline['exposed-modules']).flat(),
);

function walk(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(p));
    else if (entry.name.endsWith('.elm')) out.push(p);
  }
  return out;
}

const problems = [];
for (const file of walk(path.join(root, 'example', 'src'))) {
  const text = fs.readFileSync(file, 'utf8');
  if (file.includes(path.join('src', 'Examples') + path.sep) && /Html\.Attributes\.(class|style)\b|import Html\.Attributes exposing \([^)]*\b(class|style)\b/.test(text)) {
    problems.push(`${path.relative(root, file)}: uses class or style`);
  }
  const lines = text.split('\n');
  lines.forEach((line, index) => {
    const m = /^import\s+(Klar(?:\.[A-Z]\w*)*)\b/.exec(line);
    if (m && !exposed.has(m[1])) {
      problems.push(`${path.relative(root, file)}:${index + 1}: imports ${m[1]}, which the package does not expose`);
    }
  });
}

if (problems.length > 0) {
  console.log(problems.join('\n'));
  process.exit(1);
}
console.log('example imports: ok (only exposed modules)');
