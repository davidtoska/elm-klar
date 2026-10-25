// Compile user-authored Elm attributes in a private copy of the showcase.
// The working tree is read-only to this service. Expressions never enter a shell.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import { tokens, edits, signatures, arrows, publicAttributes } from './gallery-source.mjs';

const require = createRequire(import.meta.url);
const compiler = require('../node_modules/elm/binary.js')();
const normal = text => text.replaceAll('\r\n', '\n');
const walk = dir => fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]);
const atomEnd = (ts, start) => {
  if (!['(', '[', '{'].includes(ts[start]?.value)) return start;
  const stack = [];
  for (let i = start; i < ts.length; i++) {
    if (['(', '[', '{'].includes(ts[i].value)) stack.push(ts[i].value);
    else if ([')', ']', '}'].includes(ts[i].value)) {
      stack.pop();
      if (!stack.length) return i;
    }
  }
  throw Error('Unclosed Elm expression');
};
const readString = token => { try { return JSON.parse(token?.value); } catch { return null; } };

function viewArguments(source, ts, targetIndex, alias, component, librarySource) {
  const views = new Map(signatures(librarySource).filter(sig => /(?:Html|Overlay) msg$/.test(sig.type)).map(sig => [alias + '.' + sig.name, arrows(sig.type).slice(0, -1)]));
  if (['Button', 'Badge', 'Tag', 'Alert'].includes(component)) views.set('Options.' + component.toLowerCase() + 'View', ['Config.Config', ...arrows(signatures(librarySource).find(sig => sig.name === 'view').type).slice(0, -1)]);
  for (let index = targetIndex - 1; index >= Math.max(0, targetIndex - 1000); index--) {
    const types = views.get(ts[index].value);
    if (!types) continue;
    const positions = [];
    let start = index + 1;
    let valid = true;
    for (const type of types) {
      if (!ts[start] || [')', ']', '}', ',', '|', '='].includes(ts[start].value)) { valid = false; break; }
      const end = atomEnd(ts, start);
      positions.push({ type, start: ts[start].start, end: ts[end].end, first: start, last: end });
      start = end + 1;
    }
    const attributes = positions.find(position => /^List \(?Attribute\b/.test(position.type));
    if (!valid || !attributes || targetIndex < attributes.first || targetIndex > attributes.last) continue;
    return positions.flatMap((position, arg) => {
      if (position === attributes || position.type === 'Config.Config') return [];
      const kind = /->\s*msg\)?$/.test(position.type) ? 'Event mapping' : /\bState\b/.test(position.type) ? 'State' : /String/.test(position.type) && !position.type.startsWith('{') ? 'Content' : /Html/.test(position.type) ? 'Children' : 'Data';
      return [{ key: '$argument-' + arg, name: 'View ' + kind.toLowerCase(), type: position.type, sample: source.slice(position.start, position.end), start: position.start, end: position.end }];
    });
  }
  return [];
}

