#!/usr/bin/env node
// Reports code that breaks a rule of CLAUDE.md that the compiler cannot see:
//
// - A `Msg` or a `State` of an exposed module that can hold a function ("No functions in a
//   State or a Msg"): the application keeps them in its model and compares them with ==,
//   which fails at run time on a function, and the debugger cannot show or replay them.
// - Remote data whose freshness is thrown away (`Tuple.first (Freshness.settle ...)`, rule 5):
//   `Remote.Kept` data is then drawn as fresh, with no dimming while it refreshes and no
//   marker when the refresh failed. Keep the `Freshness` and draw it (`Freshness.wrap`).
// - A `Freshness.Fresh` branch of a case (rule 5): fresh data drawn apart from old and
//   refreshing data usually means other elements around it, so the content is replaced
//   when a refresh starts or ends and the focus in it drops to `body`. `Freshness.wrap`
//   draws the same elements in every state.
// - A `Freshness.notice` that a component draws itself: the box around the content is then
//   the component's, and must be the same element in every state (or use `Freshness.wrap`).
//
//   node scripts/check-rules.mjs            report them (exit 0)
//   node scripts/check-rules.mjs --strict   fail when there is one
//
// A source heuristic, no compiler. For the first rule it reads the type declarations of src/,
// starts at the `Msg` and the `State` of every exposed module, follows every Klar type they
// name (through the imports of each module), and reports the first function type on the way,
// with the path that leads to it: a `->`, or a type that holds functions (Html, an Html
// attribute, Cmd, Sub, Task, a decoder).

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const strict = process.argv.includes('--strict');
const elmJson = JSON.parse(fs.readFileSync(path.join(root, 'elm.json'), 'utf8'));
const exposed = Object.values(elmJson['exposed-modules']).flat();

// Types of the official packages that hold functions, by module.
const holders = {
  Html: ['Html', 'Attribute'],
  'Html.Attributes': ['Attribute'],
  'Html.Events': [],
  'Platform.Cmd': ['Cmd'],
  'Platform.Sub': ['Sub'],
  Task: ['Task'],
  'Json.Decode': ['Decoder'],
};
// The default imports of every Elm module that matter here.
const defaults = { Cmd: 'Platform.Cmd', Sub: 'Platform.Sub' };

function stripComments(text) {
  let out = '';
  let depth = 0;
  for (let i = 0; i < text.length; i++) {
    if (text.startsWith('{-', i)) {
      depth++;
      i++;
    } else if (depth > 0 && text.startsWith('-}', i)) {
      depth--;
      i++;
    } else if (depth === 0) {
      if (text.startsWith('--', i) && !/["']/.test(text[i - 1] || '')) {
        while (i < text.length && text[i] !== '\n') i++;
        out += '\n';
      } else out += text[i];
    } else if (text[i] === '\n') out += '\n';
  }
  return out;
}

const modules = new Map();

function parse(name) {
  if (modules.has(name)) return modules.get(name);
  const file = path.join(root, 'src', ...name.split('.')) + '.elm';
  if (!fs.existsSync(file)) {
    modules.set(name, null);
    return null;
  }
  const lines = stripComments(fs.readFileSync(file, 'utf8').replace(/\r/g, '')).split('\n');
  const types = new Map();
  const imports = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const imp = line.match(/^import\s+([A-Z][\w.]*)(?:\s+as\s+([A-Z]\w*))?(?:\s+exposing\s*\((.*)\))?/);
    if (imp) {
      const exposing = imp[3] ? imp[3].split(',').map((s) => s.trim().replace(/\(\.\.\)$/, '')) : [];
      imports.push({ module: imp[1], alias: imp[2] || imp[1], exposing });
      continue;
    }
    const decl = line.match(/^type\s+(alias\s+)?([A-Z]\w*)(.*)$/);
    if (decl) {
      let body = decl[3];
      let j = i + 1;
      while (j < lines.length && (lines[j].trim() === '' || /^\s/.test(lines[j]))) body += '\n' + lines[j++];
      const at = body.indexOf('=');
      types.set(decl[2], { alias: Boolean(decl[1]), body: at >= 0 ? body.slice(at + 1) : '' });
    }
  }
  const parsed = { name, types, imports };
  modules.set(name, parsed);
  return parsed;
}

// The type names a body refers to, without the constructor names of a custom type.
function references(entry) {
  let body = entry.body;
  if (!entry.alias) {
    body = splitTop(body, '|')
      .map((variant) => variant.replace(/^\s*[A-Z]\w*/, ''))
      .join(' ');
  }
  return [...body.matchAll(/\b((?:[A-Z]\w*\.)*)([A-Z]\w*)\b/g)].map((m) => ({ qualifier: m[1].replace(/\.$/, ''), name: m[2] }));
}

