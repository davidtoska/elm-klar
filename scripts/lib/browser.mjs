// Dependency-free Chromium driver for regression tests. Uses a disposable profile,
// a loopback debugging port and real browser keyboard/mouse input.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { setTimeout as delay } from 'node:timers/promises';

export async function browser() {
  const candidates = [process.env.KLAR_BROWSER,
    'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
    'C:/Program Files/Google/Chrome/Application/chrome.exe',
    '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'];
  const executable = candidates.find(candidate => candidate && fs.existsSync(candidate));
  if (!executable) throw new Error('Install Chromium, Chrome or Edge, or set KLAR_BROWSER to its executable.');
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'klar-browser-'));
  if (path.dirname(profile) !== path.resolve(os.tmpdir()) || !path.basename(profile).startsWith('klar-browser-')) {
    throw new Error('Refusing to clean up a browser profile outside the temporary directory.');
  }
  const child = spawn(executable, ['--headless=new', '--disable-gpu', '--no-first-run',
    '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
    '--no-default-browser-check', '--remote-debugging-address=127.0.0.1',
    '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank'],
  { stdio: 'ignore', windowsHide: true });
  let socket;
  async function close() {
    socket?.close();
    if (child.exitCode === null) {
      const exited = once(child, 'exit');
      child.kill();
      await Promise.race([exited, delay(5000)]);
    }
    // Chromium on Windows can briefly retain profile locks after process exit.
    for (let attempt = 0; attempt < 20; attempt++) {
      try { fs.rmSync(profile, { recursive: true, force: true }); return; }
      catch (error) { if (attempt === 19) throw error; await delay(100); }
    }
  }
  try {
    const activePort = path.join(profile, 'DevToolsActivePort');
    for (let attempt = 0; !fs.existsSync(activePort); attempt++) {
      if (attempt > 200 || child.exitCode !== null) throw new Error('Chromium did not start.');
      await delay(50);
    }
    const port = fs.readFileSync(activePort, 'utf8').split('\n')[0];
    const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
    socket = new WebSocket(targets.find(target => target.type === 'page').webSocketDebuggerUrl);
    await once(socket, 'open');
    let serial = 0;
    const pending = new Map();
    const errors = [];
    socket.addEventListener('message', event => {
      const message = JSON.parse(event.data);
      if (message.method === 'Runtime.exceptionThrown') errors.push(message.params.exceptionDetails);
      if (message.method === 'Log.entryAdded' && message.params.entry.level === 'error') errors.push(message.params.entry);
      if (message.method === 'Runtime.consoleAPICalled' && message.params.type === 'error') errors.push(message.params.args);
      const item = pending.get(message.id);
      if (item) {
        pending.delete(message.id);
        clearTimeout(item.timer);
        if (message.error) item.reject(new Error(JSON.stringify(message.error)));
        else item.resolve(message.result);
      }
    });
    function send(method, params = {}) {
      return new Promise((resolve, reject) => {
        const id = ++serial;
        const timer = setTimeout(() => { pending.delete(id); reject(new Error(`Timed out: ${method}`)); }, 15000);
        pending.set(id, { resolve, reject, timer });
        socket.send(JSON.stringify({ id, method, params }));
      });
    }
    async function evaluate(expression) {
      const result = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
      if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
      return result.result.value;
    }
    async function wait(expression, description = expression) {
      const deadline = Date.now() + 12000;
      while (Date.now() < deadline) {
        if (await evaluate(expression)) return;
        await delay(30);
      }
      const state = await evaluate('({ focus: document.activeElement?.tagName + "#" + document.activeElement?.id, text: document.body.innerText.slice(-2500) })');
      throw new Error(`Timed out waiting for ${description}\n${JSON.stringify(state, null, 2)}`);
    }
    async function click(selector, text) {
      const target = text === undefined
        ? `document.querySelector(${JSON.stringify(selector)})`
        : `Array.from(document.querySelectorAll(${JSON.stringify(selector)})).find(e => e.textContent.trim() === ${JSON.stringify(text)})`;
      await wait(`!!(${target})`, `${selector} ${text || ''}`);
      const position = await evaluate(`(() => {
        const element = ${target};
        element.scrollIntoView({block: 'center'});
        const rect = element.getBoundingClientRect();
        return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
      })()`);
      await send('Input.dispatchMouseEvent', { type: 'mousePressed', ...position, button: 'left', clickCount: 1 });
      await send('Input.dispatchMouseEvent', { type: 'mouseReleased', ...position, button: 'left', clickCount: 1 });
    }
    async function key(key, modifiers = 0) {
      const codes = { Enter: 13, Tab: 9, Escape: 27, ArrowDown: 40, ArrowUp: 38, Backspace: 8, a: 65 };
      await send('Input.dispatchKeyEvent', { type: 'keyDown', key, modifiers, windowsVirtualKeyCode: codes[key] || 0,
        ...(key === 'Enter' ? { text: '\r', unmodifiedText: '\r' } : {}) });
      await send('Input.dispatchKeyEvent', { type: 'keyUp', key, modifiers, windowsVirtualKeyCode: codes[key] || 0 });
      // Elm schedules focus for the next frame; let its key handler render before
      // the next key. A headless page may suspend requestAnimationFrame entirely.
      await delay(30);
    }
    await send('Runtime.enable');
    await send('Log.enable');
    await send('Page.enable');
    await send('Emulation.setFocusEmulationEnabled', { enabled: true });
    await send('Emulation.setDeviceMetricsOverride', { width: 1024, height: 768, deviceScaleFactor: 1, mobile: false });
    return { close, send, evaluate, wait, click, key, errors,
      async text(selector, value) {
        await click(selector);
        await key('a', process.platform === 'darwin' ? 4 : 2);
        await send('Input.insertText', { text: value });
      },
      async navigate(url) {
        await send('Page.navigate', { url });
        await wait(`location.href === ${JSON.stringify(url)} && document.readyState === "complete"`);
      },
    };
  } catch (error) { await close(); throw error; }
}
