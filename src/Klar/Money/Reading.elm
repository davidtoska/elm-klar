module Klar.Money.Reading exposing
    ( Failure(..)
    , Reading
    , read
    )

{-| Reads the text of an amount: the way a person writes one, in a field or in a
spreadsheet that was pasted. It produces the sign, the digits before the decimal
separator and the digits after it, as text. Turning those into minor units, and
saying whether there are too many decimals for a currency, is `Klar.Money`'s job.

It reads like `NumberInput.parseIn`:

  - `,` and `.` are both a decimal separator when there is only one of them;
  - two kinds together (`1.234,56`, `1,234.56`) are read with the last as the decimal
    separator and the other as the thousands separator, which must then be well
    placed (groups of exactly three);
  - the same separator several times (`1.234.567`) is a thousands separator;
  - spaces, no-break spaces and apostrophes are ignored;
  - a lone comma before exactly three digits is a thousands separator in a language
    that groups with a comma (English), as in `1,234`;
  - a lone separator that is not the decimal separator of the language, before
    digits grouped like thousands (`10.000` in Norwegian), is refused as unclear: many
    people write ten thousand that way, others write ten, and the two readings are a
    thousand times apart.

On top of that, an amount has things around it that a number has not: the currency
(its code, its symbol, the other ways it is written), a minus sign, plus sign or
parentheses, and the Norwegian ending `,-`. Anything of another currency is not taken
away, so it stays and the text is not an amount.

-}


{-| What was read: `-` or not, the digits before the separator (without thousands
separators, possibly empty) and the digits after it (possibly empty).
-}
type alias Reading =
    { negative : Bool
    , whole : String
    , fraction : String
    }


{-| Why the text is not an amount: it is empty, it is something else, or it has
separators that cannot be read with certainty. `UnclearGrouping` is the lone
separator of `10.000` in a language whose decimal separator is a comma.
-}
type Failure
    = Blank
    | NotAnAmount
    | UnclearSeparators
    | UnclearGrouping


{-| Reads the text.

  - `grouping` is the thousands separator of the language when it is a `,` or a `.`
    (a comma in English), otherwise `Nothing`.
  - `decimal` is the decimal separator of the language when it is a `,` or a `.` (a
    point in English, a comma in Norwegian), otherwise `Nothing`.
  - `decimals` is the number of decimals of the currency. With three or more, the
    thousands separator of the language before exactly three digits (`1,234` in
    English) can be a thousands separator or a decimal one, and both are an amount,
    so the text is `UnclearSeparators`.
  - `marks` are the strings that may stand around the amount: the currency code, its
    symbols.

-}
read : { grouping : Maybe Char, decimal : Maybe Char, decimals : Int, marks : List String } -> String -> Result Failure Reading
read config raw =
    if String.trim raw == "" then
        Err Blank

    else
        case peel config.marks { text = String.trim raw, signs = 0, negative = False, marked = False, noFraction = False } of
            Nothing ->
                Err NotAnAmount

            Just peeled ->
                let
                    body =
                        String.filter (\c -> not (isIgnored c)) peeled.text
                in
                if peeled.signs > 1 || not (String.all (\c -> Char.isDigit c || isSeparator c) body) || not (String.any Char.isDigit body) then
                    Err NotAnAmount

                else
                    splitDigits config peeled.noFraction body
                        |> Result.map
                            (\( whole, fraction ) ->
                                { negative = peeled.negative
                                , whole = whole
                                , fraction = fraction
                                }
                            )



-- AROUND THE AMOUNT


type alias Peeled =
    { text : String

    -- the number of signs and parentheses found; one is an amount with a sign,
    -- more than one is not an amount
    , signs : Int
    , negative : Bool

    -- a currency code or symbol has been taken away
    , marked : Bool

    -- the Norwegian `,-`: no decimals, so no separator is a decimal separator
    , noFraction : Bool
    }


{-| Takes away what stands around the amount, one thing at a time, until nothing is
left to take. `Nothing` when a currency mark is found twice.
-}
peel : List String -> Peeled -> Maybe Peeled
peel marks state =
    let
        text =
            String.trim state.text

        sign negative rest =
            peel marks { state | text = rest, signs = state.signs + 1, negative = state.negative || negative }
    in
    case String.uncons text of
        Just ( '+', rest ) ->
            sign False rest

        Just ( '-', rest ) ->
            sign True rest

        Just ( '−', rest ) ->
            sign True rest

        Just ( '–', rest ) ->
            sign True rest

        Just ( '(', rest ) ->
            if String.endsWith ")" rest then
                sign True (String.dropRight 1 rest)

            else
                Just { state | text = text }

        _ ->
            case ( dropMarkAtStart marks text, dropMarkAtEnd marks text ) of
                ( Just rest, _ ) ->
                    if state.marked then
                        Nothing

                    else
                        peel marks { state | text = rest, marked = True }

                ( Nothing, Just rest ) ->
                    if state.marked then
                        Nothing

                    else
                        peel marks { state | text = rest, marked = True }

                ( Nothing, Nothing ) ->
                    case dropNoFraction text of
                        Just rest ->
                            peel marks { state | text = rest, noFraction = True }

                        Nothing ->
                            Just { state | text = text }


