#!/usr/bin/env node
// Compiles the showcase application to example/main.js.
//
//   node scripts/build-example.mjs              development build
//   node scripts/build-example.mjs --optimize   optimized build (for publishing the demo)

import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const optimize = process.argv.includes('--optimize');

const args = ['make', 'src/Main.elm', '--output=main.js'];
if (optimize) args.splice(2, 0, '--optimize');

const run = spawnSync('elm', args, { cwd: path.join(root, 'example'), stdio: 'inherit', shell: true });
if (run.status === 0) console.log('Built example/main.js. Open example/index.html (or run: npm start).');
process.exit(run.status ?? 1);
