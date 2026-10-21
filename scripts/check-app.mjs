#!/usr/bin/env node
// Keeps an application honest about the Klar it uses before the package is published
// (Klar in a git submodule or a copy, listed in "source-directories"). Two checks:
//
//   1. the application imports only modules that Klar exposes (a source directory also
//      lets it import Klar.Internal and the other internals, which a real package would
//      not allow);
//   2. the copy of Klar has not been changed: a fingerprint of its src/ and elm.json is
//      compared with the one in klar.lock (so a changed component shows up as a
//      failing check, not as a surprise in a diff).
//
//   node check-app.mjs <klar directory> <application src directory>...   check
//   node check-app.mjs <klar directory> --write-lock                     accept this Klar
//
// The lock file, klar.lock, is written to and read from the current directory. Copy this
// script into the application; it needs only Node.

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const writeLock = args.includes('--write-lock');
const [klarDir, ...appDirs] = args.filter((arg) => !arg.startsWith('--'));
if (!klarDir || (!writeLock && appDirs.length === 0)) {
  console.log('usage: node check-app.mjs <klar directory> <application src directory>...\n       node check-app.mjs <klar directory> --write-lock');
  process.exit(2);
}

function walk(dir, extension) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(p, extension));
    else if (entry.name.endsWith(extension)) out.push(p);
  }
  return out.sort();
}

// the fingerprint: the paths and the bytes (line endings made equal) of src/**/*.elm and elm.json
function fingerprint() {
  const hash = crypto.createHash('sha256');
  const files = [...walk(path.join(klarDir, 'src'), '.elm'), path.join(klarDir, 'elm.json')];
  for (const file of files) {
    hash.update(path.relative(klarDir, file).split(path.sep).join('/') + '\n');
    hash.update(fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n'));
  }
  return hash.digest('hex');
}

const lockFile = path.join(process.cwd(), 'klar.lock');

if (writeLock) {
  fs.writeFileSync(lockFile, fingerprint() + '\n');
  console.log(`klar.lock written for ${klarDir}`);
  process.exit(0);
}

const problems = [];

// 1. imports
const outline = JSON.parse(fs.readFileSync(path.join(klarDir, 'elm.json'), 'utf8'));
const exposed = new Set(
  Array.isArray(outline['exposed-modules']) ? outline['exposed-modules'] : Object.values(outline['exposed-modules']).flat(),
);
for (const dir of appDirs) {
  for (const file of walk(dir, '.elm')) {
    fs.readFileSync(file, 'utf8')
      .split('\n')
      .forEach((line, index) => {
        const m = /^import\s+(Klar(?:\.[A-Z]\w*)*)\b/.exec(line);
        if (m && !exposed.has(m[1])) problems.push(`${file}:${index + 1}: imports ${m[1]}, which Klar does not expose`);
      });
  }
}

// 2. the copy of Klar is the one that was accepted
if (!fs.existsSync(lockFile)) {
  problems.push('klar.lock is missing: run  node check-app.mjs <klar directory> --write-lock  once, and commit it');
} else if (fs.readFileSync(lockFile, 'utf8').trim() !== fingerprint()) {
  problems.push(
    `${klarDir} is not the version in klar.lock. Klar is frozen: change it in its own repository and update the submodule, ` +
      'or run --write-lock if this is a deliberate upgrade',
  );
}

if (problems.length > 0) {
  console.log(problems.join('\n'));
  process.exit(1);
}
console.log('app: ok (only exposed Klar modules, and Klar is the locked version)');
