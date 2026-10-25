package main

import (
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"
)

// The app sends this deliberately small, explicit protocol from the public Rule
// and Table.Query types. It does not depend on Klar's private implementation.
type condition struct {
	Field      string      `json:"field"`
	Operator   string      `json:"operator"`
	Values     []string    `json:"values"`
	Children   []condition `json:"children"`
	Combinator string      `json:"combinator"`
	Negated    bool        `json:"negated"`
}

func (c condition) matches(row order) (bool, error) {
	if c.Field == "" {
		result := c.Combinator != "any"
		for _, child := range c.Children {
			match, err := child.matches(row)
			if err != nil {
				return false, err
			}
			if c.Combinator == "any" {
				result = result || match
			} else {
				result = result && match
			}
		}
		if c.Negated {
			result = !result
		}
		return result, nil
	}
	if c.Field != "customer" && c.Field != "total" {
		return false, fmt.Errorf("unsupported field %s", c.Field)
	}
	value := ""
	if len(c.Values) > 0 {
		value = c.Values[0]
	}
	text := strings.ToLower(row.Customer)
	needle := strings.ToLower(value)
	if c.Field == "total" {
		n, err := strconv.ParseFloat(value, 64)
		if err != nil {
			return false, fmt.Errorf("invalid number")
		}
		total := float64(row.Total)
		switch c.Operator {
		case "is":
			return total == n, nil
		case "isNot":
			return total != n, nil
		case "greater":
			return total > n, nil
		case "atLeast":
			return total >= n, nil
		case "less":
			return total < n, nil
		case "atMost":
			return total <= n, nil
		case "between", "notBetween":
			if len(c.Values) != 2 {
				return false, fmt.Errorf("two bounds required")
			}
			hi, err := strconv.ParseFloat(c.Values[1], 64)
			if err != nil {
				return false, err
			}
			v := total >= n && total <= hi
			if c.Operator == "notBetween" {
				v = !v
			}
			return v, nil
		}
	} else {
		switch c.Operator {
		case "is":
			return text == needle, nil
		case "isNot":
			return text != needle, nil
		case "contains":
			return strings.Contains(text, needle), nil
		case "notContains":
			return !strings.Contains(text, needle), nil
		case "starts":
			return strings.HasPrefix(text, needle), nil
		case "ends":
			return strings.HasSuffix(text, needle), nil
		case "empty":
			return text == "", nil
		case "notEmpty":
			return text != "", nil
		}
	}
	return false, fmt.Errorf("unsupported operator %s", c.Operator)
}

type listQuery struct {
	Search   string `json:"search"`
	Page     int    `json:"page"`
	PageSize int    `json:"pageSize"`
	Sort     []struct {
		Field      string `json:"field"`
		Descending bool   `json:"descending"`
	} `json:"sort"`
	Filters []struct {
		Field    string `json:"field"`
		Contains string `json:"contains"`
	} `json:"filters"`
	Rule condition `json:"rule"`
}

func (a app) queryOrders(w http.ResponseWriter, r *http.Request) {
	var q listQuery
	if !decode(w, r, &q) {
		return
	}
	if q.Page < 1 {
		q.Page = 1
	}
	if q.PageSize < 1 {
		q.PageSize = 25
	}
	if q.PageSize > 250 {
		q.PageSize = 250
	}
	if q.Search == "fail" {
		problem(w, 503, "Intentional server list failure")
		return
	}
	for _, s := range q.Sort {
		if s.Field != "id" && s.Field != "customer" && s.Field != "total" {
			problem(w, 400, "Unsupported sort field")
			return
		}
	}
	rows, err := a.loadOrders(r.Context())
	if err != nil {
		problem(w, 500, "Could not load orders")
		return
	}
	filtered := []order{}
	for _, row := range rows {
		match, err := q.Rule.matches(row)
		if err != nil {
			problem(w, 400, err.Error())
			return
		}
		if !strings.Contains(strings.ToLower(row.Customer+" "+row.ID), strings.ToLower(q.Search)) {
			continue
		}
		for _, f := range q.Filters {
			if f.Field != "customer" {
				problem(w, 400, "Unsupported column filter")
				return
			}
			match = match && strings.Contains(strings.ToLower(row.Customer), strings.ToLower(f.Contains))
		}
		if match {
			filtered = append(filtered, row)
		}
	}
	sort.SliceStable(filtered, func(i, j int) bool {
		a, b := filtered[i], filtered[j]
		for _, s := range q.Sort {
			cmp := 0
			switch s.Field {
			case "id":
				cmp = strings.Compare(a.ID, b.ID)
			case "customer":
				cmp = strings.Compare(a.Customer, b.Customer)
			case "total":
				if a.Total < b.Total {
					cmp = -1
				} else if a.Total > b.Total {
					cmp = 1
				}
			}
			if cmp != 0 {
				if s.Descending {
					return cmp > 0
				}
				return cmp < 0
			}
		}
		return a.ID < b.ID
	})
	total := len(filtered)
	start := total
	if q.Page-1 <= total/q.PageSize {
		start = min((q.Page-1)*q.PageSize, total)
	}
	end := min(start+q.PageSize, total)
	jsonReply(w, 200, struct {
		Rows  []order `json:"rows"`
		Total int     `json:"total"`
	}{filtered[start:end], total})
}
