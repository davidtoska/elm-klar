module Klar.MaskedInput.Shape exposing
    ( Checksum(..)
    , Expected(..)
    , Issue(..)
    , Reading
    , Shape(..)
    , Slot(..)
    , Unit(..)
    , afterLeaving
    , afterTyping
    , display
    , example
    , expectedLength
    , isComplete
    , isFinal
    , issue
    , keyboard
    , parsePattern
    , postalPattern
    , read
    )

{-| What a mask is made of, and everything it can do with text, as plain functions on
plain data: reading what was typed, writing it in its groups, and saying what is wrong
with it. `Klar.MaskedInput` wraps this in a state and a view.

A mask has a **shape**: a row of slots (digit, letter, either, or a fixed character
that is only shown), an IBAN, or a phone number. Reading **normalises** the text: it
drops the separators (spaces, hyphens, points, slashes, parentheses) and writes letters
in capitals. Everything else that does not fit is not dropped but remembered as
**rejected**, so that the field can show it and say what is wrong instead of quietly
changing what the user typed.

-}

import Klar.MaskedInput.Checksum as Checksum
import Klar.MaskedInput.Iban as Iban
import Klar.MaskedInput.Phone as Phone



-- WHAT A MASK IS


{-| The shape of the text a mask accepts.
-}
type Shape
    = Slots (List Slot) Checksum
    | Iban
    | Phone


{-| One position of a pattern: a digit, a letter, a letter or a digit, or a character
that the field puts in by itself (a hyphen, a space) and that is not part of the value.
-}
type Slot
    = Digit
    | Letter
    | LetterOrDigit
    | Literal Char


{-| The check digit a row of slots carries, when it does.
-}
type Checksum
    = NoChecksum
    | OrganisationNumber
    | BankAccount
    | Gtin
    | Luhn
    | Mod11 (List Int)


{-| What was read from the text: the characters that are the value (without separators,
letters in capitals), the first character that does not belong, with what was expected
in its place, and whether a phone number has the national `(0)` after its country code.
-}
type alias Reading =
    { value : String
    , rejected : Maybe ( Char, Expected )
    , trunkZero : Bool
    }


{-| What a position accepts, for the message about a character that does not belong.
-}
type Expected
    = ExpectDigit
    | ExpectLetter
    | ExpectLetterOrDigit
    | ExpectPlusOrDigit
    | ExpectNonZeroDigit


{-| What is wrong with a text. The field writes it in words, in a language.
-}
type Issue
    = Unexpected Char Expected
    | TooShort { have : Int, want : Int, exact : Bool, unit : Unit }
    | TooLong { have : Int, want : Int, exact : Bool, unit : Unit }
    | WrongIbanLength { country : String, want : Int, have : Int }
    | UnknownIbanCountry String
    | WrongNationalLength { callingCode : String, want : Int, have : Int }
    | NeedsCountryCode
    | LeaveOutTrunkZero
    | WrongCheckDigit
    | WrongIbanCheck


{-| What the characters of a mask are called in a message: a mask of digits only talks
about digits.
-}
type Unit
    = Digits
    | Characters



-- READING


type alias Scan =
    { kept : List Char
    , count : Int
    , rejected : Maybe ( Char, Expected )

    -- the slots that are left to fill, for a row of slots
    , slots : List Slot
    }


{-| Reads what was typed or pasted. Separators are dropped, letters are written in
capitals, and a character that can never be valid where it is (a letter in a field for
digits) is remembered in `rejected` and not dropped from the reading. It takes one
pass over the text.
-}
read : Shape -> String -> Reading
read shape raw =
    let
        start =
            { kept = [], count = 0, rejected = Nothing, slots = slotsOf shape }

        scanned =
            String.foldl (scan shape) start (String.map halfWidth raw)
    in
    { value = String.fromList (List.reverse scanned.kept)
    , rejected = scanned.rejected
    , trunkZero = shape == Phone && hasTrunkZero raw
    }


