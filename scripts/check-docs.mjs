#!/usr/bin/env node
// Documentation check for the exposed modules of this package.
//
//   node scripts/check-docs.mjs                      check every exposed module
//   node scripts/check-docs.mjs Klar.Button Klar.Tag check just those modules
//
// 1. A static audit: every exposed name must be listed in a `@docs` line of the
//    module documentation and must have a `{-| ... -}` comment right above its
//    definition.
// 2. A guard against doc examples that are known not to compile (KNOWN_BAD below).
// 3. The real thing: `elm make --docs` in a private workspace (in the OS temp
//    directory) that exposes only the given modules, so several people can run
//    it at the same time without sharing an `elm-stuff` directory.
//
// Exit code 0 means both passed.

import fs from 'node:fs';
import path from 'node:path';
import { loadDocs, root } from './lib/klar-docs.mjs';

const outline = JSON.parse(fs.readFileSync(path.join(root, 'elm.json'), 'utf8'));

const exposedAll = Array.isArray(outline['exposed-modules'])
  ? outline['exposed-modules']
  : Object.values(outline['exposed-modules']).flat();

const requested = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const modules = requested.length > 0 ? requested : exposedAll;

function fileOf(moduleName) {
  return path.join(root, 'src', ...moduleName.split('.')) + '.elm';
}

// ---------------------------------------------------------------- static audit

function exportList(src) {
  const m = /^module\s+([\w.]+)\s+exposing\s*\(/m.exec(src);
  if (!m) return null;
  let i = m.index + m[0].length;
  const start = i;
  let depth = 1;
  while (i < src.length && depth > 0) {
    const c = src[i];
    if (c === '(') depth++;
    else if (c === ')') depth--;
    i++;
  }
  return { body: src.slice(start, i - 1), end: i };
}

function splitNames(body) {
  const cleaned = body.replace(/--[^\n]*/g, '').replace(/\{-[\s\S]*?-\}/g, '');
  const parts = [];
  let depth = 0;
  let current = '';
  for (const c of cleaned) {
    if (c === '(') depth++;
    if (c === ')') depth--;
    if (c === ',' && depth === 0) {
      parts.push(current.trim());
      current = '';
    } else current += c;
  }
  if (current.trim()) parts.push(current.trim());
  return parts.filter(Boolean).map((n) => n.replace(/\(\.\.\)$/, '').trim());
}

function moduleDoc(src, afterIndex) {
  const rest = src.slice(afterIndex);
  const m = /^\s*(\{-\|[\s\S]*?-\})/.exec(rest);
  return m ? m[1] : null;
}

function docsNames(doc) {
  const names = [];
  for (const line of doc.split('\n')) {
    const m = /^@docs\s+(.*)$/.exec(line.trim());
    if (m) for (const n of m[1].split(',')) if (n.trim()) names.push(n.trim());
  }
  return names;
}

function hasDocComment(lines, name) {
  const isType = /^[A-Z]/.test(name);
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const definition = isType
    ? new RegExp('^(type alias|type)\\s+' + escaped + '(\\s|$)')
    : new RegExp('^' + escaped + '\\s*:');
  for (let i = 0; i < lines.length; i++) {
    if (!definition.test(lines[i])) continue;
    if (i === 0 || !/-\}\s*$/.test(lines[i - 1])) return false;
    let k = i - 1;
    while (k >= 0 && !/^\{-/.test(lines[k])) k--;
    return k >= 0 && /^\{-\|/.test(lines[k]);
  }
  return null; // no definition found (value without a type annotation, or a re-export)
}

function audit(moduleName) {
  const problems = [];
  const file = fileOf(moduleName);
  if (!fs.existsSync(file)) return [`${moduleName}: file not found (${path.relative(root, file)})`];
  const src = fs.readFileSync(file, 'utf8');
  const ex = exportList(src);
  if (!ex) return [`${moduleName}: no export list`];
  const exported = splitNames(ex.body);
  const doc = moduleDoc(src, ex.end);
  if (!doc) problems.push(`${moduleName}: no module documentation comment after the module line`);
  const listed = doc ? docsNames(doc) : [];
  for (const n of exported) if (!listed.includes(n)) problems.push(`${moduleName}: \`${n}\` is exposed but not in any @docs line`);
  for (const n of listed) if (!exported.includes(n)) problems.push(`${moduleName}: \`${n}\` is in @docs but not exposed`);
  const seen = new Set();
  for (const n of listed) {
    if (seen.has(n)) problems.push(`${moduleName}: \`${n}\` appears twice in @docs`);
    seen.add(n);
  }
  const lines = src.split('\n');
  for (const n of exported) {
    const has = hasDocComment(lines, n);
    if (has === false) problems.push(`${moduleName}: \`${n}\` has no {-| doc comment -}`);
    if (has === null) problems.push(`${moduleName}: \`${n}\` definition not found with an annotation (re-export? add a type annotation and doc)`);
  }
  return problems;
}

let failed = false;
const staticProblems = modules.flatMap(audit);
if (staticProblems.length > 0) {
  failed = true;
  console.log(`Static audit: ${staticProblems.length} problem(s)`);
  for (const p of staticProblems.slice(0, 400)) console.log('  - ' + p);
  if (staticProblems.length > 400) console.log(`  ... and ${staticProblems.length - 400} more`);
} else {
  console.log(`Static audit: ok (${modules.length} module(s))`);
}

// ------------------------------------------------- known-bad example patterns

// Mistakes that were once found in the docs, as text patterns that can only be wrong:
// a column id is a `Table.ColumnId` (never a string), a `SideNav` entry needs its
// `Ids` first, and `Remote` has `Loaded` and `Failed` (`Success` is a `Theme.Tone`).
// Complete examples are also compiled by check-doc-examples.mjs.
const KNOWN_BAD = [
  {
    pattern: /\bTable\.(text|int|float|date|maybeDate|badge|status|bool|custom|actions)\s+"/,
    message: 'a Table column constructor with a string literal as its id: use (Table.columnId "...") or a ColumnId value',
  },
  {
    pattern: /\bSideNav\.(item|group)\s+\{/,
    message: 'SideNav.item or SideNav.group with a record as the first argument: they take the Ids first (Ids.string)',
  },
  {
    pattern: /\bRemote\.(Success|Failure)\b/,
    message: 'Remote.Success and Remote.Failure do not exist: the constructors are Loaded and Failed',
  },
];

function knownBad(file) {
  const problems = [];
  const shown = path.relative(root, file).split(path.sep).join('/');
  fs.readFileSync(file, 'utf8')
    .split('\n')
    .forEach((line, i) => {
      for (const { pattern, message } of KNOWN_BAD) if (pattern.test(line)) problems.push(`${shown}:${i + 1}: ${message}`);
    });
  return problems;
}

const guideFiles = requested.length > 0 ? [] : ['README.md', 'AI.md', 'AGENTS.md'].map((f) => path.join(root, f));
const badProblems = [...modules.map(fileOf).filter((f) => fs.existsSync(f)), ...guideFiles].flatMap(knownBad);
if (badProblems.length > 0) {
  failed = true;
  console.log(`Known-bad examples: ${badProblems.length} problem(s)`);
  for (const p of badProblems) console.log('  - ' + p);
} else {
  console.log('Known-bad examples: ok');
}

// ------------------------------------------------------------ compiler check

loadDocs(requested.length > 0 ? modules : undefined);
console.log('elm make --docs: ok');
process.exit(failed ? 1 : 0);
