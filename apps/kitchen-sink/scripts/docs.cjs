const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../../..');
const index = JSON.parse(fs.readFileSync(path.join(root, 'ai/klar-index.json'), 'utf8'));
const names = process.argv.slice(2);
for (const m of index.modules.filter(m => names.length === 0 || names.some(n => m.name === 'Klar.' + n || m.name === n))) {
  const text = fs.readFileSync(path.join(root, m.reference), 'utf8');
  const signature = text.split('```elm')[1]?.split('```')[0] || '';
  console.log(m.name + '\n' + signature);
}