{-| A phone number written with the national zero in parentheses after the country code,
`+44 (0)20 7946 0958`, which means "dial the 0 only from inside the country". The
parentheses are separators and would be dropped, which leaves the 0 in the number: a
wrong number that looks right. It is not read: the field keeps the text as typed and says
what to do.
-}
hasTrunkZero : String -> Bool
hasTrunkZero raw =
    String.contains "(0)" (String.filter (\c -> not (List.member c [ ' ', '\u{00A0}', '\u{202F}', '\u{2009}', '\t' ])) raw)


scan : Shape -> Char -> Scan -> Scan
scan shape c state =
    if isSeparator shape c then
        state

    else
        case accepts shape state c of
            Ok accepted ->
                { state
                    | kept = accepted :: state.kept
                    , count = state.count + 1
                    , slots = List.drop 1 state.slots
                }

            Err expected ->
                case state.rejected of
                    Nothing ->
                        { state | rejected = Just ( c, expected ) }

                    Just _ ->
                        state


slotsOf : Shape -> List Slot
slotsOf shape =
    case shape of
        Slots slots _ ->
            List.filter (\slot -> not (isLiteral slot)) slots

        _ ->
            []


isLiteral : Slot -> Bool
isLiteral slot =
    case slot of
        Literal _ ->
            True

        _ ->
            False


{-| What is not part of the value but may be typed: spaces, hyphens, points, slashes,
parentheses, and the fixed characters of a row of slots.
-}
isSeparator : Shape -> Char -> Bool
isSeparator shape c =
    List.member c [ ' ', '\u{00A0}', '\u{202F}', '\u{2009}', '\t', '-', '–', '.', '/', '(', ')' ]
        || (case shape of
                Slots slots _ ->
                    List.member (Literal c) slots

                _ ->
                    False
           )


{-| The character to keep for `c` at the next position, in capitals, or what that
position expects instead. Only ASCII letters and digits are accepted: an identifier
is written the same everywhere.
-}
accepts : Shape -> Scan -> Char -> Result Expected Char
accepts shape state c =
    case shape of
        Slots slots _ ->
            let
                slot =
                    case state.slots of
                        next :: _ ->
                            next

                        [] ->
                            overflowSlot slots
            in
            fits slot c

        Iban ->
            if state.count < 2 then
                fits Letter c

            else if state.count < 4 then
                fits Digit c

            else
                fits LetterOrDigit c

        Phone ->
            if state.count == 0 then
                if c == '+' then
                    Ok '+'

                else if Char.isDigit c then
                    Ok c

                else
                    Err ExpectPlusOrDigit

            else if Char.isDigit c then
                if c == '0' && state.count == 1 && List.head state.kept == Just '+' then
                    Err ExpectNonZeroDigit

                else
                    Ok c

            else
                Err ExpectDigit


{-| Characters past the end of the pattern: a pattern of digits goes on with digits,
the others with letters and digits.
-}
overflowSlot : List Slot -> Slot
overflowSlot slots =
    if List.all (\slot -> slot == Digit || isLiteral slot) slots then
        Digit

    else
        LetterOrDigit


fits : Slot -> Char -> Result Expected Char
fits slot c =
    case slot of
        Digit ->
            if Char.isDigit c then
                Ok c

            else
                Err ExpectDigit

        Letter ->
            if Char.isAlpha c then
                Ok (Char.toUpper c)

            else
                Err ExpectLetter

        _ ->
            if Char.isDigit c then
                Ok c

            else if Char.isAlpha c then
                Ok (Char.toUpper c)

            else
                Err ExpectLetterOrDigit



-- WRITING


{-| The value written in its groups: `NO93 8601 1117 947`, `974 760 673`,
`+47 912 34 567`. The separators are put in as late as possible, in front of the
character that follows them, so a value that is not complete has no separator at its
end, and the text of a prefix of a value is a prefix of the text of the value.
Characters beyond the end of the shape are written in a last group.
-}
display : Shape -> String -> String
display shape value =
    case shape of
        Slots slots _ ->
            displaySlots slots (String.toList value) [] [] |> String.fromList

        Iban ->
            String.join " " (chunks [ 4 ] value)

        Phone ->
            displayPhone value


