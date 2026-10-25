package main

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	"golang.org/x/crypto/scrypt"
)

func str(value any) string {
	if value == nil {
		return ""
	}
	if s, ok := value.(string); ok {
		return s
	}
	return fmt.Sprint(value)
}
func obj(value any) object {
	if result, ok := value.(map[string]any); ok && result != nil {
		return result
	}
	return object{}
}
func objects(value any) []object {
	if list, ok := value.([]object); ok {
		return list
	}
	result := []object{}
	if list, ok := value.([]any); ok {
		for _, item := range list {
			if o, ok := item.(map[string]any); ok {
				result = append(result, o)
			}
		}
	}
	return result
}
func stringsOf(value any) []string {
	if value == nil {
		return nil
	}
	if list, ok := value.([]string); ok {
		return list
	}
	result := []string{}
	if list, ok := value.([]any); ok {
		for _, item := range list {
			result = append(result, str(item))
		}
		return result
	}
	return []string{str(value)}
}
func copyObject(value object) object {
	result := object{}
	for key, item := range value {
		result[key] = item
	}
	return result
}
func first(values ...string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return ""
}
func number(value any) int { n, _ := strconv.ParseFloat(str(value), 64); return int(n) }
func newID() string {
	var value [12]byte
	if _, err := rand.Read(value[:]); err != nil {
		panic(err)
	}
	return hex.EncodeToString(value[:])
}
func now() string               { return time.Now().UTC().Format("2006-01-02T15:04:05.000Z") }
func etag() string              { return `"` + newID() + `"` }
func publicUser(u *user) object { return object{"name": u.Name, "email": u.Email} }
func (d *state) findUser(email string) *user {
	email = strings.ToLower(strings.TrimSpace(email))
	for _, u := range d.Users {
		if u.Email == email {
			return u
		}
	}
	return nil
}

func passwordHash(password, salt string) (string, error) {
	// Node's former crypto.scryptSync used these defaults and the hex salt as text.
	key, err := scrypt.Key([]byte(password), []byte(salt), 16384, 8, 1, 32)
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(key), nil
}
func passwordMatches(u *user, password string) bool {
	hash, err := passwordHash(password, u.Salt)
	return err == nil && subtle.ConstantTimeCompare([]byte(hash), []byte(u.Hash)) == 1
}
func (d *state) createUser(name, email, password, zone string) (*user, error) {
	u := &user{Name: strings.TrimSpace(name), Email: strings.ToLower(strings.TrimSpace(email)), Salt: newID() + newID()[:8], TimeZone: first(zoneOrEmpty(zone), "UTC")}
	var err error
	u.Hash, err = passwordHash(password, u.Salt)
	if err != nil {
		return nil, err
	}
	d.Users = append(d.Users, u)
	d.createCalendar(u, object{"id": u.Email, "summary": u.Name, "timeZone": u.TimeZone})
	return u, nil
}

var calendarColors = []string{"#ac725e", "#d06b64", "#f83a22", "#fa573c", "#ff7537", "#ffad46", "#42d692", "#16a765", "#7bd148", "#b3dc6c", "#fbe983", "#fad165", "#92e1c0", "#9fe1e7", "#9fc6e7", "#4986e7", "#9a9cff", "#b99aff", "#c2c2c2", "#cabdbf", "#cca6ac", "#f691b2", "#cd74e6", "#a47ae2"}
var defaultColors = []int{16, 8, 24, 5, 3, 14, 23, 10, 12, 1}
var roleRank = map[string]int{"none": 0, "freeBusyReader": 1, "reader": 2, "writer": 3, "owner": 4}

