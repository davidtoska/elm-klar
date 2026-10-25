const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const exposed = new Set(Object.values(JSON.parse(fs.readFileSync(path.join(root,'../../elm.json')))['exposed-modules']).flat());
const text = fs.readFileSync(path.join(root,'src/Main.elm'),'utf8');
for(const match of text.matchAll(/^import (Klar(?:\.[\w]+)*)/gm)) if(!exposed.has(match[1])) throw new Error('Non-public import: '+match[1]);
if(/(?:Html\.Attributes|Attr)\.(class|classList|style)|Html\.node\s+"style"|Browser\.Dom|Klar\.Internal/.test(text)) throw new Error('Application bypasses Klar');
const coverage = JSON.parse(fs.readFileSync(path.join(root,'coverage.json')));
if(coverage.some(c=>!c.implemented)) throw new Error('Unimplemented module scenarios');
for(const name of exposed) if(!coverage.some(c=>c.module===name)) throw new Error('Missing coverage: '+name);
for(const file of ['src/Main.elm','public/adapter.js']) {
  const bytes = fs.readFileSync(path.join(root,file));
  if(bytes[0]===0xef || bytes.includes(13)) throw new Error('Expected UTF-8 without BOM and LF: '+file);
}
console.log(coverage.length+' public modules covered; public imports only; no app CSS or custom focus code.');