displaySlots : List Slot -> List Char -> List Char -> List Char -> List Char
displaySlots slots chars pending written =
    case ( slots, chars ) of
        ( _, [] ) ->
            List.reverse written

        ( [], rest ) ->
            -- past the end of the pattern: one more group
            List.reverse written ++ (' ' :: rest)

        ( (Literal c) :: more, _ ) ->
            displaySlots more chars (c :: pending) written

        ( _ :: more, c :: rest ) ->
            displaySlots more rest [] (c :: (pending ++ written))


displayPhone : String -> String
displayPhone value =
    case String.uncons value of
        Just ( '+', digits ) ->
            let
                codeLength =
                    Phone.callingCodeLength digits

                callingCode =
                    String.left codeLength digits

                national =
                    String.dropLeft codeLength digits
            in
            if national == "" then
                "+" ++ callingCode

            else
                "+" ++ callingCode ++ " " ++ String.join " " (chunks (Phone.groups callingCode national) national)

        _ ->
            String.join " " (chunks (Phone.groups "" value) value)


{-| Cuts text in groups of the given sizes; the last size repeats for what is left.
-}
chunks : List Int -> String -> List String
chunks sizes text =
    if text == "" then
        []

    else
        case sizes of
            size :: [] ->
                String.left size text :: chunks sizes (String.dropLeft size text)

            size :: more ->
                String.left size text :: chunks more (String.dropLeft size text)

            [] ->
                [ text ]



-- THE FIELD'S TEXT


{-| The text the field shows after the user typed. Text with a character that does not
belong is kept exactly as typed, so that the user sees it and the message about it.
Otherwise the text is written in its groups, but only when the caret is at the end of
the text: when the browser is told a new value of an input it moves the caret to the
end, which is right when the user was typing there and wrong when an edit in the middle
is reformatted. An edit in the middle is kept as typed until the field is left or the
user goes on typing at the end.

The caret is the position after the edit, or a negative number when it is not known
(then it counts as at the end).

-}
afterTyping : Shape -> { typed : String, caret : Int } -> String
afterTyping shape { typed, caret } =
    let
        reading =
            read shape typed

        atEnd =
            caret < 0 || caret >= String.length typed
    in
    if isVerbatim reading || not atEnd then
        typed

    else
        display shape reading.value


{-| Text that is shown exactly as typed, because something in it is wrong in a way that
writing it in groups would hide: a character that does not belong, or a phone number
with the national `(0)` in it.
-}
isVerbatim : Reading -> Bool
isVerbatim reading =
    reading.rejected /= Nothing || reading.trunkZero


{-| The text of the field after the field was left, or Enter was pressed: written in
its groups, unless a character does not belong.
-}
afterLeaving : Shape -> String -> String
afterLeaving shape text =
    let
        reading =
            read shape text
    in
    if isVerbatim reading then
        text

    else
        display shape reading.value



-- WHAT IS WRONG


{-| What is wrong with a reading, in this order: a character that does not belong, the
length, and the check digits (which only a complete value has). Empty text is not wrong.
-}
issue : Shape -> Reading -> Maybe Issue
issue shape reading =
    case reading.rejected of
        Just ( c, expected ) ->
            Just (Unexpected c expected)

        Nothing ->
            if reading.trunkZero then
                Just LeaveOutTrunkZero

            else if reading.value == "" then
                Nothing

            else
                case lengthIssue shape reading.value of
                    Just found ->
                        Just found

                    Nothing ->
                        checkIssue shape reading.value


