// Small lexical helpers for inspecting public Elm signatures without matching
// examples inside comments and string literals.
export function tokens(source) {
  const out = [];
  let i = 0;
  while (i < source.length) {
    const start = i;
    if (/\s/.test(source[i])) { i++; continue; }
    if (source.startsWith('--', i)) { const end = source.indexOf('\n', i); i = end < 0 ? source.length : end; continue; }
    if (source.startsWith('{-', i)) {
      let depth = 1; i += 2;
      while (i < source.length && depth) {
        if (source.startsWith('{-', i)) { depth++; i += 2; }
        else if (source.startsWith('-}', i)) { depth--; i += 2; }
        else i++;
      }
      continue;
    }
    if (source.startsWith('"""', i)) { i = source.indexOf('"""', i + 3) + 3; }
    else if (source[i] === '"' || (source[i] === "'" && (source[i + 2] === "'" || source[i + 1] === '\\'))) {
      const quote = source[i++];
      while (i < source.length) { if (source[i++] === '\\') i++; else if (source[i - 1] === quote) break; }
    }
    else if (/[A-Za-z_]/.test(source[i])) { i++; while (/[\w.]/.test(source[i] || '')) i++; }
    else i++;
    if (i <= start) throw Error('Unterminated Elm literal');
    out.push({ value: source.slice(start, i), start, end: i });
  }
  return out;
}

export function edits(source, changes) {
  for (const { start, end, text } of changes.sort((a, b) => b.start - a.start || b.end - a.end)) source = source.slice(0, start) + text + source.slice(end);
  return source;
}

export function signatures(source) {
  const positions = new Set(tokens(source).map(t => t.start));
  return [...source.matchAll(/^(\w+) :[ \t]*([\s\S]*?)(?=^\1(?:\s|=))/gm)].filter(m => positions.has(m.index)).map(m => ({ name: m[1], type: m[2].trim().replace(/\s+/g, ' '), start: m.index, end: m.index + m[0].length }));
}

export function arrows(type) {
  let depth = 0, start = 0;
  const out = [];
  for (let i = 0; i < type.length; i++) {
    if ('([{'.includes(type[i])) depth++;
    if (')]}'.includes(type[i])) depth--;
    if (!depth && type.slice(i, i + 2) === '->') { out.push(type.slice(start, i).trim()); start = i + 2; i++; }
  }
  out.push(type.slice(start).trim());
  return out;
}

export function publicAttributes(source) {
  if (!/^type(?: alias)? Attribute\b/m.test(source)) return [];
  const exposing = source.slice(source.indexOf('exposing'), source.indexOf('{-|'));
  return signatures(source).filter(s => new RegExp(`\\b${s.name}\\b`).test(exposing) && /^Attribute(?:\s|$)/.test(arrows(s.type).at(-1)));
}
