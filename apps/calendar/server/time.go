package main

import (
	"regexp"
	"strconv"
	"strings"
	"time"
	_ "time/tzdata"
)

var windowsZones = map[string]string{
	"W. Europe Standard Time": "Europe/Berlin", "Romance Standard Time": "Europe/Paris",
	"Central Europe Standard Time": "Europe/Budapest", "Central European Standard Time": "Europe/Warsaw",
	"GMT Standard Time": "Europe/London", "FLE Standard Time": "Europe/Helsinki", "E. Europe Standard Time": "Europe/Bucharest",
	"Eastern Standard Time": "America/New_York", "Central Standard Time": "America/Chicago",
	"Mountain Standard Time": "America/Denver", "Pacific Standard Time": "America/Los_Angeles",
	"Coordinated Universal Time": "UTC",
}

func zoneOrEmpty(name string) string {
	if mapped, ok := windowsZones[name]; ok {
		name = mapped
	}
	if name == "" {
		return ""
	}
	if _, err := time.LoadLocation(name); err != nil {
		return ""
	}
	return name
}

func location(name string) *time.Location {
	loc, err := time.LoadLocation(name)
	if err != nil {
		return time.UTC
	}
	return loc
}

// Match the previous backend's two-offset resolution at daylight-saving changes:
// spring gaps move forward; ambiguous autumn wall times choose the later offset.
func wallTime(y, mo, d, h, mi, s int, zone string) time.Time {
	guess := time.Date(y, time.Month(mo), d, h, mi, s, 0, time.UTC)
	_, first := guess.In(location(zone)).Zone()
	_, second := guess.Add(-time.Duration(first) * time.Second).In(location(zone)).Zone()
	return guess.Add(-time.Duration(second) * time.Second)
}

var dateTimePattern = regexp.MustCompile(`^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d)(?::(\d\d)(?:\.\d+)?)?(Z|[+-]\d\d:?\d\d)?$`)
var datePattern = regexp.MustCompile(`^\d{4}-\d\d-\d\d$`)

func parseDateTime(text, zone string) (time.Time, bool) {
	m := dateTimePattern.FindStringSubmatch(text)
	if m == nil {
		return time.Time{}, false
	}
	n := func(i int) int { value, _ := strconv.Atoi(m[i]); return value }
	y, mo, d, h, mi, s := n(1), n(2), n(3), n(4), n(5), n(6)
	wall := time.Date(y, time.Month(mo), d, h, mi, s, 0, time.UTC)
	if int(wall.Month()) != mo || wall.Day() != d || h > 23 || mi > 59 || s > 59 {
		return time.Time{}, false
	}
	if m[7] == "" {
		return wallTime(y, mo, d, h, mi, s, zone), true
	}
	if m[7] == "Z" {
		return wall, true
	}
	digits := strings.ReplaceAll(m[7][1:], ":", "")
	hh, _ := strconv.Atoi(digits[:2])
	mm, _ := strconv.Atoi(digits[2:])
	if hh > 23 || mm > 59 {
		return time.Time{}, false
	}
	offset := hh*3600 + mm*60
	if m[7][0] == '-' {
		offset = -offset
	}
	return wall.Add(-time.Duration(offset) * time.Second), true
}

func moment(value object, zone string) (time.Time, bool) {
	if own := zoneOrEmpty(str(value["timeZone"])); own != "" {
		zone = own
	}
	if date := str(value["date"]); date != "" {
		parsed, err := time.Parse("2006-01-02", date)
		if err != nil {
			return time.Time{}, false
		}
		return wallTime(parsed.Year(), int(parsed.Month()), parsed.Day(), 0, 0, 0, zone), true
	}
	return parseDateTime(str(value["dateTime"]), zone)
}

func formatInZone(value time.Time, zone string) string {
	return value.In(location(zone)).Format("2006-01-02T15:04:05-07:00")
}
