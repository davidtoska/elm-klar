# Calendar

A calendar in the manner of Google Calendar, simpler, built with Klar: people
register and sign in, keep several calendars, share them, invite one another to
events, and import from Google Calendar, from calendar files and from
invitations that come by email.

The client is Elm (`src/`); the server is one Node file without dependencies
(`server/`). The server speaks a subset of the **Google Calendar API v3**: the
same paths, the same JSON resources (`calendarListEntry`, `calendar`, `event`,
`aclRule`), the same error shape. Events, colors, sharing roles and recurrence
are stored exactly as Google writes them, so data moves between the two without
translation.

## Run it

```bash
npm install                                  # once, in the repository root
npm run calendar:build                       # elm make, writes calendar/main.js
node calendar/server/server.mjs --demo       # http://localhost:8080
```

`--demo` fills an empty data file with three people (`ada@example.com`,
`bob@example.com`, `cleo@example.com`, password `calendar123`), a shared
calendar, a repeating stand-up and an invitation. Without it the calendar starts
empty and the first person registers.

| Setting | Default | |
| --- | --- | --- |
| `PORT` or `--port` | `8080` | |
| `CALENDAR_DATA` | `calendar/server/data.json` | the whole store, one JSON file (not committed) |
| `GOOGLE_CLIENT_ID` | empty | turns on the import from Google Calendar |

Tests of the pure parts (the `.ics` reader and writer, recurrence, the layout of
overlapping events, the Google JSON): `npm run calendar:test`.

## What it does

- **People**: register with name, email and password (scrypt), sign in, sign out.
  The session is an HttpOnly cookie. Registering makes a primary calendar whose id
  is the email address, as in Google.
- **Calendars**: create, rename, describe, delete; show and hide each one; a color
  per person (Google's 24 colors).
- **Sharing**: per calendar and person, Google's roles: *see only free/busy*
  (`freeBusyReader`), *see all details* (`reader`), *make changes* (`writer`),
  *manage sharing* (`owner`). A shared calendar appears under "Other calendars";
  free/busy shows "Busy" blocks only. "Remove from my list" unsubscribes.
- **Events**: timed and all-day, over several days, with location, description,
  Google's 11 event colors, guests and repetition (daily, weekly on chosen days,
  monthly on a day or a weekday, yearly; ends never, after n times or on a date).
  Deleting one date of a series adds an `EXDATE`; "All events" deletes the series.
- **Invitations**: a guest who has an account sees the event in their own calendar
  and on the Invitations page, answers yes, maybe or no, and the organizer sees
  the answers. A guest who deletes an invitation declines it.
- **Views**: day, week (Monday first), month, and a 30-day agenda; a small month
  to jump to a date; the current time as a line; times in the browser's time zone,
  correct over daylight saving changes (the server converts with the time zone
  database of Node).
- **Import and export**:
  - **Google Calendar, live**: "Connect Google Calendar" signs in at Google
    (read only), lists the account's calendars, and copies the chosen ones into new
    calendars here: every event with its series, changed instances and cancelled
    dates.
  - **`.ics` files**: an export from Google Calendar (Settings, Import and export),
    Outlook or Apple Calendar goes into a new or an existing calendar. Importing the
    same file twice updates instead of doubling (events are matched by `iCalUID`,
    as Google's `events.import` does).
  - **Invitations by email** (`METHOD:REQUEST`): open the `.ics` attachment,
    answer, and the event is in your calendar; the reply (`METHOD:REPLY`) can be
    downloaded and sent to the organizer. A cancellation (`METHOD:CANCEL`) removes
    the event.
  - **Google API JSON**: the response of `events.list` saved as a `.json` file.
  - **Export**: any calendar as an `.ics` file (calendar settings, Export) that
    Google Calendar and Outlook import.

Not included, on purpose: reminders and notifications, email delivery of
invitations, rooms and resources, tasks, attachments, conferencing links, drag
and drop of events, editing one date of a series on its own (it is edited as a
series), and the sync of later changes in Google (an import is a copy).

## Connect Google Calendar

1. In the [Google Cloud console](https://console.cloud.google.com/), create a
   project and enable the **Google Calendar API**.
2. Set up the OAuth consent screen (type External, in testing mode is enough;
   add yourself as a test user) with the scope
   `https://www.googleapis.com/auth/calendar.readonly`.
3. Create an **OAuth client ID** of type *Web application* with
   - Authorized JavaScript origin: `http://localhost:8080`
   - Authorized redirect URI: `http://localhost:8080/`
4. Start the server with the client id:

   ```bash
   GOOGLE_CLIENT_ID=1234-abc.apps.googleusercontent.com node calendar/server/server.mjs
   ```

The browser talks to Google directly with a short-lived access token
(the OAuth token flow, no client secret, nothing stored on the server); the
token is used once, for the import, and is gone when the page reloads.

## The API

All paths need a signed-in session. `calendarId` may be `primary`.

| Method | Path | As in Google |
| --- | --- | --- |
| GET, POST | `/calendar/v3/users/me/calendarList` | `calendarList.list`, `.insert` |
| PATCH, PUT, DELETE | `/calendar/v3/users/me/calendarList/{calendarId}` | `selected`, `colorId`, `backgroundColor`, `summaryOverride`; delete unsubscribes |
| POST | `/calendar/v3/calendars` | `calendars.insert` |
| GET, PATCH, PUT, DELETE | `/calendar/v3/calendars/{calendarId}` | `calendars.*` |
| GET, POST | `/calendar/v3/calendars/{calendarId}/acl` | `acl.list`, `acl.insert` (scopes `user` and `default`) |
| DELETE | `/calendar/v3/calendars/{calendarId}/acl/{ruleId}` | `acl.delete` |
| GET, POST | `/calendar/v3/calendars/{calendarId}/events` | `events.list` (`timeMin`, `timeMax`, `timeZone`, `q`, `iCalUID`, `showDeleted`), `events.insert` |
| POST | `/calendar/v3/calendars/{calendarId}/events/import` | `events.import` (by `iCalUID`) |
| GET, PATCH, PUT, DELETE | `/calendar/v3/calendars/{calendarId}/events/{eventId}` | `events.*`; a guest may patch only their own `responseStatus` |

Differences from Google: `events.list` always returns series, not their
instances (`singleEvents=false`; the client expands them with
`Klar.Recurrence`), with no paging; there is no `sendUpdates`, `freebusy`,
`colors` or `settings` resource. Besides the API: `POST /auth/register`,
`POST /auth/login`, `POST /auth/logout`, `GET /auth/me`, `GET /api/users` (the
people one can share with), `GET /config.json`, and `POST /api/import/google`
(a calendar and the raw `items` of Google's `events.list`).

## The code

| File | |
| --- | --- |
| `src/Main.elm` | the application: signing in, the pages, the dialogs, the import |
| `src/Grid.elm` | the day, week, month and agenda views |
| `src/Occurrence.elm` | series to dates (with `Klar.Recurrence`), the layout of overlapping events |
| `src/Gcal.elm` | the Google Calendar resources: types, decoders, encoders, colors |
| `src/Ics.elm` | reading and writing iCalendar (RFC 5545) |
| `src/Api.elm` | the requests, here and to Google |
| `server/server.mjs`, `server/time.mjs` | the server and its time zone arithmetic |
| `samples/` | an invitation and a calendar export to try the import with |

`Grid.elm` draws the time grid with inline styles on Klar's tokens: Klar has no
week view with events placed by the hour (`KLAR GAP` in the module).
