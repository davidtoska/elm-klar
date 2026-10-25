import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { once } from 'node:events';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { browser } from './lib/browser.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../example');

test('forms: server results, drafts and keyboard focus survive failure and retry', { timeout: 150000 }, async t => {
  assert.ok(fs.existsSync(path.join(root, 'main.js')), 'Run npm run build:example first.');
  const server = http.createServer((request, response) => {
    const pathname = new URL(request.url, 'http://localhost').pathname;
    const file = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
    if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      response.writeHead(404); response.end(); return;
    }
    response.setHeader('Content-Type', file.endsWith('.js') ? 'text/javascript' : file.endsWith('.css') ? 'text/css' : 'text/html');
    fs.createReadStream(file).pipe(response);
  });
  t.after(() => new Promise(resolve => { server.closeAllConnections(); server.close(resolve); }));
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;
  const b = await browser();
  t.after(() => b.close());
  const active = () => b.evaluate('document.activeElement.id');
  const rows = '#orders-table tbody tr[id]';
  const refresh = '#orders-table button[aria-label="Refresh"]';
  async function loaded() { await b.wait(`document.querySelectorAll('${rows}').length > 0`); }
  async function tools(mode, slow = false) {
    await b.click('#tools-opener');
    await b.wait('document.activeElement.closest("#dev-tools") !== null');
    await b.click(`#dev-tools input[name="tools-mode"][value="${mode}"]`);
    if (slow) await b.click('#dev-tools input[name="tools-latency"][value="2"]');
    const requests = await b.evaluate('Number(document.querySelector("#dev-tools .klar-badge__label").textContent)');
    await b.click('#dev-tools button', 'Close');
    await b.wait('!document.querySelector("#dev-tools")');
    return requests;
  }
  let visit = 0;
  async function orders() {
    await b.navigate(base + '/?visit=' + (++visit) + '#/orders');
    await loaded();
  }
  async function tabTo(selector, text) {
    const matches = `document.activeElement.matches(${JSON.stringify(selector)})` +
      (text === undefined ? '' : ` && document.activeElement.textContent.trim() === ${JSON.stringify(text)}`);
    for (let tabs = 0; !(await b.evaluate(matches)); tabs++) {
      assert.ok(tabs < 100, `${selector} must be reachable with Tab`);
      await b.key('Tab');
    }
  }
  async function retry(scope) {
    // Use Tab and Enter rather than dispatching synthetic DOM events or calling focus().
    await tabTo(scope + ' button', 'Try again');
    await b.key('Enter');
  }

  await t.test('initial failure has a keyboard retry and a stable focus target', async () => {
    await b.navigate(base + '/#/products');
    await b.wait('!!document.querySelector("#tools-opener")');
    await tools(5, true);
    await b.click('a[href="#/orders"]');
    await b.wait('document.querySelector("#orders-table")?.innerText.includes("Try again")');
    await retry('#orders-table');
    await b.wait('document.activeElement.id === "orders-table-scroll"');
    await loaded();
    assert.equal(await active(), 'orders-table-scroll');
    await b.key('Tab');
    assert.notEqual(await b.evaluate('document.activeElement.tagName'), 'BODY');
  });

  await t.test('failed refresh keeps the same focused row; retry keeps rows and recovers focus', async () => {
    await orders();
    await tools(5, true);
    await b.evaluate('window.originalRow = document.querySelector("#orders-table-row-0")');
    const original = await b.evaluate('window.originalRow.innerText');
    await b.click(refresh);
    await b.wait('!!document.querySelector("#orders-table [aria-busy=true]")');
    await tabTo('#orders-table-row-0');
    await b.wait('document.querySelector("#orders-table .klar-stale") !== null');
    assert.equal(await b.evaluate('document.querySelector("#orders-table-row-0") === window.originalRow'), true);
    assert.equal(await b.evaluate('window.originalRow.innerText'), original);
    assert.equal(await active(), 'orders-table-row-0');
    await retry('#orders-table .klar-stale');
    await b.wait('document.activeElement.id === "orders-table-scroll"');
    await b.wait('!document.querySelector("#orders-table .klar-stale")');
    assert.equal(await b.evaluate('document.querySelector("#orders-table-row-0") === window.originalRow'), true);
    assert.equal(await active(), 'orders-table-scroll');
  });

  await t.test('validation retains input, summary links focus fields and discard returns to opener', async () => {
    await orders();
    await b.click('#orders-table-row-0 td:nth-child(2)');
    await b.wait('document.activeElement.id === "order-customer"');
    await b.text('#order-email', 'not-an-email');
    await b.click('#order-editor button', 'Save');
    await b.wait('document.activeElement.id === "order-form-summary"');
    assert.equal(await b.evaluate('document.querySelector("#order-email").value'), 'not-an-email');
    await b.click('#order-form-summary button');
    await b.wait('document.activeElement.id === "order-email"');
    await b.key('Escape');
    await b.wait('!!document.querySelector("#order-discard")');
    await b.click('#order-discard button', 'Keep editing');
    await b.wait('!document.querySelector("#order-discard")');
    assert.equal(await b.evaluate('document.querySelector("#order-email").value'), 'not-an-email');
    await b.key('Escape');
    await b.wait('!!document.querySelector("#order-discard")');
    await b.click('#order-discard button', 'Discard changes');
    await b.wait('document.activeElement.id === "orders-table-row-0"');
  });

  await t.test('failed save retains the draft; keyboard retry submits once and saved data can be reopened', async () => {
    await orders();
    const requests = await tools(5, true);
    await b.click('#orders-table-row-0 td:nth-child(2)');
    await b.wait('document.activeElement.id === "order-customer"');
    const note = 'Delivery instructions retained through a failed save.';
    await b.text('#order-note', note);
    await b.click('#order-editor button', 'Save');
    await b.wait('document.querySelector("#order-form-status")?.innerText.includes("Try again")');
    assert.equal(await b.evaluate('document.querySelector("#order-note").value'), note);
    // Reach retry by normal Tab navigation, then activate it with a real Enter.
    await retry('#order-form-status');
    await b.wait('document.activeElement.id === "order-form-status"');
    await b.key('Enter');
    await b.key('Enter');
    await b.key('Escape');
    assert.equal(await b.evaluate('!!document.querySelector("#order-editor")'), true);
    await b.wait('!document.querySelector("#order-editor")');
    await b.wait('document.activeElement.id === "orders-table-row-0"');
    await b.wait('!document.querySelector("#orders-table [aria-busy=true]")');
    await b.key('Enter');
    await b.wait('document.activeElement.id === "order-customer"');
    assert.equal(await b.evaluate('document.querySelector("#order-note").value'), note);
    await b.key('Escape');
    await b.wait('document.activeElement.id === "orders-table-row-0"');
    assert.equal(await tools(0), requests + 3, 'Only failed save, successful retry and list refresh send requests');
  });

  await t.test('empty server results and a subsequent search retain the search input', async () => {
    await orders();
    await b.evaluate('window.searchInput = document.querySelector("#orders-table-search")');
    await b.text('#orders-table-search', 'no-such-customer-672936');
    await b.wait('document.querySelector("#orders-table")?.innerText.includes("No matches")');
    assert.equal(await active(), 'orders-table-search');
    await b.text('#orders-table-search', 'Dune');
    await loaded();
    assert.equal(await b.evaluate('document.querySelector("#orders-table-search") === window.searchInput'), true);
    assert.equal(await active(), 'orders-table-search');
    assert.match(await b.evaluate('document.querySelector("#orders-table-row-0").innerText'), /Dune/);
  });

  await t.test('customer form maps server keys, preserves unknown problems and submits corrected input', async () => {
    await b.navigate(base + '/examples/edit-form.html?visit=server-keys');
    await b.wait('!!document.querySelector("#customer-email")');
    await b.evaluate('window.emailInput = document.querySelector("#customer-email")');
    await b.text('#customer-email', 'taken@example.com');
    await b.click('#customer button', 'Save');
    await b.wait('document.activeElement.id === "customer-summary"');
    assert.equal(await b.evaluate('document.querySelector("#customer-email").getAttribute("aria-invalid")'), 'true');
    assert.match(await b.evaluate('document.querySelector("#customer-summary").innerText'), /belongs to another customer/);
    await tabTo('#customer-summary button');
    await b.key('Enter');
    await b.wait('document.activeElement.id === "customer-email"');
    await b.text('#customer-email', 'unknown@example.com');
    await b.click('#customer button', 'Save');
    await b.wait('document.querySelector("#customer-summary")?.innerText.includes("billing account is suspended")');
    assert.equal(await b.evaluate('document.querySelectorAll("#customer-summary button, #customer-summary a").length'), 0);
    assert.equal(await active(), 'customer-summary');
    await b.text('#customer-email', 'corrected@aurora.example');
    await b.evaluate('window.busyStates = []; window.formSampler = setInterval(() => window.busyStates.push({ busy: document.querySelector("#customer")?.getAttribute("aria-busy"), readOnly: document.querySelector("#customer-email")?.readOnly }), 10)');
    await b.click('#customer button', 'Save');
    await b.wait('document.querySelector("#customer-status")?.innerText.includes("Customer saved.")');
    const busyStates = await b.evaluate('(clearInterval(window.formSampler), window.busyStates)');
    assert.ok(busyStates.some(state => state.busy === 'true' && state.readOnly), JSON.stringify(busyStates));
    assert.equal(await b.evaluate('document.querySelector("#customer-email") === window.emailInput'), true);
    assert.equal(await b.evaluate('document.querySelector("#customer-email").value'), 'corrected@aurora.example');
    assert.equal(await b.evaluate('!!document.querySelector("#customer-summary")'), false);
    assert.deepEqual(await b.evaluate('Array.from(document.querySelectorAll("[id]")).map(e => e.id).filter((id, i, ids) => ids.indexOf(id) !== i)'), []);
  });

  await t.test('customer save failure and keyboard retry use the same stable status region', async () => {
    await b.navigate(base + '/examples/edit-form.html?visit=retry');
    await b.wait('!!document.querySelector("#customer-name")');
    await b.text('#customer-name', 'Crash');
    await b.click('#customer button', 'Save');
    await b.wait('document.querySelector("#customer-status")?.innerText.includes("Try again")');
    await b.evaluate('window.customerStatus = document.querySelector("#customer-status")');
    await b.text('#customer-name', 'Aurora updated');
    await retry('#customer-status');
    await b.wait('document.activeElement.id === "customer-status"');
    await b.wait('document.querySelector("#customer-status")?.innerText.includes("Customer saved.")');
    assert.equal(await active(), 'customer-status');
    assert.equal(await b.evaluate('document.querySelector("#customer-status") === window.customerStatus'), true);
    assert.equal(await b.evaluate('document.querySelector("#customer-name").value'), 'Aurora updated');
  });
  assert.deepEqual(b.errors, [], 'No browser runtime or console errors');
});
