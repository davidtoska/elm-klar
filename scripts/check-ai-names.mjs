#!/usr/bin/env node
// Checks that the names the AI documents use exist.
//
//   node scripts/check-ai-names.mjs
//
// 1. NAMES. Reads AI.md, llms.txt, USING.md, README.md, recipes/*/README.md, template/README.md,
//    recipes/README.md and the documentation comments in src/ (the source of ai/modules/*.md, which is generated and
//    checked fresh by check:ai-docs). Every `Module.name` token written in backticks or in a code
//    block, where Module is a Klar module (`Klar.Table`, or an alias taken from the imports of the
//    same document, or the last part of the module name: `Table`, `Modal`), must name a module in
//    elm.json's exposed modules and a name that module exposes (value, type, constructor). The
//    names in `import Klar.X exposing (...)` lines are checked the same way.
// 2. PROGRAMS. A fenced elm block that starts with `module` in those documents is a complete
//    program: it is compiled in a scratch project (the dependencies of template/elm.json).
//    Blocks that are fragments are skipped.
// 3. DUPLICATES. Two complete programs in one document must not declare the same top-level name
//    in different modules of one file set; two fragment blocks of AI.md or USING.md must not
//    declare the same top-level function (an AI that copies both into one module gets a clash).
//
// Part of `npm run check` (check:ai-names). Nothing in the repository changes.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { loadDocs, moduleGroups, root } from './lib/klar-docs.mjs';

const exposedModules = new Set(moduleGroups().keys());

// Modules the documents name on purpose, to say "do not use these".
const FILE_EXTENSIONS = new Set(['md', 'json', 'elm', 'mjs', 'txt', 'js', 'css', 'html']);

const NAMED_AS_FORBIDDEN = new Set(['Klar.Internal', 'Klar.Table.Sort']);

// ------------------------------------------------------------------ the names

const docs = loadDocs();
const namesOf = new Map(); // module -> Set of exposed names
for (const m of docs) {
  const names = new Set();
  for (const v of m.values) names.add(v.name);
  for (const a of m.aliases) names.add(a.name);
  for (const u of m.unions) {
    names.add(u.name);
    for (const tag of u.cases) names.add(tag[0]);
  }
  for (const b of m.binops || []) names.add(b.name);
  namesOf.set(m.name, names);
}

// The module a bare last part stands for: Table -> Klar.Table, Option -> Klar.Select.Option.
const defaultAlias = new Map();
for (const name of exposedModules) {
  if (name === 'Klar') continue;
  const last = name.split('.').pop();
  const better = !defaultAlias.has(last) || (defaultAlias.get(last).startsWith('Klar.Icon.') && !name.startsWith('Klar.Icon.'));
  if (better) defaultAlias.set(last, name);
}

// ------------------------------------------------------------------- sources

