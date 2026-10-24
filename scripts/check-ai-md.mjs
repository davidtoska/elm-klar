#!/usr/bin/env node
// Checks the hand-written AI entry points.
//
//   node scripts/check-ai-md.mjs
//
// 1. AI.md exists, has fewer than 400 lines and names every exposed module (as `Name` or Klar.Name).
// 2. The links of AI.md point at files that exist.
// 3. The complete program in AI.md (the first elm block that starts with `module Main`) compiles
//    in a scratch project with the dependencies of example/elm.json.
//
// It is part of `npm run check:ai-docs`, next to the staleness check of the generated files.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { moduleGroups, root } from './lib/klar-docs.mjs';

const problems = [];
const aiFile = path.join(root, 'AI.md');
if (!fs.existsSync(aiFile)) {
  console.log('AI.md: missing');
  process.exit(1);
}
const ai = fs.readFileSync(aiFile, 'utf8');
const lineCount = ai.split('\n').length - 1;
if (lineCount >= 400) problems.push(`AI.md has ${lineCount} lines; the limit is under 400`);

for (const name of moduleGroups().keys()) {
  const short = name.replace(/^Klar\./, '');
  if (name === 'Klar') {
    if (!/Klar\.stylesheet/.test(ai)) problems.push('AI.md does not mention Klar.stylesheet');
    continue;
  }
  const found = ai.includes('`' + short + '`') || ai.includes('`' + name + '`') || ai.includes(name + '.') && new RegExp('Klar\\.' + short.replace('.', '\\.') + '\\b').test(ai);
  if (!found) problems.push(`AI.md does not mention the module ${name}`);
}

function checkLinks(file) {
  const text = fs.readFileSync(path.join(root, file), 'utf8');
  const links = [...text.matchAll(/\]\(([^)#\s]+)(?:#[^)]*)?\)/g)].map((m) => m[1]);
  // AI.md also uses plain paths in the "Read in this order" lists
  for (const link of links) {
    if (/^https?:/.test(link)) continue;
    if (!fs.existsSync(path.join(root, link))) problems.push(`${file}: the link ${link} points at nothing`);
  }
}
checkLinks('AI.md');

const match = /```elm\n(module Main[\s\S]*?)\n```/.exec(ai);
if (!match) {
  problems.push('AI.md has no complete program (an elm block that starts with `module Main`)');
} else {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), 'klar-ai-md-'));
  fs.mkdirSync(path.join(workspace, 'src'));
  const elmJson = JSON.parse(fs.readFileSync(path.join(root, 'example', 'elm.json'), 'utf8'));
  elmJson['source-directories'] = ['src', path.join(root, 'src')];
  fs.writeFileSync(path.join(workspace, 'elm.json'), JSON.stringify(elmJson, null, 4));
  fs.writeFileSync(path.join(workspace, 'src', 'Main.elm'), match[1] + '\n');
  const run = spawnSync(`elm make src/Main.elm --optimize --output="${path.join(workspace, 'main.js')}"`, { cwd: workspace, encoding: 'utf8', shell: true });
  if (run.status !== 0) {
    problems.push('the program in AI.md does not compile:\n' + ((run.stdout || '') + (run.stderr || '')).replace(/\u001b\[[0-9;]*m/g, '').replace(/^Compiling.*$/gm, '').trim());
  }
  fs.rmSync(workspace, { recursive: true, force: true });
}

if (problems.length > 0) {
  console.log(`AI.md: ${problems.length} problem(s)`);
  for (const p of problems) console.log('  - ' + p.split('\n').join('\n    '));
  process.exit(1);
}
console.log(`AI.md: ok (${lineCount} lines, every module named, links resolve, the program compiles)`);
