# Klar.Format

Formatting numbers, sizes, dates and times for people, in the conventions of a `Locale`.

Import: `import Klar.Format as Format` | Group: Data and utilities

## Signatures

```elm
-- Numbers
int : Locale.Locale -> Int -> String
decimal : Locale.Locale -> Int -> Float -> String
percent : Locale.Locale -> Int -> Float -> String
currency : Locale.Locale -> String -> Int -> Float -> String
plural : Locale.Locale -> Int -> { one : String, other : String } -> String

-- Sizes and durations
bytes : Locale.Locale -> Int -> String
duration : Locale.Locale -> Int -> String

-- Dates and times
date : Locale.Locale -> Date.Date -> String
dateLong : Locale.Locale -> Date.Date -> String
time : Time.Zone -> Time.Posix -> String
dateTime : Locale.Locale -> Time.Zone -> Time.Posix -> String
iso8601 : Time.Posix -> String
relative : Locale.Locale -> Time.Posix -> Time.Posix -> String
```

## Documentation

Formatting numbers, sizes, dates and times for people, in the conventions of
a `Locale`.

Use when: the application shows numbers, sizes, dates or times to people.
Do not use when: the text is a machine format (use `iso8601` for a date in data, or the plain value).

    import Klar.Format as Format
    import Klar.Locale exposing (Locale(..))

    Format.int Locale.en 1234567 -- "1,234,567"

    Format.decimal Locale.en 2 1234.5 -- "1,234.50"

    Format.percent Locale.en 1 0.127 -- "12.7%"

    Format.currency Locale.en "$" 2 1234.5 -- "$1,234.50"

    Format.bytes Locale.en 1536000 -- "1.5 MB"

    Format.duration Locale.en 125000 -- "2 min 5 s"

    Format.date Locale.en october20 -- "2026-10-20" (the date 20 October 2026)

    Format.int Locale.nb 1234567 -- "1 234 567" (with non-breaking spaces)

    Format.decimal Locale.nb 2 1234.5 -- "1 234,50"

Numbers are formatted from their shortest decimal text, not by multiplying and
rounding floating point numbers, so what you see is what a person would round
by hand: `Format.decimal Locale.en 2 1.005` is `"1.01"` and `Format.percent Locale.en 0 0.145`
is `"15%"`. Rounding is half away from zero. Negative numbers get a real minus
sign (U+2212), and a number that rounds to zero is never shown as negative.

Numbers and units are separated by non-breaking spaces, so a value never breaks
over two lines.

Text a person reads that depends on the language ("minutes ago", "Jan") comes
in English and Norwegian Bokmål; the rest of the world gets the English text
until more languages are added.

## Numbers

### `int`

```elm
int : Locale.Locale -> Int -> String
```

A whole number with thousands separators: a comma in English, a
non-breaking space in Norwegian.

    Format.int Locale.en 1234567 -- "1,234,567"

    Format.int Locale.en -1000 -- "−1,000"

### `decimal`

```elm
decimal : Locale.Locale -> Int -> Float -> String
```

A number with a fixed count of decimals (0 to 20), rounded half away from
zero.

    Format.decimal Locale.en 2 1234.5 -- "1,234.50"

    Format.decimal Locale.en 0 2.5 -- "3"

    Format.decimal Locale.en 1 -0.04 -- "0.0"

    Format.decimal Locale.nb 2 1234.5 -- "1 234,50"

`NaN` is written `NaN` and the infinities `∞` and `−∞`.

### `percent`

```elm
percent : Locale.Locale -> Int -> Float -> String
```

A ratio as a percentage: `0.127` is 12.7 percent. The decimals are those of
the percentage. The English text has no space before the percent sign, the
Norwegian one a non-breaking space.

    Format.percent Locale.en 0 0.127 -- "13%"

    Format.percent Locale.en 1 0.127 -- "12.7%"

    Format.percent Locale.nb 1 0.127 -- "12,7 %"

### `currency`

```elm
currency : Locale.Locale -> String -> Int -> Float -> String
```

An amount of money. The first argument after the locale is what to show for
the currency, a symbol or a code, as you want it written. English puts it in
front of the number, Norwegian after it.

