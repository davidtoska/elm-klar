package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
)

type testHost struct {
	t      *testing.T
	server *httptest.Server
	app    *application
	prefix string
}

func host(t *testing.T, file, prefix string, demo bool, legacy string) *testHost {
	t.Helper()
	s, err := openStore(file)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { s.db.Close() })
	if err = s.initialize(legacy, demo); err != nil {
		t.Fatal(err)
	}
	app := &application{store: s, prefix: prefix, demo: demo, assets: t.TempDir()}
	server := httptest.NewServer(app)
	t.Cleanup(server.Close)
	return &testHost{t, server, app, prefix}
}
func (h *testHost) call(method, path, cookie string, body any, status int) (object, *http.Response) {
	h.t.Helper()
	var data io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			h.t.Fatal(err)
		}
		data = bytes.NewReader(raw)
	}
	req, err := http.NewRequest(method, h.server.URL+h.prefix+path, data)
	if err != nil {
		h.t.Fatal(err)
	}
	if cookie != "" {
		req.Header.Set("Cookie", cookie)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	response, err := http.DefaultClient.Do(req)
	if err != nil {
		h.t.Fatal(err)
	}
	defer response.Body.Close()
	raw, err := io.ReadAll(response.Body)
	if err != nil {
		h.t.Fatal(err)
	}
	if response.StatusCode != status {
		h.t.Fatalf("%s %s: got %d, want %d: %s", method, path, response.StatusCode, status, raw)
	}
	result := object{}
	if len(raw) > 0 {
		if err = json.Unmarshal(raw, &result); err != nil {
			h.t.Fatalf("invalid JSON: %s: %v", raw, err)
		}
	}
	return result, response
}
func (h *testHost) login(email string) string {
	h.t.Helper()
	_, r := h.call("POST", "/auth/demo", "", object{"email": email}, 200)
	return strings.Split(r.Header.Get("Set-Cookie"), ";")[0]
}
func eventBody(summary string) object {
	return object{"summary": summary, "start": object{"date": "2026-10-25"}, "end": object{"date": "2026-10-26"}}
}
func primaryEvents() string { return "/calendar/v3/calendars/primary/events" }
func check(t *testing.T, ok bool, message string) {
	t.Helper()
	if !ok {
		t.Fatal(message)
	}
}

func TestMountedDemoPersistenceAndIsolation(t *testing.T) {
	file := filepath.Join(t.TempDir(), "showcase.sqlite")
	h := host(t, file, "/calendar-app", true, "")
	config, _ := h.call("GET", "/config.json", "", nil, 200)
	check(t, len(objects(config["demo"])) == 3, "three demo identities")
	h.call("GET", "/calendar/v3/users/me/calendarList", "", nil, 401)
	_, login := h.call("POST", "/auth/demo", "", object{"email": "ada@example.com"}, 200)
	cookie := strings.Split(login.Header.Get("Set-Cookie"), ";")[0]
	check(t, strings.Contains(login.Header.Get("Set-Cookie"), "Path=/calendar-app/") && strings.Contains(login.Header.Get("Set-Cookie"), "HttpOnly"), "mounted cookie scope")
	calendars, _ := h.call("GET", "/calendar/v3/users/me/calendarList", cookie, nil, 200)
	found := false
	for _, c := range objects(calendars["items"]) {
		if str(c["summary"]) == "Warehouse team" {
			found = true
		}
	}
	check(t, found, "seeded team calendar")
	ev, _ := h.call("POST", primaryEvents(), cookie, eventBody("Persistent meeting"), 200)
	reopened := host(t, file, "/calendar-app", true, "")
	restored, _ := reopened.call("GET", primaryEvents()+"/"+str(ev["id"]), cookie, nil, 200)
	check(t, str(restored["summary"]) == "Persistent meeting", "event and session survive reopening")
	isolated := host(t, filepath.Join(t.TempDir(), "standalone.sqlite"), "", true, "")
	isolated.call("GET", "/auth/me", cookie, nil, 401)
	_, logout := h.call("POST", "/auth/logout", cookie, object{}, 200)
	check(t, strings.Contains(logout.Header.Get("Set-Cookie"), "Max-Age=0"), "logout expires scoped cookie")
	reopened.call("GET", "/auth/me", cookie, nil, 401)
	var count int
	if err := h.app.store.db.QueryRow("SELECT COUNT(*) FROM events WHERE id=?", str(ev["id"])).Scan(&count); err != nil {
		t.Fatal(err)
	}
	check(t, count == 1, "events are separately keyed in SQLite")
}

