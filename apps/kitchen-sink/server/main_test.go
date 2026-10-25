package main

import (
	"bytes"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
)

func testApp(t *testing.T) (app, string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "test.sqlite")
	db, err := openDB(path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return app{db}, path
}
func call(a app, method, path, body string) *httptest.ResponseRecorder {
	r := httptest.NewRequest(method, path, strings.NewReader(body))
	r.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	a.routes("../public").ServeHTTP(w, r)
	return w
}
func TestSQLitePersistsAcrossReopen(t *testing.T) {
	a, path := testApp(t)
	w := call(a, "PUT", "/api/documents/playground", `{"text":"Saved customer","slider":72}`)
	if w.Code != 200 {
		t.Fatal(w.Code, w.Body.String())
	}
	a.db.Close()
	db, err := openDB(path)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	w = call(app{db}, "GET", "/api/documents/playground", "")
	if w.Code != 200 || !strings.Contains(w.Body.String(), "Saved customer") {
		t.Fatal(w.Code, w.Body.String())
	}
	var count int
	if err := db.QueryRow("SELECT count(*) FROM orders").Scan(&count); err != nil || count != 250 {
		t.Fatal(count, err)
	}
}
func TestOrdersScenarios(t *testing.T) {
	a, _ := testApp(t)
	for _, tc := range []struct {
		path          string
		status, count int
	}{{"/api/orders", 200, 250}, {"/api/orders?scenario=empty", 200, 0}, {"/api/orders?scenario=fail", 503, 0}} {
		w := call(a, "GET", tc.path, "")
		if w.Code != tc.status {
			t.Fatal(tc.path, w.Code)
		}
		if w.Code == 200 {
			var rows []order
			if err := json.Unmarshal(w.Body.Bytes(), &rows); err != nil || len(rows) != tc.count {
				t.Fatal(len(rows), err)
			}
		}
	}
}
func TestServerQueryFiltersSortsAndPages(t *testing.T) {
	a, _ := testApp(t)
	w := call(a, "POST", "/api/orders/query", `{"search":"Aurora","page":2,"pageSize":7,"sort":[{"field":"total","descending":true}],"rule":{"children":[{"field":"total","operator":"atLeast","values":["50000"]}]}}`)
	if w.Code != 200 {
		t.Fatal(w.Code, w.Body.String())
	}
	var page struct {
		Rows  []order
		Total int
	}
	if err := json.Unmarshal(w.Body.Bytes(), &page); err != nil {
		t.Fatal(err)
	}
	if len(page.Rows) != 7 || page.Total != 39 {
		t.Fatal(len(page.Rows), page.Total)
	}
	for i, row := range page.Rows {
		if row.Total < 50000 || !strings.Contains(row.Customer, "Aurora") {
			t.Fatal(row)
		}
		if i > 0 && page.Rows[i-1].Total < row.Total {
			t.Fatal("sort direction")
		}
	}
	w = call(a, "POST", "/api/orders/query", `{"rule":{"field":"secret","operator":"is","values":["x"]}}`)
	if w.Code != 400 {
		t.Fatal(w.Code, w.Body.String())
	}
}
func TestCustomerValidationAndFailure(t *testing.T) {
	a, _ := testApp(t)
	for _, tc := range []struct {
		name, email string
		status      int
	}{{"Alex", "taken@example.com", 422}, {"Crash", "a@example.com", 503}, {"Alex", "a@example.com", 200}, {"", "invalid", 400}} {
		body, _ := json.Marshal(map[string]string{"name": tc.name, "email": tc.email})
		w := call(a, "POST", "/api/customers", string(body))
		if w.Code != tc.status {
			t.Fatal(tc, w.Code, w.Body.String())
		}
	}
}
func TestUploadRoundTrip(t *testing.T) {
	a, _ := testApp(t)
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	file, err := writer.CreateFormFile("file", "sample.txt")
	if err != nil {
		t.Fatal(err)
	}
	_, _ = file.Write([]byte("actual file bytes\x00\xff"))
	writer.Close()
	r := httptest.NewRequest("POST", "/api/uploads", &body)
	r.Header.Set("Content-Type", writer.FormDataContentType())
	w := httptest.NewRecorder()
	a.upload(w, r)
	if w.Code != 201 {
		t.Fatal(w.Code, w.Body.String())
	}
	var result struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	w = call(a, "GET", "/api/uploads/"+result.ID, "")
	if w.Code != 200 || !bytes.Equal(w.Body.Bytes(), []byte("actual file bytes\x00\xff")) {
		t.Fatal(w.Code, w.Body.String())
	}
}
func TestMalformedAndCrossOriginWrites(t *testing.T) {
	a, _ := testApp(t)
	for _, body := range []string{`{`, `{} {}`} {
		if w := call(a, "PUT", "/api/documents/test", body); w.Code != 400 {
			t.Fatal(w.Code)
		}
	}
	r := httptest.NewRequest("PUT", "http://localhost/api/documents/test", strings.NewReader(`{}`))
	r.Header.Set("Origin", "https://other.example")
	w := httptest.NewRecorder()
	a.routes("../public").ServeHTTP(w, r)
	if w.Code != 403 {
		t.Fatal(w.Code)
	}
}
func TestChatAcceptsStreamsAndPersists(t *testing.T) {
	a, _ := testApp(t)
	server := httptest.NewServer(a.routes("../public"))
	defer server.Close()
	res, err := http.Post(server.URL+"/api/chat", "application/json", strings.NewReader(`{"text":"Hello"}`))
	if err != nil {
		t.Fatal(err)
	}
	decoder := json.NewDecoder(res.Body)
	var first map[string]string
	if err := decoder.Decode(&first); err != nil || first["phase"] != "accepted" {
		t.Fatal(first, err)
	}
	var buffer strings.Builder
	for {
		var chunk map[string]string
		err := decoder.Decode(&chunk)
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatal(err)
		}
		buffer.WriteString(chunk["text"])
	}
	res.Body.Close()
	if !strings.Contains(buffer.String(), "Simulated assistant") {
		t.Fatal(buffer.String())
	}
	var count int
	if err := a.db.QueryRow("SELECT count(*) FROM messages").Scan(&count); err != nil || count != 2 {
		t.Fatal(count, err)
	}
	// A retry regenerates the previous prompt; it must not insert another user message.
	retry, err := http.Post(server.URL+"/api/chat", "application/json", strings.NewReader(`{"text":"Hello","retry":true}`))
	if err != nil {
		t.Fatal(err)
	}
	var accepted map[string]string
	if err := json.NewDecoder(retry.Body).Decode(&accepted); err != nil || accepted["phase"] != "accepted" {
		t.Fatal(accepted, err)
	}
	retry.Body.Close()
	if err := a.db.QueryRow("SELECT count(*) FROM messages WHERE role='user'").Scan(&count); err != nil || count != 1 {
		t.Fatal(count, err)
	}
}

