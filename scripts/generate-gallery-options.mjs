// Generate typed controls directly from the exposed component API.
// Run after adding/changing component attributes: node scripts/generate-gallery-options.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { spawnSync } from 'node:child_process';
import { arrows, publicAttributes, signatures } from './gallery-source.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const outline = JSON.parse(fs.readFileSync(path.join(root, 'elm.json'), 'utf8'));
const modules = Object.values(outline['exposed-modules']).flat();
const sources = new Map(modules.map(name => [name, fs.readFileSync(path.join(root, 'src', ...name.split('.')) + '.elm', 'utf8')]));
const q = JSON.stringify;
const entries = [];
const imports = new Set(['import Html', 'import Html.Attributes', 'import Json.Decode as Decode', 'import Klar.Color as Color', 'import Klar.Date as Date', 'import Klar.Icon as Icon', 'import Klar.Icon.Library as Icons', 'import Klar.Locale as Locale', 'import Klar.Remote as Remote', 'import Klar.Settings as Settings', 'import Klar.Theme as Theme', 'import Time', 'import Showcase.Config as Config exposing (Config, Control(..), Option)']);
const unwrap = s => s.startsWith('(') && s.endsWith(')') ? s.slice(1, -1) : s;

function enumeration(type, module, source) {
  const shared = ['Size','Tone','Density','Mode'];
  const owner = shared.includes(type) ? 'Klar.Theme' : module;
  const body = sources.get(owner);
  const expose = body?.slice(0, body.indexOf('{-|')) || '';
  if (!expose.includes(type + '(..)')) {
    const constants=signatures(body || '').filter(s=>s.type===type&&new RegExp(`\\b${s.name}\\b`).test(expose));
    if(constants.length) {
      const alias=module.replaceAll('.', '');
      return { values: constants.map(s=>s.name), expression: `Config.choice [ ${constants.map(s=>`( ${q(s.name)}, ${alias}.${s.name} )`).join(', ')} ] value` };
    }
    return null;
  }
  const m = new RegExp('^type ' + type + '\\s*\\n\\s*= ([\\s\\S]*?)(?=\\n\\n)', 'm').exec(body);
  if (!m) return null;
  const values = m[1].split('|').map(s => s.trim());
  if (!values.every(s => /^[A-Z]\w*$/.test(s))) return null;
  const alias = owner === 'Klar.Theme' ? 'Theme' : module.replaceAll('.', '');
  return { values, expression: `Config.choice [ ${values.map(v => `( ${q(v)}, ${alias}.${v} )`).join(', ')} ] value` };
}