An ISO 4217 code that has a well-known symbol is written with the symbol (`"USD"`
becomes `$`, `"EUR"` `€`, `"NOK"` `kr`; the table is the one `Klar.Money` uses). Any other
text is written as given, and a text that ends in a letter (a code, `"kr"`) is
separated from the number by a non-breaking space, so that it never reads
`USD645.15`.

    Format.currency Locale.en "$" 2 1234.5 -- "$1,234.50"

    Format.currency Locale.en "USD" 2 645.15 -- "$645.15"

    Format.currency Locale.en "CHF" 2 645.15 -- "CHF 645.15" (non-breaking space)

    Format.currency Locale.en "$" 2 -3 -- "−$3.00"

    Format.currency Locale.nb "kr" 2 1234.5 -- "1 234,50 kr"

    Format.currency Locale.nb "NOK" 2 1234.5 -- "1 234,50 kr"

    Format.currency Locale.en "JPY " 0 1500 -- "JPY 1,500"

### `plural`

```elm
plural : Locale.Locale -> Int -> { one : String, other : String } -> String
```

Chooses the singular or plural form for a count.

    Format.int Locale.en 3 ++ " " ++ Format.plural Locale.en 3 { one = "order", other = "orders" } -- "3 orders"

## Sizes and durations

### `bytes`

```elm
bytes : Locale.Locale -> Int -> String
```

A size in bytes, with the decimal prefixes (1 kB is 1000 bytes), one decimal
above a kilobyte.

    Format.bytes Locale.en 512 -- "512 B"

    Format.bytes Locale.en 1536000 -- "1.5 MB"

    Format.bytes Locale.nb 2400 -- "2,4 kB"

### `duration`

```elm
duration : Locale.Locale -> Int -> String
```

A length of time in milliseconds, written with the two largest units that
matter.

    Format.duration Locale.en 340 -- "340 ms"

    Format.duration Locale.en 1200 -- "1.2 s"

    Format.duration Locale.en 125000 -- "2 min 5 s"

    Format.duration Locale.en 3720000 -- "1 h 2 min"

    Format.duration Locale.en 200000000 -- "2 d 7 h"

Negative durations are written with a minus sign.

## Dates and times

### `date`

```elm
date : Locale.Locale -> Date.Date -> String
```

A date in the short numeric form of the language: `20.10.2026` in
Norwegian, and the unambiguous ISO form `2026-10-20` in English.

    Format.date Locale.en october20 -- "2026-10-20"

    Format.date Locale.nb october20 -- "20.10.2026"

### `dateLong`

```elm
dateLong : Locale.Locale -> Date.Date -> String
```

The date with the month spelled out: `20 October 2026` in English and
`20. oktober 2026` in Norwegian.

### `time`

```elm
time : Time.Zone -> Time.Posix -> String
```

The time of day on a 24-hour clock, in a time zone: `14:05`.

    Time.here |> Task.andThen (\zone -> Task.map (Format.time zone) Time.now)

### `dateTime`

```elm
dateTime : Locale.Locale -> Time.Zone -> Time.Posix -> String
```

The date and the time: `2026-10-20 14:05` in English, `20.10.2026 14:05` in
Norwegian.

### `iso8601`

```elm
iso8601 : Time.Posix -> String
```

A moment as the text that APIs and logs use: ISO 8601 in UTC, to the second,
`2026-10-22T14:05:00Z`. It does not depend on a locale or a time zone. Milliseconds
are left out.

    Format.iso8601 (Time.millisToPosix 0) -- "1970-01-01T00:00:00Z"

### `relative`

```elm
relative : Locale.Locale -> Time.Posix -> Time.Posix -> String
```

How long ago something happened, or how long until it does, relative to
the current time. Pass the current time first, then the time of the event.

    Format.relative Locale.en now fiveMinutesAgo -- "5 minutes ago"

    Format.relative Locale.en now threeDaysAgo -- "3 days ago"

    Format.relative Locale.en now inTwoHours -- "in 2 hours"

    Format.relative Locale.nb now fiveMinutesAgo -- "for 5 minutter siden"

Within the same 45 seconds the answer is "just now" (or "in a moment"); beyond
that the largest fitting unit is used, rounded down: minutes, hours, days,
months of 30 days, years of 365 days.