export function targetsFor(root, component) {
  if (!/^[A-Z][A-Za-z0-9.]*$/.test(component)) throw Error('Invalid component name');
  const library = path.join(root, 'src', 'Klar', ...component.split('.')) + '.elm';
  if (!fs.existsSync(library)) return [];
  const librarySource = fs.readFileSync(library, 'utf8');
  const api = new Map(publicAttributes(librarySource).map(a => [a.name, a]));
  if (!api.size) return [];
  const method = 'klar' + component.replaceAll('.', '');
  const catalog = fs.readFileSync(path.join(root, 'example/src/Page/Gallery/Catalog.elm'), 'utf8');
  const owner = [...catalog.slice(catalog.indexOf('components section =')).matchAll(/\b(\w+) ->\s*\[([^\]]*)\]/g)].find(match => match[2].includes(JSON.stringify(component)))?.[1];
  const functions = new Map();
  const targets = [];
  const renderers = new Map(signatures(librarySource).filter(sig => /(?:Html|Overlay) msg$/.test(sig.type)).map(sig => [sig.name, arrows(sig.type).slice(0, -1).findIndex(type => /^List \(?Attribute\b/.test(type))]).filter(([, index]) => index >= 0));
  for (const file of walk(path.join(root, 'example/src/Page')).filter(f => f.endsWith('.elm'))) {
    const source = normal(fs.readFileSync(file, 'utf8'));
    const module = /^module ([\w.]+)/.exec(source)?.[1];
    const alias = new RegExp('^import Klar\\.' + component.replaceAll('.', '\\.') + '(?: as (\\w+))?\\b', 'm').exec(source);
    if (!alias) continue;
    const aliasName = alias[1] || 'Klar.' + component;
    const ts = tokens(source);
    const sigs = signatures(source);
    const aliasMap = new Map([...source.matchAll(/^import ([\w.]+)(?: as (\w+))?/gm)].map(match => [match[2] || match[1], match[1]]));
    for (let index = 0; index < sigs.length; index++) {
      const sig = sigs[index];
      const body = source.slice(sig.end, sigs[index + 1]?.start || source.length);
      const selected = [...body.matchAll(/Doc\.configuredSection \w+\s*\[([^\]]*)\]/g)].some(match => match[1].includes(JSON.stringify(component)));
      functions.set(module + '.' + sig.name, { module, aliasMap, body, selected });
    }
    const imports = [...source.matchAll(/^import .+$/gm)].map(m => m[0]);
    const union = /^type Msg\s*\n\s*=([\s\S]*?)(?=\n\n)/m.exec(source);
    const constructors = union ? [...union[1].matchAll(/(?:^|\|)\s*(\w+)/g)].map(m => m[1]) : [];
    for (let i = 0; i < ts.length; i++) {
      let start;
      if (ts[i].value === 'Options.' + method) {
        start = atomEnd(ts, i + 1) + 1;
      } else {
        const name = ts[i].value.startsWith(aliasName + '.') ? ts[i].value.slice(aliasName.length + 1) : '';
        if (!renderers.has(name)) continue;
        start = i + 1;
        for (let argument = 0; argument < renderers.get(name); argument++) start = atomEnd(ts, start) + 1;
        const end = atomEnd(ts, start);
        if (ts.slice(start, end + 1).some(token => token.value === 'Options.' + method)) continue;
      }
      const last = atomEnd(ts, start);
      if (!ts[start]) continue;
      const fn = sigs.filter(s => s.start < ts[i].start).at(-1);
      const samples = {};
      const keeps = [];
      for (let k = start; k < last; k++) {
        if (ts[k].value !== 'Config.keep' || readString(ts[k + 2]) !== component) continue;
        const key = readString(ts[k + 3]);
        if (!api.has(key)) continue;
        const end = atomEnd(ts, k + 4);
        const original = source.slice(ts[k + 4].start, ts[end].end);
        samples[key] = original.startsWith('(') ? original.slice(1, -1) : original;
        keeps.push({ key, start: ts[k].start, end: ts[end].end });
      }
      if (ts[start].value === '[') {
        let item = start + 1;
        while (item < last) {
          let end = item;
          while (end < last && ts[end].value !== ',') end = atomEnd(ts, end) + 1;
          const key = ts[item]?.value.startsWith(aliasName + '.') ? ts[item].value.slice(aliasName.length + 1) : '';
          if (api.has(key)) {
            samples[key] = source.slice(ts[item].start, ts[end - 1].end);
            keeps.push({ key, start: ts[item].start, end: ts[end - 1].end, raw: true });
          }
          item = end + 1;
        }
      }
      const id = module + ':' + fn?.name + ':' + targets.filter(t => t.module === module && t.function === fn?.name).length;
      const trace = union && /^update(?:\s+\w+)+\s*=\s*\n(?:[\s\S]*?)case \w+ of/m.test(source);
      const options = [...api.values()].map(a => {
        const args = arrows(a.type).slice(0, -1);
        const callbackParts = args.length === 1 ? arrows(args[0].replace(/^\(/, '').replace(/\)$/, '')) : [];
        const callback = args.length === 1 && (args[0] === 'msg' || (callbackParts.length > 1 && callbackParts.at(-1) === 'msg'));
        let traceExpression = '';
        if (trace && callback) {
          const argument = args[0];
          const parameters = argument === 'msg' ? [] : arrows(argument.replace(/^\(/, '').replace(/\)$/, '')).slice(0, -1).map((_, index) => 'arg' + (index + 1));
          const message = `PlaygroundObserved ${JSON.stringify(a.name)} [ ${parameters.map(p => 'Debug.toString ' + p).join(', ')} ]`;
          traceExpression = aliasName + '.' + a.name + ' (' + (parameters.length ? '\\' + parameters.join(' ') + ' -> ' : '') + message + ')';
        }
        return { name: a.name, type: a.type, sample: samples[a.name] || '', trace: traceExpression };
      });
      const body = fn ? source.slice(fn.end, sigs.find(s => s.start > fn.start)?.start || source.length) : '';
      const sections = [...body.matchAll(/Doc\.configuredSection \w+\s*\[([^\]]*)\]/g)];
      const relevance = (module === 'Page.Gallery.' + owner || module.startsWith('Page.Gallery.' + owner + '.') ? 1000 : 0) + (sections.length ? sections.some(section => section[1].includes(JSON.stringify(component))) ? 2000 : -4000 : 0);
      const arguments_ = viewArguments(source, ts, start, aliasName, component, librarySource);
      targets.push({ id, module, domain: owner, function: fn?.name || '', label: `${module.replace('Page.Gallery.', '')} · ${fn?.name} · ${targets.filter(t => t.module === module && t.function === fn?.name).length + 1}`, file: path.relative(path.join(root, 'example'), file).replaceAll(path.sep, '/'), alias: aliasName, imports, constructors, options, arguments: arguments_, relevance, start: ts[start].start, end: ts[last].end, keeps, source });
      i = last;
    }
  }
  const reachable = new Set([...functions].filter(([, fn]) => fn.selected).map(([name]) => name));
  const pending = [...reachable];
  while (pending.length) {
    const fn = functions.get(pending.pop());
    for (const token of tokens(fn.body)) {
      const dot = token.value.lastIndexOf('.');
      const name = dot < 0 ? fn.module + '.' + token.value : fn.aliasMap.get(token.value.slice(0, dot)) + '.' + token.value.slice(dot + 1);
      if (functions.has(name) && !reachable.has(name)) { reachable.add(name); pending.push(name); }
    }
  }
  const own = targets.filter(target => target.module === 'Page.Gallery.' + owner || target.module.startsWith('Page.Gallery.' + owner + '.'));
  const relevant = (own.length ? own : targets).filter(target => reachable.has(target.module + '.' + target.function));
  const candidates = relevant.length ? relevant : own.length ? own : targets;
  // Prefer the component's own examples over components nested inside another demo.
  const score = target => {
    return target.relevance;
  };
  return candidates.sort((a, b) => score(b) - score(a) || a.file.localeCompare(b.file) || a.start - b.start);
}

