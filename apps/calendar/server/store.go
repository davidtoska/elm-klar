package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite"
)

type object = map[string]any

type user struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Salt     string `json:"salt"`
	Hash     string `json:"hash"`
	TimeZone string `json:"timeZone"`
}

type calendar struct {
	ID          string            `json:"id"`
	Etag        string            `json:"etag"`
	Summary     string            `json:"summary"`
	Description string            `json:"description"`
	TimeZone    string            `json:"timeZone"`
	ACL         []object          `json:"acl"`
	Events      map[string]object `json:"events,omitempty"`
}

// The JSON shape also reads the former Node store. SQLite keeps independently
// keyed resources; arbitrary Google event fields survive round trips unchanged.
type state struct {
	Users     []*user                      `json:"users"`
	Sessions  map[string]string            `json:"sessions"`
	Calendars map[string]*calendar         `json:"calendars"`
	Prefs     map[string]map[string]object `json:"prefs"`
}

func emptyState() *state {
	return &state{Users: []*user{}, Sessions: map[string]string{}, Calendars: map[string]*calendar{}, Prefs: map[string]map[string]object{}}
}

type store struct{ db *sql.DB }

func openStore(filename string) (*store, error) {
	if filename != ":memory:" {
		if err := os.MkdirAll(filepath.Dir(filename), 0700); err != nil {
			return nil, err
		}
	}
	db, err := sql.Open("sqlite", filename+"?_txlock=immediate&_busy_timeout=5000")
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	s := &store{db}
	_, err = db.Exec(`PRAGMA busy_timeout=5000;
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS users (email TEXT PRIMARY KEY, record TEXT NOT NULL CHECK(json_valid(record)));
CREATE TABLE IF NOT EXISTS calendars (id TEXT PRIMARY KEY, record TEXT NOT NULL CHECK(json_valid(record)));
CREATE TABLE IF NOT EXISTS events (calendar_id TEXT NOT NULL, id TEXT NOT NULL, record TEXT NOT NULL CHECK(json_valid(record)), PRIMARY KEY(calendar_id,id));
CREATE TABLE IF NOT EXISTS preferences (email TEXT NOT NULL, calendar_id TEXT NOT NULL, record TEXT NOT NULL CHECK(json_valid(record)), PRIMARY KEY(email,calendar_id));
CREATE TABLE IF NOT EXISTS sessions (token TEXT PRIMARY KEY, email TEXT NOT NULL);`)
	if err != nil {
		db.Close()
		return nil, err
	}
	return s, nil
}

func (s *store) initialized() (bool, error) {
	var count int
	err := s.db.QueryRow("SELECT COUNT(*) FROM metadata WHERE key='initialized'").Scan(&count)
	return count > 0, err
}

func (s *store) load() (*state, error) {
	return loadState(s.db)
}

type queryer interface {
	Query(string, ...any) (*sql.Rows, error)
}

func loadState(connection queryer) (*state, error) {
	d := emptyState()
	read := func(query string, consume func(*sql.Rows) error) error {
		rows, err := connection.Query(query)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			if err := consume(rows); err != nil {
				return err
			}
		}
		return rows.Err()
	}
	if err := read("SELECT record FROM users ORDER BY rowid", func(rows *sql.Rows) error {
		var raw string
		if err := rows.Scan(&raw); err != nil {
			return err
		}
		var u user
		if err := json.Unmarshal([]byte(raw), &u); err != nil {
			return err
		}
		d.Users = append(d.Users, &u)
		return nil
	}); err != nil {
		return nil, err
	}
	if err := read("SELECT record FROM calendars ORDER BY rowid", func(rows *sql.Rows) error {
		var raw string
		if err := rows.Scan(&raw); err != nil {
			return err
		}
		var c calendar
		if err := json.Unmarshal([]byte(raw), &c); err != nil {
			return err
		}
		c.Events = map[string]object{}
		d.Calendars[c.ID] = &c
		return nil
	}); err != nil {
		return nil, err
	}
	if err := read("SELECT calendar_id,id,record FROM events", func(rows *sql.Rows) error {
		var cal, id, raw string
		if err := rows.Scan(&cal, &id, &raw); err != nil {
			return err
		}
		var ev object
		if err := json.Unmarshal([]byte(raw), &ev); err != nil {
			return err
		}
		if d.Calendars[cal] == nil {
			return fmt.Errorf("orphan event %s", id)
		}
		d.Calendars[cal].Events[id] = ev
		return nil
	}); err != nil {
		return nil, err
	}
	if err := read("SELECT email,calendar_id,record FROM preferences", func(rows *sql.Rows) error {
		var email, cal, raw string
		if err := rows.Scan(&email, &cal, &raw); err != nil {
			return err
		}
		var p object
		if err := json.Unmarshal([]byte(raw), &p); err != nil {
			return err
		}
		if d.Prefs[email] == nil {
			d.Prefs[email] = map[string]object{}
		}
		d.Prefs[email][cal] = p
		return nil
	}); err != nil {
		return nil, err
	}
	if err := read("SELECT token,email FROM sessions", func(rows *sql.Rows) error {
		var token, email string
		if err := rows.Scan(&token, &email); err != nil {
			return err
		}
		d.Sessions[token] = email
		return nil
	}); err != nil {
		return nil, err
	}
	return d, nil
}