func (d *state) createCalendar(u *user, body object) *calendar {
	c := &calendar{ID: first(str(body["id"]), newID()+"@group.calendar.local"), Etag: etag(), Summary: first(strings.TrimSpace(str(body["summary"])), "Untitled calendar"), Description: str(body["description"]), TimeZone: first(zoneOrEmpty(str(body["timeZone"])), u.TimeZone, "UTC"), ACL: []object{{"id": "user:" + u.Email, "role": "owner", "scope": object{"type": "user", "value": u.Email}}}, Events: map[string]object{}}
	d.Calendars[c.ID] = c
	return c
}
func resolveID(u *user, id string) string {
	if id == "primary" {
		return u.Email
	}
	return id
}
func roleOf(c *calendar, u *user) string {
	best := "none"
	for _, r := range c.ACL {
		scope := obj(r["scope"])
		if (str(scope["type"]) == "user" && str(scope["value"]) == u.Email) || str(scope["type"]) == "default" {
			role := str(r["role"])
			if roleRank[role] > roleRank[best] {
				best = role
			}
		}
	}
	return best
}
func (d *state) prefsOf(u *user) map[string]object {
	if d.Prefs[u.Email] == nil {
		d.Prefs[u.Email] = map[string]object{}
	}
	return d.Prefs[u.Email]
}
func (d *state) listEntry(c *calendar, u *user) object {
	prefs := d.prefsOf(u)
	if prefs[c.ID] == nil {
		color := defaultColors[len(prefs)%len(defaultColors)]
		prefs[c.ID] = object{"selected": true, "colorId": strconv.Itoa(color), "backgroundColor": calendarColors[color-1]}
	}
	p := prefs[c.ID]
	entry := object{"kind": "calendar#calendarListEntry", "etag": c.Etag, "id": c.ID, "summary": c.Summary, "description": c.Description, "timeZone": c.TimeZone, "colorId": p["colorId"], "backgroundColor": p["backgroundColor"], "foregroundColor": first(str(p["foregroundColor"]), "#000000"), "selected": p["selected"] != false, "accessRole": roleOf(c, u), "defaultReminders": []any{}}
	if c.ID == u.Email {
		entry["primary"] = true
	}
	if str(p["summaryOverride"]) != "" {
		entry["summaryOverride"] = p["summaryOverride"]
	}
	return entry
}
func calendarResource(c *calendar) object {
	return object{"kind": "calendar#calendar", "etag": c.Etag, "id": c.ID, "summary": c.Summary, "description": c.Description, "timeZone": c.TimeZone}
}

