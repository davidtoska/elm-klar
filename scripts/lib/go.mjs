// Go is an application toolchain, separate from the Elm library's npm tools.
import { spawnSync } from 'node:child_process';

export function runGo(args, options = {}) {
  const executable = process.env.KLAR_GO || 'go';
  const result = spawnSync(executable, args, { ...options, windowsHide: true });
  if (result.error) throw new Error(`Could not run Go. Install Go 1.26+ on PATH or set KLAR_GO to its executable. ${result.error.message}`);
  return result;
}
