# Connected AI application examples

The showcase's **Application examples** menu includes the connected-app screens below. They
also appear in command search (Ctrl K) and on the complete examples page.

| URL fragment | Screen |
| --- | --- |
| `#/applications/sign-in` | Google, Microsoft and email sign-in |
| `#/applications/sign-up` | Account details, consent and verification-email feedback |
| `#/applications/forgot-password` | Account-neutral recovery confirmation |
| `#/applications/reset-password` | Password confirmation and expired-link feedback |
| `#/applications/connections` | GitHub, Drive, Calendar, Microsoft 365, Slack and Notion |
| `#/applications/github` | Selected repositories, permission review and imports |
| `#/applications/google-workspace` | Independent Drive and Calendar connections |
| `#/applications/ai-providers` | OpenAI, Anthropic, OpenRouter, JEV and a custom adapter |
| `#/applications/jev-classification` | Document queue, confidence policy and human review |

Run `npm start` and open one of these fragments on `http://localhost:8000/`.
All responses, identities, documents and emails are simulated. No credentials or
documents leave the browser, no provider API is called, and reload resets state.
The credential screen accepts only invented `demo-` keys. Verification discards
the key immediately; the saved record contains only a label and environment.
These are UI examples, not production authentication or provider clients.

## Copying and extending the system

- `src/Patterns/Workspace.elm`: larger reusable compositions for a connection card,
  permission choice, account/settings section, flow indicator and live result.
  They use only public Klar components and need no CSS.
- `src/Page/Applications/Catalog.elm`: the typed page registry. Its title, slug,
  description and icon drive the sidebar, command palette and examples index.
- `src/Page/Applications.elm`: composition and lifecycle boundary.
- `src/Page/Applications/{Auth,Connections,Providers,Classification}.elm`:
  independent models, messages, update functions and views. Copy the feature and
  the compositions it imports into an application.

To add a screen, add a `Page` and its registry entries, then dispatch its view in
`Page.Applications.view`. Add feature state/update wiring when the screen is
interactive. Navigation and discovery use the registry automatically. Keep the
existing standalone programs under `src/Examples/` for single-file examples.

Every delayed callback carries an operation generation. Leaving any application
screen invalidates pending callbacks, clears password/key drafts and returns
unfinished classifications to the queue. Completed connection metadata and
classification results survive navigation in memory. Cancellation is a local
demo behavior; cancelling a production operation also needs a server contract.

## Connecting an application server

Replace simulated commands in the feature's `start`, `run`, `Verify` and `next`
branches with your application's transport. Klar remains transport neutral.
Use the same state transitions for actual server responses.

The following are suggested application endpoints, not endpoints implemented by
this repository or provider API paths:

| Application operation | Suggested server responsibility |
| --- | --- |
| `POST /session` | Validate credentials; issue a secure HttpOnly session cookie |
| `POST /password-recovery` | Rate-limit recovery; always return account-neutral feedback |
| `POST /password-reset` | Validate a short-lived, single-use token server-side |
| `POST /connections/:provider/start` | Bind an authorization attempt to the authenticated user and requested scope |
| Provider callback | Verify state and the provider response, exchange the code server-side, then redirect without exposing tokens |
| `POST /connections/:id/import` | Authorize workspace access and import only selected resources |
| `DELETE /connections/:id` | Revoke credentials, stop scheduled imports and apply the chosen data-retention policy |
| `POST /providers/:id/credential` | Admin-only key verification and encrypted secret storage; return metadata only |
| `POST /classification-jobs` | Read authorized document text, call the provider, validate results and persist job progress |
| `POST /classification-jobs/:id/review` | Authorize reviewer access; record category, actor and source/result revision |

Protect mutation endpoints against CSRF and enforce tenant ownership on the
server. Use HTTPS and the provider-supported authorization-code flow, with PKCE
where applicable. A production reset screen must validate the actual recovery
token before offering an editable form; selecting "Expired link" here only
simulates that outcome. Never log secrets, return them to the UI, or persist them
in browser storage. Frontend hiding and generation checks do not replace server
authorization, token revocation or audit records.

GitHub uses the GitHub App installation model with a repository selection. The
configured app needs read-only contents, issues and pull-request permissions;
organization policy may require approval. Google sign-in is separate from Drive
or Calendar consent. Drive's `drive.file` grant is per file and can permit writes;
the application server must enforce this example's read-only policy. A real file
picker must establish grants. Calendar authorization and the chosen calendar
import filter are different: enforce the filter server-side. Request offline
access when the server must refresh tokens for background imports.

The Anthropic connection represents an API key. A Claude Code subscription login
is separate; never scrape or import a local Claude Code session token into this UI.

## JEV classification

Jev is TypeSafe's decision model. A `Choice` question defines the allowed labels;
its answer provides the selected label, per-label probabilities and confidence.
This demo applies an application policy to those values: confidence under the
selected threshold enters `NeedsReview`, while a reviewer can change the category
and explicitly approve it. Confidence is not a guarantee of correctness.

A server adapter can send extracted document text to
`https://api.typesafe.ai/v1/systemone` with a request shaped like this:

```json
{
  "model": "jev-latest",
  "state": "Invoice 1042. Total EUR 2400. Payment due in 30 days.",
  "questions": {
    "document_category": {
      "type": "choice",
      "instructions": "Which category describes this document?",
      "criteria": {
        "invoice": "A request for payment with an amount and due date",
        "contract": "An agreement defining obligations between parties",
        "support": "A request for help with a product or account",
        "other": "Content outside the listed categories"
      }
    }
  }
}
```

Map `answers.document_category.choice` to your closed application vocabulary and
validate the numeric scores. Use a server-held TypeSafe API key. Extract PDF text
or run OCR before this step: the demo uses canned excerpts, including for the
scanned attachment. Its final row deliberately fails in the mixed scenario.
Retrying demonstrates recovery; a low-confidence retry still requires review.

The lifecycle is `Queued -> Classifying -> Checking -> Classified | NeedsReview | Failed`;
review produces `Approved`, retry returns a failed row to the queue, and stopping
a batch retains completed results. A reset invalidates responses from the old run.
The UI never automatically executes a downstream action based on an AI label.

## Validation and references

`npm run test:gallery` includes route round trips, form gates, secret clearing,
cancelled/late callbacks, default-provider handling, classification thresholds,
review corrections and retry behavior. `npm run build:example` compiles all pages.

Implementation references checked on 2026-10-25:

- [GitHub App installation and repository access](https://docs.github.com/en/apps/using-github-apps/installing-a-github-app-from-a-third-party)
- [Google server-side OAuth and offline access](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Claude Code API key authentication](https://support.claude.com/en/articles/12304248-manage-api-key-environment-variables-in-claude-code)
- [TypeSafe Choice questions](https://docs.typesafe.ai/primitives/choice)
- [TypeSafe quick start](https://docs.typesafe.ai/introduction/quickstart)
- [TypeSafe confidence](https://docs.typesafe.ai/confidence)