func normalizeTime(value object, zone, which string) (object, error) {
	if len(value) == 0 {
		return nil, apiError(400, "required", "Missing "+which+" time.")
	}
	if date := str(value["date"]); date != "" {
		if !datePattern.MatchString(date) {
			return nil, apiError(400, "invalid", "Invalid "+which+" date.")
		}
		if _, err := time.Parse("2006-01-02", date); err != nil {
			return nil, apiError(400, "invalid", "Invalid "+which+" date.")
		}
		return object{"date": date}, nil
	}
	own := zoneOrEmpty(str(value["timeZone"]))
	instant, ok := parseDateTime(str(value["dateTime"]), first(own, zone))
	if !ok {
		return nil, apiError(400, "invalid", "Invalid "+which+" time.")
	}
	result := object{"dateTime": formatInZone(instant, first(own, zone))}
	if own != "" {
		result["timeZone"] = own
	}
	return result, nil
}
func (d *state) normalizePerson(value object) object {
	p := copyObject(value)
	p["email"] = strings.ToLower(strings.TrimSpace(str(p["email"])))
	if known := d.findUser(str(p["email"])); known != nil && str(p["displayName"]) == "" {
		p["displayName"] = known.Name
	}
	delete(p, "self")
	return p
}
func (d *state) shapeEvent(c *calendar, u *user, body, existing object) (object, error) {
	ev := copyObject(existing)
	for k, v := range body {
		ev[k] = v
	}
	if existing != nil {
		for _, key := range []string{"id", "etag", "kind", "htmlLink", "created", "creator", "organizer", "self"} {
			if value, ok := existing[key]; ok {
				ev[key] = value
			} else {
				delete(ev, key)
			}
		}
	}
	start, err := normalizeTime(obj(ev["start"]), c.TimeZone, "start")
	if err != nil {
		return nil, err
	}
	end, err := normalizeTime(obj(ev["end"]), c.TimeZone, "end")
	if err != nil {
		return nil, err
	}
	if (str(start["date"]) != "") != (str(end["date"]) != "") {
		return nil, apiError(400, "invalid", "The start and end times must both be dates or both be date-times.")
	}
	s, ok1 := moment(start, c.TimeZone)
	e, ok2 := moment(end, c.TimeZone)
	if !ok1 || !ok2 || !e.After(s) {
		return nil, apiError(400, "timeRangeEmpty", "The specified time range is empty.")
	}
	ev["start"] = start
	ev["end"] = end
	ev["summary"] = str(ev["summary"])
	if status := str(ev["status"]); status != "confirmed" && status != "tentative" && status != "cancelled" {
		ev["status"] = "confirmed"
	}
	if recurrence := stringsOf(ev["recurrence"]); len(recurrence) > 0 {
		ev["recurrence"] = recurrence
	} else {
		delete(ev, "recurrence")
	}
	if existing == nil {
		ev["kind"] = "calendar#event"
		ev["id"] = newID()
		ev["created"] = now()
		ev["creator"] = object{"email": u.Email, "displayName": u.Name}
		if str(obj(ev["organizer"])["email"]) == "" {
			email, name := c.ID, c.Summary
			if c.ID == u.Email {
				email, name = u.Email, u.Name
			}
			ev["organizer"] = object{"email": email, "displayName": name}
		} else {
			ev["organizer"] = d.normalizePerson(obj(ev["organizer"]))
		}
		ev["iCalUID"] = first(str(ev["iCalUID"]), str(ev["id"])+"@calendar.local")
		ev["sequence"] = number(ev["sequence"])
	} else {
		ev["sequence"] = number(existing["sequence"]) + 1
	}
	people := []object{}
	seen := map[string]bool{}
	for _, person := range objects(ev["attendees"]) {
		if str(person["email"]) == "" {
			continue
		}
		p := d.normalizePerson(person)
		email := str(p["email"])
		if seen[email] {
			continue
		}
		seen[email] = true
		p["responseStatus"] = first(str(p["responseStatus"]), "needsAction")
		people = append(people, p)
	}
	if len(people) > 0 {
		organizer := str(obj(ev["organizer"])["email"])
		if known := d.findUser(organizer); known != nil && !seen[organizer] {
			people = append([]object{{"email": organizer, "displayName": known.Name, "organizer": true, "responseStatus": "accepted"}}, people...)
		}
		ev["attendees"] = people
	} else {
		delete(ev, "attendees")
	}
	ev["updated"] = now()
	ev["etag"] = etag()
	return ev, nil
}
func isAttendee(ev object, u *user) bool {
	for _, p := range objects(ev["attendees"]) {
		if str(p["email"]) == u.Email {
			return true
		}
	}
	return false
}
func viewEvent(ev object, c *calendar, u *user, zone, role string) object {
	asTime := func(value any) object {
		result := copyObject(obj(value))
		if tz := zoneOrEmpty(zone); tz != "" && str(result["dateTime"]) != "" {
			instant, _ := moment(result, c.TimeZone)
			result["dateTime"] = formatInZone(instant, tz)
		}
		return result
	}
	if role == "freeBusyReader" {
		result := object{"kind": ev["kind"], "id": ev["id"], "status": ev["status"], "start": asTime(ev["start"]), "end": asTime(ev["end"])}
		if recurrence, ok := ev["recurrence"]; ok {
			result["recurrence"] = recurrence
		}
		return result
	}
	mark := func(value object) object {
		p := copyObject(value)
		if str(p["email"]) == u.Email {
			p["self"] = true
		}
		return p
	}
	result := copyObject(ev)
	result["start"] = asTime(ev["start"])
	result["end"] = asTime(ev["end"])
	for _, key := range []string{"creator", "organizer"} {
		if person, ok := ev[key]; ok {
			result[key] = mark(obj(person))
		}
	}
	if people, ok := ev["attendees"]; ok {
		marked := []object{}
		for _, p := range objects(people) {
			marked = append(marked, mark(p))
		}
		result["attendees"] = marked
	}
	return result
}
func overlaps(ev object, c *calendar, min, max *time.Time) bool {
	s, ok1 := moment(obj(ev["start"]), c.TimeZone)
	e, ok2 := moment(obj(ev["end"]), c.TimeZone)
	if !ok1 || !ok2 {
		return false
	}
	for _, r := range stringsOf(ev["recurrence"]) {
		if strings.HasPrefix(r, "RRULE") {
			return max == nil || s.Before(*max)
		}
	}
	return (max == nil || s.Before(*max)) && (min == nil || e.After(*min))
}
func textMatches(ev object, q string) bool {
	hay := strings.ToLower(str(ev["summary"]) + " " + str(ev["description"]) + " " + str(ev["location"]))
	for _, word := range strings.Fields(strings.ToLower(q)) {
		if !strings.Contains(hay, word) {
			return false
		}
	}
	return true
}

