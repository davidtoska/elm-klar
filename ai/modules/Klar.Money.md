# Klar.Money

An exact amount of money: a whole number of minor units (øre, cents, yen) together with its currency.

Import: `import Klar.Money as Money` | Group: Inputs

Types: `Money`, `Problem`, `Currency`

## Signatures

```elm
-- Amounts
type Money  -- opaque: no constructors are exposed
fromMinor : Currency -> Int -> Maybe Money
fromMajorAndMinor : Currency -> Int -> Int -> Maybe Money
zero : Currency -> Money
toMinor : Money -> Int
currencyOf : Money -> Currency

-- Currencies
type Currency  -- opaque: no constructors are exposed
currency : String -> Maybe Currency
currencyCode : Currency -> String
decimals : Currency -> Int
symbol : Currency -> String
isActive : Currency -> Bool
allCurrencies : List Currency
nok : Currency
sek : Currency
dkk : Currency
isk : Currency
eur : Currency
usd : Currency
gbp : Currency
chf : Currency
jpy : Currency
cad : Currency
aud : Currency
cny : Currency

-- Calculating
add : Money -> Money -> Result Problem Money
subtract : Money -> Money -> Result Problem Money
sum : Currency -> List Money -> Result Problem Money
multiply : Int -> Money -> Result Problem Money
percentOf : Int -> Money -> Result Problem Money
fraction : Int -> Int -> Money -> Result Problem Money
allocate : List Int -> Money -> Result Problem (List Money)
split : Int -> Money -> Result Problem (List Money)
negate : Money -> Money
abs : Money -> Money

-- Comparing
compare : Money -> Money -> Order
isZero : Money -> Bool
isPositive : Money -> Bool
isNegative : Money -> Bool

-- Reading and writing
parse : Locale.Locale -> Currency -> String -> Result Problem Money
parseRounded : Locale.Locale -> Currency -> String -> Result Problem Money
toString : Locale.Locale -> Money -> String
toSymbolString : Locale.Locale -> Money -> String
toAmountString : Locale.Locale -> Money -> String
toDecimalString : Money -> String
fromDecimalString : Currency -> String -> Result Problem Money

-- Problems
type Problem  -- opaque: no constructors are exposed
problemText : Locale.Locale -> Problem -> String
```

## Documentation

An exact amount of money: a whole number of minor units (øre, cents, yen)
together with its currency. There is no `Float` in it, so there is no 0.1 + 0.2.

Use when: every amount of money the application keeps, adds or splits, in an exact currency.
Do not use when: the user types the amount (`Klar.MoneyInput`) or the number is not money, such as a quantity or a percentage (`Klar.NumberInput`).

    import Klar.Locale as Locale
    import Klar.Money as Money exposing (Money)

    price : Money
    price =
        Money.fromMinor Money.nok 123450
            |> Maybe.withDefault (Money.zero Money.nok)

    Money.toString Locale.nb price -- "1 234,50 NOK"

    Money.toString Locale.en price -- "NOK 1,234.50"

    Money.percentOf 25 price -- Ok 308.63 NOK: 308.625 rounded half away from zero

    Money.split 3 price -- Ok [ 411.50, 411.50, 411.50 ]

Use this module for every amount an application keeps, adds or splits, and
[Klar.MoneyInput](Klar.MoneyInput.md) to let a person type one. Use
[Klar.NumberInput](Klar.NumberInput.md) for a quantity, a percentage or a weight: a
number that is not money.

**The currency is part of the amount.** `Money.add` of 10 NOK and 10 EUR is an
`Err`, not 20 of something. The currency is a value (`Money.nok`, or
`Money.currency "KWD"` for a code that comes from data) and not a phantom type,
because the currency of an invoice is only known when the program runs. Every
currency of the active ISO 4217 list is there (`allCurrencies`), with its number of
decimals, which is two for NOK and USD, none for JPY and three for KWD. The two that ended most
recently, the Netherlands Antillean guilder (ANG) and the Bulgarian lev (BGN), can
still be read from old data with `currency` and are not active (`isActive`).

**Rounding is what a person does by hand.** Whenever an amount has to be rounded
(a percentage of an amount, a ratio) a half goes away from zero: 0.5 øre becomes 1,
and -0.5 becomes -1. The function says so by its name; nothing is rounded behind
your back. Text with too many decimals (`parse`) is refused, and `parseRounded`
rounds it when you ask.

**Splitting never loses a unit.** `allocate` and `split` give out the minor units
that do not divide evenly one by one, so the parts add up to the amount. They, and
`fraction`, are exact for any numbers in the range below: the working never leaves it.