export function describe(root, component) {
  return targetsFor(root, component).map(({ source, start, end, keeps, ...publicTarget }) => publicTarget);
}

export function patchTarget(target, component, expressions, imports = '', definitions = '') {
  const changes = [];
  const keys = Object.keys(expressions);
  if (!keys.length) throw Error('Enable at least one custom Elm expression.');
  const known = new Set([...target.options.map(option => option.name), ...target.arguments.map(argument => argument.key)]);
  for (const key of keys) {
    if (!known.has(key)) throw Error('Unknown attribute: ' + key);
    if (typeof expressions[key] !== 'string' || !expressions[key].trim()) throw Error('Empty Elm expression for ' + key);
  }
  const replaced = new Set();
  for (const argument of target.arguments) {
    if (!keys.includes(argument.key)) continue;
    changes.push({ start: argument.start, end: argument.end, text: '(' + expressions[argument.key] + ')' });
    replaced.add(argument.key);
  }
  for (const keep of target.keeps) {
    if (!keys.includes(keep.key)) continue;
    // Remove the old expression from the AST, rather than hiding it at runtime.
    // That lets columns, remote rows and callbacks acquire the new inferred type.
    changes.push({ start: keep.start, end: keep.end, text: keep.raw ? `(${expressions[keep.key]})` : `[ (${expressions[keep.key]}) ]` });
    replaced.add(keep.key);
  }
  const additions = keys.filter(key => !replaced.has(key));
  if (additions.length) {
    changes.push({ start: target.start, end: target.start, text: '(' }, { start: target.end, end: target.end, text: ' ++ [ ' + additions.map(key => '(' + expressions[key] + ')').join(', ') + ' ])' });
  }
  let source = edits(target.source, changes);
  if (imports.trim()) {
    if (!imports.trim().split('\n').every(line => /^\s*(import\s+[A-Z][\w.]*(?:\s+as\s+[A-Z]\w*)?(?:\s+exposing\s*\([^\n]*\))?\s*|--.*|)$/.test(line))) throw Error('The imports editor accepts Elm import lines only.');
    const firstImport = source.indexOf('\nimport ');
    source = source.slice(0, firstImport) + '\n' + imports.trim() + '\n' + source.slice(firstImport);
  }
  if (expressions && Object.values(expressions).some(expression => tokens(expression).some(token => token.value === 'PlaygroundObserved'))) {
    const union = /^type Msg\s*\n\s*=([\s\S]*?)(?=\n\n)/m.exec(source);
    if (!union) throw Error('This target has no Msg union. Choose a stateful target or return one of its existing messages.');
    source = source.slice(0, union.index + union[0].length) + '\n    | PlaygroundObserved String (List String)' + source.slice(union.index + union[0].length);
    const sig = signatures(source).find(s => s.name === 'update');
    const definition = sig && source.slice(sig.end).match(/^update(?:\s+\w+)+\s*=\s*\n[\s\S]*?case (\w+) of/m);
    if (!definition) throw Error('This target delegates update. Choose the module that owns the callback.');
    const at = sig.end + definition.index + definition[0].length;
    const model = /^update\s+([^=]+)=/.exec(definition[0])[1].trim().split(/\s+/).at(-1);
    const result = /->\s*\( Model, Cmd Msg \)$/.test(sig.type) ? `( ${model}, Cmd.none )` : model;
    source = source.slice(0, at) + `\n        PlaygroundObserved callback arguments ->\n            Debug.log "__klar_playground_callback__" ( callback, arguments ) |> always ${result}\n` + source.slice(at);
  }
  return source + '\n\n-- User-authored playground definitions\n' + definitions + '\n';
}

