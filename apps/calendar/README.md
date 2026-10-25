# Calendar

An Elm calendar with a Go HTTP server and SQLite persistence. It supports day,
week, month and agenda views, shared calendars, invitations, recurrence and
ICS/Google-calendar import. The app uses public Klar modules; transport and
calendar-specific behavior stay here, outside the library.

## Run

Install the repository's npm tools and Go 1.26+ on PATH. `KLAR_GO` can instead
point to a Go executable. From the repository root:

```sh
npm install
npm run calendar -- --demo
```

Open `http://localhost:8080`. Without `--demo`, register the first account.
Demo mode seeds an empty database with Ada, Bob and Cleo (`calendar123`) and
provides one-click sign-in. Existing databases are never replaced with demo data.

For the full showcase, `npm start` builds the client and starts the Go server
behind `/calendar-app/`. Open the Calendar component or Google Calendar application
example. Both display the same app; **Open full calendar** opens it in its own tab.
Node handles repository tooling and the showcase proxy only, not the calendar API.

The standalone app also runs without Node once Elm is compiled:

```sh
cd apps/calendar
go run ./server --demo
```

| Setting | Default |
| --- | --- |
| `--port` / `PORT` | `8080`, on loopback |
| `--addr` | Overrides host/port; `127.0.0.1:0` chooses a free port |
| `--db` / `CALENDAR_DB` | `data/calendar.sqlite` |
| Showcase database | `data/showcase.sqlite`, independent of standalone data |
| `--assets` | Working directory containing `index.html` and compiled `main.js` |
| `--prefix` | Empty; the showcase uses `/calendar-app` and scoped cookies |
| `--google-client-id` / `GOOGLE_CLIENT_ID` | Empty; enables optional Google import |
| `--import-json` / `CALENDAR_DATA` | Legacy JSON to import into an uninitialized database |

## Existing data

On first start, the server imports an existing legacy JSON store when provided,
or looks for `server/data.json`, preferring the old root backup if it still exists.
The showcase similarly supplies its legacy `showcase-data.json`. Users, scrypt
password hashes, sessions, calendar and
event ids, sharing rules and preferences are retained. The JSON file is not
modified, and initialization is recorded transactionally so it is not reapplied
over newer SQLite changes. Invalid JSON stops startup instead of seeding over it.

The migration retains the original ignored JSON backups under the old
`calendar/server/` directory as well. Stop/restart any old showcase instances
before using the new app: already running Node servers still use their old JSON
store. To migrate a later backup, give its path with `--import-json` and choose a
new `--db` path. Do not delete an existing SQLite database to force an import.

SQLite has separate users, sessions, calendars, events and preferences tables.
Event resources retain their JSON fields for import/export compatibility.
Each request reads and writes within one transaction; a failed commit returns an
error and leaves the previous persisted state intact. Data and build output are
ignored by Git.

## HTTP and calendar behavior

The existing Elm client uses ordinary HTTP calls. The server retains the app's
Google-Calendar-shaped `/calendar/v3` resource paths and JSON errors, plus `/auth`
for accounts and sessions, `/api/users`, `/config.json` and `/api/import/google`.
The implementation is a subset: series are returned without expansion/pagination;
Elm expands recurrence with Klar.Recurrence. Guest updates change only their own
RSVP, guest deletion declines an invitation, and free/busy access omits event text.

ICS imports update matching iCalUIDs instead of duplicating events. Whole-calendar
Google import converts changed/cancelled instances into exclusions on the series;
changed instances also become standalone events. Sharing uses owner, writer,
reader and freeBusyReader roles. Time zones use Go's bundled IANA database and
recognize common Windows zone names from calendar files.

Optional live Google import still uses a short-lived browser access token and
copies data; it is not ongoing synchronization. Configure a Google OAuth web
client for the origin you run. For standalone development that is normally
`http://localhost:8080` with redirect `http://localhost:8080/`; for showcase use
its origin and `/calendar-app/` redirect. Open the full calendar for provider
sign-in. Credentials are not stored by the Go server.

Not included: email delivery, reminders, rooms/resources, attachments, conferencing,
dragging/resizing events or editing one occurrence independently. Grid.elm retains
the app-specific time grid; the library does not yet provide that component.

## Verify

From the repository root:

```sh
npm run test:calendar-server
npm run calendar:test -- --workers 2
npm run build:example
```

Go tests exercise accounts, permissions, guest replies, query/update/import
contracts, timezone transitions, SQLite rollback/reopening, concurrent writes and
legacy migration. The HTTP integration check launches real Go processes with
fresh temporary databases, mounted and standalone. Elm tests cover ICS, Google
JSON, recurrence and overlapping-event layout. `npm run check` includes these
checks; production Google authorization is not exercised by the local test suite.
