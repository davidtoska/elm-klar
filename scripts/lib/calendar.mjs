// Build and host the Go app for the showcase and HTTP contract checks. No calendar
// domain logic belongs in this adapter; the application itself runs without Node.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';
import { runGo } from './go.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export const calendarDir = path.join(root, 'apps/calendar');

export function buildCalendar() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'klar-calendar-build-'));
  const binary = path.join(directory, process.platform === 'win32' ? 'calendar.exe' : 'calendar');
  const dispose = () => { fs.rmSync(binary, { force: true }); fs.rmdirSync(directory); };
  try {
    const result = runGo(['build', '-o', binary, './server'], { cwd: calendarDir, encoding: 'utf8' });
    if (result.status !== 0) throw new Error((result.stdout || '') + (result.stderr || '') || 'Calendar build failed.');
    return { binary, dispose };
  } catch (error) { dispose(); throw error; }
}

export async function startCalendar({ binary, db, prefix = '', legacy = '', demo = true, googleClientId = process.env.GOOGLE_CLIENT_ID || '' } = {}) {
  const build = binary ? null : buildCalendar();
  const child = spawn(binary || build.binary, ['--addr', '127.0.0.1:0', '--assets', calendarDir, '--db', db || path.join(calendarDir, 'data/showcase.sqlite'), '--prefix', prefix, '--import-json', legacy, '--google-client-id', googleClientId, ...(demo ? ['--demo'] : [])], { cwd: calendarDir, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  let stderr = '';
  child.stderr.on('data', chunk => { stderr += chunk; });
  let closing;
  const close = () => closing ||= (async () => {
    if (child.pid && child.exitCode === null && child.signalCode === null) { const exited = once(child, 'exit'); child.kill(); await exited; }
    build?.dispose();
  })();
  try {
    const url = await new Promise((resolve, reject) => {
      let output = '';
      const timeout = setTimeout(() => done(new Error(`Calendar startup timed out. ${stderr}`)), 30000);
      const done = (error, value) => { clearTimeout(timeout); child.off('error', failed); child.off('exit', exited); child.stdout.off('data', received); error ? reject(error) : resolve(value); };
      const failed = error => done(error);
      const exited = code => done(new Error(`Calendar exited (${code}). ${stderr}`));
      const received = chunk => { output += chunk; const match = /Calendar on (http:\/\/\S+)/.exec(output); if (match) done(null, match[1]); };
      child.on('error', failed); child.on('exit', exited); child.stdout.on('data', received);
    });
    return { url, child, close };
  } catch (error) { await close(); throw error; }
}
