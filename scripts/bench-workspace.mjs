#!/usr/bin/env node
// Builds the folder a fresh AI session is given for one benchmark run (see bench/run.md).
//
//   node scripts/bench-workspace.mjs <out directory> [T01 T02 ...]
//
// The folder holds only what the builder may read: the package (`klar/`: src for the compiler,
// elm.json, AI.md, llms.txt, ai/, USING.md, recipes/, template/ and check-app.mjs) and an empty
// application (`app/`) with an elm.json that lists elm/url as a direct dependency, an index.html,
// a CLAUDE.md with the paragraph from USING.md, and BRIEF.md with the tasks. It never contains
// apps/, example/, design/, tests/, ROADMAP.md or any friction log.
//
// Without task ids the brief holds all twelve tasks.

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { root } from './lib/klar-docs.mjs';

const args = process.argv.slice(2);
const out = args.find((a) => !/^T\d\d$/.test(a));
const wanted = args.filter((a) => /^T\d\d$/.test(a));
if (!out) {
  console.log('usage: node scripts/bench-workspace.mjs <out directory> [T01 T02 ...]');
  process.exit(2);
}
const target = path.resolve(out);
if (fs.existsSync(target) && fs.readdirSync(target).length > 0) {
  console.error(`${target} is not empty; choose a new directory.`);
  process.exit(1);
}

const skip = new Set(['elm-stuff', 'node_modules', '.git', 'main.js']);
function copy(from, to) {
  const stat = fs.statSync(from);
  if (stat.isDirectory()) {
    fs.mkdirSync(to, { recursive: true });
    for (const name of fs.readdirSync(from)) if (!skip.has(name)) copy(path.join(from, name), path.join(to, name));
  } else fs.copyFileSync(from, to);
}

const klar = path.join(target, 'klar');
for (const item of ['src', 'elm.json', 'AI.md', 'llms.txt', 'USING.md', 'recipes', 'template']) copy(path.join(root, item), path.join(klar, item));
copy(path.join(root, 'ai'), path.join(klar, 'ai'));
for (const dev of ['doc-example-report.md', 'index-report.md']) fs.rmSync(path.join(klar, 'ai', dev), { force: true });
fs.mkdirSync(path.join(klar, 'scripts'), { recursive: true });
fs.copyFileSync(path.join(root, 'scripts', 'check-app.mjs'), path.join(klar, 'scripts', 'check-app.mjs'));

// the tasks
const tasksText = fs.readFileSync(path.join(root, 'bench', 'tasks.md'), 'utf8');
const [head, ...rest] = tasksText.split(/^## (?=T\d\d\. )/m);
const sections = rest.filter((s) => wanted.length === 0 || wanted.includes(s.slice(0, 3)));
// the builder is not told which modules the scorer expects
const stripped = sections.map((s) => '## ' + s.replace(/\nReference modules:[^\n]*\n?/g, '\n').replace(/\n{3,}/g, '\n\n').trimEnd() + '\n');
const headWithoutReferences = head
  .replace(/Each task lists, for the person who scores[\s\S]*$/, '')
  .replace(' (the builder is told once, see [run.md](run.md))', '')
  .trimEnd();

const app = path.join(target, 'app');
fs.mkdirSync(path.join(app, 'src'), { recursive: true });
fs.writeFileSync(
  path.join(app, 'BRIEF.md'),
  [
    headWithoutReferences,
    '',
    'Klar is in `../klar`. Start with `../klar/AI.md`. Build each task in its own folder under this one',
    '(`t01/`, `t02/` ...), each with `elm.json` copied from this folder, `src/Main.elm` and `index.html`.',
    '',
    ...stripped,
  ].join('\n'),
);
fs.writeFileSync(
  path.join(app, 'elm.json'),
  JSON.stringify(
    {
      type: 'application',
      'source-directories': ['src', '../../klar/src'],
      'elm-version': '0.19.3',
      dependencies: {
        direct: {
          'elm/browser': '1.0.2',
          'elm/core': '1.0.5',
          'elm/file': '1.0.5',
          'elm/html': '1.0.1',
          'elm/json': '1.1.4',
          'elm/time': '1.0.0',
          'elm/url': '1.0.0',
        },
        indirect: { 'elm/bytes': '1.0.8', 'elm/virtual-dom': '1.0.5' },
      },
      'test-dependencies': { direct: {}, indirect: {} },
    },
    null,
    4,
  ) + '\n',
);
fs.rmSync(path.join(app, 'src'), { recursive: true });
fs.writeFileSync(
  path.join(app, 'index.html'),
  '<!DOCTYPE html>\n<html lang="en">\n<head>\n  <meta charset="utf-8">\n  <meta name="viewport" content="width=device-width, initial-scale=1">\n  <title>Klar benchmark</title>\n</head>\n<body>\n  <script src="main.js"></script>\n  <script>Elm.Main.init();</script>\n</body>\n</html>\n',
);
const usingText = fs.readFileSync(path.join(root, 'USING.md'), 'utf8');
const paragraph = /> This application uses Klar[\s\S]*?LIBRARY-REQUESTS\.md`\./.exec(usingText);
fs.writeFileSync(
  path.join(app, 'CLAUDE.md'),
  [
    '# Benchmark application',
    '',
    paragraph ? paragraph[0].replace(/vendor\/klar/g, '../klar').replace(/^\s*> ?/gm, '') : 'Use only exposed Klar modules. Read ../klar/AI.md first.',
    '',
    'Read only `../klar/AI.md`, `../klar/llms.txt`, `../klar/ai/`, `../klar/USING.md`, `../klar/recipes/` and `../klar/template/`.',
    'Do not open `../klar/src/` (the compiler needs it, you do not), and do not look for other folders.',
    'Tasks are in `BRIEF.md`. Verify imports, from this folder, with `node ../klar/scripts/check-app.mjs ../klar tXX/src`.',
    '',
  ].join('\n'),
);
const lock = spawnSync(process.execPath, [path.join(klar, 'scripts', 'check-app.mjs'), klar, '--write-lock'], { cwd: app, encoding: 'utf8' });
if (lock.status !== 0) {
  console.error(lock.stdout + lock.stderr);
  process.exit(1);
}
console.log(`Workspace written to ${target}: klar/ (what the builder may read) and app/ (BRIEF.md, CLAUDE.md, elm.json, index.html). ${sections.length} task(s) in the brief.`);
