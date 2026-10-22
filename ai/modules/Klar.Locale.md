# Klar.Locale

The language and the regional conventions of the text the library writes itself: placeholders such as "Search ...", the labels of icon buttons, month names, validation messages, number separators.

Import: `import Klar.Locale as Locale` | Group: Foundations

Types: `Locale`

## Signatures

```elm
-- Choosing a language
type Locale  -- opaque: no constructors are exposed
en : Locale
nb : Locale
default : Locale
all : List Locale
pick : Locale -> { nb : a, en : a } -> a

-- Names and codes
name : Locale -> String
toCode : Locale -> String
fromCode : String -> Maybe Locale

-- Numbers
thousandSeparator : Locale -> String
decimalSeparator : Locale -> String

-- Calendar
firstDayOfWeek : Locale -> Int
monthName : Locale -> Int -> String
monthShort : Locale -> Int -> String
weekdayLong : Locale -> Int -> String
weekdayShort : Locale -> Int -> String
```

## Documentation

The language and the regional conventions of the text the library writes
itself: placeholders such as "Search ...", the labels of icon buttons, month
names, validation messages, number separators.

    import Klar.Locale as Locale exposing (Locale)

    Locale.pick model.locale { nb = "Neste", en = "Next" }

Every component that has built-in text of its own has a `locale` attribute; the
default is `Locale.default`, which is English:

    Select.view CountryMsg [ Select.locale Locale.nb ] model.country

Two languages are built in: English (`Locale.en`) and Norwegian Bokmål
(`Locale.nb`). The type is opaque, so that more languages can be added in a later
version without breaking your code. Text of your application never goes through
the library: your own labels, column titles and messages come from your
application, and `pick` is just a convenient way to choose between two of them.

Switch the language of a whole page by keeping a `Locale` in your model and
passing it to every component; `Klar.AppShell` also sets the `lang` attribute of
the page content from it, which screen readers use to choose the voice.

## Choosing a language

### `Locale`

```elm
type Locale  -- opaque: no constructors are exposed
```

The language of the built-in text. Make one with `en` or `nb`, or read it
from a language code with `fromCode`.

### `en`

```elm
en : Locale
```

English. This is the default.

### `nb`

```elm
nb : Locale
```

Norwegian Bokmål.

### `default`

```elm
default : Locale
```

The language used when nothing else is said: English.

### `all`

```elm
all : List Locale
```

Every language, for a language switcher.

### `pick`

```elm
pick : Locale -> { nb : a, en : a } -> a
```

Chooses between a Norwegian and an English text. A language that is added in
a later version and has no text here gets the English one.

    Locale.pick Locale.en { nb = "Lagre", en = "Save" } -- "Save"

## Names and codes

### `name`

```elm
name : Locale -> String
```

The name of a language, in that language: for a language switcher.

    Locale.name Locale.nb -- "Norsk (bokmål)"

    Locale.name Locale.en -- "English"

### `toCode`

```elm
toCode : Locale -> String
```

The language code for the `lang` attribute: `"en"` or `"nb"`.

### `fromCode`

```elm
fromCode : String -> Maybe Locale
```

Reads a language code, ignoring case. `"no"` is taken as Bokmål, like most
browsers do. Use it on `navigator.language` that your application gets in its
flags, or on a stored setting.

    Locale.fromCode "nb" -- Just Locale.nb

    Locale.fromCode "EN" -- Just Locale.en

    Locale.fromCode "sv" -- Nothing

## Numbers

### `thousandSeparator`

```elm
thousandSeparator : Locale -> String
```

What separates groups of three digits: a comma in English and a
non-breaking space in Norwegian.

### `decimalSeparator`

```elm
decimalSeparator : Locale -> String
```

What separates the decimals: a point in English and a comma in Norwegian.

## Calendar

### `firstDayOfWeek`

```elm
firstDayOfWeek : Locale -> Int
```

The first day of the week in calendars, from 1 (Monday) to 7 (Sunday).
Both languages start the week on Monday, like ISO 8601.

### `monthName`

```elm
monthName : Locale -> Int -> String
```

The name of a month, from 1 (January) to 12 (December); an empty text for
any other number.

    Locale.monthName Locale.en 3 -- "March"

    Locale.monthName Locale.nb 3 -- "mars"

### `monthShort`

```elm
monthShort : Locale -> Int -> String
```

The short name of a month: `Mar` or `mar`.

### `weekdayLong`

```elm
weekdayLong : Locale -> Int -> String
```

The name of a day of the week, from 1 (Monday) to 7 (Sunday).

    Locale.weekdayLong Locale.en 2 -- "Tuesday"

### `weekdayShort`

```elm
weekdayShort : Locale -> Int -> String
```

The short name of a day of the week, from 1 (Monday) to 7 (Sunday): `Mo` or
`ma`.