// A source is { file, text, kind } where kind is 'markdown' (fenced blocks) or 'comment'
// (indented blocks). Returns [{ line, text, code }] pieces to search for tokens.
function pieces(source) {
  const out = [];
  const lines = source.text.split('\n');
  if (source.kind === 'markdown') {
    let fenced = false;
    lines.forEach((line, i) => {
      if (/^\s*```/.test(line)) {
        fenced = !fenced;
        return;
      }
      if (fenced) out.push({ line: i + 1, text: line, code: true });
      else for (const m of line.matchAll(/`([^`]+)`/g)) out.push({ line: i + 1, text: m[1], code: false });
    });
  } else {
    lines.forEach((line, i) => {
      if (/^( {4}|\t)/.test(line)) out.push({ line: i + 1, text: line, code: true });
      else for (const m of line.matchAll(/`([^`]+)`/g)) out.push({ line: i + 1, text: m[1], code: false });
    });
  }
  return out;
}

function readSources() {
  const sources = [];
  const add = (file, kind) => {
    const p = path.join(root, file);
    if (fs.existsSync(p)) sources.push({ file, text: fs.readFileSync(p, 'utf8'), kind });
  };
  for (const f of ['AI.md', 'llms.txt', 'USING.md', 'README.md', 'template/README.md', 'recipes/README.md']) add(f, 'markdown');
  for (const d of fs.readdirSync(path.join(root, 'recipes'), { withFileTypes: true })) {
    if (d.isDirectory()) add(`recipes/${d.name}/README.md`, 'markdown');
  }
  for (const m of docs) {
    const file = 'src/' + m.name.replace(/\./g, '/') + '.elm';
    sources.push({ file: `${file} (module doc)`, text: m.comment, kind: 'comment' });
    for (const v of m.values) sources.push({ file: `${file} ${v.name}`, text: v.comment, kind: 'comment' });
    for (const u of m.unions) sources.push({ file: `${file} ${u.name}`, text: u.comment, kind: 'comment' });
    for (const a of m.aliases) sources.push({ file: `${file} ${a.name}`, text: a.comment, kind: 'comment' });
  }
  return sources;
}

// import Klar.Form.Layout as FormLayout  ->  FormLayout = Klar.Form.Layout
function importsIn(text) {
  const aliases = new Map();
  for (const m of text.matchAll(/^\s*import\s+(Klar[\w.]*)(?:\s+as\s+(\w+))?/gm)) {
    if (exposedModules.has(m[1])) aliases.set(m[2] || m[1].split('.').pop(), m[1]);
  }
  return aliases;
}

// Aliases the repository uses for a module, when every use agrees (FormLayout, Spec ...).
function repositoryAliases(sources) {
  const seen = new Map(); // alias -> Set of modules
  for (const s of sources) {
    for (const [alias, mod] of importsIn(s.text)) {
      if (!seen.has(alias)) seen.set(alias, new Set());
      seen.get(alias).add(mod);
    }
  }
  const out = new Map();
  for (const [alias, mods] of seen) if (mods.size === 1) out.set(alias, [...mods][0]);
  return out;
}

// ------------------------------------------------------------------- checking

const problems = [];
let tokenCount = 0;
let importCount = 0;
const seenProblems = new Set();

function report(source, line, message) {
  const key = `${source.file}\u0000${message}`;
  if (seenProblems.has(key)) return;
  seenProblems.add(key);
  problems.push(`${source.file}:${line}: ${message}`);
}

function stripStringsAndComments(line) {
  return line.replace(/"(?:[^"\\]|\\.)*"/g, '""').replace(/--[^\n]*/g, (c) => c);
}

function resolveChain(segments, aliases) {
  // segments: capitalised parts, then the name. Returns { module, name } or null (not Klar).
  const caps = [];
  let i = 0;
  while (i < segments.length && /^[A-Z]/.test(segments[i])) caps.push(segments[i++]);
  const rest = segments.slice(i);
  for (let k = caps.length; k >= 1; k--) {
    const head = caps[0];
    const tail = caps.slice(1, k);
    let candidates = [];
    if (head === 'Klar') candidates = [['Klar', ...tail].join('.')];
    else {
      const mod = aliases.get(head) || defaultAlias.get(head);
      if (mod) candidates.push([mod, ...tail].join('.'));
      candidates.push(['Klar', head, ...tail].join('.'));
    }
    for (const c of candidates) {
      if (exposedModules.has(c)) {
        if (c === 'Klar' && caps.length > 1) return { module: caps.join('.'), name: null, missing: true }; // Klar.Nothing.x
        const after = [...caps.slice(k), ...rest];
        return { module: c, name: after[0] || null, extra: after.length > 1 };
      }
    }
  }
  if (caps[0] === 'Klar') return { module: ['Klar', ...caps.slice(1)].join('.'), name: null, missing: true };
  return null;
}

function checkSource(source, repoAliases) {
  const aliases = new Map([...repoAliases, ...importsIn(source.text)]);
  for (const piece of pieces(source)) {
    let text = stripStringsAndComments(piece.text);
    // import lines: check the exposing list
    const imp = /^\s*import\s+(Klar[\w.]*)(?:\s+as\s+\w+)?\s+exposing\s*\((.*)\)\s*$/.exec(text);
    if (piece.code && imp && exposedModules.has(imp[1])) {
      for (const n of imp[2].replace(/\(\.\.\)/g, '').split(',').map((s) => s.trim()).filter((s) => s && s !== '..')) {
        importCount++;
        if (!namesOf.get(imp[1]).has(n)) report(source, piece.line, `\`${imp[1]}\` does not expose \`${n}\` (in an import line)`);
      }
      continue;
    }
    if (piece.code && /^\s*import\s/.test(text)) {
      const m = /^\s*import\s+(Klar[\w.]*)/.exec(text);
      if (m && !exposedModules.has(m[1]) && !NAMED_AS_FORBIDDEN.has(m[1])) report(source, piece.line, `\`${m[1]}\` is not an exposed module`);
      continue;
    }
    for (const m of text.matchAll(/(?<![\w.'])((?:[A-Z][A-Za-z0-9_]*)(?:\.[A-Za-z][A-Za-z0-9_']*)+)/g)) {
      const token = m[1];
      const segments = token.split('.');
      const r = resolveChain(segments, aliases);
      if (r === null) continue;
      tokenCount++;
      if (r.missing) {
        if ([...NAMED_AS_FORBIDDEN].some((f) => token === f || token.startsWith(f + '.'))) continue;
        report(source, piece.line, `\`${token}\`: there is no exposed module ${r.module}`);
        continue;
      }
      if (r.name === null) continue; // a module name
      if (FILE_EXTENSIONS.has(r.name)) continue; // Klar.Table.md is a file name, not a name
      if (r.extra) continue; // e.g. record access on a value: Table.rows.foo (not ours to judge)
      if (!namesOf.get(r.module).has(r.name)) {
        if (NAMED_AS_FORBIDDEN.has(`${r.module}.${r.name}`) || NAMED_AS_FORBIDDEN.has(token)) continue;
        report(source, piece.line, `\`${token}\`: ${r.module} exposes no \`${r.name}\``);
      }
    }
  }
}

