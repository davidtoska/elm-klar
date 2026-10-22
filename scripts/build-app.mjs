#!/usr/bin/env node
// Compiles one of the A0 applications in apps/<name> to apps/<name>/main.js.
//
//   node scripts/build-app.mjs fulfilment              development build
//   node scripts/build-app.mjs fulfilment --optimize   optimized build

import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const name = process.argv[2];
if (!name || name.startsWith('--')) {
  console.log('usage: node scripts/build-app.mjs <app> [--optimize]');
  process.exit(2);
}
const optimize = process.argv.includes('--optimize');

const args = ['make', 'src/Main.elm', '--output=main.js'];
if (optimize) args.splice(2, 0, '--optimize');

const run = spawnSync('elm', args, { cwd: path.join(root, 'apps', name), stdio: 'inherit', shell: true });
if (run.status === 0) console.log(`Built apps/${name}/main.js. Open apps/${name}/index.html.`);
process.exit(run.status ?? 1);
