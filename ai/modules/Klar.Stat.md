# Klar.Stat

A KPI tile: one number with its label, the change since last time, a short note and optionally a trend line.

Import: `import Klar.Stat as Stat` | Group: Data display

Types: `Attribute`

## Signatures

```elm
-- Views
view : List (Attribute msg) -> Html msg
row : List (Html msg) -> Html msg

-- Content
type Attribute msg  -- opaque: no constructors are exposed
label : String -> Attribute msg
value : String -> Attribute msg
int : Int -> Attribute msg
decimal : Int -> Float -> Attribute msg
abbreviated : Float -> Attribute msg
money : Money.Money -> Attribute msg
unit : String -> Attribute msg
caption : String -> Attribute msg
icon : Icon.Icon -> Attribute msg

-- Change since last time
delta : Float -> Attribute msg
deltaBy : Float -> Attribute msg
deltaPoints : Float -> Attribute msg
change : { current : Float, previous : Float } -> Attribute msg
moneyChange : { current : Money.Money, previous : Money.Money } -> Attribute msg
deltaText : String -> Attribute msg
deltaLabel : String -> Attribute msg
lowerIsBetter : Attribute msg
deltaTone : Theme.Tone -> Attribute msg

-- Trend
trend : List Float -> Attribute msg
trendTone : Theme.Tone -> Attribute msg

-- Look and behavior
size : Theme.Size -> Attribute msg
flat : Attribute msg
onClick : msg -> Attribute msg
id : String -> Attribute msg
locale : Locale.Locale -> Attribute msg
settings : Settings.Settings -> Attribute msg

-- Data from the backend
remote : Remote.Remote a -> (a -> List (Attribute msg)) -> Attribute msg
onRetry : msg -> Attribute msg
```

## Documentation

A KPI tile: one number with its label, the change since last time, a short
note and optionally a trend line.

Use when: a headline number is read at a glance on a dashboard or at the top of a page.
Do not use when: there are several label and value pairs, use `Klar.DescriptionList`, or one value against a scale, use `gauge` or `meter` from `Klar.Chart`.
Quick path: `view` with `label` and a number (`int`, `decimal`, `abbreviated`, `money`); data from the backend goes in through `remote` with `onRetry`.

    import Klar.Stat as Stat

    Stat.view
        [ Stat.label "Open orders"
        , Stat.int 1284
        , Stat.delta 4.2
        , Stat.deltaLabel "vs. last week"
        , Stat.trend [ 12, 14, 13, 17, 16, 19, 21 ]
        ]

    -- delivery time: down is good
    Stat.view
        [ Stat.label "Delivery time"
        , Stat.value "14"
        , Stat.unit "days"
        , Stat.delta -8.5
        , Stat.lowerIsBetter
        ]

    -- from the backend: model.shipments is a Remote { count : Int, change : Float }
    Stat.view
        [ Stat.label "Shipments"
        , Stat.onRetry Reload
        , Stat.remote model.shipments (\s -> [ Stat.int s.count, Stat.delta s.change ])
        ]

    -- tiles side by side
    Stat.row
        [ Stat.view [ Stat.label "Orders", Stat.int 1284 ]
        , Stat.view [ Stat.label "Revenue", Stat.abbreviated 4200000, Stat.unit "USD" ]
        ]

Give the number as `int`, `decimal`, `abbreviated` or `money` and the tile writes it with the
separators of its `locale` (English by default: `1,284`, `4.2M`), or pass a
string you have formatted yourself to `value`. A long number is set in a smaller
type so that it is always written out in full.

The change is a percentage (`delta`: `4.2` is shown as "+4.2%"), a difference
in the tile's own units (`deltaBy`: "+12") or, for a number that is itself a
rate, percentage points (`deltaPoints`: "+0.3 pp"). Its color follows
direction and meaning: up is good unless the tile says `lowerIsBetter`. The arrow
and a visually hidden word ("increase" or "decrease") carry the direction, so
color is never the only signal.

A tile from the backend (`remote`) can be loading (a skeleton in place of the
number) or failed (a short message with a retry link); both keep the label so the
layout does not jump. A tile with no number at all shows a dash, and screen
readers hear "No data".
With `onClick` the whole tile is a button, so it can be reached and activated
from the keyboard (except while it shows a failure: then it is a plain block, and
only its retry button is a control).

## Views

### `view`

```elm
view : List (Attribute msg) -> Html msg
```

One tile. It is a plain block, or a button when `onClick` is set (a tile that
shows a failure is always a plain block).

    Stat.view [ Stat.label "Open orders", Stat.int 1284 ]

### `row`

```elm
row : List (Html msg) -> Html msg
```

