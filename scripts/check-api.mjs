#!/usr/bin/env node
// Checks the public API for types that a user cannot see.
//
//   node scripts/check-api.mjs
//
// Builds the documentation (`elm make --docs`) and reads every type that appears in an
// exposed signature, alias or constructor. A type of a Klar module that the module does
// not export (or a module that is not in "exposed-modules") could be used but not named,
// imported or read about, so it is a mistake. Also lists the exposed unions whose
// constructors are public: adding a constructor to one is a breaking change, so there
// should be few of them and they should be small, closed vocabularies.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const docsFile = path.join(os.tmpdir(), 'klar-api-docs.json');
const run = spawnSync('elm', ['make', `--docs=${docsFile}`], { cwd: root, encoding: 'utf8', shell: true });
if (run.status !== 0) {
  console.log((run.stdout || '') + (run.stderr || ''));
  process.exit(1);
}
const docs = JSON.parse(fs.readFileSync(docsFile, 'utf8'));

// every type that an exposed module defines: "Module.Name"
const defined = new Set();
for (const mod of docs) {
  for (const a of mod.aliases) defined.add(`${mod.name}.${a.name}`);
  for (const u of mod.unions) defined.add(`${mod.name}.${u.name}`);
}
const exposedModules = new Set(docs.map((mod) => mod.name));

const hidden = new Map(); // "Module.Type" -> places
function check(typeText, place) {
  for (const m of typeText.matchAll(/\b((?:[A-Z][A-Za-z0-9_]*\.)+)([A-Z][A-Za-z0-9_]*)\b/g)) {
    const moduleName = m[1].slice(0, -1);
    if (!moduleName.startsWith('Klar')) continue;
    const key = `${moduleName}.${m[2]}`;
    const known = exposedModules.has(moduleName) && defined.has(key);
    if (!known) {
      if (!hidden.has(key)) hidden.set(key, []);
      hidden.get(key).push(place);
    }
  }
}

const openUnions = [];
for (const mod of docs) {
  for (const v of mod.values) check(v.type, `${mod.name}.${v.name}`);
  for (const a of mod.aliases) check(a.type, `${mod.name}.${a.name}`);
  for (const b of mod.binops) check(b.type, `${mod.name}.${b.name}`);
  for (const u of mod.unions) {
    for (const [, args] of u.cases) for (const arg of args) check(arg, `${mod.name}.${u.name}`);
    if (u.cases.length > 0) openUnions.push(`${mod.name}.${u.name} (${u.cases.length})`);
  }
}

let failed = false;
if (hidden.size > 0) {
  failed = true;
  console.log('Types in the public API that no exposed module exports:');
  for (const [type, places] of hidden) console.log(`  ${type}\n      used by ${[...new Set(places)].slice(0, 6).join(', ')}`);
}
console.log(`\nExposed unions with public constructors (${openUnions.length}):\n  ${openUnions.join('\n  ')}`);
if (!failed) console.log('\napi: ok (every type in a public signature can be named by a user)');
process.exit(failed ? 1 : 0);
