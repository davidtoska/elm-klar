import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { browser } from './lib/browser.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

test('calendar: showcase mount, real HTTP save, keyboard focus and persisted session', { timeout: 90000 }, async t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'klar-calendar-browser-'));
  const child = spawn(process.execPath, ['scripts/serve-example.mjs', '0', '--no-build'], {
    cwd: root, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe', 'ipc'],
    env: { ...process.env, KLAR_CALENDAR_SHOWCASE_DB: path.join(directory, 'calendar.sqlite'), KLAR_CALENDAR_LEGACY_JSON: '' },
  });
  let output = '';
  child.stdout.on('data', data => { output += data; });
  child.stderr.on('data', data => { output += data; });
  t.after(async () => {
    if (child.exitCode === null) { const exited = once(child, 'exit'); child.send({ type: 'shutdown' }); await exited; }
    assert.equal(path.dirname(directory), path.resolve(os.tmpdir()));
    assert.ok(path.basename(directory).startsWith('klar-calendar-browser-'));
    fs.rmSync(directory, { recursive: true, force: true });
  });
  const base = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Showcase startup timed out: ' + output)), 30000);
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.once('exit', code => { clearTimeout(timer); reject(new Error(`Showcase exited (${code}): ${output}`)); });
    child.on('message', message => { if (message?.type === 'ready') { clearTimeout(timer); resolve(message.url.replace(/\/$/, '')); } });
  });
  const b = await browser();
  t.after(() => b.close());
  await b.navigate(base + '/#/components/calendar');
  await b.wait('!!document.querySelector(\'a[href="reference/Klar.Calendar.html"]\')', 'generated component reference link');
  const reference = await fetch(base + '/reference/Klar.Calendar.html');
  assert.equal(reference.status, 200);
  assert.ok((await reference.text()).includes('Klar.Calendar'));
  await b.wait('!!document.querySelector(\'iframe[src="/calendar-app/"]\')?.contentDocument?.body.innerText.includes("ada@example.com")', 'calendar iframe served through the Go proxy');
  await b.navigate(base + '/calendar-app/');
  await b.click('button', 'Ada Lovelace (ada@example.com)');
  await b.wait('!!document.querySelector("#create-event")');
  await b.click('#create-event');
  await b.wait('document.activeElement.id === "event-title"');
  await b.text('#event-title', 'Migration browser meeting');
  await b.click('[role="dialog"] button', 'Save');
  await b.wait('!document.querySelector("#event-title")');
  const query = `fetch('calendar/v3/calendars/primary/events?q=Migration%20browser').then(r=>r.json())`;
  let events = await b.evaluate(query);
  assert.equal(events.items.length, 1);
  assert.equal(events.items[0].summary, 'Migration browser meeting');
  await b.navigate(base + '/calendar-app/?visit=2');
  await b.wait('!!document.querySelector("#create-event")');
  events = await b.evaluate(query);
  assert.equal(events.items.length, 1);
  await b.click('#create-event');
  await b.wait('document.activeElement.id === "event-title"');
  await b.key('Escape');
  await b.wait('!document.querySelector("#event-title")');
  assert.equal(await b.evaluate('document.activeElement.id'), 'create-event');
  if (process.env.KLAR_CALENDAR_SCREENSHOT) {
    const screenshot = await b.send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(process.env.KLAR_CALENDAR_SCREENSHOT, Buffer.from(screenshot.data, 'base64'));
  }
  const unexpected = b.errors.filter(error => !(error.url?.endsWith('/auth/me') && error.text?.includes('401')));
  assert.deepEqual(unexpected, [], 'no unexpected browser errors');
});
