package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

type app struct{ db *sql.DB }
type order struct {
	ID       string `json:"id"`
	Customer string `json:"customer"`
	Total    int    `json:"total"`
}

func openDB(path string) (*sql.DB, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return nil, err
	}
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	_, err = db.Exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
	CREATE TABLE IF NOT EXISTS orders (id TEXT PRIMARY KEY, customer TEXT NOT NULL, total INTEGER NOT NULL);
	CREATE TABLE IF NOT EXISTS documents (id TEXT PRIMARY KEY, body TEXT NOT NULL, updated_at TEXT NOT NULL);
	CREATE TABLE IF NOT EXISTS events (id INTEGER PRIMARY KEY, action TEXT NOT NULL, body TEXT NOT NULL, at TEXT NOT NULL);
	CREATE TABLE IF NOT EXISTS uploads (id INTEGER PRIMARY KEY, name TEXT NOT NULL, mime TEXT NOT NULL, content BLOB NOT NULL);
	CREATE TABLE IF NOT EXISTS messages (id INTEGER PRIMARY KEY, role TEXT NOT NULL, body TEXT NOT NULL, at TEXT NOT NULL);`)
	if err != nil {
		db.Close()
		return nil, err
	}
	var count int
	if err = db.QueryRow("SELECT count(*) FROM orders").Scan(&count); err != nil {
		db.Close()
		return nil, err
	}
	if count == 0 {
		tx, err := db.Begin()
		if err != nil {
			db.Close()
			return nil, err
		}
		defer tx.Rollback()
		names := []string{"Aurora Logistics", "Fjord Foods", "Northstar Supply", "Harbour Products", "Summit Warehouses"}
		for i := 0; i < 250; i++ {
			if _, err := tx.Exec("INSERT INTO orders VALUES (?, ?, ?)", strconv.Itoa(1001+i), fmt.Sprintf("%s %02d", names[i%len(names)], i/len(names)+1), 12500+i*725); err != nil {
				db.Close()
				return nil, err
			}
		}
		if err = tx.Commit(); err != nil {
			db.Close()
			return nil, err
		}
	}
	return db, nil
}

func jsonReply(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
func problem(w http.ResponseWriter, status int, message string) {
	jsonReply(w, status, map[string]string{"error": message})
}
func decode(w http.ResponseWriter, r *http.Request, value any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 2<<20)
	d := json.NewDecoder(r.Body)
	if err := d.Decode(value); err != nil {
		problem(w, 400, "Invalid JSON body")
		return false
	}
	if err := d.Decode(new(any)); err != io.EOF {
		problem(w, 400, "Exactly one JSON value is required")
		return false
	}
	return true
}
func (a app) routes(public string) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, r *http.Request) {
		if err := a.db.PingContext(r.Context()); err != nil {
			problem(w, 503, "Database unavailable")
			return
		}
		jsonReply(w, 200, map[string]string{"status": "ok", "database": "sqlite"})
	})
	mux.HandleFunc("GET /api/orders", a.orders)
	mux.HandleFunc("POST /api/orders/query", a.queryOrders)
	mux.HandleFunc("GET /api/documents/{id}", a.getDocument)
	mux.HandleFunc("PUT /api/documents/{id}", a.putDocument)
	mux.HandleFunc("POST /api/customers", a.saveCustomer)
	mux.HandleFunc("GET /api/events", a.events)
	mux.HandleFunc("POST /api/events", a.addEvent)
	mux.HandleFunc("GET /api/comments", a.comments)
	mux.HandleFunc("POST /api/uploads", a.upload)
	mux.HandleFunc("GET /api/uploads/{id}", a.download)
	mux.HandleFunc("GET /api/chat", a.chatHistory)
	mux.HandleFunc("POST /api/chat", a.chat)
	mux.HandleFunc("/api/", func(w http.ResponseWriter, r *http.Request) { problem(w, 404, "Unknown API route") })
	mux.Handle("/", http.FileServer(http.Dir(public)))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "same-origin")
		// This application is a local test bench. Reject cross-origin writes.
		if r.Method != "GET" && r.Method != "HEAD" {
			origin := r.Header.Get("Origin")
			if origin != "" && origin != "http://"+r.Host && origin != "https://"+r.Host {
				problem(w, 403, "Origin rejected")
				return
			}
		}
		mux.ServeHTTP(w, r)
	})
}
func (a app) loadOrders(ctx context.Context) ([]order, error) {
	rows, err := a.db.QueryContext(ctx, "SELECT id,customer,total FROM orders ORDER BY id")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := []order{}
	for rows.Next() {
		var row order
		if err := rows.Scan(&row.ID, &row.Customer, &row.Total); err != nil {
			return nil, err
		}
		result = append(result, row)
	}
	return result, rows.Err()
}
func (a app) orders(w http.ResponseWriter, r *http.Request) {
	switch r.URL.Query().Get("scenario") {
	case "fail":
		problem(w, 503, "Intentional kitchen-sink failure")
		return
	case "empty":
		jsonReply(w, 200, []order{})
		return
	case "slow":
		select {
		case <-time.After(2 * time.Second):
		case <-r.Context().Done():
			return
		}
	}
	rows, err := a.loadOrders(r.Context())
	if err != nil {
		problem(w, 500, "Could not load orders")
		return
	}
	jsonReply(w, 200, rows)
}
func (a app) getDocument(w http.ResponseWriter, r *http.Request) {
	var body string
	err := a.db.QueryRowContext(r.Context(), "SELECT body FROM documents WHERE id=?", r.PathValue("id")).Scan(&body)
	if errors.Is(err, sql.ErrNoRows) {
		jsonReply(w, 200, nil)
		return
	}
	if err != nil {
		problem(w, 500, "Could not load document")
		return
	}
	jsonReply(w, 200, json.RawMessage(body))
}
func (a app) store(ctx context.Context, id string, body any) error {
	encoded, err := json.Marshal(body)
	if err != nil {
		return err
	}
	_, err = a.db.ExecContext(ctx, "INSERT INTO documents VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET body=excluded.body, updated_at=excluded.updated_at", id, string(encoded), time.Now().UTC().Format(time.RFC3339Nano))
	return err
}
func (a app) putDocument(w http.ResponseWriter, r *http.Request) {
	var body json.RawMessage
	if !decode(w, r, &body) {
		return
	}
	if err := a.store(r.Context(), r.PathValue("id"), body); err != nil {
		problem(w, 500, "Could not save document")
		return
	}
	jsonReply(w, 200, map[string]bool{"saved": true})
}
func (a app) saveCustomer(w http.ResponseWriter, r *http.Request) {
	var c struct {
		Name      string `json:"name"`
		Email     string `json:"email"`
		Warehouse string `json:"warehouse"`
		Credit    *int   `json:"credit"`
		Active    bool   `json:"active"`
	}
	if !decode(w, r, &c) {
		return
	}
	if c.Name == "Crash" {
		problem(w, 503, "Intentional save failure")
		return
	}
	if c.Email == "taken@example.com" {
		jsonReply(w, 422, map[string]any{"problems": []map[string]string{{"field": "email_address", "message": "This address already belongs to a customer."}}})
		return
	}
	if strings.TrimSpace(c.Name) == "" || !strings.Contains(c.Email, "@") {
		problem(w, 400, "Name and email are required")
		return
	}
	if err := a.store(r.Context(), "customer", c); err != nil {
		problem(w, 500, "Could not save customer")
		return
	}
	jsonReply(w, 200, map[string]bool{"saved": true})
}
func (a app) addEvent(w http.ResponseWriter, r *http.Request) {
	var body map[string]any
	if !decode(w, r, &body) {
		return
	}
	action, _ := body["action"].(string)
	if action == "" {
		action = "Playground change"
	}
	encoded, err := json.Marshal(body)
	if err != nil {
		problem(w, 400, "Invalid event")
		return
	}
	result, err := a.db.ExecContext(r.Context(), "INSERT INTO events(action,body,at) VALUES(?,?,?)", action, string(encoded), time.Now().UTC().Format(time.RFC3339Nano))
	if err != nil {
		problem(w, 500, "Could not persist event")
		return
	}
	id, err := result.LastInsertId()
	if err != nil {
		problem(w, 500, "Could not read event id")
		return
	}
	jsonReply(w, 201, map[string]any{"saved": true, "id": strconv.FormatInt(id, 10)})
}
func (a app) events(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.QueryContext(r.Context(), "SELECT id,action,at FROM events ORDER BY id DESC LIMIT 100")
	if err != nil {
		problem(w, 500, "Could not load events")
		return
	}
	defer rows.Close()
	result := []map[string]any{}
	for rows.Next() {
		var id int
		var action, at string
		if err := rows.Scan(&id, &action, &at); err != nil {
			problem(w, 500, "Could not read event")
			return
		}
		instant, err := time.Parse(time.RFC3339Nano, at)
		if err != nil {
			problem(w, 500, "Invalid stored timestamp")
			return
		}
		result = append(result, map[string]any{"id": strconv.Itoa(id), "action": action, "at": instant.UnixMilli()})
	}
	if err := rows.Err(); err != nil {
		problem(w, 500, "Could not read events")
		return
	}
	jsonReply(w, 200, result)
}
func (a app) comments(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.QueryContext(r.Context(), "SELECT id,body,at FROM events WHERE action='Posted comment' ORDER BY id")
	if err != nil {
		problem(w, 500, "Could not load comments")
		return
	}
	defer rows.Close()
	result := []map[string]any{}
	for rows.Next() {
		var id int
		var body, at string
		if err := rows.Scan(&id, &body, &at); err != nil {
			problem(w, 500, "Could not read comment")
			return
		}
		var value map[string]any
		if err := json.Unmarshal([]byte(body), &value); err != nil {
			problem(w, 500, "Invalid stored comment")
			return
		}
		instant, err := time.Parse(time.RFC3339Nano, at)
		if err != nil {
			problem(w, 500, "Invalid stored timestamp")
			return
		}
		result = append(result, map[string]any{"id": "comment-" + strconv.Itoa(id), "author": "You", "body": value["body"], "parent": value["parent"], "at": instant.UnixMilli()})
	}
	if err := rows.Err(); err != nil {
		problem(w, 500, "Could not read comments")
		return
	}
	jsonReply(w, 200, result)
}
func (a app) upload(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 6<<20)
	if err := r.ParseMultipartForm(6 << 20); err != nil {
		problem(w, 400, "Invalid multipart upload (maximum 5 MiB)")
		return
	}
	if r.MultipartForm != nil {
		defer r.MultipartForm.RemoveAll()
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		problem(w, 400, "Missing file")
		return
	}
	defer file.Close()
	content, err := io.ReadAll(io.LimitReader(file, (5<<20)+1))
	if err != nil || len(content) > 5<<20 {
		problem(w, 413, "File is too large")
		return
	}
	result, err := a.db.ExecContext(r.Context(), "INSERT INTO uploads(name,mime,content) VALUES(?,?,?)", filepath.Base(header.Filename), header.Header.Get("Content-Type"), content)
	if err != nil {
		problem(w, 500, "Could not store file")
		return
	}
	id, err := result.LastInsertId()
	if err != nil {
		problem(w, 500, "Could not read upload id")
		return
	}
	jsonReply(w, 201, map[string]any{"id": strconv.FormatInt(id, 10), "name": header.Filename, "size": len(content)})
}
func (a app) download(w http.ResponseWriter, r *http.Request) {
	var name, mime string
	var content []byte
	if err := a.db.QueryRowContext(r.Context(), "SELECT name,mime,content FROM uploads WHERE id=?", r.PathValue("id")).Scan(&name, &mime, &content); err != nil {
		problem(w, 404, "Upload not found")
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%q", strings.Map(func(r rune) rune {
		if r == '\r' || r == '\n' {
			return -1
		}
		return r
	}, name)))
	_, _ = w.Write(content)
}
func (a app) chatHistory(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.QueryContext(r.Context(), "SELECT id,role,body FROM messages ORDER BY id")
	if err != nil {
		problem(w, 500, "Could not load chat")
		return
	}
	defer rows.Close()
	result := []map[string]string{}
	for rows.Next() {
		var id int
		var role, body string
		if err := rows.Scan(&id, &role, &body); err != nil {
			problem(w, 500, "Could not read chat")
			return
		}
		result = append(result, map[string]string{"id": strconv.Itoa(id), "role": role, "body": body})
	}
	if err := rows.Err(); err != nil {
		problem(w, 500, "Could not read chat")
		return
	}
	jsonReply(w, 200, result)
}
func (a app) chat(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Text  string `json:"text"`
		Retry bool   `json:"retry"`
	}
	if !decode(w, r, &body) {
		return
	}
	if strings.TrimSpace(body.Text) == "" {
		problem(w, 400, "A prompt is required")
		return
	}
	var previous string
	if body.Retry {
		_ = a.db.QueryRowContext(r.Context(), "SELECT body FROM messages WHERE role='user' ORDER BY id DESC LIMIT 1").Scan(&previous)
	}
	if !body.Retry || previous != body.Text {
		if _, err := a.db.ExecContext(r.Context(), "INSERT INTO messages(role,body,at) VALUES('user',?,?)", body.Text, time.Now().UTC().Format(time.RFC3339Nano)); err != nil {
			problem(w, 500, "Could not save prompt")
			return
		}
	}
	w.Header().Set("Content-Type", "application/x-ndjson")
	w.Header().Set("Cache-Control", "no-store")
	encoder := json.NewEncoder(w)
	if err := encoder.Encode(map[string]string{"phase": "accepted"}); err != nil {
		return
	}
	if f, ok := w.(http.Flusher); ok {
		f.Flush()
	}
	answer := "**Simulated assistant** — no model provider is connected.\n\nGo received your prompt and stores this conversation in SQLite. This answer is streamed in chunks so you can test Stop, Retry, draft acknowledgement and safe Markdown.\n\nYour prompt: " + body.Text
	var partial strings.Builder
	defer func() {
		_, err := a.db.Exec("INSERT INTO messages(role,body,at) VALUES('assistant',?,?)", partial.String(), time.Now().UTC().Format(time.RFC3339Nano))
		if err != nil {
			log.Printf("persist assistant: %v", err)
		}
	}()
	words := strings.SplitAfter(answer, " ")
	for _, word := range words {
		select {
		case <-r.Context().Done():
			return
		case <-time.After(45 * time.Millisecond):
		}
		partial.WriteString(word)
		if err := encoder.Encode(map[string]string{"phase": "chunk", "text": word}); err != nil {
			return
		}
		if f, ok := w.(http.Flusher); ok {
			f.Flush()
		}
	}
	_ = encoder.Encode(map[string]string{"phase": "done"})
}
func main() {
	addr := flag.String("addr", "127.0.0.1:8090", "HTTP listen address")
	dbPath := flag.String("db", "data/kitchen-sink.sqlite", "SQLite database path")
	public := flag.String("public", "public", "Static frontend directory")
	flag.Parse()
	db, err := openDB(*dbPath)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	server := &http.Server{Addr: *addr, Handler: app{db}.routes(*public), ReadHeaderTimeout: 5 * time.Second, IdleTimeout: 60 * time.Second}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdown)
	}()
	log.Printf("Klar Kitchen Sink: http://%s (SQLite: %s)", *addr, *dbPath)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
