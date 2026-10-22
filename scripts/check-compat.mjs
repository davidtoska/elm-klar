#!/usr/bin/env node
// Checks that the package builds with the oldest things it claims to support:
//
//   node scripts/check-compat.mjs
//
// 1. Elm 0.19.1 (the previous release of the compiler; the package says
//    "0.19.0 <= v < 0.20.0", so it must not need anything newer than 0.19.0).
// 2. The lowest version of every dependency that elm.json allows.
//
// It needs the network the first time (it installs `elm@0.19.1-5` from npm into the
// temporary directory and downloads the packages). Run it before a release.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const work = path.join(os.tmpdir(), 'klar-compat');
const isWindows = process.platform === 'win32';
fs.mkdirSync(work, { recursive: true });

function run(command, args, cwd) {
  const result = spawnSync(command, args, { cwd, encoding: 'utf8', shell: true });
  const text = ((result.stdout || '') + (result.stderr || '')).replace(/\r/g, '\n');
  return { ok: result.status === 0, text: text.split('\n').filter((l) => !/^(Compiling|Verifying)/.test(l)).join('\n').trim() };
}

// ---- the old compiler ---------------------------------------------------------------------
const compilerDir = path.join(work, 'elm-0.19.1');
const elm191 = path.join(compilerDir, 'node_modules', '.bin', isWindows ? 'elm.cmd' : 'elm');
if (!fs.existsSync(elm191)) {
  fs.mkdirSync(compilerDir, { recursive: true });
  fs.writeFileSync(path.join(compilerDir, 'package.json'), '{"private":true}');
  console.log('installing elm@0.19.1-5 ...');
  const install = run('npm', ['install', 'elm@0.19.1-5', '--no-audit', '--no-fund'], compilerDir);
  if (!install.ok) {
    console.log(install.text);
    process.exit(1);
  }
}
const quoted = `"${elm191}"`;

let failed = false;

// ---- 1. the package itself, with Elm 0.19.1 ---------------------------------------------------
const pkg = path.join(work, 'package');
fs.rmSync(pkg, { recursive: true, force: true });
fs.mkdirSync(pkg, { recursive: true });
fs.cpSync(path.join(root, 'src'), path.join(pkg, 'src'), { recursive: true });
fs.copyFileSync(path.join(root, 'elm.json'), path.join(pkg, 'elm.json'));
const build = run(quoted, ['make'], pkg);
const docs = run(quoted, ['make', '--docs=docs.json'], pkg);
console.log(`Elm 0.19.1, the package:          ${build.ok ? 'ok' : 'FAILED'}`);
console.log(`Elm 0.19.1, elm make --docs:      ${docs.ok ? 'ok' : 'FAILED'}`);
if (!build.ok) console.log(build.text.split('\n').slice(0, 40).join('\n'));
if (!docs.ok) console.log(docs.text.split('\n').slice(0, 40).join('\n'));
failed = failed || !build.ok || !docs.ok;

// ---- 2. the oldest allowed dependencies ----------------------------------------------------------
const outline = JSON.parse(fs.readFileSync(path.join(root, 'elm.json'), 'utf8'));
const modules = Array.isArray(outline['exposed-modules']) ? outline['exposed-modules'] : Object.values(outline['exposed-modules']).flat();
const lowest = {};
for (const [name, range] of Object.entries(outline.dependencies)) lowest[name] = range.split('<=')[0].trim();
const oldest = path.join(work, 'oldest');
fs.rmSync(oldest, { recursive: true, force: true });
fs.mkdirSync(path.join(oldest, 'src'), { recursive: true });
fs.writeFileSync(
  path.join(oldest, 'src', 'AllModules.elm'),
  `module AllModules exposing (main)\n\n${modules.map((m) => `import ${m}`).join('\n')}\nimport Html\n\n\nmain : Html.Html msg\nmain =\n    Html.text ""\n`,
);
fs.writeFileSync(
  path.join(oldest, 'elm.json'),
  JSON.stringify(
    {
      type: 'application',
      'source-directories': ['src', path.join(root, 'src').split(path.sep).join('/')],
      'elm-version': '0.19.1',
      // what the direct ones need themselves (elm/file needs elm/bytes, elm/html needs elm/virtual-dom)
      dependencies: { direct: lowest, indirect: { 'elm/bytes': '1.0.0', 'elm/virtual-dom': '1.0.2' } },
      'test-dependencies': { direct: {}, indirect: {} },
    },
    null,
    4,
  ),
);
const oldestBuild = run(quoted, ['make', 'src/AllModules.elm', '--output=out.js'], oldest);
console.log(`Oldest dependencies (${Object.entries(lowest).map(([n, v]) => `${n.replace('elm/', '')} ${v}`).join(', ')}): ${oldestBuild.ok ? 'ok' : 'FAILED'}`);
if (!oldestBuild.ok) console.log(oldestBuild.text.split('\n').slice(0, 40).join('\n'));
failed = failed || !oldestBuild.ok;

process.exit(failed ? 1 : 0);
