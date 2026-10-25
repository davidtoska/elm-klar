# Connected application examples

Run `npm start` and choose **Application examples** or search with Ctrl K.
[Catalog.elm](src/Page/Applications/Catalog.elm) owns the screen list, route slugs,
titles and descriptions; the menu and examples index use the same registry.

The account, connection, credential and classification screens simulate their
responses in Elm. Reload resets them. They do not call providers or send documents.
Credential fields accept invented `demo-` keys, discard them after verification,
and retain metadata only. These screens are UI patterns, not production clients.
The calendar has its own Go/SQLite backend; see [its guide](../apps/calendar/README.md).

## Copy or extend a pattern

- [Patterns/Workspace.elm](src/Patterns/Workspace.elm) contains public-Klar
  compositions for connection cards, permissions, settings, steps and results.
- [Page/Applications.elm](src/Page/Applications.elm) owns composition and lifecycle.
  The feature modules under `Page/Applications/` own their models, messages and views.
- Add a screen to the typed catalog, dispatch its view and wire its state/update.
  Navigation and discovery then use the registry automatically.
- Keep the [standalone programs](src/Examples/) for small, copyable applications.

Leaving an application screen invalidates delayed callbacks and clears credential
drafts. Completed connection metadata and classification results remain in memory.
This is demo cancellation; a real service also needs cancellation/reply correlation.

## Replace the simulator

Replace each feature's simulated command with requests to your application's
server. New apps use the Elm/Go/SQLite stack in [AGENTS.md](../AGENTS.md).
Klar remains transport neutral; its components do not authenticate users, store
credentials or authorize imports and writes.

The server owns verified sessions, tenant/resource access, provider consent and
credentials, password-recovery tokens, background imports and persisted results.
Return metadata to the interface, not secrets. Enforce permissions and revisions
on every mutation; hiding a control or ignoring a late callback is not authorization.
Provider-specific protocol details belong in the real adapter's documentation,
not in this simulated component showcase.

## Classification scenario

The JEV page demonstrates application policy over simulated categories, numeric
scores and confidence. Rows move through
`Queued -> Classifying -> Checking -> Classified | NeedsReview | Failed`.
A low-confidence result requires human review; a reviewer can correct and approve
it. Confidence is not a guarantee of correctness, and an AI label does not execute
any downstream action.

The mixed scenario includes a deliberate failure. Retry demonstrates recovery;
a low-confidence retry still requires review. Stopping keeps completed results,
and reset invalidates replies from the old run. The excerpts are canned, including
the scanned attachment; a real adapter must extract text/OCR, validate provider
results against the application's vocabulary and persist review/audit decisions.

## Verify

`npm run test:gallery` covers routes, form gates, cleared secrets, late/cancelled
callbacks, classification thresholds, corrections and retry. `npm run build:example`
compiles the showcase and complete programs. Try the same failure and cancellation
paths manually when changing the feature lifecycle.