lengthIssue : Shape -> String -> Maybe Issue
lengthIssue shape value =
    let
        have =
            String.length value
    in
    if have == 0 then
        Nothing

    else
        case shape of
            Slots slots _ ->
                let
                    want =
                        List.length (List.filter (\slot -> not (isLiteral slot)) slots)

                    unit =
                        unitOf slots
                in
                if have > want then
                    Just (TooLong { have = have, want = want, exact = True, unit = unit })

                else if have < want then
                    Just (TooShort { have = have, want = want, exact = True, unit = unit })

                else
                    Nothing

            Iban ->
                let
                    country =
                        String.left 2 value
                in
                if have < 2 then
                    Just (TooShort { have = have, want = 15, exact = False, unit = Characters })

                else
                    case Iban.lengthOf country of
                        Nothing ->
                            Just (UnknownIbanCountry country)

                        Just want ->
                            if have /= want then
                                Just (WrongIbanLength { country = country, want = want, have = have })

                            else
                                Nothing

            Phone ->
                case String.uncons value of
                    Just ( '+', digits ) ->
                        let
                            count =
                                String.length digits
                        in
                        if count > 15 then
                            Just (TooLong { have = count, want = 15, exact = False, unit = Digits })

                        else if String.startsWith "47" digits then
                            if count - 2 /= 8 then
                                Just (WrongNationalLength { callingCode = "47", want = 8, have = count - 2 })

                            else
                                Nothing

                        else if count < 7 then
                            Just (TooShort { have = count, want = 7, exact = False, unit = Digits })

                        else
                            Nothing

                    _ ->
                        Just NeedsCountryCode


checkIssue : Shape -> String -> Maybe Issue
checkIssue shape value =
    case shape of
        Slots _ NoChecksum ->
            Nothing

        Slots _ OrganisationNumber ->
            if Checksum.mod11 [ 3, 2, 7, 6, 5, 4, 3, 2 ] value then
                Nothing

            else
                Just WrongCheckDigit

        Slots _ BankAccount ->
            if Checksum.mod11 [ 5, 4, 3, 2, 7, 6, 5, 4, 3, 2 ] value then
                Nothing

            else
                Just WrongCheckDigit

        Slots _ Gtin ->
            if Checksum.mod10 value then
                Nothing

            else
                Just WrongCheckDigit

        Slots _ Luhn ->
            if Checksum.luhn value then
                Nothing

            else
                Just WrongCheckDigit

        Slots _ (Mod11 weights) ->
            if Checksum.mod11 weights value then
                Nothing

            else
                Just WrongCheckDigit

        Iban ->
            if Checksum.mod97 value then
                Nothing

            else
                Just WrongIbanCheck

        Phone ->
            Nothing


unitOf : List Slot -> Unit
unitOf slots =
    if List.all (\slot -> slot == Digit || isLiteral slot) slots then
        Digits

    else
        Characters


{-| Has the text all the characters it needs, whatever its check digits say? An empty
text is not complete.
-}
isComplete : Shape -> Reading -> Bool
isComplete shape reading =
    reading.value /= "" && not (isVerbatim reading) && lengthIssue shape reading.value == Nothing


{-| Can no more typing fix it? A character that does not belong, text that is too long
and check digits that are wrong can only be fixed by changing what is there; text that
is too short is just not finished.
-}
isFinal : Issue -> Bool
isFinal found =
    case found of
        Unexpected _ _ ->
            True

        TooShort _ ->
            False

        TooLong _ ->
            True

        WrongIbanLength details ->
            details.have > details.want

        UnknownIbanCountry _ ->
            True

        WrongNationalLength details ->
            details.have > details.want

        NeedsCountryCode ->
            False

        LeaveOutTrunkZero ->
            True

        WrongCheckDigit ->
            True

        WrongIbanCheck ->
            True



-- WHAT THE FIELD SHOWS AROUND THE TEXT


{-| The number of significant characters the value will have when it is finished, when
that is known: the counter next to the field shows `6/9`.
-}
expectedLength : Shape -> String -> Maybe Int
expectedLength shape value =
    case shape of
        Slots slots _ ->
            Just (List.length (List.filter (\slot -> not (isLiteral slot)) slots))

        Iban ->
            if String.length value >= 2 then
                Iban.lengthOf (String.left 2 value)

            else
                Nothing

        Phone ->
            Nothing


{-| A text of the shape, for the placeholder: `NO00 0000 0000 000`, `000 000 000`.
-}
example : Shape -> String
example shape =
    case shape of
        Slots slots _ ->
            slots
                |> List.map
                    (\slot ->
                        case slot of
                            Digit ->
                                '0'

                            Letter ->
                                'A'

                            LetterOrDigit ->
                                'A'

                            Literal c ->
                                c
                    )
                |> String.fromList

        Iban ->
            "NO00 0000 0000 000"

        Phone ->
            "+47 000 00 000"