type foundEvent struct {
	cal     *calendar
	event   object
	role    string
	invited bool
}

func (d *state) locate(u *user, calID, eventID string) (foundEvent, error) {
	c := d.Calendars[calID]
	if c == nil {
		return foundEvent{}, apiError(404, "notFound", "Not Found")
	}
	role := roleOf(c, u)
	if ev := c.Events[eventID]; ev != nil && roleRank[role] >= 1 {
		return foundEvent{c, ev, role, false}, nil
	}
	if calID == u.Email {
		for _, other := range sortedCalendars(d) {
			if ev := other.Events[eventID]; ev != nil && isAttendee(ev, u) {
				role := roleOf(other, u)
				if roleRank[role] < 3 {
					role = "attendee"
				}
				return foundEvent{other, ev, role, true}, nil
			}
		}
	}
	return foundEvent{}, apiError(404, "notFound", "Not Found")
}
func sortedCalendars(d *state) []*calendar {
	ids := []string{}
	for id := range d.Calendars {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	result := []*calendar{}
	for _, id := range ids {
		result = append(result, d.Calendars[id])
	}
	return result
}
func (d *state) upsert(c *calendar, u *user, body object) (object, error) {
	var existing object
	if uid := str(body["iCalUID"]); uid != "" {
		for _, ev := range c.Events {
			if str(ev["iCalUID"]) == uid {
				existing = ev
				break
			}
		}
	}
	ev, err := d.shapeEvent(c, u, body, existing)
	if err == nil {
		c.Events[str(ev["id"])] = ev
	}
	return ev, err
}
func exdate(original, master object, c *calendar) string {
	compact := strings.NewReplacer("-", "", ":", "").Replace
	if date := str(original["date"]); date != "" {
		return "EXDATE;VALUE=DATE:" + compact(date)
	}
	tz := first(zoneOrEmpty(str(obj(master["start"])["timeZone"])), c.TimeZone)
	instant, _ := moment(original, tz)
	return "EXDATE;TZID=" + tz + ":" + compact(formatInZone(instant, tz)[:19])
}
func (d *state) importGoogle(c *calendar, u *user, items []object) (int, int) {
	masters := map[string]object{}
	imported, skipped := 0, 0
	for _, item := range items {
		if str(item["recurringEventId"]) != "" {
			continue
		}
		if str(item["status"]) == "cancelled" {
			skipped++
			continue
		}
		body := copyObject(item)
		delete(body, "id")
		ev, err := d.upsert(c, u, body)
		if err != nil {
			skipped++
			continue
		}
		masters[str(item["id"])] = ev
		imported++
	}
	for _, item := range items {
		parent := str(item["recurringEventId"])
		if parent == "" {
			continue
		}
		if master := masters[parent]; master != nil && len(obj(item["originalStartTime"])) > 0 {
			rule := exdate(obj(item["originalStartTime"]), master, c)
			rules := stringsOf(master["recurrence"])
			exists := false
			for _, r := range rules {
				if r == rule {
					exists = true
				}
			}
			if !exists {
				master["recurrence"] = append(rules, rule)
			}
		}
		if str(item["status"]) == "cancelled" {
			continue
		}
		body := copyObject(item)
		body["iCalUID"] = first(str(item["iCalUID"]), str(item["id"])) + "-" + str(item["id"])
		for _, key := range []string{"id", "recurringEventId", "originalStartTime", "recurrence"} {
			delete(body, key)
		}
		if _, err := d.upsert(c, u, body); err != nil {
			skipped++
		} else {
			imported++
		}
	}
	return imported, skipped
}

func seedDemo(d *state) error {
	zone := "Europe/Oslo"
	ada, err := d.createUser("Ada Lovelace", "ada@example.com", "calendar123", zone)
	if err != nil {
		return err
	}
	bob, err := d.createUser("Bob Hansen", "bob@example.com", "calendar123", zone)
	if err != nil {
		return err
	}
	if _, err = d.createUser("Cleo Berg", "cleo@example.com", "calendar123", zone); err != nil {
		return err
	}
	today := time.Now().In(location(zone))
	day := func(offset int) string { return today.AddDate(0, 0, offset).Format("2006-01-02") }
	monday := -(int(today.Weekday()) + 6) % 7
	at := func(offset int, clock string) object {
		return object{"dateTime": day(offset) + "T" + clock + ":00", "timeZone": zone}
	}
	add := func(c *calendar, u *user, body object) {
		ev, e := d.shapeEvent(c, u, body, nil)
		if e != nil {
			panic(e)
		}
		c.Events[str(ev["id"])] = ev
	}
	a, b := d.Calendars[ada.Email], d.Calendars[bob.Email]
	add(a, ada, object{"summary": "Stand-up", "start": at(monday, "09:00"), "end": at(monday, "09:15"), "recurrence": []string{"RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"}})
	add(a, ada, object{"summary": "Lunch with Cleo", "location": "Fjord Café", "start": at(1, "11:30"), "end": at(1, "12:30")})
	add(a, ada, object{"summary": "Quarterly planning", "description": "Orders, warehouses and the new product line.", "start": at(2, "13:00"), "end": at(2, "15:30"), "attendees": []object{{"email": "bob@example.com"}, {"email": "cleo@example.com"}}})
	add(a, ada, object{"summary": "Conference", "start": object{"date": day(monday + 10)}, "end": object{"date": day(monday + 12)}})
	team := d.createCalendar(ada, object{"summary": "Warehouse team", "description": "Shifts and deliveries", "timeZone": zone})
	team.ACL = append(team.ACL, object{"id": "user:bob@example.com", "role": "writer", "scope": object{"type": "user", "value": bob.Email}}, object{"id": "user:cleo@example.com", "role": "reader", "scope": object{"type": "user", "value": "cleo@example.com"}})
	add(team, ada, object{"summary": "Delivery from Aurora Logistics", "start": at(0, "07:00"), "end": at(0, "08:00")})
	add(team, ada, object{"summary": "Stock count", "start": at(3, "14:00"), "end": at(3, "17:00")})
	add(team, ada, object{"summary": "Inventory day", "start": object{"date": day(monday + 4)}, "end": object{"date": day(monday + 5)}})
	add(b, bob, object{"summary": "Customer visit: Fjord Foods", "location": "Bergen", "start": at(1, "10:00"), "end": at(1, "11:00"), "attendees": []object{{"email": ada.Email}}})
	add(b, bob, object{"summary": "Dentist", "start": at(2, "08:00"), "end": at(2, "09:00")})
	b.ACL = append(b.ACL, object{"id": "user:" + ada.Email, "role": "freeBusyReader", "scope": object{"type": "user", "value": ada.Email}})
	return nil
}
