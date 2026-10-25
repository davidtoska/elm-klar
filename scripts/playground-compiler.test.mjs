import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import { createCompiler, describe, patchTarget, targetsFor } from './playground-compiler.mjs';
import { publicAttributes } from './gallery-source.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

test('callbacks and complex data are discovered in their own visible example contexts', () => {
  const button = describe(root, 'Button')[0];
  assert.match(button.id, /^Page.Gallery.Basics:viewButtons:/);
  assert.match(button.options.find(option => option.name === 'onClick').trace, /PlaygroundObserved "onClick"/);
  const table = describe(root, 'Table')[0];
  assert.equal(table.options.find(option => option.name === 'columns').trace, '');
  assert.match(table.options.find(option => option.name === 'onRowClick').trace, /Debug.toString arg1/);
  const layout = describe(root, 'Layout')[0];
  assert.notEqual(layout.function, 'swatches');
});

test('every public attribute module has an editable compilation target', () => {
  const modules = Object.values(JSON.parse(fs.readFileSync(path.join(root, 'elm.json')))['exposed-modules']).flat();
  for (const module of modules) {
    const source = fs.readFileSync(path.join(root, 'src', ...module.split('.')) + '.elm', 'utf8');
    if (!publicAttributes(source).length) continue;
    assert.ok(describe(root, module.slice(5)).length, module + ' needs a configurable preview target');
  }
});

test('source injection replaces the original typed attribute, preserving the real working tree', () => {
  const target = targetsFor(root, 'Button')[0];
  const before = fs.readFileSync(path.join(root, 'example', target.file), 'utf8');
  const source = patchTarget(target, 'Button', { onClick: 'Button.onClick (PlaygroundObserved "custom" [ "payload" ])' });
  assert.match(source, /\| PlaygroundObserved String \(List String\)/);
  assert.match(source, /Debug.log "__klar_playground_callback__"/);
  assert.equal(fs.readFileSync(path.join(root, 'example', target.file), 'utf8'), before);
  assert.throws(() => patchTarget(target, 'Button', { notAnAttribute: 'Button.primary' }), /Unknown attribute/);
});

test('actual Elm compiler accepts custom callbacks and typed fixtures and rejects invalid expressions', { timeout: 180000 }, async () => {
  const compiler = createCompiler(root);
  try {
    const button = describe(root, 'Button')[0];
    const callback = await compiler.compile({ component: 'Button', slug: 'button', target: button.id, expressions: { onClick: button.options.find(option => option.name === 'onClick').trace }, definitions: '', imports: '', values: {} });
    assert.equal(callback.ok, true, callback.diagnostics);
    const table = describe(root, 'Table')[0];
    const data = await compiler.compile({
      component: 'Table', slug: 'table', target: table.id,
      expressions: {
        columns: 'Table.columns [ Table.text (Table.columnId "custom-customer") "Arbitrary customer" .customer [] ]',
        remote: 'Table.remote (Remote.Loaded customOrders)',
        onRowClick: 'Table.onRowClick (\\order -> PlaygroundObserved "custom-row" [ order.customer ])',
      },
      definitions: 'customOrders : List Order\ncustomOrders =\n    Sample.orders |> List.take 2 |> List.map (\\order -> { order | customer = "My own typed fixture" })',
      imports: '', values: {},
    });
    assert.equal(data.ok, true, data.diagnostics);
    const chat = describe(root, 'AiChat')[0];
    const chatData = chat.arguments.find(argument => argument.name === 'View data');
    assert.ok(chatData, 'structured data passed to view must be editable too');
    const chatResult = await compiler.compile({ component: 'AiChat', slug: 'ai-chat', target: chat.id, expressions: { [chatData.key]: '{ label = "Own conversation data", ids = Ids.int, messages = Remote.Loaded [ Chat.message { id = 99, role = Chat.Assistant, author = "Mine", body = "Custom conversation supplied from the panel" } ], status = Chat.Idle }' }, definitions: '', imports: '', values: {} });
    assert.equal(chatResult.ok, true, chatResult.diagnostics);
    const invalid = await compiler.compile({ component: 'Button', slug: 'button', target: button.id, expressions: { loading: 'Button.loading "wrong type"' }, definitions: '', imports: '', values: {} });
    assert.equal(invalid.ok, false);
    assert.match(invalid.diagnostics, /TYPE MISMATCH/);
    assert.ok(compiler.artifact(callback.url.split('/')[3]), 'previous successful preview remains available');
  } finally { await compiler.close(); }
});
