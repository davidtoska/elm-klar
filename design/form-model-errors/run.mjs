#!/usr/bin/env node
// Compiles every case in cases/ and prints the compiler's own words.
//
//   node design/form-model-errors/run.mjs            all cases
//   node design/form-model-errors/run.mjs A_FieldNotInFields
//
// "Good" must compile; the other cases are mistakes made on purpose (D compiles too: that is
// the point of case D). Not part of `npm run check`.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const only = process.argv.slice(2);
const names = fs.readdirSync(path.join(here, 'cases')).filter((f) => f.endsWith('.elm')).map((f) => f.slice(0, -4)).sort();
for (const name of names) {
  if (only.length > 0 && !only.includes(name)) continue;
  const run = spawnSync('npx', ['elm', 'make', `cases/${name}.elm`, '--output=/dev/null'], { cwd: here, encoding: 'utf8', shell: true });
  const text = ((run.stdout || '') + (run.stderr || '')).replace(/\[[0-9;]*m/g, '').replace(/^[\s\S]*?(?=(-- [A-Z ]+ -|Success!))/, '');
  console.log(`===== ${name}: ${run.status === 0 ? 'COMPILES' : 'DOES NOT COMPILE'}`);
  console.log(text.trim() + '\n');
}
