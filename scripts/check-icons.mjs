#!/usr/bin/env node
// Checks the icon library: every icon is an Elm value made with `fromSvg`, its name is
// unique and written in kebab-case, its drawing is made of the allowed shapes and has
// the characters that survive in a CSS url(), `Klar.Icon.Library` lists every icon
// module, and the stylesheet has no drawings of its own.
//
//   node scripts/check-icons.mjs

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const iconDir = path.join(root, 'src', 'Klar', 'Icon');
const files = [
  path.join(root, 'src', 'Klar', 'Icon.elm'),
  ...fs.readdirSync(iconDir).filter((f) => f.endsWith('.elm') && f !== 'Library.elm').map((f) => path.join(iconDir, f)),
];

const shapes = new Set(['path', 'circle', 'rect', 'line', 'polyline', 'polygon', 'ellipse']);
const attributes = new Set(['d', 'cx', 'cy', 'r', 'rx', 'ry', 'x', 'y', 'width', 'height', 'x1', 'y1', 'x2', 'y2', 'points', 'fill']);
const problems = [];
const names = new Map();

for (const file of files) {
  const rel = path.relative(root, file).replace(/\\/g, '/');
  const elm = fs.readFileSync(file, 'utf8');
  // fromSvg "name" "markup"  (a call in an icon definition)
  const definitions = [...elm.matchAll(/^(\w+) : Icon\n\1 =\n {4}(?:Icon\.)?fromSvg "([^"]*)" "([^"]*)"$/gm)];
  for (const [, fn, name, markup] of definitions) {
    if (!/^[a-z][a-z0-9]*(-[a-z0-9]+)*$/.test(name)) problems.push(`${rel}: "${name}" is not a kebab-case name`);
    if (names.has(name)) problems.push(`${rel}: "${name}" is also in ${names.get(name)}`);
    names.set(name, rel);
    const elements = markup.match(/<[^>]*>/g) || [];
    if (elements.length === 0 || elements.join('') !== markup) problems.push(`${rel}: ${name} has markup that is not only shapes`);
    for (const el of elements) {
      const m = /^<(\w+)((?: \w+='[^']*')*)\/>$/.exec(el);
      if (!m) {
        problems.push(`${rel}: ${name} has a malformed element ${el}`);
        continue;
      }
      if (!shapes.has(m[1])) problems.push(`${rel}: ${name} uses <${m[1]}>, which is not an allowed shape`);
      for (const a of m[2].matchAll(/ (\w+)='([^']*)'/g)) {
        if (!attributes.has(a[1])) problems.push(`${rel}: ${name} uses the attribute ${a[1]}`);
        if (a[1] === 'fill' && a[2] !== 'black' && a[2] !== 'none') problems.push(`${rel}: ${name} has fill='${a[2]}'`);
        if (/[%#"]/.test(a[2])) problems.push(`${rel}: ${name} has a character in ${a[1]} that breaks a CSS url()`);
      }
    }
    if (elm.split(`\n${fn} : Icon\n`).length !== 2) problems.push(`${rel}: ${fn} is defined twice`);
  }
  const defined = (elm.match(/^\w+ : Icon$/gm) || []).length;
  if (defined !== definitions.length) problems.push(`${rel}: ${defined} icon values but ${definitions.length} written as fromSvg "name" "shapes" on one line`);
}

const library = fs.readFileSync(path.join(iconDir, 'Library.elm'), 'utf8');
for (const f of fs.readdirSync(iconDir)) {
  const m = f.replace('.elm', '');
  if (m !== 'Library' && !library.includes(`Klar.Icon.${m}.all`)) problems.push(`Klar.Icon.Library does not list Klar.Icon.${m}`);
}

const css = fs.readFileSync(path.join(root, 'src', 'Klar', 'Internal', 'Css', 'Icons.elm'), 'utf8');
const sizes = new Set(['xs', 'sm', 'md', 'lg', 'xl', 'xxl', 'xxxl']);
for (const m of css.matchAll(/^\.klar-icon--([a-z0-9-]+)\s*\{/gm)) {
  if (!sizes.has(m[1])) problems.push(`Klar.Internal.Css.Icons has a rule for "${m[1]}": icon drawings belong in Elm (Icon.fromSvg)`);
}

if (names.size === 0) problems.push('found no icons (did the layout of src/Klar/Icon.elm change?)');
if (problems.length > 0) {
  console.log(problems.join('\n'));
  process.exit(1);
}
console.log(`icons: ok (${names.size} icons in ${files.length} modules)`);
