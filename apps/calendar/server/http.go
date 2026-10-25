package main

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"net/url"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

type apiProblem struct {
	code            int
	reason, message string
}

func (e *apiProblem) Error() string                   { return e.message }
func apiError(code int, reason, message string) error { return &apiProblem{code, reason, message} }
func sendError(w http.ResponseWriter, err error) {
	p := &apiProblem{500, "backendError", "Internal error"}
	if !errors.As(err, &p) {
		log.Printf("calendar: %v", err)
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(p.code)
	json.NewEncoder(w).Encode(object{"error": object{"code": p.code, "message": p.message, "errors": []object{{"domain": "global", "reason": p.reason, "message": p.message}}}})
}

type application struct {
	store                          *store
	assets, prefix, googleClientID string
	demo                           bool
}

type request struct {
	d       *state
	u       *user
	r       *http.Request
	parts   []string
	body    object
	changed bool
	cookie  *http.Cookie
}

func (a *application) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	path := r.URL.EscapedPath()
	if a.prefix != "" {
		if path == a.prefix {
			http.Redirect(w, r, a.prefix+"/", http.StatusFound)
			return
		}
		if !strings.HasPrefix(path, a.prefix+"/") {
			sendError(w, apiError(404, "notFound", "Not Found"))
			return
		}
		path = strings.TrimPrefix(path, a.prefix)
	}
	if r.Method == "GET" && path == "/favicon.ico" {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method == "GET" && (path == "/" || path == "/index.html" || path == "/main.js") {
		file := "index.html"
		if path == "/main.js" {
			file = "main.js"
		}
		w.Header().Set("Cache-Control", "no-cache")
		http.ServeFile(w, r, filepath.Join(a.assets, file))
		return
	}
	parts := strings.Split(strings.TrimPrefix(path, "/"), "/")
	for i, p := range parts {
		decoded, err := url.PathUnescape(p)
		if err != nil {
			sendError(w, apiError(400, "invalid", "Invalid path."))
			return
		}
		parts[i] = decoded
	}
	q := &request{r: r, parts: parts, body: object{}}
	if r.Method == "POST" || r.Method == "PUT" || r.Method == "PATCH" {
		raw, readErr := io.ReadAll(http.MaxBytesReader(w, r.Body, 50*1024*1024))
		if readErr != nil {
			var tooLarge *http.MaxBytesError
			if errors.As(readErr, &tooLarge) {
				sendError(w, apiError(413, "tooLarge", "The request is too large."))
			} else {
				sendError(w, readErr)
			}
			return
		}
		if len(raw) > 0 {
			if err := json.Unmarshal(raw, &q.body); err != nil || q.body == nil {
				sendError(w, apiError(400, "parseError", "Parse Error"))
				return
			}
		}
	}
	tx, err := a.store.db.Begin()
	if err != nil {
		sendError(w, err)
		return
	}
	defer tx.Rollback()
	d, err := loadState(tx)
	if err != nil {
		sendError(w, err)
		return
	}
	q.d = d
	if cookie, err := r.Cookie("calendar_session"); err == nil {
		q.u = d.findUser(d.Sessions[cookie.Value])
	}
	public := path == "/config.json" || path == "/healthz" || path == "/auth/login" || path == "/auth/register" || path == "/auth/demo" || path == "/auth/logout"
	if !public && q.u == nil {
		sendError(w, apiError(401, "authError", "Sign in first."))
		return
	}
	result, err := a.route(q)
	if err == nil && q.changed {
		err = saveState(tx, d)
	}
	if err == nil {
		err = tx.Commit()
	}
	if err != nil {
		sendError(w, err)
		return
	}
	if q.cookie != nil {
		http.SetCookie(w, q.cookie)
	}
	w.Header().Set("Cache-Control", "no-store")
	if result == nil {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	json.NewEncoder(w).Encode(result)
}

func (a *application) session(q *request, u *user) {
	token := newID() + newID()
	q.d.Sessions[token] = u.Email
	q.changed = true
	q.cookie = &http.Cookie{Name: "calendar_session", Value: token, Path: a.prefix + "/", HttpOnly: true, SameSite: http.SameSiteLaxMode, MaxAge: 2592000}
}
func requireRole(c *calendar, u *user, minimum string) (string, error) {
	if c == nil {
		return "", apiError(404, "notFound", "Not Found")
	}
	role := roleOf(c, u)
	if roleRank[role] < roleRank[minimum] {
		if roleRank[role] == 0 {
			return "", apiError(404, "notFound", "Not Found")
		}
		return "", apiError(403, "forbidden", "Forbidden")
	}
	return role, nil
}

var emailPattern = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)
var shareEmailPattern = regexp.MustCompile(`^[^@\s]+@[^@\s]+$`)

func (a *application) route(q *request) (any, error) {
	p, m, b, d, u := q.parts, q.r.Method, q.body, q.d, q.u
	if len(p) == 1 && p[0] == "healthz" && m == "GET" {
		return object{"ok": true}, nil
	}
	if len(p) == 1 && p[0] == "config.json" && m == "GET" {
		people := []object{}
		if a.demo {
			for _, person := range d.Users {
				if strings.HasSuffix(person.Email, "@example.com") {
					people = append(people, publicUser(person))
				}
			}
		}
		return object{"googleClientId": a.googleClientID, "demo": people}, nil
	}
	if len(p) == 2 && p[0] == "auth" {
		switch {
		case p[1] == "demo" && m == "POST":
			person := d.findUser(str(b["email"]))
			if !a.demo || person == nil || !strings.HasSuffix(person.Email, "@example.com") {
				return nil, apiError(404, "notFound", "Not Found")
			}
			a.session(q, person)
			return publicUser(person), nil
		case p[1] == "register" && m == "POST":
			if strings.TrimSpace(str(b["name"])) == "" {
				return nil, apiError(400, "invalid", "Write your name.")
			}
			if !emailPattern.MatchString(strings.TrimSpace(str(b["email"]))) {
				return nil, apiError(400, "invalid", "Write a valid email address.")
			}
			if len([]rune(str(b["password"]))) < 8 {
				return nil, apiError(400, "invalid", "The password needs at least 8 characters.")
			}
			if d.findUser(str(b["email"])) != nil {
				return nil, apiError(409, "duplicate", "Someone is already registered with that email address.")
			}
			person, err := d.createUser(str(b["name"]), str(b["email"]), str(b["password"]), str(b["timeZone"]))
			if err != nil {
				return nil, err
			}
			a.session(q, person)
			return publicUser(person), nil
		case p[1] == "login" && m == "POST":
			person := d.findUser(str(b["email"]))
			if person == nil || !passwordMatches(person, str(b["password"])) {
				return nil, apiError(401, "authError", "The email address or the password is wrong.")
			}
			a.session(q, person)
			return publicUser(person), nil
		case p[1] == "logout" && m == "POST":
			if cookie, err := q.r.Cookie("calendar_session"); err == nil {
				delete(d.Sessions, cookie.Value)
			}
			q.changed = true
			q.cookie = &http.Cookie{Name: "calendar_session", Path: a.prefix + "/", HttpOnly: true, SameSite: http.SameSiteLaxMode, MaxAge: -1}
			return object{}, nil
		case p[1] == "me" && m == "GET":
			return publicUser(u), nil
		}
	}
	if len(p) == 2 && p[0] == "api" && p[1] == "users" && m == "GET" {
		people := []object{}
		for _, person := range d.Users {
			people = append(people, publicUser(person))
		}
		return object{"items": people}, nil
	}
	if len(p) == 3 && p[0] == "api" && p[1] == "import" && p[2] == "google" && m == "POST" {
		var c *calendar
		if id := str(b["calendarId"]); id != "" {
			c = d.Calendars[resolveID(u, id)]
			if _, err := requireRole(c, u, "writer"); err != nil {
				return nil, err
			}
		} else {
			source := obj(b["calendar"])
			c = d.createCalendar(u, object{"summary": source["summary"], "description": source["description"], "timeZone": source["timeZone"]})
			d.listEntry(c, u)
			for _, key := range []string{"backgroundColor", "foregroundColor"} {
				if str(source[key]) != "" {
					d.prefsOf(u)[c.ID][key] = source[key]
				}
			}
		}
		imported, skipped := d.importGoogle(c, u, objects(b["items"]))
		q.changed = true
		return object{"calendarId": c.ID, "summary": c.Summary, "imported": imported, "skipped": skipped}, nil
	}
	if len(p) >= 5 && strings.Join(p[:5], "/") == "calendar/v3/users/me/calendarList" {
		if len(p) == 5 {
			switch m {
			case "GET":
				items := []object{}
				prefs := d.prefsOf(u)
				for _, c := range sortedCalendars(d) {
					if roleRank[roleOf(c, u)] < 1 || (q.r.URL.Query().Get("showHidden") != "true" && prefs[c.ID]["hidden"] == true) {
						continue
					}
					items = append(items, d.listEntry(c, u))
				}
				sort.SliceStable(items, func(i, j int) bool {
					if (items[i]["primary"] == true) != (items[j]["primary"] == true) {
						return items[i]["primary"] == true
					}
					ri, rj := roleRank[str(items[i]["accessRole"])], roleRank[str(items[j]["accessRole"])]
					if ri != rj {
						return ri > rj
					}
					return str(items[i]["summary"]) < str(items[j]["summary"])
				})
				q.changed = true
				return object{"kind": "calendar#calendarList", "etag": etag(), "items": items}, nil
			case "POST":
				c := d.Calendars[str(b["id"])]
				if _, err := requireRole(c, u, "freeBusyReader"); err != nil {
					return nil, err
				}
				d.listEntry(c, u)
				prefs := d.prefsOf(u)[c.ID]
				prefs["hidden"] = false
				if str(b["backgroundColor"]) != "" {
					prefs["backgroundColor"] = b["backgroundColor"]
				}
				q.changed = true
				return d.listEntry(c, u), nil
			}
		}
		if len(p) == 6 {
			c := d.Calendars[resolveID(u, p[5])]
			if _, err := requireRole(c, u, "freeBusyReader"); err != nil {
				return nil, err
			}
			d.listEntry(c, u)
			prefs := d.prefsOf(u)[c.ID]
			switch m {
			case "PUT", "PATCH":
				if selected, ok := b["selected"].(bool); ok {
					prefs["selected"] = selected
				}
				if color := number(b["colorId"]); color >= 1 && color <= len(calendarColors) {
					prefs["colorId"] = str(b["colorId"])
					prefs["backgroundColor"] = calendarColors[color-1]
				}
				for _, key := range []string{"backgroundColor", "foregroundColor"} {
					if str(b[key]) != "" {
						prefs[key] = b[key]
					}
				}
				if value, ok := b["summaryOverride"]; ok {
					if str(value) == "" {
						delete(prefs, "summaryOverride")
					} else {
						prefs["summaryOverride"] = value
					}
				}
				q.changed = true
				return d.listEntry(c, u), nil
			case "DELETE":
				if c.ID == u.Email {
					return nil, apiError(400, "invalid", "The primary calendar cannot be removed from the list.")
				}
				prefs["hidden"] = true
				q.changed = true
				return nil, nil
			}
		}
	}
	if len(p) >= 3 && strings.Join(p[:3], "/") == "calendar/v3/calendars" {
		if len(p) == 3 && m == "POST" {
			if strings.TrimSpace(str(b["summary"])) == "" {
				return nil, apiError(400, "required", "Missing title.")
			}
			if id := str(b["id"]); id != "" && d.Calendars[id] != nil {
				return nil, apiError(409, "duplicate", "Calendar already exists.")
			}
			c := d.createCalendar(u, b)
			d.listEntry(c, u)
			q.changed = true
			return calendarResource(c), nil
		}
		if len(p) < 4 {
			return nil, apiError(404, "notFound", "Not Found")
		}
		id := resolveID(u, p[3])
		c := d.Calendars[id]
		if len(p) == 4 {
			switch m {
			case "GET":
				if _, err := requireRole(c, u, "freeBusyReader"); err != nil {
					return nil, err
				}
				return calendarResource(c), nil
			case "PUT", "PATCH":
				if _, err := requireRole(c, u, "owner"); err != nil {
					return nil, err
				}
				if title, ok := b["summary"]; ok {
					if strings.TrimSpace(str(title)) == "" {
						return nil, apiError(400, "required", "Missing title.")
					}
					c.Summary = strings.TrimSpace(str(title))
				}
				if desc, ok := b["description"]; ok {
					c.Description = str(desc)
				}
				if zone := zoneOrEmpty(str(b["timeZone"])); zone != "" {
					c.TimeZone = zone
				}
				c.Etag = etag()
				q.changed = true
				return calendarResource(c), nil
			case "DELETE":
				if _, err := requireRole(c, u, "owner"); err != nil {
					return nil, err
				}
				if id == u.Email {
					return nil, apiError(400, "cannotDeletePrimaryCalendar", "The primary calendar cannot be deleted.")
				}
				delete(d.Calendars, id)
				for _, prefs := range d.Prefs {
					delete(prefs, id)
				}
				q.changed = true
				return nil, nil
			}
		}
		if len(p) >= 5 && p[4] == "acl" {
			return a.acl(q, c)
		}
		if len(p) >= 5 && p[4] == "events" {
			return a.events(q, id, c)
		}
	}
	return nil, apiError(404, "notFound", "Not Found")
}

func (a *application) acl(q *request, c *calendar) (any, error) {
	if _, err := requireRole(c, q.u, "owner"); err != nil {
		return nil, err
	}
	p, b, m := q.parts, q.body, q.r.Method
	if len(p) == 5 && m == "GET" {
		rules := []object{}
		for _, r := range c.ACL {
			rule := copyObject(r)
			rule["kind"] = "calendar#aclRule"
			rule["etag"] = c.Etag
			rules = append(rules, rule)
		}
		return object{"kind": "calendar#acl", "etag": c.Etag, "items": rules}, nil
	}
	if len(p) == 5 && m == "POST" {
		role, scope := str(b["role"]), obj(b["scope"])
		if roleRank[role] < 1 {
			return nil, apiError(400, "invalid", "Invalid role.")
		}
		kind := str(scope["type"])
		if kind != "user" && kind != "default" {
			return nil, apiError(400, "invalid", "Only the scopes user and default are supported.")
		}
		value := strings.ToLower(strings.TrimSpace(str(scope["value"])))
		id := "default"
		normalized := object{"type": kind}
		if kind == "user" {
			if !shareEmailPattern.MatchString(value) {
				return nil, apiError(400, "invalid", "Invalid email address.")
			}
			id = "user:" + value
			normalized["value"] = value
		}
		if id == "user:"+q.u.Email && role != "owner" {
			return nil, apiError(400, "invalid", "You cannot lower your own access.")
		}
		rule := object{"id": id, "role": role, "scope": normalized}
		rules := []object{}
		for _, r := range c.ACL {
			if str(r["id"]) != id {
				rules = append(rules, r)
			}
		}
		c.ACL = append(rules, rule)
		c.Etag = etag()
		q.changed = true
		result := copyObject(rule)
		result["kind"] = "calendar#aclRule"
		result["etag"] = c.Etag
		return result, nil
	}
	if len(p) == 6 && m == "DELETE" {
		id := p[5]
		if id == "user:"+q.u.Email {
			return nil, apiError(400, "invalid", "You cannot remove your own access.")
		}
		rules := []object{}
		found := false
		for _, r := range c.ACL {
			if str(r["id"]) == id {
				found = true
			} else {
				rules = append(rules, r)
			}
		}
		if !found {
			return nil, apiError(404, "notFound", "Not Found")
		}
		c.ACL = rules
		c.Etag = etag()
		q.changed = true
		return nil, nil
	}
	return nil, apiError(404, "notFound", "Not Found")
}

func (a *application) events(q *request, calID string, c *calendar) (any, error) {
	p, b, m, d, u, query := q.parts, q.body, q.r.Method, q.d, q.u, q.r.URL.Query()
	if len(p) == 5 && m == "GET" {
		role, err := requireRole(c, u, "freeBusyReader")
		if err != nil {
			return nil, err
		}
		zone := first(query.Get("timeZone"), c.TimeZone)
		asTime := func(key string) *time.Time {
			if instant, ok := parseDateTime(query.Get(key), "UTC"); ok {
				return &instant
			}
			return nil
		}
		min, max := asTime("timeMin"), asTime("timeMax")
		keep := func(ev object, cal *calendar) bool {
			term := query.Get("q")
			if role == "freeBusyReader" {
				term = ""
			}
			return (query.Get("showDeleted") == "true" || str(ev["status"]) != "cancelled") && overlaps(ev, cal, min, max) && (query.Get("iCalUID") == "" || str(ev["iCalUID"]) == query.Get("iCalUID")) && textMatches(ev, term)
		}
		items := []object{}
		for _, ev := range c.Events {
			if keep(ev, c) {
				items = append(items, viewEvent(ev, c, u, zone, role))
			}
		}
		if calID == u.Email {
			for _, other := range sortedCalendars(d) {
				if other.ID == calID {
					continue
				}
				for _, ev := range other.Events {
					if isAttendee(ev, u) && keep(ev, other) {
						items = append(items, viewEvent(ev, other, u, zone, "reader"))
					}
				}
			}
		}
		sort.SliceStable(items, func(i, j int) bool {
			ti, _ := moment(obj(items[i]["start"]), zone)
			tj, _ := moment(obj(items[j]["start"]), zone)
			return ti.Before(tj)
		})
		return object{"kind": "calendar#events", "etag": c.Etag, "summary": c.Summary, "description": c.Description, "updated": now(), "timeZone": c.TimeZone, "accessRole": role, "defaultReminders": []any{}, "items": items}, nil
	}
	if (len(p) == 5 || (len(p) == 6 && p[5] == "import")) && m == "POST" {
		if _, err := requireRole(c, u, "writer"); err != nil {
			return nil, err
		}
		body := copyObject(b)
		var ev object
		var err error
		if len(p) == 6 {
			if str(body["iCalUID"]) == "" {
				return nil, apiError(400, "required", "Missing iCalUID.")
			}
			delete(body, "id")
			ev, err = d.upsert(c, u, body)
		} else {
			delete(body, "iCalUID")
			ev, err = d.shapeEvent(c, u, body, nil)
			if err == nil {
				c.Events[str(ev["id"])] = ev
			}
		}
		if err != nil {
			return nil, err
		}
		q.changed = true
		return viewEvent(ev, c, u, query.Get("timeZone"), "writer"), nil
	}
	if len(p) == 6 {
		found, err := d.locate(u, calID, p[5])
		if err != nil {
			return nil, err
		}
		switch m {
		case "GET":
			role := found.role
			if role == "attendee" {
				role = "reader"
			}
			return viewEvent(found.event, found.cal, u, query.Get("timeZone"), role), nil
		case "PATCH", "PUT":
			var ev object
			if roleRank[found.role] >= 3 {
				existing := found.event
				if m == "PUT" {
					fixed := object{}
					for _, key := range []string{"id", "iCalUID", "created", "creator", "organizer", "kind", "sequence"} {
						if value, ok := existing[key]; ok {
							fixed[key] = value
						}
					}
					existing = fixed
				}
				ev, err = d.shapeEvent(found.cal, u, b, existing)
				if err != nil {
					return nil, err
				}
			} else if found.invited || isAttendee(found.event, u) {
				var mine object
				for _, person := range objects(b["attendees"]) {
					if strings.ToLower(str(person["email"])) == u.Email {
						mine = person
						break
					}
				}
				if mine == nil {
					return nil, apiError(403, "forbidden", "Only the organizer can change this event.")
				}
				response := str(mine["responseStatus"])
				if response != "accepted" && response != "tentative" && response != "declined" && response != "needsAction" {
					return nil, apiError(400, "invalid", "Invalid response.")
				}
				ev = copyObject(found.event)
				people := []object{}
				for _, person := range objects(ev["attendees"]) {
					person = copyObject(person)
					if str(person["email"]) == u.Email {
						person["responseStatus"] = response
						if comment, ok := mine["comment"]; ok {
							person["comment"] = comment
						} else {
							delete(person, "comment")
						}
					}
					people = append(people, person)
				}
				ev["attendees"] = people
				ev["updated"] = now()
				ev["etag"] = etag()
			} else {
				return nil, apiError(403, "forbidden", "Forbidden")
			}
			found.cal.Events[str(ev["id"])] = ev
			q.changed = true
			return viewEvent(ev, found.cal, u, query.Get("timeZone"), "writer"), nil
		case "DELETE":
			if roleRank[found.role] >= 3 && !found.invited {
				delete(found.cal.Events, str(found.event["id"]))
			} else if isAttendee(found.event, u) {
				people := []object{}
				for _, person := range objects(found.event["attendees"]) {
					person = copyObject(person)
					if str(person["email"]) == u.Email {
						person["responseStatus"] = "declined"
					}
					people = append(people, person)
				}
				found.event["attendees"] = people
				found.event["updated"] = now()
			} else {
				return nil, apiError(403, "forbidden", "Forbidden")
			}
			q.changed = true
			return nil, nil
		}
	}
	return nil, apiError(404, "notFound", "Not Found")
}
