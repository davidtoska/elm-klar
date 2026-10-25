#!/usr/bin/env node
// Compile current public docs once, then run all documentation/API checks against
// that snapshot. Keep it private to this run; never reuse yesterday's docs.json.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { loadDocs, root } from './lib/klar-docs.mjs';

const docs = loadDocs();
const workspace = fs.mkdtempSync(path.join(os.tmpdir(), 'klar-documentation-'));
const snapshot = path.join(workspace, 'docs.json');
const checks = [
  ['check-docs.mjs'],
  ['gen-ai-docs.mjs', '--check'],
  ['check-ai-md.mjs'],
  ['check-ai-names.mjs'],
  ['check-doc-examples.mjs', '--strict'],
  ['check-api.mjs'],
];
let status = 0;
try {
  fs.writeFileSync(snapshot, JSON.stringify(docs));
  console.log(`Documentation: one fresh snapshot for ${docs.length} modules.`);
  for (const [script, ...args] of checks) {
    console.log(`\n${script}`);
    const run = spawnSync(process.execPath, [path.join(root, 'scripts', script), ...args, `--docs-file=${snapshot}`], { cwd: root, stdio: 'inherit' });
    if (run.status !== 0) {
      if (run.error) console.error(run.error.message);
      status = run.status ?? 1;
      break;
    }
  }
} finally {
  fs.rmSync(workspace, { recursive: true, force: true });
}
process.exitCode = status;
