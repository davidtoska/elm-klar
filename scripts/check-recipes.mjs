#!/usr/bin/env node
// Compiles every recipe in recipes/ and the application template in template/.
//
//   node scripts/check-recipes.mjs               compile all (elm make --optimize)
//   node scripts/check-recipes.mjs inbox form    compile just these folders of recipes/
//
// A recipe is a folder with elm.json (its source directories point at the package), src/Main.elm
// and README.md. The script also checks that a recipe imports only exposed Klar modules and
// lists the `-- KLAR GAP:` comments it found (a place where Klar lacked something).

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { readElmJson, root } from './lib/klar-docs.mjs';

const exposed = new Set(
  Array.isArray(readElmJson()['exposed-modules']) ? readElmJson()['exposed-modules'] : Object.values(readElmJson()['exposed-modules']).flat(),
);

const requested = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const recipesDir = path.join(root, 'recipes');
const folders = [];
if (fs.existsSync(recipesDir)) {
  for (const entry of fs.readdirSync(recipesDir, { withFileTypes: true })) {
    if (entry.isDirectory() && (requested.length === 0 || requested.includes(entry.name))) folders.push(path.join('recipes', entry.name));
  }
}
if (requested.length === 0) folders.push('template');
folders.sort();

function elmFiles(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...elmFiles(p));
    else if (entry.name.endsWith('.elm')) out.push(p);
  }
  return out;
}

let failed = false;
const gaps = [];
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'klar-recipes-'));

for (const folder of folders) {
  const dir = path.join(root, folder);
  const problems = [];
  for (const required of ['elm.json', 'README.md', 'src/Main.elm']) {
    if (!fs.existsSync(path.join(dir, required))) problems.push(`missing ${required}`);
  }
  if (problems.length === 0) {
    const elmJson = JSON.parse(fs.readFileSync(path.join(dir, 'elm.json'), 'utf8'));
    if (!elmJson.dependencies?.direct?.['elm/url']) problems.push('elm.json: elm/url must be a direct dependency');
    const toPackage = path.relative(dir, path.join(root, 'src')).split(path.sep).join('/');
    if (!elmJson['source-directories']?.includes(toPackage)) problems.push(`elm.json: source-directories must include "${toPackage}"`);
    for (const file of elmFiles(path.join(dir, 'src'))) {
      const text = fs.readFileSync(file, 'utf8');
      for (const m of text.matchAll(/^import\s+(Klar[\w.]*)/gm)) {
        if (!exposed.has(m[1])) problems.push(`${path.relative(root, file)}: imports ${m[1]}, which is not an exposed module`);
      }
      if (/Html\.Attributes\.(class|style)\b|import Html\.Attributes exposing \([^)]*\b(class|style)\b/.test(text)) {
        problems.push(`${path.relative(root, file)}: uses class or style`);
      }
      text.split('\n').forEach((line, i) => {
        const g = /--\s*KLAR GAP:\s*(.*)$/.exec(line);
        if (g) gaps.push(`${path.relative(root, file).split(path.sep).join('/')}:${i + 1}: ${g[1]}`);
      });
    }
  }
  if (problems.length === 0) {
    const out = path.join(tmp, folder.replace(/[\\/]/g, '-') + '.js');
    const run = spawnSync(`elm make src/Main.elm --optimize --output="${out}"`, { cwd: dir, encoding: 'utf8', shell: true });
    if (run.status !== 0) {
      problems.push('elm make failed:\n' + ((run.stdout || '') + (run.stderr || '')).replace(/\u001b\[[0-9;]*m/g, '').replace(/^Compiling.*$/gm, '').trim());
    }
  }
  if (problems.length > 0) {
    failed = true;
    console.log(`FAIL ${folder}`);
    for (const p of problems) console.log('  ' + p.split('\n').join('\n  '));
  } else {
    console.log(`ok   ${folder}`);
  }
}
fs.rmSync(tmp, { recursive: true, force: true });

if (gaps.length > 0) {
  console.log(`\nKLAR GAP comments (${gaps.length}):`);
  for (const g of gaps) console.log('  ' + g);
}
console.log(failed ? '\nRecipes: FAILED' : `\nRecipes: ${folders.length} compiled`);
process.exit(failed ? 1 : 0);