func TestRegistrationAndPasswords(t *testing.T) {
	h := host(t, filepath.Join(t.TempDir(), "auth.sqlite"), "", false, "")
	h.call("POST", "/auth/demo", "", object{"email": "ada@example.com"}, 404)
	h.call("POST", "/auth/register", "", object{"name": "Pat", "email": "pat@example.com", "password": "short"}, 400)
	person, response := h.call("POST", "/auth/register", "", object{"name": " Pat ", "email": "PAT@example.com", "password": "calendar123", "timeZone": "W. Europe Standard Time"}, 200)
	check(t, str(person["email"]) == "pat@example.com" && len(person) == 2, "registration returns public identity only")
	cookie := strings.Split(response.Header.Get("Set-Cookie"), ";")[0]
	list, _ := h.call("GET", "/calendar/v3/users/me/calendarList", cookie, nil, 200)
	check(t, len(objects(list["items"])) == 1, "registration creates primary calendar")
	h.call("POST", "/auth/register", "", object{"name": "Pat", "email": "pat@example.com", "password": "calendar123"}, 409)
	h.call("POST", "/auth/login", "", object{"email": "pat@example.com", "password": "wrong"}, 401)
	h.call("POST", "/auth/login", "", object{"email": "PAT@example.com", "password": "calendar123"}, 200)
	state, err := h.app.store.load()
	if err != nil {
		t.Fatal(err)
	}
	check(t, state.Users[0].TimeZone == "Europe/Berlin", "Windows time zone normalizes")
}

func TestCalendarPermissionsAndPreferences(t *testing.T) {
	h := host(t, filepath.Join(t.TempDir(), "sharing.sqlite"), "", true, "")
	ada, bob, cleo := h.login("ada@example.com"), h.login("bob@example.com"), h.login("cleo@example.com")
	cal, _ := h.call("POST", "/calendar/v3/calendars", ada, object{"summary": "Private calendar", "timeZone": "Europe/Oslo"}, 200)
	base := "/calendar/v3/calendars/" + str(cal["id"])
	h.call("GET", base, bob, nil, 404)
	for _, share := range []struct{ email, role string }{{"bob@example.com", "writer"}, {"cleo@example.com", "reader"}} {
		h.call("POST", base+"/acl", ada, object{"role": share.role, "scope": object{"type": "user", "value": share.email}}, 200)
	}
	h.call("POST", base+"/events", bob, eventBody("Writer meeting"), 200)
	h.call("POST", base+"/events", cleo, eventBody("Reader cannot write"), 403)
	h.call("PATCH", base, bob, object{"summary": "Not owner"}, 403)
	h.call("POST", base+"/acl", ada, object{"role": "reader", "scope": object{"type": "user", "value": "ada@example.com"}}, 400)
	h.call("DELETE", base+"/acl/user:ada@example.com", ada, nil, 400)
	listPath := "/calendar/v3/users/me/calendarList/" + str(cal["id"])
	h.call("PATCH", listPath, bob, object{"selected": false, "colorId": "3", "summaryOverride": "My title"}, 200)
	list, _ := h.call("GET", "/calendar/v3/users/me/calendarList", ada, nil, 200)
	for _, entry := range objects(list["items"]) {
		if str(entry["id"]) == str(cal["id"]) {
			_, overridden := entry["summaryOverride"]
			check(t, !overridden, "preferences are per user")
		}
	}
	h.call("DELETE", listPath, bob, nil, 204)
	hidden, _ := h.call("GET", "/calendar/v3/users/me/calendarList?showHidden=true", bob, nil, 200)
	visible, _ := h.call("GET", "/calendar/v3/users/me/calendarList", bob, nil, 200)
	check(t, len(objects(hidden["items"])) == len(objects(visible["items"]))+1, "unsubscribe hides only from list")
	h.call("POST", "/calendar/v3/users/me/calendarList", bob, object{"id": cal["id"]}, 200)
	h.call("DELETE", base+"/acl/user:bob@example.com", ada, nil, 204)
	h.call("GET", base, bob, nil, 404)
	h.call("POST", "/calendar/v3/calendars", bob, object{"id": "ada@example.com", "summary": "Cannot replace someone else's calendar"}, 409)
	h.call("DELETE", "/calendar/v3/calendars/primary", ada, nil, 400)
	h.call("DELETE", base, ada, nil, 204)
	h.call("GET", base, ada, nil, 404)
}

