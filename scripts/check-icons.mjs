#!/usr/bin/env node
// Checks that every icon value in src/Klar/Icon.elm has a rule in css/src/icons.css
// and the other way round.
//
//   node scripts/check-icons.mjs

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const elm = fs.readFileSync(path.join(root, 'src', 'Klar', 'Icon.elm'), 'utf8');
const css = fs.readFileSync(path.join(root, 'css', 'src', 'icons.css'), 'utf8');

const inElm = new Set([...elm.matchAll(/^\w+ =\n {4}Icon "([a-z0-9-]+)"$/gm)].map((m) => m[1]));
const inCss = new Set(
  [...css.matchAll(/^\.klar-icon--([a-z0-9-]+)\s*\{\s*--klar-icon:/gm)].map((m) => m[1]),
);
const sizes = new Set(['xs', 'sm', 'md', 'lg', 'xl', 'xxl', 'xxxl']);

const problems = [];
for (const name of inElm) if (!inCss.has(name)) problems.push(`Icon.elm has "${name}" but icons.css has no rule for it`);
for (const name of inCss) {
  if (!inElm.has(name) && !sizes.has(name)) problems.push(`icons.css has "${name}" but Icon.elm has no value for it`);
}

if (inElm.size === 0) problems.push('found no icons in src/Klar/Icon.elm (did its layout change?)');

if (problems.length > 0) {
  console.log(problems.join('\n'));
  process.exit(1);
}
console.log(`icons: ok (${inElm.size} icons)`);
