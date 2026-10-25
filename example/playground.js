/* The showcase's optional local Elm compiler. Static hosting still supports all
   ordinary controls; custom expressions report how to start the local server. */
window.KlarPlayground = {
  boot(app, preview = false) {
    const ports = app.ports;
    if (preview) {
      const original = console.log.bind(console);
      console.log = (...items) => {
        original(...items);
        const message = items.map(String).join(' ');
        const marker = '__klar_playground_callback__: ';
        if (message.startsWith(marker)) window.parent.postMessage({ kind: 'klar-playground-callback', payload: message.slice(marker.length) }, window.location.origin);
      };
      return;
    }
    if (!ports?.request || !ports?.responses) return;
    const send = response => ports.responses.send(response);
    ports.request.subscribe(async input => {
      try {
        if (input.action === 'describe') {
          const response = await fetch('/__playground/describe?component=' + encodeURIComponent(input.component));
          if (!response.ok) throw Error('Custom Elm expressions need the local compiler. Start the demo with npm start, then reload.');
          const body = await response.json();
          if (body.error) throw Error(body.error);
          send({ ...input, action: 'described', targets: body.targets });
        } else if (input.action === 'compile') {
          const response = await fetch('/__playground/compile', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(input) });
          const body = await response.json();
          send({ ...input, action: 'compiled', ok: Boolean(body.ok), url: body.url || '', diagnostics: body.diagnostics || body.error || '' });
        }
      } catch (error) {
        send({ ...input, action: 'compiler-error', diagnostics: error.message });
      }
    });
    window.addEventListener('message', event => {
      const frame = document.querySelector('.playground-compiled-preview');
      if (event.origin !== window.location.origin || event.source !== frame?.contentWindow || event.data?.kind !== 'klar-playground-callback') return;
      send({ action: 'callback', payload: String(event.data.payload), component: frame.dataset.component, id: Number(frame.dataset.request) });
    });
  },
};