dropMarkAtStart : List String -> String -> Maybe String
dropMarkAtStart marks text =
    let
        lowered =
            String.toLower text
    in
    marks
        |> List.filter (\mark -> String.startsWith (String.toLower mark) lowered)
        |> List.head
        |> Maybe.map (\mark -> String.dropLeft (String.length mark) text)


dropMarkAtEnd : List String -> String -> Maybe String
dropMarkAtEnd marks text =
    let
        lowered =
            String.toLower text
    in
    marks
        |> List.filter (\mark -> String.endsWith (String.toLower mark) lowered)
        |> List.head
        |> Maybe.map (\mark -> String.dropRight (String.length mark) text)


{-| The Norwegian way to write an amount without decimals: `1 234,-`.
-}
dropNoFraction : String -> Maybe String
dropNoFraction text =
    [ ",-", ".-", ",–", ".–", ",—" ]
        |> List.filter (\ending -> String.endsWith ending text)
        |> List.head
        |> Maybe.map (\ending -> String.dropRight (String.length ending) text)


isIgnored : Char -> Bool
isIgnored c =
    c == ' ' || c == '\u{00A0}' || c == '\u{202F}' || c == '\u{2009}' || c == '\t' || c == '\'' || c == '’'


isSeparator : Char -> Bool
isSeparator c =
    c == ',' || c == '.'



-- SEPARATORS


{-| The digits before and after the decimal separator, from a body that holds only
digits and separators.
-}
splitDigits : { a | grouping : Maybe Char, decimal : Maybe Char, decimals : Int } -> Bool -> String -> Result Failure ( String, String )
splitDigits config noFraction body =
    case List.reverse (List.filter isSeparator (String.toList body)) of
        [] ->
            Ok ( body, "" )

        lastSeparator :: earlier ->
            case uniqueChars earlier of
                [] ->
                    onlySeparator config noFraction lastSeparator body

                [ thousands ] ->
                    if noFraction then
                        if thousands == lastSeparator && wellGrouped thousands body then
                            Ok ( digitsOf body, "" )

                        else
                            Err UnclearSeparators

                    else if thousands /= lastSeparator then
                        let
                            ( whole, fraction ) =
                                splitAtLast lastSeparator body
                        in
                        if wellGrouped thousands whole then
                            Ok ( digitsOf whole, fraction )

                        else
                            Err UnclearSeparators

                    else if wellGrouped thousands body then
                        Ok ( digitsOf body, "" )

                    else
                        Err UnclearSeparators

                _ ->
                    Err UnclearSeparators


{-| One separator in the text: a decimal separator, unless the language groups
thousands with it and the digits are grouped by three (`1,234` in English, but not
`0,500`, which is a decimal comma in any language).

With three decimals or more `1,234` can be read both ways in such a language, and
both are an amount. It is refused rather than guessed: the guess could be wrong by a
factor of a thousand.

The same goes for a separator that is neither the decimal separator of the language
nor its thousands separator, before digits grouped like thousands: `10.000` in
Norwegian, where the decimal separator is a comma and thousands are grouped with a
space, is ten thousand to many people and ten to others. `10.5` and `0.500` are not
grouped like thousands, so they are decimals.

-}
onlySeparator : { a | grouping : Maybe Char, decimal : Maybe Char, decimals : Int } -> Bool -> Char -> String -> Result Failure ( String, String )
onlySeparator config noFraction separator body =
    let
        ( whole, fraction ) =
            splitAtLast separator body

        groupLike =
            wellGrouped separator body && not (String.startsWith "0" body)
    in
    if noFraction then
        if wellGrouped separator body then
            Ok ( digitsOf body, "" )

        else
            Err UnclearSeparators

    else if config.grouping == Just separator && groupLike then
        -- `1,234` in a language that groups with a comma. Where the currency has three
        -- decimals this is also a plausible 1.234, and the guess could be a thousand
        -- times wrong.
        if config.decimals >= 3 then
            Err UnclearSeparators

        else
            Ok ( digitsOf body, "" )

    else if config.decimal /= Just separator && groupLike then
        -- `10.000` in Norwegian: a thousand times apart, so neither is guessed
        Err UnclearGrouping

    else
        Ok ( whole, fraction )


digitsOf : String -> String
digitsOf text =
    String.filter Char.isDigit text


splitAtLast : Char -> String -> ( String, String )
splitAtLast separator text =
    case List.reverse (String.split (String.fromChar separator) text) of
        fraction :: wholeParts ->
            ( String.join (String.fromChar separator) (List.reverse wholeParts), fraction )

        [] ->
            ( text, "" )


{-| `1.234.567`: one to three digits, then groups of exactly three.
-}
wellGrouped : Char -> String -> Bool
wellGrouped separator text =
    case String.split (String.fromChar separator) text of
        first :: rest ->
            String.length first
                >= 1
                && String.length first
                <= 3
                && List.all (\group -> String.length group == 3) rest

        [] ->
            False


uniqueChars : List Char -> List Char
uniqueChars chars =
    List.foldl
        (\c seen ->
            if List.member c seen then
                seen

            else
                seen ++ [ c ]
        )
        []
        chars
