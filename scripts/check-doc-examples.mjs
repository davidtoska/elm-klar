#!/usr/bin/env node
// Compiles the code examples of the documentation.
//
//   node scripts/check-doc-examples.mjs            compile and print the summary
//   node scripts/check-doc-examples.mjs --strict   also exit with 1 when a complete example does not compile
//
// Every indented code block in the documentation of an exposed module (the module comment and the
// comment of each name) is sorted into one of four kinds:
//
//   compiled   a complete set of top-level declarations (a type annotation followed by its
//              definition, or a type declaration, optionally after `module` / `import` lines),
//              compiled in a scratch project with the imports it needs added from the names it
//              uses (`Table.` -> `import Klar.Table as Table`).
//   failed     complete, and the compiler rejects it for a reason that is not a missing name of
//              the application. These are mistakes in the documentation.
//   context    complete, but it uses names of the application (`Model`, `Msg`, `Order` ...) that
//              the example does not define, or a package the scratch project does not have.
//   fragment   not a set of declarations (an expression, a case branch, a comment): skipped.
//
// The scratch project lives in the OS temp directory; nothing in the repository changes except
// the report. Run `npm run gen:ai-docs` is unrelated; this script reads `elm make --docs` itself.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { codeBlocks, loadDocs, moduleGroups, root } from './lib/klar-docs.mjs';

const strict = process.argv.includes('--strict');

// ------------------------------------------------------------------ the blocks

function collectBlocks(docs) {
  const blocks = [];
  for (const m of docs) {
    if (/^Klar\.Icon\./.test(m.name) && m.name !== 'Klar.Icon.Library') continue;
    const sources = [{ owner: `${m.name}`, comment: m.comment }];
    for (const v of m.values) sources.push({ owner: `${m.name}.${v.name}`, comment: v.comment });
    for (const u of m.unions) sources.push({ owner: `${m.name}.${u.name}`, comment: u.comment });
    for (const a of m.aliases) sources.push({ owner: `${m.name}.${a.name}`, comment: a.comment });
    for (const s of sources) {
      for (const b of codeBlocks(s.comment)) blocks.push({ owner: s.owner, module: m.name, code: b.code.replace(/\s+$/, ''), line: b.line });
    }
  }
  return blocks;
}