func TestFreeBusyAndGuestReplies(t *testing.T) {
	h := host(t, filepath.Join(t.TempDir(), "guests.sqlite"), "", true, "")
	ada, bob := h.login("ada@example.com"), h.login("bob@example.com")
	busy, _ := h.call("GET", "/calendar/v3/calendars/bob@example.com/events?q=secret", ada, nil, 200)
	check(t, len(objects(busy["items"])) > 0, "search does not disclose matching secret text in free/busy view")
	for _, ev := range objects(busy["items"]) {
		_, title := ev["summary"]
		_, guests := ev["attendees"]
		check(t, !title && !guests, "busy-only view redacts details")
	}
	body := eventBody("Organizer title")
	body["attendees"] = []object{{"email": "bob@example.com"}}
	ev, _ := h.call("POST", primaryEvents(), ada, body, 200)
	path := primaryEvents() + "/" + str(ev["id"])
	guest, _ := h.call("GET", path, bob, nil, 200)
	check(t, str(guest["summary"]) == "Organizer title", "invitation reachable in guest primary calendar")
	h.call("PATCH", path, bob, object{"summary": "Cannot edit without RSVP"}, 403)
	h.call("PATCH", path, bob, object{"summary": "Malicious overwrite", "attendees": []object{{"email": "bob@example.com", "responseStatus": "accepted"}}}, 200)
	organizer, _ := h.call("GET", path, ada, nil, 200)
	check(t, str(organizer["summary"]) == "Organizer title", "guest edits cannot change organizer content")
	h.call("DELETE", path, bob, nil, 204)
	organizer, _ = h.call("GET", path, ada, nil, 200)
	declined := false
	for _, p := range objects(organizer["attendees"]) {
		if str(p["email"]) == "bob@example.com" {
			declined = str(p["responseStatus"]) == "declined"
		}
	}
	check(t, declined, "guest delete declines; organizer event stays")
}

func TestEventValidationPutAndQueries(t *testing.T) {
	h := host(t, filepath.Join(t.TempDir(), "events.sqlite"), "", true, "")
	cookie := h.login("ada@example.com")
	h.call("POST", primaryEvents(), cookie, object{}, 400)
	bad := eventBody("Bad date")
	bad["start"] = object{"date": "2026-02-30"}
	h.call("POST", primaryEvents(), cookie, bad, 400)
	bad = eventBody("Mixed")
	bad["end"] = object{"dateTime": "2026-10-26T12:00:00Z"}
	h.call("POST", primaryEvents(), cookie, bad, 400)
	bad = eventBody("Empty")
	bad["end"] = bad["start"]
	h.call("POST", primaryEvents(), cookie, bad, 400)
	body := eventBody("Find unique request")
	body["extendedProperties"] = object{"private": object{"custom": "preserved"}}
	ev, _ := h.call("POST", primaryEvents(), cookie, body, 200)
	path := primaryEvents() + "/" + str(ev["id"])
	patched, _ := h.call("PATCH", path, cookie, object{"id": "cannot-change", "location": "Dock"}, 200)
	check(t, str(patched["id"]) == str(ev["id"]), "event id remains immutable")
	check(t, str(obj(obj(patched["extendedProperties"])["private"])["custom"]) == "preserved", "unknown Google fields survive")
	query, _ := h.call("GET", primaryEvents()+"?q=unique%20request&timeMin=2026-10-25T00:00:00Z&timeMax=2026-10-26T00:00:00Z", cookie, nil, 200)
	check(t, len(objects(query["items"])) == 1, "event search and overlap filters")
	put, _ := h.call("PUT", path, cookie, eventBody("Replacement"), 200)
	_, custom := put["extendedProperties"]
	check(t, !custom && str(put["iCalUID"]) == str(ev["iCalUID"]), "PUT replaces mutable fields but keeps identity")
	h.call("DELETE", path, cookie, nil, 204)
	h.call("GET", path, cookie, nil, 404)
}

