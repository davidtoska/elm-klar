# Orders: a complete server-backed workflow

Run `npm start` and open `http://localhost:8000/#/orders`.
The existing Orders application combines server-side search, sorting and paging,
editing in a drawer, field validation, unsaved-change confirmation and saving.
It uses only public Klar modules. There is one implementation, rather than a
second example of the same workflow.

## Try the failure and recovery path

1. Open Orders and wait for the rows. Open Developer tools, choose **Slow** latency
   and **Fail next request**, and close the tools. This fails exactly one request
   with a simulated 503; subsequent requests work normally.
2. Refresh the table. Its existing rows remain while loading and after failure,
   with the built-in stale-data notice. Tab to **Try again** and press Enter.
   Focus waits in the table while the retry control disappears on success.
3. Arm **Fail next request** again, then open the first draft order. Change its
   note and save. The failed write leaves the drawer open and preserves the draft.
   Tab to **Try again** and press Enter. The status region holds focus during the
   request; success closes the drawer and returns focus to the originating row.
   Open that row again to verify the server accepted the change.
4. Enter an invalid email and save. The summary receives focus, its button takes
   you to the email field, and the original input stays visible. Escape asks
   whether to discard; **Keep editing** retains the draft, and **Discard changes**
   returns focus to the row.
5. Search for a customer that does not exist, then for **Dune**. The table draws
   the empty result and subsequent rows, keeping the search input and its focus.

For an initial read failure, arm **Fail next request** on Products, then navigate
to Orders. The table's initial failure and retry are distinct from a failed
refresh with retained data. Offline, server-error and timeout modes are also
available in Developer tools.

## Data ownership and transport

`Api` is the application request boundary; `Backend.Server` is a simulated server
in Elm. Requests deliver delayed `Result` values, and failed requests do not mutate
the database. This workflow does not contact a real HTTP server or persist across
page reloads. A real application replaces the transport in `Api`, keeps the server
validation, and maps its failures to `Remote.Problem`. Klar remains transport neutral.

The page owns request tickets and typed row ids. Reading rows and saving an order
are separate operations. Closing the editor is blocked during submission; failed
writes preserve the draft. Public lifecycle contracts live in
[Remote](../ai/modules/Klar.Remote.md), [Table](../ai/modules/Klar.Table.md) and
[Form.Submission](../ai/modules/Klar.Form.Submission.md).

The second application, `examples/edit-form.html`, uses the lifecycle inside
`Form.State`. Try `taken@example.com` for a server field
rejection, `unknown@example.com` for a problem without a matching field, and the
name `Crash` for a failed request. Correct the input and retry. `Spec.serverKey`
maps `email_address` to the email field; the unknown billing-account problem stays
in the summary as plain text. An accepted save marks only submitted values clean.

## Automated checks and limits

Run `npm run build:example` followed by `npm run test:browser`, or `npm run check`.
Tests start an isolated local static server and a disposable headless Chromium
profile, use actual mouse/keyboard input, inspect `document.activeElement`, compare
DOM node identity and verify the saved data by reopening the order. They check
browser runtime/console errors as well. No test hooks or browser dependency are
added to the Elm application or library.

Node 22 or newer is required for its built-in WebSocket client. Edge or Chrome is
detected on Windows, Chromium/Chrome on Linux and Chrome on macOS. Set `KLAR_BROWSER`
to an absolute executable path for another Chromium installation. Missing browsers
fail the check explicitly. Firefox, Safari and screen-reader verification remain
release work.

Outstanding library decisions are tracked only in [ROADMAP.md](../ROADMAP.md).
This regression workflow is separate from the independent AI-documentation-only
application trial.
