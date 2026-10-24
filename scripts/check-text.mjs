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
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const fix = process.argv.includes('--fix');

const skipDirectories = new Set(['node_modules', 'elm-stuff', '.git', '.claude']);
const skipFiles = new Set(['example/main.js', 'calendar/main.js', 'calendar/server/data.json', 'example/docs.json', 'docs.json']);
const textExtensions = new Set([
  '.elm', '.css', '.md', '.json', '.mjs', '.js', '.html', '.yml', '.yaml', '.txt',
]);
const textNames = new Set(['.gitignore', '.gitattributes', 'LICENSE']);

const problems = [];

function isText(file) {
  const base = path.basename(file);
  return textNames.has(base) || textExtensions.has(path.extname(base));
}

function visit(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    const relative = path.relative(root, full).split(path.sep).join('/');
    if (entry.isDirectory()) {
      if (!skipDirectories.has(entry.name)) visit(full);
    } else if (!skipFiles.has(relative) && isText(relative)) {
      inspect(full, relative);
    }
  }
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

visit(root);

if (problems.length > 0) {
  console.error(problems.join('\n'));
  console.error(`\ntext: ${problems.length} file(s) to repair. Run: node scripts/check-text.mjs --fix`);
  process.exit(1);
}
if (!fix) console.log('text: ok (UTF-8, LF, newline at the end)');