func TestCommentAndAuditHistory(t *testing.T) {
	a, _ := testApp(t)
	w := call(a, "POST", "/api/events", `{"action":"Posted comment","body":"Check the address","parent":null}`)
	if w.Code != 201 {
		t.Fatal(w.Code, w.Body.String())
	}
	var created struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &created); err != nil || created.ID == "" {
		t.Fatal(created, err)
	}
	w = call(a, "GET", "/api/comments", "")
	var comments []struct {
		ID, Body string
		At       int64
	}
	if err := json.Unmarshal(w.Body.Bytes(), &comments); err != nil || len(comments) != 1 || comments[0].ID != "comment-"+created.ID || comments[0].Body != "Check the address" || comments[0].At == 0 {
		t.Fatal(w.Body.String(), err)
	}
	w = call(a, "GET", "/api/events", "")
	var events []struct {
		Action string
		At     int64
	}
	if err := json.Unmarshal(w.Body.Bytes(), &events); err != nil || len(events) != 1 || events[0].At == 0 {
		t.Fatal(w.Body.String(), err)
	}
}

func TestMissingOptionalDocument(t *testing.T) {
	a, _ := testApp(t)
	w := call(a, "GET", "/api/documents/never-saved", "")
	if w.Code != 200 || strings.TrimSpace(w.Body.String()) != "null" {
		t.Fatal(w.Code, w.Body.String())
	}
}
