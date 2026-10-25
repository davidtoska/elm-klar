# Building an application with Klar

Klar is an Elm toolkit for precise, data-dense applications. Build the interface
with Klar and your own Elm code; keep business logic and transport in the application.
For work on the library itself, read [AGENTS.md](AGENTS.md).

## Read only what you need

1. Read this guide for the conventions and local setup.
2. Search [ai/klar-index.json](ai/klar-index.json) by `keywords`, `purpose`,
   `whenToUse`, `whenNot`, `quickPath` and `related`.
3. Read the selected [module references](ai/modules/README.md). They contain
   signatures, defaults, examples and the public contract, generated from Elm docs.
4. Copy the nearest [complete program](example/src/Examples/). Start with
   [Application.elm](example/src/Examples/Application.elm) for the shell, routing,
   settings, table, simulated requests and overlays, or
   [EditForm.elm](example/src/Examples/EditForm.elm) for a declared form.

Do not depend on library internals or copy its implementation. The generated
references are the API guide; the showcase's implementation is not a prerequisite.

For real Go/SQLite integration, see the [kitchen-sink consumer](apps/kitchen-sink/README.md)
and its [findings and verification limits](apps/kitchen-sink/FINDINGS.md). It exercises
HTTP queries, form saves and file uploads; the smaller examples use Elm simulators.
The short [HTTP boundary guide](example/HTTP.md) connects the query wire format,
request tickets, multipart progress, cancellation and persistence to that code.

## Component conventions

- A stateful component has `State`, `Msg`, `init`, `update` and `view`.
  Keep its state in your model and map its command with `Cmd.map`.
  Read its value before and after `update` to react to changes; there are no out-messages.
- View-only components take attributes and required content:
  `Button.view [ Button.primary, Button.onClick Save ] "Save"`.
  The last repeated attribute wins, except state flags, which add up.
- The string passed to `init` is a DOM id, unique on the page.
  Keep DOM ids and table column ids as named values.
- Domain ids are your own types, shared through one `Klar.Ids` per type.
  Use `Ids.make`, `Ids.list`, `Ids.string` or `Ids.int` as appropriate.
- Put `Klar.stylesheetFor model.settings` once in the view (`Klar.stylesheet`
  uses the default settings). Use `Klar.Layout`, `Klar.Text` and typed themes;
  do not add CSS, class names, style strings or copied components.
- Dates are `Klar.Date`, money is `Klar.Money`, presentation is `Klar.Format`.
  Read the time zone and current time into `Settings`; pass `X.locale`
  explicitly where the component needs the language.

## Requests, forms and overlays

- Keep backend data as `Remote a` and pass it to the component's remote API.
  Start a request with `Remote.refresh`; finish with `Remote.settle old result`
  (or `Remote.refreshWith old result at` when recording the answer's time).
  `Remote.Kept` preserves data during refresh and after a failed refresh.
  Do not replace retained data with `Remote.fromResult` or separate stale/loading flags.
- Klar sends no requests. Map transport failures to `Remote.Problem` once at the
  application boundary. Correlate replies with the relevant request and record/session.
- Use `ServerList` for a server table with filters and saved views; it owns query
  changes and reply tickets. For a server-mode `Table` alone, follow the request
  wiring in its module reference. Do not add another debounce to queries Klar delays.
- Declare record forms with `Klar.Form.Spec` and keep one `Form.State`.
  `Form.submit` validates and returns one request with a ticket;
  `Form.finish` settles its reply. Draw the shared save state with
  `Form.submission` and `Klar.Form.Submission`; do not keep a second save status.
  `Spec.serverKey` maps backend field names; unmatched problems remain in the summary.
  For hand-wired forms, use `Klar.Form.Layout` and `Klar.Form.Submission` directly.
- Give every overlay to one `AppShell.overlays` or `Overlay.host`, even while closed.
  An opener needs an id (`Button.id`) passed to `open` so focus can return.
  Use `setInitialFocus` for a field inside a dialog, drawer or popover.
- Do not implement popup positioning, click-away layers, focus traps, scrolling,
  date arithmetic or keyboard infrastructure. Find the corresponding Klar module.
  Explicit page focus uses `Klar.focus id NoOp`.
- Global shortcuts need both `Shortcut.listen` (through `AppShell.shortcuts`
  or `Overlay.host` attributes) and `Shortcut.subscription`; subscription alone
  does not handle keys while an element has focus. Follow `Klar.Shortcut` wiring.

## Application frame and common traps

- Follow [Application.elm](example/src/Examples/Application.elm) for `AppShell`:
  its update returns the address, which is where the application learns route changes.
  A leave guard adds the wiring documented in `Klar.LeaveGuard`; see
  [MultiStep.elm](example/src/Examples/MultiStep.elm).
- `Browser.application` and `Browser.document` mount with `Elm.Main.init()`.
  `Browser.element` and `Browser.sandbox` need a node. The shell needs `elm/url`
  as a direct application dependency.
- Keep a page's `h1` outside remote content so it exists during loading and failure.
  A card or form-section title is an `h2`; nested sections need the right heading level.
- Retry controls may disappear. Follow the component's documented retry-focus wiring;
  a retry region needs a stable id. The [Orders walkthrough](example/ORDERS.md)
  covers the keyboard path through failure and recovery.
- Draw wizard step fields inside `Form.stepBody` so a new step does not reuse the
  focused input from the previous step.
- In a server table, `AllMatching { except }` is not a list of selected ids.
  Inspect `Table.selection`; cross-page exports belong on the backend.
- Applications own persistence, provider credentials, authorization, tool execution
  and approval of AI proposals. Ports and JavaScript adapters may live at that boundary;
  the library remains transport neutral and port-free.
- If Klar lacks something, document the limitation with `-- KLAR GAP: ...` and
  build the best honest version. Do not import internals or silently change user input.

## Getting Klar into a project

Before publication, pin a checkout or git submodule and include its `src` directory
in the application's `source-directories`. Elm uses the application's dependencies,
not the dependencies of the source folder. For a new local app, copy
[example/elm.json](example/elm.json), change `source-directories` to
`["src", "vendor/klar/src"]` (using your actual checkout path), and remove or adapt
the test dependencies. Keep its compiler version and direct/indirect dependencies.
After publication, use `elm install davidtoska/elm-klar` instead.

Compile a program with `elm make src/Main.elm --output=main.js`. For a shell-based
`Browser.application`, an HTML page only needs `<script src="main.js"></script>`
and `<script>Elm.Main.init();</script>`; Klar supplies the page styles.
The [starter's HTML](example/examples/application.html) shows the mounting shape.

Add `elm/http` or other transport only to your application when needed. Settle
responses into `Remote`; never put credentials or provider calls in Klar modules.
The [connected-app guide](example/APPLICATIONS.md) and
[process studio guide](example/WORKFLOWS.md) explain the simulated server boundaries.

For the application's agent instructions, point to this guide, the generated index
and the relevant complete program. Keep application-specific decisions there;
do not copy the whole Klar guide into another file.
