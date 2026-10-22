// A minimal Chrome DevTools driver for the browser tests (Node 22+: global fetch and
// WebSocket, no dependencies). Chrome is found from $CHROME or the usual places.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const candidates = [
  process.env.CHROME,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
].filter(Boolean);

export async function launch(port = 9333) {
  const exe = candidates.find((candidate) => fs.existsSync(candidate));
  if (!exe) throw new Error('Chrome not found: set CHROME to its path');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'klar-chrome-'));
  const chrome = spawn(
    exe,
    ['--headless=new', `--remote-debugging-port=${port}`, `--user-data-dir=${dir}`, '--window-size=1280,800', '--no-first-run', '--disable-gpu', 'about:blank'],
    { stdio: 'ignore' },
  );
  let targets;
  for (let i = 0; i < 50; i++) {
    try {
      targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
      if (targets.some((t) => t.type === 'page')) break;
    } catch {}
    await new Promise((r) => setTimeout(r, 200));
  }
  const page = targets.find((t) => t.type === 'page');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((r) => (ws.onopen = r));
  let id = 0;
  const pending = new Map();
  ws.onmessage = (m) => {
    const data = JSON.parse(m.data);
    if (data.id && pending.has(data.id)) {
      const { resolve, reject } = pending.get(data.id);
      pending.delete(data.id);
      data.error ? reject(new Error(JSON.stringify(data.error))) : resolve(data.result);
    }
  };
  const send = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const n = ++id;
      pending.set(n, { resolve, reject });
      ws.send(JSON.stringify({ id: n, method, params }));
    });

  await send('Page.enable');
  await send('Runtime.enable');
  await send('Emulation.setFocusEmulationEnabled', { enabled: true });
  await send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 800, deviceScaleFactor: 1, mobile: false });

  const ev = async (expression) => {
    const r = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
    return r.result.value;
  };
  // Like `ev`, but gives up after `ms`: a frozen page never answers.
  const evWithin = (expression, ms = 3000) =>
    Promise.race([ev(expression), new Promise((resolve) => setTimeout(() => resolve('__FROZEN__'), ms))]);
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const frames = (n = 3) => ev(`new Promise(r => { let n = ${n}; const f = () => (--n <= 0 ? r(true) : requestAnimationFrame(f)); requestAnimationFrame(f); })`);
  const KEYS = {
    Tab: { key: 'Tab', code: 'Tab', vk: 9 },
    Enter: { key: 'Enter', code: 'Enter', vk: 13, text: '\r' },
    Space: { key: ' ', code: 'Space', vk: 32, text: ' ' },
    Escape: { key: 'Escape', code: 'Escape', vk: 27 },
    ArrowDown: { key: 'ArrowDown', code: 'ArrowDown', vk: 40 },
  };
  const key = async (name, modifiers = 0) => {
    const k = KEYS[name];
    await send('Input.dispatchKeyEvent', { type: k.text ? 'keyDown' : 'rawKeyDown', key: k.key, code: k.code, windowsVirtualKeyCode: k.vk, text: k.text, modifiers });
    await send('Input.dispatchKeyEvent', { type: 'keyUp', key: k.key, code: k.code, windowsVirtualKeyCode: k.vk, modifiers });
    await frames(4);
  };
  const type = async (text) => {
    await send('Input.insertText', { text });
    await frames(3);
  };
  const click = async (selector) => {
    const box = await ev(`(() => { const e = document.querySelector(${JSON.stringify(selector)}); if (!e) return null; e.scrollIntoView({block:'center'}); const r = e.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; })()`);
    if (!box) throw new Error('no element ' + selector);
    await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: box.x, y: box.y });
    await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: box.x, y: box.y, button: 'left', clickCount: 1 });
    await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: box.x, y: box.y, button: 'left', clickCount: 1 });
    await frames(4);
  };
  const active = () =>
    ev(`(() => { const e = document.activeElement; const t = (e.textContent||'').trim().slice(0,24); return e.tagName.toLowerCase() + (e.id ? '#' + e.id : '') + (t && e.tagName !== 'BODY' && !e.id ? ' "' + t + '"' : ''); })()`);
  const goto = async (url) => {
    await send('Page.navigate', { url });
    await sleep(1000);
    await frames(5);
  };
  const close = async () => {
    try { await send('Browser.close'); } catch {}
    try { chrome.kill(); } catch {}
  };
  return { send, ev, evWithin, sleep, frames, key, type, click, active, goto, close };
}