// The caller holds one IMMEDIATE transaction from load through save. This also
// serializes writes from distinct server processes sharing the same database.
func saveState(tx *sql.Tx, d *state) error {
	var err error
	for _, table := range []string{"users", "calendars", "events", "preferences", "sessions"} {
		if _, err = tx.Exec("DELETE FROM " + table); err != nil {
			return err
		}
	}
	put := func(query string, value any, args ...any) error {
		raw, err := json.Marshal(value)
		if err != nil {
			return err
		}
		_, err = tx.Exec(query, append(args, string(raw))...)
		return err
	}
	for _, u := range d.Users {
		if err = put("INSERT INTO users(email,record) VALUES(?,?)", u, u.Email); err != nil {
			return err
		}
	}
	for id, c := range d.Calendars {
		resource := *c
		resource.Events = nil
		if err = put("INSERT INTO calendars(id,record) VALUES(?,?)", resource, id); err != nil {
			return err
		}
		for eid, ev := range c.Events {
			if err = put("INSERT INTO events(calendar_id,id,record) VALUES(?,?,?)", ev, id, eid); err != nil {
				return err
			}
		}
	}
	for email, prefs := range d.Prefs {
		for cal, p := range prefs {
			if err = put("INSERT INTO preferences(email,calendar_id,record) VALUES(?,?,?)", p, email, cal); err != nil {
				return err
			}
		}
	}
	for token, email := range d.Sessions {
		if _, err = tx.Exec("INSERT INTO sessions(token,email) VALUES(?,?)", token, email); err != nil {
			return err
		}
	}
	if _, err = tx.Exec("INSERT OR REPLACE INTO metadata(key,value) VALUES('initialized','1')"); err != nil {
		return err
	}
	return nil
}

func (s *store) initialize(legacy string, demo bool) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var count int
	if err = tx.QueryRow("SELECT COUNT(*) FROM metadata WHERE key='initialized'").Scan(&count); err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	finish := func(d *state) error {
		if err := saveState(tx, d); err != nil {
			return err
		}
		return tx.Commit()
	}
	d := emptyState()
	if legacy != "" {
		raw, readErr := os.ReadFile(legacy)
		if readErr == nil {
			if err = json.Unmarshal(raw, d); err != nil {
				return fmt.Errorf("legacy calendar store %s: %w", legacy, err)
			}
			if d.Sessions == nil {
				d.Sessions = map[string]string{}
			}
			if d.Calendars == nil {
				d.Calendars = map[string]*calendar{}
			}
			if d.Prefs == nil {
				d.Prefs = map[string]map[string]object{}
			}
			for _, u := range d.Users {
				if u == nil || u.Email == "" {
					return fmt.Errorf("invalid legacy calendar user")
				}
			}
			for id, c := range d.Calendars {
				if c == nil || c.ID != id {
					return fmt.Errorf("invalid legacy calendar %q", id)
				}
				if c.Events == nil {
					c.Events = map[string]object{}
				}
			}
			if demo && len(d.Users) == 0 && len(d.Calendars) == 0 && len(d.Sessions) == 0 && len(d.Prefs) == 0 {
				if err = seedDemo(d); err != nil {
					return err
				}
			}
			return finish(d)
		}
		if !os.IsNotExist(readErr) {
			return readErr
		}
	}
	if demo {
		if err = seedDemo(d); err != nil {
			return err
		}
	}
	return finish(d)
}
