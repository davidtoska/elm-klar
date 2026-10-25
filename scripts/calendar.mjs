#!/usr/bin/env node
// npm run calendar -- [Go server flags], or node scripts/calendar.mjs --test.
import { spawn } from 'node:child_process';
import { buildCalendar, calendarDir } from './lib/calendar.mjs';
import { runGo } from './lib/go.mjs';

if (process.argv.includes('--test')) {
  const result = runGo(['test', './...', '-count=1'], { cwd: calendarDir, stdio: 'inherit' });
  process.exitCode = result.status ?? 1;
} else {
  const build = buildCalendar();
  const child = spawn(build.binary, process.argv.slice(2), { cwd: calendarDir, stdio: 'inherit', windowsHide: true });
  const stop = () => child.kill();
  process.once('SIGINT', stop); process.once('SIGTERM', stop);
  child.on('error', error => { console.error(error.message); process.exitCode = 1; });
  child.on('close', code => { process.removeListener('SIGINT', stop); process.removeListener('SIGTERM', stop); build.dispose(); process.exitCode = code ?? 1; });
}
