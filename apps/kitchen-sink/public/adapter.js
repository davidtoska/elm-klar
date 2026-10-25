/* Application boundary only: transport, cancellation and streamed JSON. No UI. */
const application = Elm.Main.init();
const controllers = new Map();
const reply = (id, ok, body, extra = {}) => application.ports.incoming.send({ id, ok, body, at: Date.now(), ...extra });
application.ports.outgoing.subscribe(async ({ id, method, url, body }) => {
  if (method === 'CANCEL') { controllers.get(id)?.abort(); return; }
  const controller = new AbortController();
  controllers.set(id, controller);
  try {
    const response = await fetch(url, { method, signal: controller.signal, headers: body === null ? {} : { 'Content-Type': 'application/json' }, body: method === 'GET' || body === null ? undefined : JSON.stringify(body) });
    if (response.ok && response.headers.get('Content-Type')?.includes('application/x-ndjson')) {
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let pending = '';
      while (true) {
        const { value, done } = await reader.read();
        pending += decoder.decode(value, { stream: !done });
        const lines = pending.split('\n');
        pending = lines.pop();
        for (const line of lines) if (line.trim()) reply(id, true, JSON.parse(line));
        if (done) break;
      }
      if (pending.trim()) reply(id, true, JSON.parse(pending));
    } else {
      reply(id, response.ok, await response.json(), { status: response.status });
    }
  } catch (error) {
    if (error.name !== 'AbortError') reply(id, false, { error: String(error) }, { status: 0 });
  } finally {
    if (controllers.get(id) === controller) controllers.delete(id);
  }
});
