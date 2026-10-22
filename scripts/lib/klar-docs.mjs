// Shared helpers for the scripts that read the documentation of the package
// (gen-ai-docs.mjs, check-doc-examples.mjs): build docs.json in a private workspace and
// parse the documentation comments.

import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

export function readElmJson() {
  return JSON.parse(fs.readFileSync(path.join(root, 'elm.json'), 'utf8'));
}

// "Klar.Button" -> "Actions"
export function moduleGroups() {
  const groups = new Map();
  const exposed = readElmJson()['exposed-modules'];
  if (Array.isArray(exposed)) for (const m of exposed) groups.set(m, '');
  else for (const [group, names] of Object.entries(exposed)) for (const m of names) groups.set(m, group);
  return groups;
}

// The output of `elm make --docs` for the whole package, built in a private workspace in the
// OS temp directory so that it never shares an elm-stuff directory with another run.
export function loadDocs() {
  const key = crypto.createHash('sha1').update('ai-docs' + root).digest('hex').slice(0, 10);
  const workspace = path.join(os.tmpdir(), 'klar-ai-docs-ws', key);
  fs.mkdirSync(workspace, { recursive: true });
  const srcLink = path.join(workspace, 'src');
  if (!fs.existsSync(srcLink)) fs.symlinkSync(path.join(root, 'src'), srcLink, 'junction');
  fs.copyFileSync(path.join(root, 'elm.json'), path.join(workspace, 'elm.json'));
  const out = path.join(workspace, 'docs.json');
  const run = spawnSync(`elm make --docs="${out}"`, { cwd: workspace, encoding: 'utf8', shell: true });
  if (run.status !== 0) {
    console.error(((run.stdout || '') + (run.stderr || '')).replace(/\u001b\[[0-9;]*m/g, ''));
    process.exit(1);
  }
  const docs = JSON.parse(fs.readFileSync(out, 'utf8'));
  const order = [...moduleGroups().keys()];
  docs.sort((a, b) => order.indexOf(a.name) - order.indexOf(b.name));
  return docs;
}

// The name a module is imported as: Klar.Button -> Button, Klar.Select.Option -> Option.
export function aliasOf(moduleName) {
  return moduleName.split('.').pop();
}

export function importLine(moduleName, comment) {
  if (moduleName === 'Klar') return 'import Klar';
  const used = (comment || '').split('\n').map((line) => /^\s*import\s+([\w.]+)\s+as\s+(\w+)/.exec(line)).find((m) => m && m[1] === moduleName);
  return `import ${moduleName} as ${used ? used[2] : aliasOf(moduleName)}`;
}

// ------------------------------------------------------------------ comments

// One piece of a module documentation comment, in order: prose (a string of lines) or the
// names of an `@docs` line.
export function commentBlocks(comment) {
  const blocks = [];
  let prose = [];
  const flush = () => {
    if (prose.length > 0) blocks.push({ kind: 'prose', text: prose.join('\n') });
    prose = [];
  };
  for (const line of comment.replace(/^ /, '').split('\n')) {
    const m = /^@docs\s+(.*)$/.exec(line.trim());
    if (m) {
      flush();
      blocks.push({ kind: 'docs', names: m[1].split(',').map((n) => n.trim()).filter(Boolean) });
    } else prose.push(line);
  }
  flush();
  return blocks;
}

// The text of a comment with the `@docs` lines taken out.
export function proseOf(comment) {
  return commentBlocks(comment)
    .filter((b) => b.kind === 'prose')
    .map((b) => b.text)
    .join('\n');
}

// Paragraphs of prose (not code, not headings, not lists of links), as one line each.
export function paragraphs(comment) {
  return proseOf(comment)
    .split(/\n\s*\n/)
    .map((p) => p.replace(/\s+/g, ' ').trim())
    .filter((p) => p && !/^#/.test(p));
}

// Indented (four spaces) code blocks of a piece of documentation: [{ code, line }].
export function codeBlocks(comment) {
  const lines = proseOf(comment).split('\n');
  const blocks = [];
  let current = null;
  let blank = 0;
  lines.forEach((line, i) => {
    if (/^( {4}|\t)/.test(line)) {
      if (current === null) current = { start: i, lines: [] };
      for (let k = 0; k < blank; k++) current.lines.push('');
      blank = 0;
      current.lines.push(line.replace(/^( {4}|\t)/, ''));
    } else if (line.trim() === '') {
      if (current !== null) blank++;
    } else {
      if (current !== null) blocks.push({ code: current.lines.join('\n'), line: current.start });
      current = null;
      blank = 0;
    }
  });
  if (current !== null) blocks.push({ code: current.lines.join('\n'), line: current.start });
  return blocks;
}

// --------------------------------------------------------------------- types

const CORE_TYPE = /^(Basics|String|List|Maybe|Result|Char|Tuple|Dict|Set|Array)$/;

// "String.String -> Klar.Button.Attribute msg" -> "String -> Button.Attribute msg"
export function prettyType(type, own) {
  return type
    .replace(/\b((?:[A-Z][A-Za-z0-9_]*\.)+)([A-Z][A-Za-z0-9_]*)\b/g, (all, mods, name) => {
      const m = mods.slice(0, -1);
      if (m === own) return name;
      if (m.startsWith('Klar.')) return m.slice(5) + '.' + name;
      if (m === 'Klar') return name;
      if (CORE_TYPE.test(m)) return name;
      if (m === 'Platform.Cmd' || m === 'Platform.Sub' || m === 'Platform' || (m === 'Html' && name === 'Html')) return name;
      return m + '.' + name;
    });
}

// Split a type at the top-level occurrences of a separator ("->" or ",").
export function splitTop(text, separator) {
  const parts = [];
  let depth = 0;
  let current = '';
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if ('({['.includes(c)) depth++;
    if (')}]'.includes(c)) depth--;
    if (depth === 0 && text.startsWith(separator, i)) {
      parts.push(current.trim());
      current = '';
      i += separator.length - 1;
    } else current += c;
  }
  parts.push(current.trim());
  return parts;
}

export function signature(name, type, own) {
  const t = prettyType(type, own);
  const one = `${name} : ${t}`;
  if (one.length <= 100) return one;
  const parts = splitTop(t, '->');
  if (parts.length === 1) return one;
  return `${name} :\n    ${parts[0]}\n` + parts.slice(1).map((p) => `    -> ${p}`).join('\n');
}

function recordBody(t) {
  // "{ a : Int, b : String }" or "{ r | a : Int }" -> field lines, or null
  const m = /^\{\s*([\s\S]*?)\s*\}$/.exec(t);
  if (!m) return null;
  return splitTop(m[1], ',');
}

function typeParams(name, args) {
  return [name, ...args].join(' ');
}

export function aliasDeclaration(a, own) {
  const t = prettyType(a.type, own);
  const head = `type alias ${typeParams(a.name, a.args)} =`;
  const one = `${head} ${t}`;
  const fields = recordBody(t);
  if (one.length <= 100 || fields === null) return one;
  return `${head}\n    { ` + fields.join('\n    , ') + '\n    }';
}

export function unionDeclaration(u, own) {
  const head = `type ${typeParams(u.name, u.args)}`;
  if (u.cases.length === 0) return head + '  -- opaque: no constructors are exposed';
  const cases = u.cases.map(([c, args]) => [c, ...args.map((a) => prettyType(a, own)).map((a) => (/[ ]/.test(a) && !/^[({\[]/.test(a) ? `(${a})` : a))].join(' '));
  const one = `${head} = ${cases.join(' | ')}`;
  if (one.length <= 100) return one;
  return `${head}\n    = ` + cases.join('\n    | ');
}

// The result of a function: the last part of the type after the top-level arrows.
export function resultType(type) {
  const parts = splitTop(type, '->');
  return parts[parts.length - 1];
}

export function isAttributeType(type) {
  return /\bAttribute( \w+)?$/.test(resultType(type));
}