Tiles side by side in one bordered strip, divided by hairlines. Each tile is
at least 200px wide, so they wrap onto new lines in narrow containers.

    Stat.row
        [ Stat.view [ Stat.label "Orders", Stat.int 1284 ]
        , Stat.view [ Stat.label "Customers", Stat.int 312 ]
        ]

## Content

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of a tile. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `label`

```elm
label : String -> Attribute msg
```

What the number is, in sentence case and without a colon: "Open orders". It
is the heading of the tile and stays on one line; a long label is cut with an
ellipsis and its full text is the tooltip. Default: empty.

### `value`

```elm
value : String -> Attribute msg
```

The number as text that you have formatted yourself: `"1,284"`, `"87%"`,
`"14.5"`. To let the tile format it with its `locale`, use `int`, `decimal`,
`abbreviated` or `money` instead. Without any of them the tile shows a dash.

### `int`

```elm
int : Int -> Attribute msg
```

A whole number, written with the thousands separator of the tile's `locale`:
`1284` is "1,284" in English.

### `decimal`

```elm
decimal : Int -> Float -> Attribute msg
```

A number with a fixed count of decimals, in the decimal and thousands
separators of the tile's `locale`: `decimal 1 14.53` is "14.5" in English. The
number is rounded, not cut. A number that is not finite (NaN or infinity) is
shown as an en dash.

### `abbreviated`

```elm
abbreviated : Float -> Attribute msg
```

A number that shortens itself when it is large: `12900` stays "12,900", but
`4200000` becomes "4.2M". Millions are written "M", billions "B" and trillions
"T" (English). Below a million the number is written in full, with at most one
decimal. A number that is not finite (NaN or infinity) is shown as an en dash.

### `money`

```elm
money : Money.Money -> Attribute msg
```

An amount of money, written with the symbol of its currency in the conventions
of the tile's `locale` (`$1,234.50` in English, `1 234,50 kr` in Norwegian), exactly
as `Money.toSymbolString` writes it. Use it instead of formatting the amount
yourself, so that money stays `Klar.Money` all the way to the screen. A symbol can
stand for several currencies (`kr`): where more than one is on the page, give the
code with `value (Money.toString locale amount)`.

### `unit`

```elm
unit : String -> Attribute msg
```

A unit written after the number, smaller and muted: "days", "USD", "%".

### `caption`

```elm
caption : String -> Attribute msg
```

A line of explanation under the number and its change: "Excluding returns".

### `icon`

```elm
icon : Icon.Icon -> Attribute msg
```

A small icon at the right end of the label line.

## Change since last time

### `delta`

```elm
delta : Float -> Attribute msg
```

The change since last time, as a percentage: `4.2` is shown as "+4.2%" and
`-8` as "−8%" (with a true minus sign), rounded to one decimal. The sign picks the arrow and, together
with `lowerIsBetter`, the color. A change smaller than 0.05 counts as unchanged
and gets a dash. A value that is not a number (NaN or infinity) shows no change.

### `deltaBy`

```elm
deltaBy : Float -> Attribute msg
```

The change since last time as a difference in the tile's own units: `12` is
shown as "+12" and `-3.5` as "−3.5", in the separators of the `locale`. It is
written the way the tile writes its value: whole for `int`, with the same decimals
for `decimal` (`0.03` on a `decimal 2` tile is "+0.03"), abbreviated for
`abbreviated` ("+1.5M" next to "4.2M"), and otherwise rounded to one decimal. It
counts as unchanged (a dash) only when that writing rounds it to zero. Use it
when a percentage would mislead: "+12 orders" on a small count. The sign picks the
arrow and the color, as with `delta`; `delta`, `deltaBy` and `deltaPoints`
replace each other.

    Stat.view [ Stat.label "Open orders", Stat.int 112, Stat.deltaBy 12, Stat.deltaLabel "since Monday" ]

### `deltaPoints`

```elm
deltaPoints : Float -> Attribute msg
```

The change of a number that is itself a rate, in percentage points: a
conversion rate from 3.2% to 3.5% is `deltaPoints 0.3`, shown as "+0.3 pp"
("+0,3 p.p." in Norwegian). A relative change of a rate ("+9.4%") is almost never
what the reader thinks it is. The sign picks the arrow and the color, as with
`delta`.

    Stat.view [ Stat.label "Conversion", Stat.decimal 1 3.5, Stat.unit "%", Stat.deltaPoints 0.3 ]

### `change`

```elm
change : { current : Float, previous : Float } -> Attribute msg
```

The change from a previous value to the current one, worked out for you: the
same as `delta` with the percentage `(current - previous) / |previous| * 100`. When
the previous value is 0 there is no percentage: two zeros are unchanged (a dash),
and from 0 to anything else no change is shown (use `deltaText "new"` to say so),
never `NaN` or infinity.

    Stat.change { current = 3, previous = 0 } -- no change shown

    Stat.change { current = 150, previous = 120 } -- +25%

