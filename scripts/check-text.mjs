#!/usr/bin/env node
// Keeps the text files of the repository plain: UTF-8 without a byte order mark, LF line
// endings and a newline at the end of the file.
//
//   node scripts/check-text.mjs          list the files that break the rules, fail if there are any
//   node scripts/check-text.mjs --fix    repair them in place
//
// Windows editors and `Set-Content` like to add a byte order mark or CRLF. A mark in the middle
// of a bundled stylesheet silently disables the first rule after it, and `elm-format --validate`
// disagrees about CRLF between machines, so both are caught here.

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fix = process.argv.includes('--fix');

const textExtensions = new Set([
  '.elm', '.css', '.md', '.json', '.mjs', '.js', '.html', '.yml', '.yaml', '.txt', '.go', '.mod', '.sum',
]);
const textNames = new Set(['.gitignore', '.gitattributes', 'LICENSE']);

const problems = [];

function isText(file) {
  const base = path.basename(file);
  return textNames.has(base) || textExtensions.has(path.extname(base));
}

function inspect(full, relative) {
  const bytes = fs.readFileSync(full);
  if (bytes.length === 0) return;
  let text = bytes.toString('utf8');
  const found = [];

  if (text.charCodeAt(0) === 0xfeff) {
    found.push('byte order mark');
    text = text.slice(1);
  }
  if (text.includes('\r')) {
    found.push('CRLF line endings');
    text = text.replace(/\r\n?/g, '\n');
  }
  if (!text.endsWith('\n')) {
    found.push('no newline at the end');
    text += '\n';
  }
  if (found.length === 0) return;

  if (fix) {
    fs.writeFileSync(full, text, 'utf8');
    console.log(`fixed ${relative}: ${found.join(', ')}`);
  } else {
    problems.push(`${relative}: ${found.join(', ')}`);
  }
}

// Check repository sources, including new files, without entering ignored build
// output or app-local toolchains. Tracked files remain checked even if ignored.
const inventory = spawnSync('git', ['ls-files', '--cached', '--others', '--exclude-standard', '-z'], { cwd: root, encoding: 'utf8' });
if (inventory.status !== 0) {
  console.error(inventory.stderr || 'Could not list repository files with git ls-files.');
  process.exit(1);
}
for (const relative of new Set(inventory.stdout.split('\0').filter(Boolean))) {
  const full = path.join(root, relative);
  if (isText(relative) && fs.existsSync(full) && fs.statSync(full).isFile()) inspect(full, relative);
}

if (problems.length > 0) {
  console.error(problems.join('\n'));
  console.error(`\ntext: ${problems.length} file(s) to repair. Run: node scripts/check-text.mjs --fix`);
  process.exit(1);
}
if (!fix) console.log('text: ok (UTF-8, LF, newline at the end)');
