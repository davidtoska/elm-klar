#!/usr/bin/env node
// Browser test of Klar.LeaveGuard against the real browser buttons (headless Chrome over the
// DevTools protocol; pages are served over http because file:// has no history to speak of).
//
//   node scripts/test-leave-guard.mjs
//
// It builds scripts/leave-guard-browser (the example of the module documentation), serves it,
// and presses Back and Forward through `history.back()` / `history.forward()`. Chrome is found
// from $CHROME or the usual places. Exit code 1 if anything fails.
//
// What is checked, in short: Back asks while dirty and does not loop (`onUrlChange` is counted),
// Stay keeps the page, the draft and the history position, Leave goes where the user pressed,
// Forward works, a second Back after Stay asks again, links and code navigation ask too, and
// nothing is asked when nothing is dirty. Focus after Stay, Escape and Leave is checked.

import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { launch } from './lib/cdp.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const appDir = path.join(root, 'scripts', 'leave-guard-browser');
const out = fs.mkdtempSync(path.join(os.tmpdir(), 'klar-leave-guard-'));

const build = spawnSync('elm', ['make', 'src/Main.elm', `--output=${path.join(out, 'main.js')}`], { cwd: appDir, stdio: 'inherit', shell: true });
if (build.status !== 0) process.exit(build.status ?? 1);
fs.copyFileSync(path.join(appDir, 'index.html'), path.join(out, 'index.html'));

const server = http.createServer((request, response) => {
  const name = request.url.split('?')[0];
  const file = path.join(out, name === '/' ? 'index.html' : name);
  fs.readFile(file, (error, data) => {
    if (error) {
      response.writeHead(404);
      response.end();
      return;
    }
    response.writeHead(200, { 'content-type': file.endsWith('.js') ? 'text/javascript' : 'text/html' });
    response.end(data);
  });
});
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const URL = `http://127.0.0.1:${server.address().port}/`;

