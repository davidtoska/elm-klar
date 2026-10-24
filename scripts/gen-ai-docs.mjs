#!/usr/bin/env node
// Turns the documentation of the package into text an AI can read.
//
//   node scripts/gen-ai-docs.mjs            write the files
//   node scripts/gen-ai-docs.mjs --check    fail when the committed files differ from what would be written
//
// Written (never edit by hand; the source of truth is the doc comments in src/):
//
//   ai/modules/<Module>.md   one file per exposed module: the purpose, every signature, then
//                            the documentation in the author's order (the `@docs` sections)
//   ai/modules/README.md     the modules by group, one line each
//   ai/klar-index.json       for each module: purpose, when to use, when not, State / Msg / ids,
//                            main functions, related modules, keywords
//
// `elm make --docs` keeps the `@docs` lines in the module comment, so the order of the
// sections is the order the author chose.

import fs from 'node:fs';
import path from 'node:path';
import {
  aliasDeclaration,
  aliasOf,
  commentBlocks,
  importLine,
  isAttributeType,
  loadDocs,
  moduleGroups,
  paragraphs,
  prettyType,
  proseOf,
  root,
  signature,
  unionDeclaration,
} from './lib/klar-docs.mjs';

const check = process.argv.includes('--check');

// ------------------------------------------------------------------ helpers

function clean(text) {
  return text
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/(^|[^\w`])\*([^*\s][^*]*)\*/g, '$1$2')
    .replace(/\s+/g, ' ')
    .trim();
}

function sentences(paragraph) {
  return paragraph.split(/(?<=[.!?])\s+(?=[A-Z*`\[])/).map((s) => s.trim()).filter(Boolean);
}

function clip(text, max) {
  if (text.length <= max) return text;
  const cut = text.slice(0, max);
  return cut.slice(0, Math.max(cut.lastIndexOf(' '), 40)).replace(/[,;:]$/, '') + ' ...';
}