**Whole numbers up to 9 007 199 254 740 991 minor units** (90 trillion in the main
unit of a currency with two decimals) are exact in every browser. Beyond that
Elm's `Int` silently gives wrong answers, so an amount outside that range cannot be
made: `fromMinor` says `Nothing`, and a calculation that leaves the range says
`Err`.

Amounts can be compared with `==`: two amounts are equal when the currency and the
number of minor units are. A `Money` is not `comparable`, so it cannot be a `Dict` key
or a `Set` member; use `( currencyCode (currencyOf amount), toMinor amount )` for that.
Sort with `List.sortWith Money.compare`.

The built-in texts (`problemText`, the number format) follow a
[Klar.Locale](Klar.Locale.md).

## Amounts

### `Money`

```elm
type Money  -- opaque: no constructors are exposed
```

An amount of money in one currency. Make one with `fromMinor`,
`fromMajorAndMinor`, `zero` or `parse`.

### `fromMinor`

```elm
fromMinor : Currency -> Int -> Maybe Money
```

The amount `minor` of the smallest unit of a currency: `Money.fromMinor
Money.nok 12550` is 125.50 NOK, and `Money.fromMinor Money.jpy 500` is 500 yen.
`Nothing` when the number is beyond 9 007 199 254 740 991 in either direction,
where whole numbers stop being exact.

### `fromMajorAndMinor`

```elm
fromMajorAndMinor : Currency -> Int -> Int -> Maybe Money
```

An amount from its main and its minor part: `Money.fromMajorAndMinor
Money.nok 125 50` is 125.50 NOK. Neither part may be negative (use `negate` for a
negative amount) and the minor part must be smaller than a main unit: below 100 for
NOK, 1 000 for KWD, and 0 for JPY. `Nothing` otherwise, and when the amount is too
large.

### `zero`

```elm
zero : Currency -> Money
```

No money in a currency.

### `toMinor`

```elm
toMinor : Money -> Int
```

The number of minor units: 12550 for 125.50 NOK, negative for a debt. Use it
to store an amount or to send it to a server; `Money.fromMinor` reads it back.

### `currencyOf`

```elm
currencyOf : Money -> Currency
```

The currency of an amount.

## Currencies

### `Currency`

```elm
type Currency  -- opaque: no constructors are exposed
```

A currency: its ISO 4217 code and the number of decimals of its minor unit.
Make one with `currency`, or take a common one such as `nok`.

### `currency`

```elm
currency : String -> Maybe Currency
```

