const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const local = path.resolve(__dirname, '../.tools/go/bin', process.platform === 'win32' ? 'go.exe' : 'go');
const executable = fs.existsSync(local) ? local : 'go';
const result = spawnSync(executable, process.argv.slice(2), { stdio: 'inherit', cwd: path.resolve(__dirname, '..') });
if (result.error) { console.error('Install Go 1.26 or newer and put go on PATH.', result.error.message); process.exit(1); }
process.exit(result.status ?? 1);
