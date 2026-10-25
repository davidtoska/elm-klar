#!/usr/bin/env node
// Checks the hand-written AI entry points.
//
//   node scripts/check-ai-md.mjs
//
// Keep AI.md short and check local links in the hand-written guides.
// The generated index owns module coverage. Complete programs live in
// example/src/Examples/ and are compiled by build-example.mjs; any complete
// Markdown programs are compiled by check-ai-names.mjs.
//
// It is part of `npm run check:ai-docs`, next to the staleness check of the generated files.

import fs from 'node:fs';
import path from 'node:path';
import { root } from './lib/klar-docs.mjs';

const problems = [];
const aiFile = path.join(root, 'AI.md');
if (!fs.existsSync(aiFile)) {
  console.log('AI.md: missing');
  process.exit(1);
}
const ai = fs.readFileSync(aiFile, 'utf8');
const lineCount = ai.split('\n').length - 1;
if (lineCount > 150) problems.push(`AI.md has ${lineCount} lines; keep the entry point within 150`);

function checkLinks(file) {
  const text = fs.readFileSync(path.join(root, file), 'utf8')
    .replace(/```[\s\S]*?```/g, '')
    .replace(/`[^`\n]+`/g, '');
  const links = [...text.matchAll(/\]\(([^)#\s]+)(?:#[^)]*)?\)/g)].map((m) => m[1]);
  for (const link of links) {
    if (/^https?:/.test(link)) continue;
    if (!fs.existsSync(path.resolve(root, path.dirname(file), link))) problems.push(`${file}: the link ${link} points at nothing`);
  }
}
const guides = ['AI.md', 'README.md', 'AGENTS.md', 'CLAUDE.md', 'ROADMAP.md', 'CHANGELOG.md', 'example/APPLICATIONS.md', 'example/WORKFLOWS.md', 'example/ORDERS.md', 'example/HTTP.md', 'apps/calendar/README.md'];
for (const file of guides) checkLinks(file);

if (problems.length > 0) {
  console.log(`AI.md: ${problems.length} problem(s)`);
  for (const p of problems) console.log('  - ' + p.split('\n').join('\n    '));
  process.exit(1);
}
console.log(`Guides: ok (AI.md: ${lineCount} lines; local links resolve in ${guides.length} guides)`);