export function createCompiler(root) {
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), 'elm-klar-playground-'));
  const artifacts = new Map();
  let queue = Promise.resolve();
  let closed = false;
  const compile = input => {
    const run = queue.then(async () => {
      if (closed) throw Error('Playground compiler is closed.');
      const target = targetsFor(root, input.component).find(t => t.id === input.target);
      if (!target) throw Error('The selected target no longer exists. Reload its context.');
      const patched = patchTarget(target, input.component, input.expressions || {}, input.imports, input.definitions);
      fs.cpSync(path.join(root, 'example/src'), path.join(workspace, 'src'), { recursive: true });
      const outline = JSON.parse(fs.readFileSync(path.join(root, 'example/elm.json'), 'utf8'));
      outline['source-directories'] = ['src', path.join(root, 'src').replaceAll(path.sep, '/')];
      fs.writeFileSync(path.join(workspace, 'elm.json'), JSON.stringify(outline));
      fs.writeFileSync(path.join(workspace, target.file), patched);
      // Compile just the gallery. Unrelated application pages can be under
      // development without breaking a component's expression editor.
      fs.writeFileSync(path.join(workspace, 'src/PlaygroundMain.elm'), previewMain(root, input, target.domain));
      const build = crypto.randomUUID();
      const output = path.join(workspace, build + '.js');
      const result = await new Promise((resolve, reject) => {
        const child = spawn(compiler, ['make', 'src/PlaygroundMain.elm', '--report=json', '--output=' + output], { cwd: workspace, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
        let stdout = '', stderr = '';
        child.stdout.on('data', data => { stdout += data; });
        child.stderr.on('data', data => { stderr += data; });
        const timeout = setTimeout(() => { child.kill(); reject(Error('Compilation exceeded 90 seconds. Your last successful preview is preserved.')); }, 90000);
        child.on('error', error => { clearTimeout(timeout); reject(error); });
        child.on('exit', code => { clearTimeout(timeout); resolve({ code, stdout, stderr }); });
      });
      if (result.code !== 0) return { ok: false, diagnostics: diagnostics(result.stderr || result.stdout, workspace), url: '' };
      artifacts.set(build, output);
      if (artifacts.size > 12) { const oldest = artifacts.keys().next().value; fs.unlinkSync(artifacts.get(oldest)); artifacts.delete(oldest); }
      return { ok: true, diagnostics: '', url: '/__playground/preview/' + build + '/#/components/' + input.slug };
    });
    queue = run.catch(() => {});
    return run;
  };
  return {
    compile,
    artifact: id => artifacts.get(id),
    close: async () => {
      closed = true;
      await queue;
      const resolved = fs.realpathSync(workspace);
      if (path.dirname(resolved).toLowerCase() !== fs.realpathSync(os.tmpdir()).toLowerCase() || !path.basename(resolved).startsWith('elm-klar-playground-')) throw Error('Unexpected compiler workspace path');
      fs.rmSync(resolved, { recursive: true, force: true });
    },
  };
}

function previewMain(root, input, domain) {
  const module = 'Page.Gallery.' + domain;
  const source = fs.readFileSync(path.join(root, 'example/src', ...module.split('.')) + '.elm', 'utf8');
  const api = new Map(signatures(source).map(s => [s.name, s.type]));
  const args = type => arrows(type).slice(0, -1).map(type => ({ 'Config.Config': 'configuration', 'Config': 'configuration', 'Locale': 'Locale.en', 'Settings': 'Settings.default', 'Model': 'model', 'Msg': 'msg' })[type] || type).join(' ');
  const init = 'Demo.init ' + args(api.get('init'));
  const update = 'Demo.update ' + args(api.get('update'));
  const values = Object.entries(input.values || {}).filter(([key]) => !Object.hasOwn(input.expressions || {}, key));
  const pairs = values.map(([key, value]) => `( ${JSON.stringify(key)}, ${JSON.stringify(value)} )`).join(', ');
  return `module PlaygroundMain exposing (main)

import Browser
import Dict
import Html
import Html.Attributes as Attr
import Klar
import Klar.Locale as Locale
import Klar.Settings as Settings
import Showcase.Config as Config
import ${module} as Demo

configuration : Config.Config
configuration = { component = ${JSON.stringify(input.component)}, values = Dict.fromList [ ${pairs} ] }

main : Program () Demo.Model Demo.Msg
main = Browser.document { init = init, update = update, subscriptions = subscriptions, view = view }

init _ = ${api.get('init').includes('Cmd') ? init : '( ' + init + ', Cmd.none )'}

update msg model = ${api.get('update').includes('Cmd') ? update : '( ' + update + ', Cmd.none )'}

subscriptions model = Demo.subscriptions ${args(api.get('subscriptions'))}

view model = { title = "Custom component preview", body = [ Klar.stylesheet, Html.main_ [ Attr.style "padding" "12px" ] [ Demo.view ${args(api.get('view'))} ] ] }
`;
}

function diagnostics(text, workspace) {
  try {
    const report = JSON.parse(text);
    const flatten = message => (message || []).map(part => typeof part === 'string' ? part : part.string).join('');
    if (report.errors) return report.errors.flatMap(error => error.problems.map(problem => `${error.path.replace(workspace, 'preview')} ${problem.region.start.line}:${problem.region.start.column}\n${problem.title}\n${flatten(problem.message)}`)).join('\n\n');
    return flatten(report.message) || text;
  } catch { return text.replaceAll(workspace, 'preview'); }
}