for (const [module, source] of sources) {
  const attributes = publicAttributes(source);
  if (!attributes.length) continue;
  const alias = module.replaceAll('.', '');
  const name = module.slice(5);
  const fn = alias[0].toLowerCase() + alias.slice(1);
  imports.add(`import ${module} as ${alias}`);
  const attributeType = arrows(attributes[0].type).at(-1);
  const options = [];
  const applications = [];
  for (const attribute of attributes) {
    const args = arrows(attribute.type).slice(0,-1);
    const arg = args[0];
    let control = 'Example', expression = null;
    if (!args.length) { control = 'Choice [ "Enabled", "omit" ]'; expression = `if value == "Enabled" then Just ${alias}.${attribute.name} else Nothing`; }
    else if (args.length === 1) {
      let converted = null;
      if (arg === 'String') { control = 'Text'; converted = 'Just value'; }
      else if (arg === 'Bool') { control = 'Choice [ "True", "False" ]'; converted = 'Just (value == "True")'; }
      else if (arg === 'Int' || arg === 'Float') { control = 'Number'; converted = `String.to${arg} value`; }
      else if (arg === 'Char') { control = 'Text'; converted = 'String.uncons value |> Maybe.map Tuple.first'; }
      else if (arg === 'Maybe String') { control = 'Text'; converted = 'Just (if value == "" then Nothing else Just value)'; }
      else if (arg === 'Maybe Int' || arg === 'Maybe Float') { control = 'Number'; converted = `Just (String.to${arg.slice(6)} value)`; }
      else if (arg === 'Icon') { control = 'Choice (List.map Icon.name Icons.all)'; converted = 'List.filter (Icon.name >> (==) value) Icons.all |> List.head'; }
      else if (arg === 'Locale') { control = 'Choice [ "en", "nb" ]'; converted = 'Locale.fromCode value'; }
      else if (arg === 'Date') { control = 'Text'; converted = 'Date.fromIso value'; }
      else if (arg === 'Color') { control = 'Text'; converted = 'Color.hex value'; }
      else if (arg === 'Time.Posix' || arg === 'Posix') { control = 'Number'; converted = 'String.toInt value |> Maybe.map Time.millisToPosix'; }
      else if (arg === 'Settings') { control = 'Choice [ "Compact", "Normal", "Comfortable" ]'; converted = 'Config.choice [ ( "Compact", Theme.Compact ), ( "Normal", Theme.Normal ), ( "Comfortable", Theme.Comfortable ) ] value |> Maybe.map (\\density -> Settings.withDensity density Settings.default)'; }
      else if (arg === 'Link.Target' || (module === 'Klar.Link' && arg === 'Target')) { control = 'Text'; converted = 'if String.startsWith "#/" value || String.startsWith "/" value then Just (KlarLink.internal value) else KlarLink.external value'; }
      else if (/^List (Int|Float|String)$/.test(arg)) { control = 'Text'; converted = `Decode.decodeString (Decode.list Decode.${arg.slice(5).toLowerCase()}) value |> Result.toMaybe`; }
      else if (/^Html \w+$/.test(arg)) { control = 'Text'; converted = 'Just (Config.slot value)'; }
      else if (/^List \(Html \w+\)$/.test(arg)) { control = 'Choice [ "Configured content", "Badge", "Button", "Stack", "Empty" ]'; converted = 'Just (if value == "Empty" then [] else [ Config.slot value ])'; }
      else if (/^List \(Html.Attribute \w+\)$/.test(arg)) { control = 'Text'; converted = 'Decode.decodeString (Decode.keyValuePairs Decode.string) value |> Result.toMaybe |> Maybe.map (List.map (\\( key, item ) -> Html.Attributes.attribute key item))'; }
      else if (/^Remote\b/.test(unwrap(arg))) {
        const list = /^Remote \(List /.test(arg);
        control = `Choice [ "Not asked", "Loading", "Failed", "Refreshing", "Stale"${list?', "Empty"':''} ]`;
        if(list) expression=`if value == "Empty" then Just (${alias}.${attribute.name} (Remote.Loaded [])) else Nothing`;
      }
      else {
        const e = enumeration(arg, module, source);
        if (e) { control = `Choice [ ${e.values.map(q).join(', ')} ]`; converted = e.expression; }
      }
      if (converted) expression = `(${converted}) |> Maybe.map ${alias}.${attribute.name}`;
    }
    if (expression) applications.push(`Config.get config ${q(name)} ${q(attribute.name)} |> Maybe.andThen (\\value -> ${expression})`);
    const preceding = source.slice(0, attribute.start);
    const lastDoc = preceding.slice(preceding.lastIndexOf('{-|'));
    const doc = /\{-\|([\s\S]*?)-\}\s*$/.exec(lastDoc)?.[1].trim().split(/\n\s*\n/)[0].replace(/\s+/g,' ') || '';
    options.push(`{ name = ${q(attribute.name)}, type_ = ${q(args.join(' -> ') || 'Flag')}, description = ${q(doc.slice(0,350))}, control = ${control} }`);
  }
  if(['Button','Badge','Tag','Alert'].includes(name)) options.unshift(`{ name = "content", type_ = "String", description = "The visible text passed to view. Reset to keep each example's label.", control = Text }`);
  entries.push({ module, name, fn, attributes, source, options, code: `${fn} : Config -> List (${alias}.${attributeType}) -> List (${alias}.${attributeType})\n${fn} config original =\n    original ++ List.filterMap identity\n        [ ${applications.join('\n        , ')}\n        ]` });
}
const renderers=['Button','Badge','Tag','Alert'].map(name=>{
  const type = arrows(entries.find(e=>e.name===name).attributes[0].type).at(-1);
  return `${name.toLowerCase()}View : Config -> List (Klar${name}.${type}) -> String -> Html.Html msg\n${name.toLowerCase()}View config attributes original =\n    Klar${name}.view attributes (Config.get config ${q(name)} "content" |> Maybe.withDefault original)`;
});
const catalog = fs.readFileSync(path.join(root, 'example/src/Page/Gallery/Catalog.elm'), 'utf8');
// Include pure helpers and icon groups too: checking attributes alone silently
// missed exposed modules with no Attribute type.
const missingPages = modules.filter(module => !catalog.includes(q(module === 'Klar' ? module : module.slice(5))));
if (missingPages.length) throw Error('Modules missing from the gallery catalog: ' + missingPages.join(', '));
const output = `module Showcase.Options exposing (${entries.map(e=>e.fn).join(', ')}, buttonView, badgeView, tagView, alertView, forComponent)\n\n{-| Generated by scripts/generate-gallery-options.mjs. Do not edit by hand. -}\n\n${[...imports].sort().join('\n')}\n\nforComponent : String -> List Option\nforComponent component =\n    case component of\n${entries.map(e=>`        ${q(e.name)} ->\n            [ ${e.options.join('\n            , ')}\n            ]`).join('\n\n')}\n\n        _ ->\n            []\n\n${entries.map(e=>e.code).join('\n\n')}\n\n${renderers.join('\n\n')}\n`;
// Qualify polymorphic attribute types and their parameters without altering variables.
const require = createRequire(import.meta.url);
const formatBinary = require('../node_modules/elm-format/binary.js')();
const formatted = spawnSync(formatBinary, ['--stdin'], { input: output, encoding: 'utf8' });
if (formatted.status !== 0) throw Error(formatted.stderr || 'Could not format gallery options');
const target = path.join(root,'example/src/Showcase/Options.elm');
if (process.argv.includes('--check')) {
  if (fs.readFileSync(target,'utf8').replaceAll('\r\n','\n') !== formatted.stdout.replaceAll('\r\n','\n')) {
    console.error('Gallery controls are stale. Run npm run gen:gallery.');
    process.exit(1);
  }
} else fs.writeFileSync(target, formatted.stdout);
console.log(`Generated controls for ${entries.length} modules / ${entries.reduce((n,e)=>n+e.attributes.length,0)} attributes.`);