func TestImportsRetainIdentityAndRecurringExceptions(t *testing.T) {
	h := host(t, filepath.Join(t.TempDir(), "import.sqlite"), "", true, "")
	cookie := h.login("ada@example.com")
	body := eventBody("Imported appointment")
	body["iCalUID"] = "external-uid"
	ev, _ := h.call("POST", primaryEvents()+"/import", cookie, body, 200)
	body["summary"] = "Updated import"
	second, _ := h.call("POST", primaryEvents()+"/import", cookie, body, 200)
	check(t, str(ev["id"]) == str(second["id"]), "repeated import updates instead of duplicating")
	master := object{"id": "google-master", "iCalUID": "series-uid", "summary": "Recurring", "start": object{"dateTime": "2026-10-20T09:00:00", "timeZone": "Europe/Oslo"}, "end": object{"dateTime": "2026-10-20T10:00:00", "timeZone": "Europe/Oslo"}, "recurrence": []string{"RRULE:FREQ=DAILY"}}
	changed := object{"id": "changed-instance", "iCalUID": "series-uid", "recurringEventId": "google-master", "originalStartTime": object{"dateTime": "2026-10-21T09:00:00+02:00"}, "summary": "Moved occurrence", "start": object{"dateTime": "2026-10-21T11:00:00+02:00"}, "end": object{"dateTime": "2026-10-21T12:00:00+02:00"}}
	cancelled := object{"id": "cancelled-instance", "recurringEventId": "google-master", "status": "cancelled", "originalStartTime": object{"dateTime": "2026-10-22T09:00:00+02:00"}}
	result, _ := h.call("POST", "/api/import/google", cookie, object{"calendar": object{"summary": "Google import", "timeZone": "Europe/Oslo"}, "items": []object{master, changed, cancelled, {"status": "cancelled"}, {"summary": "Invalid item"}}}, 200)
	check(t, number(result["imported"]) == 2 && number(result["skipped"]) == 2, "import counts distinguish skipped masters and cancelled instances")
	path := "/calendar/v3/calendars/" + str(result["calendarId"]) + "/events"
	list, _ := h.call("GET", path, cookie, nil, 200)
	check(t, len(objects(list["items"])) == 2, "series plus changed standalone occurrence")
	for _, item := range objects(list["items"]) {
		if str(item["summary"]) == "Recurring" {
			rules := strings.Join(stringsOf(item["recurrence"]), "\n")
			check(t, strings.Contains(rules, "20261021T090000") && strings.Contains(rules, "20261022T090000"), "exception dates retain Oslo wall time")
		}
	}
	h.call("POST", "/api/import/google", cookie, object{"calendarId": result["calendarId"], "items": []object{master, changed, cancelled}}, 200)
	list, _ = h.call("GET", path, cookie, nil, 200)
	check(t, len(objects(list["items"])) == 2, "reimport does not duplicate exception event")
}

func TestDatabaseFailureRollsBackAndConcurrentWrites(t *testing.T) {
	file := filepath.Join(t.TempDir(), "atomic.sqlite")
	h := host(t, file, "", true, "")
	cookie := h.login("ada@example.com")
	if _, err := h.app.store.db.Exec("CREATE TRIGGER reject_events BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'injected storage failure'); END"); err != nil {
		t.Fatal(err)
	}
	h.call("POST", primaryEvents(), cookie, eventBody("Must not survive"), 500)
	if _, err := h.app.store.db.Exec("DROP TRIGGER reject_events"); err != nil {
		t.Fatal(err)
	}
	list, _ := h.call("GET", primaryEvents()+"?q=Must%20not%20survive", cookie, nil, 200)
	check(t, len(objects(list["items"])) == 0, "failed commit leaves previous persisted state intact")
	other := host(t, file, "", true, "")
	var group sync.WaitGroup
	failures := make(chan error, 12)
	for i := 0; i < 12; i++ {
		group.Add(1)
		go func(i int) {
			defer group.Done()
			base := h.server.URL
			if i%2 == 1 {
				base = other.server.URL
			}
			raw, err := json.Marshal(eventBody(fmt.Sprintf("Concurrent %d", i)))
			if err != nil {
				failures <- err
				return
			}
			req, err := http.NewRequest("POST", base+primaryEvents(), bytes.NewReader(raw))
			if err != nil {
				failures <- err
				return
			}
			req.Header.Set("Cookie", cookie)
			response, err := http.DefaultClient.Do(req)
			if err != nil {
				failures <- err
				return
			}
			defer response.Body.Close()
			io.Copy(io.Discard, response.Body)
			if response.StatusCode != 200 {
				failures <- fmt.Errorf("concurrent write: %s", response.Status)
			}
		}(i)
	}
	group.Wait()
	close(failures)
	for err := range failures {
		t.Error(err)
	}
	list, _ = h.call("GET", primaryEvents()+"?q=Concurrent", cookie, nil, 200)
	check(t, len(objects(list["items"])) == 12, "concurrent requests across database connections do not lose updates")
}