const sources = readSources();
const repoAliases = repositoryAliases(sources);
for (const s of sources) checkSource(s, repoAliases);

// -------------------------------------------------------------------- programs

function fencedBlocks(source) {
  const blocks = [];
  const lines = source.text.split('\n');
  let current = null;
  lines.forEach((line, i) => {
    const m = /^\s*```(\w*)/.exec(line);
    if (m) {
      if (current === null) current = { lang: m[1], start: i + 1, lines: [] };
      else {
        blocks.push({ ...current, code: current.lines.join('\n') });
        current = null;
      }
    } else if (current !== null) current.lines.push(line);
  });
  return blocks;
}

const markdownSources = sources.filter((s) => s.kind === 'markdown');
const programs = [];
const fragmentsByFile = new Map(); // file -> [{ name, line }]
for (const s of markdownSources) {
  for (const b of fencedBlocks(s)) {
    if (b.lang !== 'elm') continue;
    if (/^module\s+\w/m.test(b.code)) programs.push({ source: s, block: b });
    else if (s.file === 'AI.md' || s.file === 'USING.md') {
      const names = [...b.code.matchAll(/^([a-z][\w']*)\s*:/gm)].map((m) => m[1]);
      for (const name of names) {
        if (!fragmentsByFile.has(s.file)) fragmentsByFile.set(s.file, []);
        fragmentsByFile.get(s.file).push({ name, line: b.start, block: b.start });
      }
    }
  }
}

// Duplicate top-level names between the fragments (and programs) of one document.
for (const [file, list] of fragmentsByFile) {
  const byName = new Map();
  for (const f of list) {
    if (!byName.has(f.name)) byName.set(f.name, new Set());
    byName.get(f.name).add(f.block);
  }
  for (const [name, blocks] of byName) {
    if (blocks.size > 1) {
      problems.push(`${file}: the top-level name \`${name}\` is declared in ${blocks.size} code blocks (lines ${[...blocks].join(', ')}); copied into one module they clash. Rename one.`);
    }
  }
}

let compiled = 0;
if (programs.length > 0) {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), 'klar-ai-names-'));
  const elmJson = JSON.parse(fs.readFileSync(path.join(root, 'template', 'elm.json'), 'utf8'));
  elmJson['source-directories'] = ['.', path.join(root, 'src')];
  fs.writeFileSync(path.join(workspace, 'elm.json'), JSON.stringify(elmJson, null, 4));
  programs.forEach((p, i) => {
    const dir = path.join(workspace, `p${i}`);
    fs.mkdirSync(path.join(dir, 'src'), { recursive: true });
    const e = { ...elmJson, 'source-directories': ['src', path.join(root, 'src')] };
    fs.writeFileSync(path.join(dir, 'elm.json'), JSON.stringify(e, null, 4));
    const name = /^module\s+([\w.]+)/m.exec(p.block.code)[1];
    const file = path.join(dir, 'src', name.replace(/\./g, '/') + '.elm');
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, p.block.code + '\n');
    const run = spawnSync(`elm make src/${name.replace(/\./g, '/')}.elm --output="${path.join(dir, 'out.js')}"`, { cwd: dir, encoding: 'utf8', shell: true });
    compiled++;
    if (run.status !== 0) {
      problems.push(
        `${p.source.file}:${p.block.start}: the program \`${name}\` does not compile:\n    ` +
          ((run.stdout || '') + (run.stderr || '')).replace(/\u001b\[[0-9;]*m/g, '').replace(/^Compiling.*$/gm, '').trim().split('\n').slice(0, 24).join('\n    '),
      );
    }
  });
  fs.rmSync(workspace, { recursive: true, force: true });
}

if (problems.length > 0) {
  console.log(`AI names: ${problems.length} problem(s) (${tokenCount} qualified names and ${importCount} imported names checked in ${sources.length} documents, ${compiled} complete programs compiled)`);
  for (const p of problems) console.log('  - ' + p);
  process.exit(1);
}
console.log(`AI names: ok (${tokenCount} qualified names and ${importCount} imported names checked in ${sources.length} documents, ${compiled} complete programs compiled)`);