The currency with an ISO 4217 code such as `"NOK"`; lower case and spaces around
the code are fine. `Nothing` for a code that is not an ISO 4217 currency. The active
currencies (`allCurrencies`) are found, and so are the two that ended most recently,
the Netherlands Antillean guilder (`"ANG"`, replaced by `"XCG"` on 2025-03-31) and the
Bulgarian lev (`"BGN"`, ended with Bulgaria's joining of the euro on 2026-01-01), so
that old data can be read. Check `isActive` before you offer one of them in a choice.

    Money.currency "kwd" |> Maybe.map Money.decimals -- Just 3

    Money.currency "BTC" -- Nothing

### `currencyCode`

```elm
currencyCode : Currency -> String
```

The three-letter ISO 4217 code: `"NOK"`.

### `decimals`

```elm
decimals : Currency -> Int
```

How many digits the minor unit of the currency has: 2 for NOK, USD and EUR
(100 øre, 100 cents), 0 for JPY, 3 for KWD.

### `symbol`

```elm
symbol : Currency -> String
```

The symbol people write for the currency (`"kr"`, `"$"`, `"€"`), or its code when
there is no symbol they all know. A symbol can be shared (`kr` is NOK, SEK, DKK and
ISK), so in a list of amounts in several currencies use the code.

### `isActive`

```elm
isActive : Currency -> Bool
```

Is the currency on the active ISO 4217 list? `False` for a currency that was
withdrawn and can only be read from old data: `Money.currency "BGN"` gives one.

### `allCurrencies`

```elm
allCurrencies : List Currency
```

Every currency of the active ISO 4217 list, sorted by code, for a list to choose a
currency from. It follows the list that SIX, the maintenance agency, published on
2026-09-17. Withdrawn currencies, precious metals, test codes and units of account that
have no minor unit are not in it.

### `nok`

```elm
nok : Currency
```

Norwegian krone.

### `sek`

```elm
sek : Currency
```

Swedish krona.

### `dkk`

```elm
dkk : Currency
```

Danish krone.

### `isk`

```elm
isk : Currency
```

Icelandic króna, which has no minor unit in use.

### `eur`

```elm
eur : Currency
```

Euro.

### `usd`

```elm
usd : Currency
```

United States dollar.

### `gbp`

```elm
gbp : Currency
```

Pound sterling.

### `chf`

```elm
chf : Currency
```

Swiss franc.

### `jpy`

```elm
jpy : Currency
```

Japanese yen, which has no minor unit.

### `cad`

```elm
cad : Currency
```

Canadian dollar.

### `aud`

```elm
aud : Currency
```

Australian dollar.

### `cny`

```elm
cny : Currency
```

Chinese yuan (renminbi).

## Calculating

### `add`

```elm
add : Money -> Money -> Result Problem Money
```

Two amounts added. `Err` when they are in different currencies, or when the sum
is beyond what whole numbers hold exactly.

    Money.add a b -- Ok (a and b added)

    Money.add tenNok tenEur -- Err (Cannot mix NOK and EUR)

### `subtract`

```elm
subtract : Money -> Money -> Result Problem Money
```

The second amount taken from the first. `Err` when they are in different
currencies, or when the result is beyond what whole numbers hold exactly.

### `sum`

```elm
sum : Currency -> List Money -> Result Problem Money
```

The total of a list of amounts in the given currency, which is also the answer
for an empty list. `Err` when one of the amounts is in another currency, or when the
total is out of range.

    Money.sum Money.nok (List.map .price lines)

### `multiply`

```elm
multiply : Int -> Money -> Result Problem Money
```

An amount times a whole number: three of a 125.50 NOK article. A negative factor
gives a negative amount. `Err` when the result is out of range.

### `percentOf`

```elm
percentOf : Int -> Money -> Result Problem Money
```

A whole number of percent of an amount, rounded half away from zero to the
minor unit: 25 percent of 1 234.50 NOK is 308.63 NOK (308.625 rounds up). Use it
for VAT and discounts. For a percentage with decimals use `fraction`: 12.5 percent
is `Money.fraction 125 1000`. `Err` when the result is out of range.

    Money.percentOf 25 price

### `fraction`

```elm
fraction : Int -> Int -> Money -> Result Problem Money
```

A fraction of an amount: `Money.fraction 3 8 amount` is three eighths of it. It
is rounded half away from zero to the minor unit, so 2.5 øre becomes 3 and -2.5
becomes -3. The numerator may be negative; the denominator must be above zero.

The working keeps everything exact: it never forms the product of the amount and the
numerator, which could be far beyond the range of whole numbers, so any numerator and
denominator in that range work, such as an exchange rate written as a ratio of two
large whole numbers, and only the result must stay inside the range. The VAT inside a
price that includes it, at 25 percent, is `Money.fraction 25 125 price`.

`Err` when the denominator is not above zero, or when a number is out of range.

### `allocate`

```elm
allocate : List Int -> Money -> Result Problem (List Money)
```

Divides an amount into parts in proportion to the weights, so that the parts
always add up to the amount. 100.00 NOK with the weights `[ 1, 1, 1 ]` is 33.34,
33.33 and 33.33. With `[ 50, 30, 20 ]` it is 50.00, 30.00 and 20.00.

Each part is the share rounded down to the minor unit. The units left over go, one
each, to the parts with the biggest fractions, and to the earlier part when two are
equal. A part with the weight 0 gets nothing. A negative amount is divided the same
way, so the parts of -100.00 are -33.34, -33.33 and -33.33.

The shares are exact for any weights, however large, as long as the weights add up to
no more than 9 007 199 254 740 991 (the range of whole numbers, 90 trillion in the main
unit of a currency with two decimals); they are scaled with exact arithmetic, never by
a product that could leave the range. `Err` when there are no weights, when one is
negative, when they all are 0, or when they add up to more than that.

### `split`

```elm
split : Int -> Money -> Result Problem (List Money)
```

An amount in equal parts, the first parts a minor unit larger when it does not
divide: `Money.split 3` of 100.00 NOK is 33.34, 33.33 and 33.33. It is
`allocate` with equal weights. `Err` when the number of parts is below 1 or above
100 000.

### `negate`

```elm
negate : Money -> Money
```

The same amount with the opposite sign.

### `abs`

```elm
abs : Money -> Money
```

The amount without its sign.

## Comparing

### `compare`

```elm
compare : Money -> Money -> Order
```

An order for sorting. Amounts in the same currency are ordered by their value.
Amounts in different currencies are ordered by the currency code, so a mixed list
sorts into groups; it says nothing about which is worth more. Use it as
`List.sortWith Money.compare`.

### `isZero`

```elm
isZero : Money -> Bool
```

Is this no money at all?

### `isPositive`

```elm
isPositive : Money -> Bool
```

Is this more than nothing?

### `isNegative`

```elm
isNegative : Money -> Bool
```

Is this less than nothing, a debt or a credit?

## Reading and writing

### `parse`

```elm
parse : Locale.Locale -> Currency -> String -> Result Problem Money
```

Reads an amount the way a person writes it, in a currency. It reads like
[`NumberInput.parseIn`](Klar.NumberInput.md#parsein): `,` and `.` are both a decimal
separator, spaces and no-break spaces are ignored, and `1.234,56` and `1,234.56` are
both 1234.56. The language decides what a lone comma before three digits means:
`1,234` is 1234 in English and 1.234 in Norwegian; a lone point between groups of
three digits is a thousands separator in Norwegian (`10.000` is ten thousand) and
a decimal point in English.

On top of that it takes away the code and the symbol of the currency (`NOK 1 234`,
`1 234,50 kr`, `$100` in a field for USD), a leading `-`, `−` or `+`, parentheses for
a negative amount (`(100,00)`), and the Norwegian ending `,-`.

It never rounds and never guesses. The result is an `Err` for text that is not an
amount, for more decimals than the currency has (`100,505` NOK: use `parseRounded`
to round it; `100,500` is fine, it is the same amount), for separators that cannot
be read (`1.2.3`), for a comma before three digits in English in a currency with
three decimals (`1,234` KWD could be a thousand or one and a bit), for an amount of
another currency (`$100` in a NOK field) and for an amount out of range. Thousands are
grouped by three: the Indian grouping `1,23,456` is not read, and is refused as unclear
(write `123456` or `123,456`).

    Money.parse Locale.nb Money.nok "1 234,50" -- Ok 1234.50 NOK

    Money.parse Locale.en Money.nok "1,234.50" -- Ok 1234.50 NOK

    Money.parse Locale.en Money.jpy "¥1,500" -- Ok 1500 JPY

    Money.parse Locale.nb Money.nok "(100)" -- Ok -100.00 NOK

    Money.parse Locale.en Money.nok "12.505" -- Err (NOK has 2 decimals)

### `parseRounded`

```elm
parseRounded : Locale.Locale -> Currency -> String -> Result Problem Money
```

Like `parse`, but text with more decimals than the currency has is rounded to
the minor unit, half away from zero (`12.505` NOK is 12.51 and `-12.505` is -12.51).
Use it where rounding is what you want, such as an import of prices from a
spreadsheet; use `parse` where a person types and must be told.

### `toString`

```elm
toString : Locale.Locale -> Money -> String
```

The amount with its code, the way `Klar.Format.currency` writes an amount: the
number format of the language, a real minus sign, and no-break spaces so that an
amount never breaks over two lines. The code is the same in every language, so it
cannot be mistaken for another currency.

    Money.toString Locale.nb price -- "1 234,50 NOK"

    Money.toString Locale.en price -- "NOK 1,234.50"

    Money.toString Locale.en (Money.negate price) -- "−NOK 1,234.50"

### `toSymbolString`

```elm
toSymbolString : Locale.Locale -> Money -> String
```

Like `toString`, with the symbol of the currency instead of its code, when it
has one that people know (`1 234,50 kr`, `$1,234.50`, `€1,234.50`). A symbol can
stand for several currencies (`kr`), so use `toString` where more than one currency
is on the page.

### `toAmountString`

```elm
toAmountString : Locale.Locale -> Money -> String
```

Only the number, with the grouping and decimals of the language and no currency:
for a column of a table whose header says which currency it is, or for a field.

    Money.toAmountString Locale.nb price -- "1 234,50"

    Money.toAmountString Locale.en price -- "1,234.50"

### `toDecimalString`

```elm
toDecimalString : Money -> String
```

The amount as a machine reads it, whatever the language: no thousands
separators, a `.` before the decimals, a `-` for a negative amount, and exactly as
many decimals as the currency has. Use it for a JSON document or a CSV file;
`fromDecimalString` reads it back.

    Money.toDecimalString price -- "1234.50"

### `fromDecimalString`

```elm
fromDecimalString : Currency -> String -> Result Problem Money
```

Reads an amount that a machine wrote: an optional `-`, digits, and an optional
`.` with digits, nothing else (`"1234.50"`, `"-0.5"`, `"1500"`): what `toDecimalString`
writes. No thousands separators, no currency, no leniency. Use it for a field of a
JSON document or a CSV file; use `parse` for text a person typed.

## Problems

### `Problem`

```elm
type Problem  -- opaque: no constructors are exposed
```

Why an amount could not be made or a calculation could not be done: the text is
not an amount, it has more decimals than the currency, the currencies are mixed, the
number is too large. It is opaque so that a new kind of problem is not a breaking
change; `problemText` says it in words.

### `problemText`

```elm
problemText : Locale.Locale -> Problem -> String
```

A problem in words, in the language: "NOK has 2 decimals", "Cannot mix NOK and
EUR". It is meant for a person who typed an amount and for a log.

    Money.parse Locale.en Money.nok "12.505"
        |> Result.mapError (Money.problemText Locale.en)
    -- Err "NOK has 2 decimals"