// A block is complete when every line that starts in column 0 starts a declaration, and at
// least one annotation is followed by its definition (or a type is declared).
function classify(code) {
  if (/^\s*\.\.\.\s*$/m.test(code)) return 'fragment'; // an elision on purpose
  const lines = code.split('\n');
  const top = lines.filter((l) => l.trim() !== '' && !/^\s/.test(l));
  if (top.length === 0) return 'fragment';
  let annotated = false;
  let sawType = false;
  for (const l of top) {
    if (/^(module|import|port)\s/.test(l) || /^--/.test(l) || /^\{-/.test(l) || /^-\}/.test(l)) continue;
    if (/^type(\s+alias)?\s+[A-Z]/.test(l)) {
      sawType = true;
      continue;
    }
    if (/^[a-z_][\w']*\s*:/.test(l)) {
      annotated = true;
      continue;
    }
    if (/^[a-z_][\w']*(\s+[^=]*)?=(\s|$)/.test(l) || /^\(.*\)\s*=/.test(l)) continue;
    return 'fragment';
  }
  const names = [...code.matchAll(/^([a-z_][\w']*)\s*:/gm)].map((m) => m[1]);
  const defined = names.some((n) => new RegExp('^' + n + "(\\s[^:]*)?=", 'm').test(code));
  return (annotated && defined) || sawType || /^module\s/m.test(code) ? 'complete' : 'fragment';
}

// ----------------------------------------------------------------- the imports

const CORE_ALIASES = {
  Html: 'import Html',
  Attr: 'import Html.Attributes as Attr',
  Attributes: 'import Html.Attributes as Attributes',
  Events: 'import Html.Events as Events',
  Decode: 'import Json.Decode as Decode',
  D: 'import Json.Decode as D',
  Encode: 'import Json.Encode as Encode',
  E: 'import Json.Encode as E',
  Time: 'import Time',
  Task: 'import Task',
  Process: 'import Process',
  Browser: 'import Browser',
  Nav: 'import Browser.Navigation as Nav',
  Dom: 'import Browser.Dom as Dom',
  Events_: 'import Browser.Events',
  Url: 'import Url',
  Dict: 'import Dict exposing (Dict)',
  Set: 'import Set exposing (Set)',
  Array: 'import Array exposing (Array)',
  Http: 'import Http',
  Parser: 'import Parser',
  Bitwise: 'import Bitwise',
};
const CORE_MODULES = new Set(['List', 'Maybe', 'Result', 'String', 'Char', 'Tuple', 'Basics', 'Platform', 'Cmd', 'Sub', 'Debug']);

function aliasTable(exposedNames) {
  const table = new Map();
  for (const name of exposedNames) {
    if (name === 'Klar') continue;
    const last = name.split('.').pop();
    const better = !table.has(last) || (table.get(last).startsWith('Klar.Icon.') && !name.startsWith('Klar.Icon.'));
    if (better) table.set(last, name);
  }
  table.set('Fm', 'Klar.Form.Model');
  return table;
}

function withImports(code, table, moduleName) {
  const lines = code.split('\n');
  const imports = lines.filter((l) => /^import\s/.test(l));
  const body = lines.filter((l) => !/^import\s/.test(l) && !/^module\s/.test(l));
  const already = new Set();
  for (const l of imports) {
    const m = /^import\s+([\w.]+)(?:\s+as\s+(\w+))?/.exec(l);
    if (m) already.add(m[2] || m[1].split('.').pop()), already.add(m[1]);
  }
  const text = body.join('\n').replace(/"(?:[^"\\]|\\.)*"/g, '""').replace(/--[^\n]*/g, '');
  const added = [];
  const used = new Set([...text.matchAll(/(?<![\w.])([A-Z]\w*)\.[a-zA-Z]/g)].map((m) => m[1]));
  for (const alias of used) {
    if (already.has(alias) || CORE_MODULES.has(alias)) continue;
    if (table.has(alias)) {
      const full = table.get(alias);
      added.push(alias === 'Fm' ? `import ${full} as Fm` : `import ${full} as ${alias}`);
    } else if (CORE_ALIASES[alias]) added.push(CORE_ALIASES[alias]);
    already.add(alias);
  }
  if (/(?<![\w.])Html\b(?!\.)/.test(text) && !imports.some((l) => /Html\s+exposing/.test(l))) added.push('import Html exposing (Html)');
  if (/\b(NotAsked|Loading|Loaded|Failed)\b/.test(text) && !imports.some((l) => /Remote/.test(l) && /exposing/.test(l))) {
    added.push('import Klar.Remote exposing (Remote(..))');
  }
  const header = `module ${moduleName} exposing (..)`;
  return [header, '', ...imports, ...added, '', ...body].join('\n') + '\n';
}

// ------------------------------------------------------------------- compiling

function messageText(problem) {
  return problem.message.map((part) => (typeof part === 'string' ? part : part.string)).join('');
}

function compileAll(entries, workspace) {
  const result = new Map(); // module -> [{title, text}]
  const src = path.join(workspace, 'src');
  fs.rmSync(src, { recursive: true, force: true });
  fs.mkdirSync(src, { recursive: true });
  for (const e of entries) fs.writeFileSync(path.join(src, `${e.module}.elm`), e.source);
  const files = entries.map((e) => `"src/${e.module}.elm"`).join(' ');
  const out = path.join(workspace, 'out.js');
  const run = spawnSync(`elm make ${files} --report=json --output=/dev/null`, { cwd: workspace, encoding: 'utf8', shell: true, maxBuffer: 256 * 1024 * 1024 });
  const text = (run.stderr || '') + (run.stdout || '');
  if (run.status === 0) return result;
  const jsonStart = text.indexOf('{"type"');
  let report;
  try {
    report = JSON.parse(text.slice(jsonStart));
  } catch {
    console.error('elm make gave no report:\n' + text.slice(0, 3000));
    process.exit(1);
  }
  if (report.type !== 'compile-errors') {
    console.error(`elm make: ${report.title}\n${messageText(report)}`);
    process.exit(1);
  }
  for (const err of report.errors) {
    const name = path.basename(err.path, '.elm');
    result.set(name, err.problems.map((p) => ({ title: p.title, text: messageText(p) })));
  }
  return result;
}

// Errors that only say "the application has not defined this" (an unqualified name, a package that
// is not in the scratch project): the example needs its context and is not compiled.
function isContextProblem(p, aliases) {
  if (p.title === 'UNKNOWN IMPORT' || p.title === 'MODULE NOT FOUND') return true;
  if (p.title === 'NAMING ERROR' || p.title === 'MISSING IMPORT') {
    const m = /I cannot find a `([\w.']+)` (variable|type|constructor|pattern)/.exec(p.text) || /Cannot find (?:variable|type|constructor|pattern) `([\w.']+)`/.exec(p.text);
    if (!m) return false;
    const name = m[1];
    if (name.includes('.')) return !aliases.has(name.split('.')[0]);
    return true;
  }
  if (p.title === 'AMBIGUOUS NAME' || p.title === 'UNKNOWN EXPOSING') return false;
  return false;
}

// ------------------------------------------------------------------------ main

const docs = loadDocs();
const groups = moduleGroups();
const exposed = docs.map((m) => m.name);
const table = aliasTable(exposed);
const blocks = collectBlocks(docs);

const kinds = { compiled: [], failed: [], context: [], fragment: [] };
const complete = [];
blocks.forEach((b, i) => {
  if (classify(b.code) === 'complete') {
    b.module_ = `B${String(i).padStart(4, '0')}`;
    complete.push(b);
  } else kinds.fragment.push(b);
});

const workspace = path.join(os.tmpdir(), 'klar-doc-examples-ws');
fs.mkdirSync(workspace, { recursive: true });
const dir = path.join(workspace);
const elmJson = JSON.parse(fs.readFileSync(path.join(root, 'example', 'elm.json'), 'utf8'));
elmJson['source-directories'] = ['src', path.relative(workspace, path.join(root, 'src')).split(path.sep).join('/')];
fs.writeFileSync(path.join(dir, 'elm.json'), JSON.stringify(elmJson, null, 4));

const entries = complete.map((b) => ({ module: b.module_, source: withImports(b.code, table, b.module_) }));
let errors = new Map();
// Elm stops at the first module with a syntax error in a batch, so repeat without the modules that failed.
let remaining = entries;
for (let round = 0; round < 6 && remaining.length > 0; round++) {
  const found = compileAll(remaining, workspace);
  if (found.size === 0) break;
  for (const [k, v] of found) errors.set(k, v);
  const next = remaining.filter((e) => !found.has(e.module));
  if (next.length === remaining.length) break;
  remaining = next;
  if (round === 5) break;
}
// A last pass over the survivors, to be sure they compile together.
if (remaining.length > 0) {
  const finalErrors = compileAll(remaining, workspace);
  for (const [k, v] of finalErrors) errors.set(k, v);
}

const aliasNames = new Set([...table.keys(), ...Object.keys(CORE_ALIASES)]);
for (const b of complete) {
  const problems = errors.get(b.module_);
  if (!problems) kinds.compiled.push(b);
  else if (problems.every((p) => isContextProblem(p, aliasNames))) {
    b.problems = problems;
    kinds.context.push(b);
  } else {
    b.problems = problems;
    kinds.failed.push(b);
  }
}

// ----------------------------------------------------------------------- report

function tidy(text) {
  return text
    .replace(/[A-Z]:\\[^\s]*?(B\d{4}\.elm)/g, '$1')
    .replace(/\u001b\[[0-9;]*m/g, '')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

const total = blocks.length;
const summary = [
  `${total} code blocks in the documentation of ${exposed.length} modules.`,
  `- compiled: ${kinds.compiled.length}`,
  `- failed: ${kinds.failed.length} (complete examples that the compiler rejects)`,
  `- needs context: ${kinds.context.length} (complete, but they use names of the application or a package that is not here)`,
  `- fragments, skipped: ${kinds.fragment.length}`,
];

console.log('Doc examples:\n' + summary.map((l) => '  ' + l).join('\n'));
if (kinds.failed.length > 0) {
  console.log('\nFailed examples:');
  for (const b of kinds.failed) {
    console.log(`\n  - ${b.owner}: ${b.problems[0].title}\n${b.code}\n${tidy(b.problems[0].text).split('\n').slice(0, 14).join('\n')}`);
  }
}
void groups;
process.exit(strict && kinds.failed.length > 0 ? 1 : 0);