const b = await launch(9471);
let failed = 0;
const check = (name, ok, detail = '') => {
  if (!ok) failed++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '   ' + detail : ''}`);
};
const note = (name, detail) => console.log(`NOTE  ${name}   ${detail}`);

const state = async () => {
  const s = await b.evWithin(`JSON.stringify({
    route: document.getElementById('route')?.textContent,
    hash: location.hash,
    open: !!document.getElementById('leave-dialog-stay'),
    changes: +document.getElementById('url-changes')?.textContent,
    dirty: document.getElementById('dirty')?.textContent,
    draft: document.getElementById('draft')?.value ?? null,
    length: history.length,
  })`);
  if (s === '__FROZEN__') throw new Error('the page is frozen');
  return JSON.parse(s);
};
const history = async (call) => {
  await b.evWithin(`history.${call}(); true`);
  await b.sleep(350);
  await b.frames(3);
};
// A fresh page with the history  /, /orders, /orders/new  and the new-order page showing.
const fresh = async () => {
  await b.goto('about:blank');
  await b.goto(URL + '#/');
  await b.click('#link-orders');
  await b.click('a[href="#/orders/new"]');
  await b.sleep(150);
};
const dirty = async () => {
  await b.click('#make-dirty');
};

try {
  // 1. The Back button while dirty.
  await fresh();
  const s0 = await state();
  check('start: the new-order page, nothing asked', s0.route === '#/orders/new' && !s0.open && s0.dirty === 'no', JSON.stringify(s0));
  await dirty();
  await history('back');
  let s = await state();
  check('Back while dirty asks', s.open, JSON.stringify(s));
  check('Back does not loop (onUrlChange calls)', s.changes - s0.changes <= 2, `${s.changes - s0.changes} calls`);
  check('the page stays while the question is open', s.route === '#/orders/new', s.route);
  check('the address bar is at the page the user wanted', s.hash === '#/orders', s.hash);
  check('focus is on Stay', (await b.active()) === 'button#leave-dialog-stay', await b.active());

  // 2. Stay.
  await b.click('#leave-dialog-stay');
  await b.sleep(200);
  s = await state();
  check('Stay closes the dialog and keeps the page', !s.open && s.route === '#/orders/new', JSON.stringify(s));
  check('Stay puts the address right', s.hash === '#/orders/new', s.hash);
  check('Stay keeps the history position (Back case: no entry added)', s.length === s0.length, `${s0.length} -> ${s.length}`);
  check('Stay keeps the dirty mark', s.dirty === 'yes');
  check('Stay does not loop', s.changes - s0.changes <= 3, `${s.changes - s0.changes} calls`);
  note('focus after Stay (Back button)', await b.active());

  // 3. A second Back after Stay asks again; Leave goes back.
  await history('back');
  s = await state();
  check('a second Back after Stay asks again, no loop', s.open && s.changes - s0.changes <= 6, `${s.changes - s0.changes} calls`);
  await b.click('#leave-dialog-leave');
  await b.sleep(250);
  s = await state();
  check('Leave shows the page the user pressed Back to', s.route === '#/orders' && s.hash === '#/orders' && !s.open, JSON.stringify(s));
  check('Leave adds no history entry', s.length === s0.length, `${s0.length} -> ${s.length}`);
  check('Leave gives the changes up', s.dirty === 'no');
  check('focus goes to the content after Leave', (await b.active()) === 'main#content', await b.active());

  // 4. Back and Forward when nothing is dirty are not asked.
  const before = await state();
  await history('back');
  s = await state();
  check('Back when clean: no question, page changes', !s.open && s.route === '#/', JSON.stringify(s));
  check('Back when clean: one call', s.changes - before.changes === 1, `${s.changes - before.changes} calls`);
  await history('forward');
  await history('forward');
  s = await state();
  check('Forward when clean works to the end of the history', !s.open && s.route === '#/orders/new', JSON.stringify(s));

  // 5. Forward while dirty (the direction cannot be known by the application).
  await history('back'); // /orders, clean
  const f0 = await state();
  await dirty();
  await history('forward');
  s = await state();
  check('Forward while dirty asks', s.open && s.route === '#/orders' && s.hash === '#/orders/new', JSON.stringify(s));
  await b.click('#leave-dialog-stay');
  await b.sleep(200);
  s = await state();
  check('Stay after Forward: the page and the address agree', s.route === '#/orders' && s.hash === '#/orders', JSON.stringify(s));
  note('history length after Stay on Forward', `${f0.length} -> ${s.length} (one entry more is documented)`);
  // The extra entry is the one Stay pushed: Back from here lands on the page the user tried to reach.
  await history('back');
  s = await state();
  check('Back after that asks again, no loop', s.open && s.changes - f0.changes <= 8, `${s.changes - f0.changes} calls`);
  await b.click('#leave-dialog-leave');
  await b.sleep(250);
  s = await state();
  check('Leave shows the page the user pressed Back to', s.route === '#/orders/new' && s.hash === '#/orders/new' && !s.open, JSON.stringify(s));
  // Forward while dirty, then Leave: the page the user pressed Forward to.
  await fresh();
  await history('back');
  await dirty();
  await history('forward');
  await b.click('#leave-dialog-leave');
  await b.sleep(250);
  s = await state();
  check('Leave after Forward shows the page the user pressed Forward to', s.route === '#/orders/new' && s.hash === '#/orders/new' && !s.open && s.dirty === 'no', JSON.stringify(s));

  // 6. Back twice while the question is open; Forward back to the page closes it.
  await fresh();
  await dirty();
  await history('back');
  await history('back');
  s = await state();
  check('Back twice with the dialog open: still one question, the latest address', s.open && s.route === '#/orders/new' && s.hash === '#/', JSON.stringify(s));
  await b.click('#leave-dialog-leave');
  await b.sleep(250);
  s = await state();
  check('Leave goes to the latest page asked for', s.route === '#/' && s.hash === '#/' && !s.open, JSON.stringify(s));
  await fresh();
  await dirty();
  await history('back');
  await history('forward');
  s = await state();
  check('Back then Forward to the shown page closes the question', !s.open && s.route === '#/orders/new' && s.hash === '#/orders/new', JSON.stringify(s));

  // 7. Links and code navigation.
  await fresh();
  await dirty();
  await b.click('#link-orders');
  s = await state();
  check('a link click while dirty asks, the address does not change', s.open && s.hash === '#/orders/new', JSON.stringify(s));
  await b.key('Escape');
  await b.sleep(200);
  s = await state();
  check('Escape means Stay', !s.open && s.route === '#/orders/new' && s.dirty === 'yes');
  check('focus returns to the link that asked (it has an id)', (await b.active()) === 'a#link-orders', await b.active());
  await b.click('#open-orders');
  s = await state();
  check('navigation by code (request + pushUrl) while dirty asks', s.open && s.hash === '#/orders/new', JSON.stringify(s));
  await b.click('#leave-dialog-stay');
  await b.sleep(200);
  check('focus returns to the button that asked', (await b.active()) === 'button#open-orders', await b.active());
  await b.click('a[href="#/orders/new"]'); // the link without an id, to the page we are on
  s = await state();
  check('a link to the same page while dirty also asks', s.open, JSON.stringify(s));
  await b.key('Escape');
  await b.sleep(200);
  note('focus after Escape when the asker has no id (documented rule)', await b.active());
  await b.click('#link-orders');
  await b.click('#leave-dialog-leave');
  await b.sleep(250);
  s = await state();
  check('Leave after a link click goes there', s.route === '#/orders' && s.hash === '#/orders' && !s.open && s.dirty === 'no', JSON.stringify(s));
  check('focus goes to the content after Leave (the application enters the page)', (await b.active()) === 'main#content', await b.active());

  // 8. Links when clean are not asked.
  const c0 = await state();
  await b.click('#link-home');
  s = await state();
  check('a link when clean: no question, page changes', !s.open && s.route === '#/' && s.changes - c0.changes === 1, JSON.stringify(s));
} catch (error) {
  failed++;
  console.log('FAIL  ' + error.message);
} finally {
  await b.close();
  server.close();
}
console.log(failed === 0 ? '\nAll browser checks passed.' : `\n${failed} browser check(s) failed.`);
process.exit(failed === 0 ? 0 : 1);