function splitTop(text, separator) {
  const parts = [];
  let depth = 0;
  let current = '';
  for (const char of text) {
    if ('({['.includes(char)) depth++;
    if (')}]'.includes(char)) depth--;
    if (char === separator && depth === 0) {
      parts.push(current);
      current = '';
    } else current += char;
  }
  parts.push(current);
  return parts;
}

// Where a referenced type is defined: { module, name } or null for a type of core.
function resolve(mod, ref) {
  if (ref.qualifier) {
    const imp = mod.imports.find((i) => i.alias === ref.qualifier || i.module === ref.qualifier);
    return imp ? { module: imp.module, name: ref.name } : null;
  }
  if (mod.types.has(ref.name)) return { module: mod.name, name: ref.name };
  for (const imp of mod.imports) {
    if (imp.exposing.includes(ref.name)) return { module: imp.module, name: ref.name };
  }
  for (const imp of mod.imports) {
    if (imp.exposing.includes('..')) {
      const other = parse(imp.module);
      if (other && other.types.has(ref.name)) return { module: imp.module, name: ref.name };
    }
  }
  if (defaults[ref.name]) return { module: defaults[ref.name], name: ref.name };
  return null;
}

// The first function on the way from a type: a path of "Module.Type" and what holds it.
function findFunction(where, trail, seen) {
  const key = `${where.module}.${where.name}`;
  if (seen.has(key)) return null;
  seen.add(key);
  if ((holders[where.module] || []).includes(where.name)) return { trail: [...trail, key], what: `${key} holds functions` };
  const mod = parse(where.module);
  if (!mod) return null;
  const entry = mod.types.get(where.name);
  if (!entry) return null;
  const here = [...trail, key];
  const arrow = entry.body.split('\n').find((line) => line.includes('->'));
  if (arrow) return { trail: here, what: arrow.trim() };
  for (const ref of references(entry)) {
    const target = resolve(mod, ref);
    if (!target) continue;
    const found = findFunction(target, here, seen);
    if (found) return found;
  }
  return null;
}

const found = [];
for (const name of exposed) {
  const mod = parse(name);
  if (!mod) continue;
  for (const root of ['Msg', 'State']) {
    if (!mod.types.has(root)) continue;
    const hit = findFunction({ module: name, name: root }, [], new Set());
    if (hit) found.push({ root: `${name}.${root}`, ...hit });
  }
}

// ---- Freshness thrown away

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(p));
    else if (entry.name.endsWith('.elm')) out.push(p);
  }
  return out;
}

const dropped = [];
const freshBranches = [];
const ownNotices = [];
for (const file of walk(path.join(root, 'src'))) {
  if (file.endsWith(path.join('Internal', 'Freshness.elm'))) continue;
  const lines = stripComments(fs.readFileSync(file, 'utf8').replace(/\r/g, '')).split('\n');
  const at = (index) => `${path.relative(root, file)}:${index + 1}`;
  lines.forEach((line, index) => {
    if (/Tuple\.first\s*(\(\s*|<\|\s*)Freshness\.settle\b/.test(line) || /Freshness\.settle\b[^|]*\|>\s*Tuple\.first\b/.test(line)) {
      dropped.push(at(index));
    }
    if (/\bFreshness\.Fresh\s*\)?\s*->\s*$/.test(line)) freshBranches.push(at(index));
    if (/\bFreshness\.notice\b/.test(line)) ownNotices.push(at(index));
  });
}

// ---- Report

if (found.length === 0) console.log('rules: no Msg or State of an exposed module holds a function');
else {
  console.log(`${found.length} Msg or State type(s) that can hold a function:`);
  for (const f of found) console.log(`  - ${f.root}: ${f.trail.slice(1).join(' > ') || f.root}: ${f.what}`);
}
if (dropped.length === 0) console.log('rules: no remote data loses its freshness');
else {
  console.log(`${dropped.length} place(s) that throw the freshness of remote data away (draw it with Freshness.wrap):`);
  for (const d of dropped) console.log(`  - ${d}`);
}
if (freshBranches.length === 0) console.log('rules: no case draws fresh data apart from old and refreshing data');
else {
  console.log(`${freshBranches.length} Freshness.Fresh branch(es) that may draw other elements than old or refreshing data (use Freshness.wrap):`);
  for (const d of freshBranches) console.log(`  - ${d}`);
}
if (ownNotices.length > 0) {
  console.log(`${ownNotices.length} Freshness.notice call(s) outside Freshness.wrap (the box around the content must be the same element in every state):`);
  for (const d of ownNotices) console.log(`  - ${d}`);
}
if (found.length + dropped.length + freshBranches.length + ownNotices.length > 0) {
  if (strict) process.exit(1);
  console.log('(report only; run with --strict to fail)');
}
