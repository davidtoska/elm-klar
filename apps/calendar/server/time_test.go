package main

import "testing"

func TestTimeZonesAndDST(t *testing.T) {
	for _, tc := range []struct{ input, zone, want string }{
		{"2026-01-20T09:00:00", "Europe/Oslo", "2026-01-20T09:00:00+01:00"},
		{"2026-07-20T09:00:00", "Europe/Oslo", "2026-07-20T09:00:00+02:00"},
		{"2026-03-29T02:30:00", "Europe/Oslo", "2026-03-29T03:30:00+02:00"},
		{"2026-10-25T02:30:00", "Europe/Oslo", "2026-10-25T02:30:00+01:00"},
		{"2026-10-25T09:00:00Z", "Europe/Oslo", "2026-10-25T10:00:00+01:00"},
		{"2026-10-25T09:00:00-0500", "Europe/Oslo", "2026-10-25T15:00:00+01:00"},
	} {
		t.Run(tc.input, func(t *testing.T) {
			instant, ok := parseDateTime(tc.input, tc.zone)
			if !ok {
				t.Fatal("could not parse")
			}
			if got := formatInZone(instant, tc.zone); got != tc.want {
				t.Fatalf("got %s, want %s", got, tc.want)
			}
		})
	}
	if zoneOrEmpty("W. Europe Standard Time") != "Europe/Berlin" || zoneOrEmpty("Unknown/Place") != "" {
		t.Fatal("zone alias/validation")
	}
	if _, ok := parseDateTime("2026-02-30T09:00:00", "UTC"); ok {
		t.Fatal("invalid day accepted")
	}
}