{-| The on-screen keyboard that suits the shape: the numeric pad for digits, the
telephone pad for a phone number, none (the ordinary keyboard) for letters.
-}
keyboard : Shape -> Maybe String
keyboard shape =
    case shape of
        Slots slots _ ->
            if unitOf slots == Digits then
                Just "numeric"

            else
                Nothing

        Iban ->
            Nothing

        Phone ->
            Just "tel"



-- PATTERNS


{-| Reads a pattern: `#` is a digit, `@` a letter, `*` a letter or a digit, and any
other character is shown by the field and not part of the value (a hyphen, a space, a
point). A backslash makes the next character one of those fixed ones, so `\#` is a
hash sign. Letters and digits cannot be fixed characters, because the user would
have to type them.

`Nothing` for a pattern without a slot, one that ends in a backslash, one with a
letter or a digit that is not a slot, one with a control character, and one longer
than 64 characters.

-}
parsePattern : String -> Maybe (List Slot)
parsePattern pattern =
    if String.length pattern > 64 then
        Nothing

    else
        parseSlots (String.toList pattern)
            |> Maybe.andThen
                (\slots ->
                    if List.all isLiteral slots then
                        Nothing

                    else
                        Just slots
                )


parseSlots : List Char -> Maybe (List Slot)
parseSlots chars =
    case chars of
        [] ->
            Just []

        '\\' :: [] ->
            Nothing

        '\\' :: c :: rest ->
            literal c |> Maybe.andThen (\slot -> Maybe.map ((::) slot) (parseSlots rest))

        '#' :: rest ->
            Maybe.map ((::) Digit) (parseSlots rest)

        '@' :: rest ->
            Maybe.map ((::) Letter) (parseSlots rest)

        '*' :: rest ->
            Maybe.map ((::) LetterOrDigit) (parseSlots rest)

        c :: rest ->
            literal c |> Maybe.andThen (\slot -> Maybe.map ((::) slot) (parseSlots rest))


literal : Char -> Maybe Slot
literal c =
    if Char.toCode c < 32 || Char.isAlphaNum c || isCasedLetter c then
        Nothing

    else
        Just (Literal c)


{-| A letter of an alphabet that has capitals (`å`, `é`, `ß`, `ж`): it is not one of
the ASCII letters that a slot takes, and a fixed character cannot be one either, because
the user would have to type it. A letter and its capital differ, which tells without a
table of alphabets.
-}
isCasedLetter : Char -> Bool
isCasedLetter c =
    Char.toUpper c /= Char.toLower c


{-| The pattern of the postal codes of a country, by its ISO 3166 code in capitals.
-}
postalPattern : String -> Maybe String
postalPattern country =
    case country of
        "NO" ->
            Just "####"

        "SE" ->
            Just "### ##"

        "DK" ->
            Just "####"

        "FI" ->
            Just "#####"

        "IS" ->
            Just "###"

        "DE" ->
            Just "#####"

        "AT" ->
            Just "####"

        "CH" ->
            Just "####"

        "LI" ->
            Just "####"

        "NL" ->
            Just "#### @@"

        "BE" ->
            Just "####"

        "LU" ->
            Just "####"

        "FR" ->
            Just "#####"

        "ES" ->
            Just "#####"

        "IT" ->
            Just "#####"

        "PT" ->
            Just "####-###"

        "PL" ->
            Just "##-###"

        "CZ" ->
            Just "### ##"

        "SK" ->
            Just "### ##"

        "EE" ->
            Just "#####"

        "US" ->
            Just "#####"

        "JP" ->
            Just "###-####"

        "AU" ->
            Just "####"

        "NZ" ->
            Just "####"

        _ ->
            Nothing


{-| The full-width forms of the ASCII digits, letters and signs that an IME types
(`１２３`, `ＡＢ`), and its wide space, as the ordinary ones: the same kind of
normalisation as writing letters in capitals.
-}
halfWidth : Char -> Char
halfWidth c =
    let
        code =
            Char.toCode c
    in
    if code >= 0xFF01 && code <= 0xFF5E then
        Char.fromCode (code - 0xFEE0)

    else if code == 0x3000 then
        ' '

    else
        c