### `moneyChange`

```elm
moneyChange : { current : Money.Money, previous : Money.Money } -> Attribute msg
```

The change between two amounts of money, as a percentage, worked out in minor
units: the same as `change`, and nothing is shown when the two are in different
currencies (a percentage of two currencies means nothing) or the previous amount
is zero.

    Stat.moneyChange { current = stockValueNow, previous = stockValueLastWeek }

### `deltaText`

```elm
deltaText : String -> Attribute msg
```

The change as text of your own: "+12 orders". Pair it with `delta` to set
the arrow and the color; on its own the text is shown in neutral gray, without an
arrow.

### `deltaLabel`

```elm
deltaLabel : String -> Attribute msg
```

What the change is measured against: "vs. last week". It follows the change
and is only shown when there is one (`delta` or `deltaText`).

### `lowerIsBetter`

```elm
lowerIsBetter : Attribute msg
```

Says that a decrease is the good direction, as with delivery times, error
rates and costs: a falling number is then green and a rising one red.

### `deltaTone`

```elm
deltaTone : Theme.Tone -> Attribute msg
```

Overrides the color of the change, whatever its direction. `Neutral` is gray,
`Success`, `Warning` and `Danger` are green, amber and red. The `Tone` type is
in [Klar.Theme](Klar.Theme.md).

## Trend

### `trend`

```elm
trend : List Float -> Attribute msg
```

A small trend line under the tile, with the last values oldest first; about
12 is plenty. Nothing is drawn for fewer than two values. The line is a
`sparkline` from [Klar.Chart](Klar.Chart.md), and its accessible name is the label
followed by "trend".

### `trendTone`

```elm
trendTone : Theme.Tone -> Attribute msg
```

The color of the trend line. The default is `Primary` (blue).

## Look and behavior

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the number: `Small` (20px), `Medium` (26px, the default) or
`Large` (34px). The `Size` type is in [Klar.Theme](Klar.Theme.md). Without it the
size follows the density of the application (`Klar.Settings`): 20px when compact, 26px
when normal, 30px when comfortable.

### `flat`

```elm
flat : Attribute msg
```

No border and no background, for a tile that sits inside a card or another
bordered container. Tiles in a `row` are already drawn without a border of their
own.

### `onClick`

```elm
onClick : msg -> Attribute msg
```

Makes the whole tile a button that sends this message when it is clicked or
activated with the keyboard: for drilling down into the numbers. Without it the
tile is a plain block.

A tile that shows a failure is a plain block too, whatever `onClick` says: its
"Try again" button must not sit inside another button, and there is nothing to
drill down into. The tile is a button again when the data is back.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the tile. A tile that is not a button can then take focus from a
command in every state (loading, failed, old data, drawn): the "Try again" link is
replaced when the request starts again and focus would fall back to the page, so
call [`Klar.focus`](Klar.md#focus) with this id in the same `update`
branch. The id must be unique on the page.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text ("Loading", "Try again" and the hidden
"increase" and "decrease") and of the number format. The default is
`Locale.default`, which is English. See [Klar.Locale](Klar.Locale.md).

### `settings`

```elm
settings : Settings.Settings -> Attribute msg
```

The settings of the application (`Klar.Settings`): the time zone of the time in
"Old data from 14:05". Without it the time is written in UTC and ends in "UTC".

    Stat.settings model.settings

## Data from the backend

### `remote`

```elm
remote : Remote.Remote a -> (a -> List (Attribute msg)) -> Attribute msg
```

Takes the content of the tile from a `Remote`. While the data is `NotAsked`
or `Loading` the tile shows a skeleton, on `Failed` it shows the problem, and
when the data has arrived it applies the attributes that the function returns
for it. Data that is `Kept` stays on the tile: dimmed and busy while it is
refreshed, and with "Old data from 14:05" and a retry (`onRetry`) when the last
refresh failed. A tile with that retry is a plain block, like a failed tile.

    Stat.view
        [ Stat.label "Shipments"
        , Stat.onRetry ReloadShipments
        , Stat.remote model.shipments (\s -> [ Stat.int s.count, Stat.delta s.change ])
        ]

Attributes that do not depend on the data, such as `label`, belong next to
`remote` in the list. Several tiles can read the same `Remote`, each taking its
own numbers from it.

### `onRetry`

```elm
onRetry : msg -> Attribute msg
```

The message sent by the "Try again" link in the failure state. The link is
only shown when the problem is worth retrying (see `Klar.Remote.isRetryable` in
[Klar.Remote](Klar.Remote.md)).