// Links between module pages: [Klar.Table](Klar-Table#columnId) -> [Klar.Table](Klar.Table.md#columnid)
function fixLinks(text) {
  return text
    .replace(/\]\((Klar(?:-[A-Za-z0-9]+)*)(#[A-Za-z0-9_]+)?\)/g, (all, mod, anchor) => `](${mod.replace(/-/g, '.')}.md${anchor ? anchor.toLowerCase() : ''})`)
    .replace(/\]\(#([A-Za-z0-9_]+)\)/g, (all, anchor) => `](#${anchor.toLowerCase()})`);
}

function demoteHeadings(text) {
  return text.replace(/^(#{1,5}) /gm, '#$1 ');
}

function linkedModules(text) {
  const found = [];
  for (const m of text.matchAll(/\]\((Klar(?:-[A-Za-z0-9]+)*)(?:#[A-Za-z0-9_]+)?\)/g)) found.push(m[1].replace(/-/g, '.'));
  return found;
}

// ----------------------------------------------------------------- one module

function renderModule(m, group) {
  const isIconSet = m.name.startsWith('Klar.Icon.') && m.name !== 'Klar.Icon.Library';
  const entries = new Map();
  for (const u of m.unions) entries.set(u.name, { kind: 'union', item: u });
  for (const a of m.aliases) entries.set(a.name, { kind: 'alias', item: a });
  for (const v of m.values) entries.set(v.name, { kind: 'value', item: v });
  for (const b of m.binops) entries.set(b.name, { kind: 'binop', item: b });

  const blocks = commentBlocks(m.comment);
  const listed = new Set(blocks.filter((b) => b.kind === 'docs').flatMap((b) => b.names));
  const unlisted = [...entries.keys()].filter((n) => !listed.has(n));

  const declaration = (name) => {
    const e = entries.get(name);
    if (!e) return null;
    if (e.kind === 'union') return unionDeclaration(e.item, m.name);
    if (e.kind === 'alias') return aliasDeclaration(e.item, m.name);
    if (e.kind === 'binop') return `(${name}) : ${prettyType(e.item.type, m.name)}`;
    return signature(name, e.item.type, m.name);
  };
  const isType = (name) => {
    const e = entries.get(name);
    return e && (e.kind === 'union' || e.kind === 'alias');
  };

  const glance = []; // signatures at a glance
  const body = []; // documentation in the author's order
  let heading = null;
  let pending = [];
  let glanceHeading = null;

  const flush = () => {
    if (pending.length === 0) return;
    const names = [...pending.filter(isType), ...pending.filter((n) => !isType(n))];
    pending = [];
    if (heading !== null && heading !== glanceHeading) {
      if (glance.length > 0) glance.push('');
      glance.push('-- ' + heading);
      glanceHeading = heading;
    }
    if (isIconSet) {
      glance.push(...names);
      return;
    }
    for (const name of names) {
      const decl = declaration(name);
      if (decl === null) continue;
      glance.push(decl);
      const e = entries.get(name);
      body.push(`### \`${name}\``, '', '```elm', decl, '```', '');
      const comment = e.item.comment.replace(/^ /, '').trim();
      if (comment) body.push(fixLinks(demoteHeadings(comment)), '');
    }
  };

  for (const block of blocks) {
    if (block.kind === 'docs') {
      pending.push(...block.names.filter((n) => entries.has(n)));
      continue;
    }
    flush();
    const headings = [...block.text.matchAll(/^#{1,5} (.+)$/gm)];
    if (headings.length > 0) heading = headings[headings.length - 1][1].trim();
    const text = block.text.replace(/\s+$/, '');
    if (text.trim()) body.push(fixLinks(demoteHeadings(text)), '');
  }
  flush();
  if (unlisted.length > 0) {
    // exposed in the module but missing from every @docs line: check:docs fails on that, still show them
    pending.push(...unlisted);
    heading = 'Not in any @docs line';
    flush();
  }

  const purpose = purposeOf(m);
  const out = [`# ${m.name}`, '', purpose, ''];
  out.push(`Import: \`${importLine(m.name, m.comment)}\`${group ? ` | Group: ${group}` : ''}`, '');
  const types = [...m.unions.map((u) => u.name), ...m.aliases.map((a) => a.name)];
  if (types.length > 0) out.push(`Types: ${types.map((t) => `\`${t}\``).join(', ')}`, '');
  if (isIconSet) {
    out.push('## Icons', '', '```elm', ...glance.filter((l) => l && !l.startsWith('--')), '```', '');
    out.push('Each is a `Icon.Icon`; use it with `Icon.view`, `Icon.sized` or any component that takes an icon.', '');
    return out.join('\n');
  }
  out.push('## Signatures', '', '```elm', ...glance.filter((l, i, a) => !(l === '' && (i === 0 || a[i - 1] === ''))), '```', '');
  out.push('## Documentation', '', ...body);
  return out.join('\n').replace(/\n{3,}/g, '\n\n').replace(/\s+$/, '') + '\n';
}

function purposeOf(m) {
  const first = paragraphs(m.comment)[0] || '';
  let s = clean(sentences(first)[0] || first);
  if (s.length > 200) {
    const colon = s.indexOf(':');
    s = colon > 40 && colon < 200 ? s.slice(0, colon).trim() + '.' : clip(s, 200);
  }
  return s;
}

// ---------------------------------------------------------------------- index

const STOP = new Set('that this with from which their there they have into each also only when then than them what your will been more other some such these those where while about after before would could should without within between because shows show used uses using make makes made called'.split(' '));

const SYNONYMS = {
  'Klar.Table': ['grid', 'datagrid', 'rows', 'columns', 'sort', 'filter', 'paging', 'pagination', 'server mode', 'virtual', 'csv', 'bulk'],
  'Klar.FilterBar': ['filters', 'search', 'rule', 'chips', 'query'],
  'Klar.SavedViews': ['views', 'bookmarks', 'presets', 'saved filters'],
  'Klar.Remote': ['loading', 'async', 'request', 'backend', 'not asked', 'failed', 'retry'],
  'Klar.Form': ['validation', 'submit', 'fields', 'layout', 'unsaved', 'form state', 'dirty', 'server errors', 'record', 'steps'],
  'Klar.Validate': ['validation', 'rules', 'required', 'email'],
  'Klar.Overlay': ['focus', 'modal', 'toast', 'layer', 'stack'],
  'Klar.Modal': ['dialog', 'popup'],
  'Klar.ConfirmDialog': ['confirm', 'delete', 'are you sure', 'destructive'],
  'Klar.Drawer': ['side panel', 'detail', 'slide over'],
  'Klar.Toast': ['notification', 'snackbar', 'message'],
  'Klar.CommandPalette': ['search', 'go to', 'ctrl k', 'actions', 'launcher'],
  'Klar.AppShell': ['layout', 'frame', 'top bar', 'sidebar', 'application'],
  'Klar.SideNav': ['menu', 'navigation', 'routes', 'sidebar'],
  'Klar.LeaveGuard': ['unsaved', 'navigate away', 'prompt', 'back button'],
  'Klar.Stat': ['kpi', 'metric', 'number', 'tile', 'dashboard'],
  'Klar.Chart': ['graph', 'line', 'bar', 'donut', 'gauge', 'sparkline', 'dashboard'],
  'Klar.Timeline': ['history', 'activity', 'events', 'audit', 'log'],
  'Klar.Tree': ['hierarchy', 'folders', 'nested', 'expand'],
  'Klar.RuleBuilder': ['conditions', 'and or', 'query builder', 'filter'],
  'Klar.Rule': ['conditions', 'filter', 'predicate', 'json'],
  'Klar.Date': ['calendar date', 'day', 'month', 'year'],
  'Klar.Select': ['dropdown', 'combobox', 'options', 'choose'],
  'Klar.Stepper': ['wizard', 'steps', 'multi-step', 'progress'],
  'Klar.Locale': ['language', 'norwegian', 'english', 'translation', 'i18n'],
  'Klar.Theme': ['tone', 'size', 'density', 'colors', 'dark mode'],
  'Klar.Settings': ['density', 'compact', 'comfortable', 'time zone', 'zone', 'settings', 'utc'],
  'Klar.Format': ['numbers', 'currency', 'dates', 'text'],
  'Klar.Shortcut': ['keyboard', 'keys', 'hotkey'],
  'Klar.VirtualList': ['long list', 'scroll', 'virtual'],
  'Klar.Layout': ['stack', 'row', 'grid', 'spacing', 'width'],
};

function keywordsOf(m, group, purpose) {
  const words = [];
  const last = m.name.split('.').pop();
  words.push(last.replace(/([a-z0-9])([A-Z])/g, '$1 $2').toLowerCase());
  for (const part of m.name.split('.').slice(1)) words.push(part.toLowerCase());
  if (group) words.push(group.toLowerCase());
  words.push(...(SYNONYMS[m.name] || []));
  const fromPurpose = clean(purpose).toLowerCase().match(/[a-z]{5,}/g) || [];
  words.push(...fromPurpose.filter((w) => !STOP.has(w)).slice(0, 5));
  return [...new Set(words)];
}

// "Quick path: `init`, `update`, `view`" -> ["init", "update", "view"]
function quickPathOf(m) {
  const line = /^\**Quick path\**:?\**:?\s*(.+)$/im.exec(proseOf(m.comment));
  return line ? [...line[1].matchAll(/`([\w.]+)`/g)].map((x) => x[1]) : [];
}

function whenFromText(m) {
  const text = proseOf(m.comment);
  let use = '';
  let not = '';
  const quickUse = /^\**Use when\**:?\**:?\s*(.+)$/im.exec(text);
  const quickNot = /^\**Do not use when\**:?\**:?\s*(.+)$/im.exec(text);
  if (quickUse) use = clean(quickUse[1]);
  if (quickNot) not = clean(quickNot[1]);
  if (use && not) return { use, not };
  const sents = paragraphs(m.comment)
    .slice(0, 4)
    .flatMap(sentences)
    .slice(1);
  if (!use) {
    const hit = sents.filter((s) => /^(Use|Used|Reach for|Choose|Pick)\b/.test(clean(s)) || /\b[Uu]se (it|this|a|an|the|them|one)\b/.test(clean(s)) || /\bis for\b|\bare for\b/.test(clean(s)));
    use = clip(hit.slice(0, 2).map(clean).join(' '), 320);
  }
  if (!not) {
    const hit = sents.filter((s) => {
      const t = clean(s);
      return /^(Do not use|Not for|Unlike|Where)\b/.test(t) || (/\[Klar\.[A-Za-z.]+\]/.test(s) && /\b(instead|see|use|for)\b/i.test(t) && !/^(Use|Used)\b/.test(t));
    });
    not = clip(hit.slice(0, 2).map(clean).join(' '), 320);
  }
  return { use, not };
}

function buildIndexEntry(m, group) {
  const purpose = purposeOf(m);
  const { use, not } = whenFromText(m);
  const typeNames = [...m.unions.map((u) => u.name), ...m.aliases.map((a) => a.name)];
  const pick = (re) => typeNames.filter((t) => re.test(t));
  const fnNames = m.values.map((v) => v.name);
  const blocks = commentBlocks(m.comment).filter((b) => b.kind === 'docs');
  const byName = new Map(m.values.map((v) => [v.name, v]));
  const main = [];
  for (const b of blocks) {
    for (const n of b.names) {
      const v = byName.get(n);
      if (v && !isAttributeType(v.type) && !main.includes(n)) main.push(n);
    }
    if (main.length >= 8) break;
  }
  const counts = new Map();
  const prose = [proseOf(m.comment), ...m.values.map((v) => v.comment), ...m.unions.map((u) => u.comment), ...m.aliases.map((a) => a.comment)].join('\n');
  for (const l of linkedModules(prose)) if (l !== m.name && l !== 'Klar') counts.set(l, (counts.get(l) || 0) + 1);
  const related = [...counts.entries()].sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1)).slice(0, 8).map(([n]) => n);
  return {
    name: m.name,
    import: importLine(m.name, m.comment),
    group,
    purpose,
    whenToUse: use,
    whenNot: not,
    state: pick(/^State$/),
    msg: pick(/^Msg$/),
    ids: pick(/(^Ids?$|Id$|Ids$|^Keys$)/),
    stateful: fnNames.includes('update') && (typeNames.includes('State') || typeNames.includes('Msg')),
    quickPath: quickPathOf(m),
    mainFunctions: main.slice(0, 8),
    related,
    keywords: keywordsOf(m, group, purpose),
    reference: `ai/modules/${m.name}.md`,
  };
}

// ---------------------------------------------------------------------- files

function readmeMd(index) {
  const lines = ['# Klar modules', '', 'One file per exposed module, generated from the doc comments by `npm run gen:ai-docs`. Start with [../klar-index.json](../klar-index.json) or [../../AI.md](../../AI.md).', ''];
  let group = null;
  for (const e of index) {
    if (e.group !== group) {
      group = e.group;
      lines.push(`## ${group}`, '');
    }
    lines.push(`- [${e.name}](${e.name}.md): ${e.purpose}`);
  }
  lines.push('');
  return lines.join('\n');
}

// ----------------------------------------------------------------------- main

const docs = loadDocs();
const groups = moduleGroups();
const files = new Map();
const index = [];
for (const m of docs) {
  const group = groups.get(m.name) || '';
  files.set(`ai/modules/${m.name}.md`, renderModule(m, group));
  index.push(buildIndexEntry(m, group));
}
files.set('ai/modules/README.md', readmeMd(index));
files.set('ai/klar-index.json', JSON.stringify({ package: 'davidtoska/elm-klar', note: 'Generated by npm run gen:ai-docs from the doc comments. Do not edit.', modules: index }, null, 2) + '\n');

const expected = new Set(files.keys());
const moduleDir = path.join(root, 'ai', 'modules');
const existing = fs.existsSync(moduleDir) ? fs.readdirSync(moduleDir).map((f) => `ai/modules/${f}`) : [];
const stale = [];
for (const [rel, content] of files) {
  const full = path.join(root, rel);
  const current = fs.existsSync(full) ? fs.readFileSync(full, 'utf8').replace(/\r\n/g, '\n') : null;
  if (current !== content) stale.push(rel);
  if (!check && current !== content) {
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, content);
  }
}
const leftovers = existing.filter((f) => !expected.has(f));
if (!check) for (const f of leftovers) fs.rmSync(path.join(root, f));

const lacking = index.filter((e) => !e.whenToUse || !e.whenNot).map((e) => e.name);
if (check) {
  if (lacking.length > 0) {
    console.log(`${lacking.length} module(s) have no "Use when:" or "Do not use when:" line in their doc comment: ${lacking.join(', ')}`);
    process.exit(1);
  }
  if (stale.length > 0 || leftovers.length > 0) {
    console.log(`AI documentation is stale: ${stale.length} file(s) differ, ${leftovers.length} file(s) should not exist.`);
    for (const f of [...stale, ...leftovers].slice(0, 20)) console.log('  - ' + f);
    console.log('Run: npm run gen:ai-docs, and commit the result.');
    process.exit(1);
  }
  console.log(`AI documentation: up to date (${docs.length} modules).`);
} else {
  const noUse = index.filter((e) => !e.whenToUse && !/^Klar\.Icon\./.test(e.name)).length;
  const noNot = index.filter((e) => !e.whenNot && !/^Klar\.Icon\./.test(e.name)).length;
  console.log(`Wrote ${files.size} files for ${docs.length} modules (${stale.length} changed). Modules without "when to use": ${noUse}, without "when not": ${noNot}.`);
}
