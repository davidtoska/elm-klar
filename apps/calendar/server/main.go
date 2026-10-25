package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	port := flag.String("port", first(os.Getenv("PORT"), "8080"), "loopback HTTP port")
	addr := flag.String("addr", "", "listen address (overrides port)")
	assets := flag.String("assets", ".", "directory containing index.html and main.js")
	dbFile := flag.String("db", os.Getenv("CALENDAR_DB"), "SQLite path (default data/calendar.sqlite)")
	legacy := flag.String("import-json", os.Getenv("CALENDAR_DATA"), "legacy JSON imported once into a new database")
	prefix := flag.String("prefix", "", "HTTP mount prefix, for example /calendar-app")
	demo := flag.Bool("demo", false, "seed and enable demo identities")
	google := flag.String("google-client-id", os.Getenv("GOOGLE_CLIENT_ID"), "optional Google import client id")
	flag.Parse()
	appDir, err := filepath.Abs(*assets)
	if err != nil {
		log.Fatal(err)
	}
	if *dbFile == "" {
		*dbFile = filepath.Join(appDir, "data", "calendar.sqlite")
	}
	if *legacy == "" && !flagWasSet("import-json") {
		*legacy = filepath.Join(appDir, "server", "data.json")
		oldPath := filepath.Join(appDir, "..", "..", "calendar", "server", "data.json")
		if _, err := os.Stat(oldPath); err == nil {
			*legacy = oldPath
		}
	}
	s, err := openStore(*dbFile)
	if err != nil {
		log.Fatal(err)
	}
	defer s.db.Close()
	if err = s.initialize(*legacy, *demo); err != nil {
		log.Fatal(err)
	}
	a := &application{store: s, assets: appDir, prefix: strings.TrimRight(*prefix, "/"), googleClientID: *google, demo: *demo}
	listen := *addr
	if listen == "" {
		listen = net.JoinHostPort("127.0.0.1", *port)
	}
	listener, err := net.Listen("tcp", listen)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Calendar on http://%s%s/\n", listener.Addr().String(), a.prefix)
	if err = http.Serve(listener, a); err != nil {
		log.Fatal(err)
	}
}

func flagWasSet(name string) bool {
	found := false
	flag.Visit(func(f *flag.Flag) {
		if f.Name == name {
			found = true
		}
	})
	return found
}