func TestLegacyJSONImportedOnceWithoutChangingSource(t *testing.T) {
	directory := t.TempDir()
	legacy := filepath.Join(directory, "legacy.json")
	file := filepath.Join(directory, "calendar.sqlite")
	d := emptyState()
	u := &user{Name: "Legacy user", Email: "legacy@example.com", Salt: "0123456789abcdef0123456789abcdef", Hash: "5f86b6ca3c5a502dc09c1cbb7bee3b1aa7b3d0b1b67c49f755a5ef1b5dd51961", TimeZone: "Europe/Oslo"}
	d.Users = append(d.Users, u)
	d.Sessions["legacy-session"] = u.Email
	cal := d.createCalendar(u, object{"id": u.Email, "summary": "Migrated"})
	body := eventBody("Legacy event")
	body["iCalUID"] = "preserved-uid"
	ev, err := d.shapeEvent(cal, u, body, nil)
	if err != nil {
		t.Fatal(err)
	}
	cal.Events[str(ev["id"])] = ev
	d.Prefs[u.Email] = map[string]object{u.Email: {"selected": false, "colorId": "3", "backgroundColor": "#f83a22"}}
	raw, err := json.Marshal(d)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(legacy, raw, 0600); err != nil {
		t.Fatal(err)
	}
	h := host(t, file, "", false, legacy)
	h.call("GET", "/auth/me", "calendar_session=legacy-session", nil, 200)
	h.call("POST", "/auth/login", "", object{"email": u.Email, "password": "calendar123"}, 200)
	path := primaryEvents() + "/" + str(ev["id"])
	h.call("PATCH", path, "calendar_session=legacy-session", object{"summary": "Changed after migration"}, 200)
	reopened := host(t, file, "", true, legacy)
	value, _ := reopened.call("GET", path, "calendar_session=legacy-session", nil, 200)
	check(t, str(value["summary"]) == "Changed after migration", "legacy data is not reapplied over SQLite changes")
	unchanged, err := os.ReadFile(legacy)
	if err != nil {
		t.Fatal(err)
	}
	check(t, bytes.Equal(raw, unchanged), "legacy source remains a byte-identical backup")
}

func TestInvalidLegacyStoreFailsWithoutSeeding(t *testing.T) {
	directory := t.TempDir()
	legacy := filepath.Join(directory, "broken.json")
	if err := os.WriteFile(legacy, []byte("{broken"), 0600); err != nil {
		t.Fatal(err)
	}
	s, err := openStore(filepath.Join(directory, "calendar.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	defer s.db.Close()
	check(t, s.initialize(legacy, true) != nil, "corrupt data must not be replaced with demos")
	ready, err := s.initialized()
	if err != nil {
		t.Fatal(err)
	}
	check(t, !ready, "failed migration leaves initialization retryable")
}

func TestDemoCanSeedAnEmptyLegacyStore(t *testing.T) {
	directory := t.TempDir()
	legacy := filepath.Join(directory, "empty.json")
	if err := os.WriteFile(legacy, []byte(`{"users":[],"sessions":{},"calendars":{},"prefs":{}}`), 0600); err != nil {
		t.Fatal(err)
	}
	h := host(t, filepath.Join(directory, "demo.sqlite"), "", true, legacy)
	config, _ := h.call("GET", "/config.json", "", nil, 200)
	check(t, len(objects(config["demo"])) == 3, "explicit demo mode seeds a wholly empty legacy store")
}
