import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { once } from 'node:events';
import { test } from 'node:test';
import { createCalendarHandler } from '../calendar/server/server.mjs';

test('mounted calendar supports demo sign-in, event writes, persistence and isolated stores', async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'klar-calendar-integration-'));
  const servers = [];
  t.after(async () => {
    await Promise.all(servers.map(server => new Promise(resolve => server.close(resolve))));
    const resolved = path.resolve(directory);
    assert.ok(resolved.startsWith(path.join(os.tmpdir(), 'klar-calendar-integration-')));
    fs.rmSync(resolved, { recursive: true, force: true });
  });
  async function host(dataFile, mounted = true) {
    const prefix = mounted ? '/calendar-app' : '';
    const handler = createCalendarHandler({ dataFile, demoMode: true, cookiePath: `${prefix}/` });
    const server = http.createServer((request, response) => {
      if (prefix) request.url = request.url.slice(prefix.length);
      return handler(request, response);
    });
    servers.push(server);
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const base = `http://127.0.0.1:${server.address().port}${prefix}`;
    return async (url, { cookie, body, method = 'GET' } = {}) => {
      const response = await fetch(base + url, {
        method,
        headers: { ...(cookie ? { Cookie: cookie } : {}), ...(body ? { 'Content-Type': 'application/json' } : {}) },
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      return { response, data: await response.json() };
    };
  }
  const dataFile = path.join(directory, 'showcase.json');
  const request = await host(dataFile);
  const config = await request('/config.json');
  assert.equal(config.data.demo.length, 3);
  assert.equal((await request('/calendar/v3/users/me/calendarList')).response.status, 401);
  const login = await request('/auth/demo', { method: 'POST', body: { email: 'ada@example.com' } });
  assert.equal(login.response.status, 200);
  const setCookie = login.response.headers.get('set-cookie');
  assert.match(setCookie, /Path=\/calendar-app\//);
  assert.match(setCookie, /HttpOnly/);
  const cookie = setCookie.split(';')[0];
  const calendars = await request('/calendar/v3/users/me/calendarList', { cookie });
  assert.ok(calendars.data.items.some(calendar => calendar.summary === 'Warehouse team'));
  const created = await request('/calendar/v3/calendars/primary/events', {
    cookie, method: 'POST', body: {
      summary: 'Showcase integration check',
      start: { date: '2026-10-25' }, end: { date: '2026-10-26' },
    },
  });
  assert.equal(created.response.status, 200);
  assert.equal(created.data.summary, 'Showcase integration check');
  const restarted = await host(dataFile);
  const restored = await restarted(`/calendar/v3/calendars/primary/events/${created.data.id}`, { cookie });
  assert.equal(restored.data.summary, 'Showcase integration check');
  const standalone = await host(path.join(directory, 'standalone.json'), false);
  assert.equal((await standalone('/auth/me', { cookie })).response.status, 401);
  const standaloneLogin = await standalone('/auth/demo', { method: 'POST', body: { email: 'bob@example.com' } });
  assert.equal(standaloneLogin.response.status, 200);
  assert.match(standaloneLogin.response.headers.get('set-cookie'), /Path=\/;/);
  const logout = await request('/auth/logout', { method: 'POST', cookie, body: {} });
  assert.match(logout.response.headers.get('set-cookie'), /Path=\/calendar-app\/; Max-Age=0/);
  assert.equal((await request('/auth/me', { cookie })).response.status, 401);
});
