module Klar.MaskedInput exposing
    ( view, Attribute
    , State, Msg, init, update
    , Mask, iban, norwegianOrganisationNumber, norwegianBankAccount, norwegianPostalCode, postalCode, phone, pattern
    , value, text, setValue, reset, touch, isComplete, isValid, isTouched
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , placeholder, size, disabled, readOnly, name
    , locale
    )

{-| A field for an identifier that has a fixed shape and, often, a check digit: an
IBAN, an organisation number, a bank account, a postal code, a phone number, or a
code of your own such as `AB-1234`. It writes the text in its groups as the user types
it, and says what is wrong with it. It is stateful.

Use when: an identifier with a fixed shape and often a check digit, such as an IBAN, an organisation number or a postal code.
Do not use when: the text is free (`Klar.TextInput`) or the value is an amount of money (`Klar.MoneyInput`).
Quick path: `init`, `update`, `view`, `value`

    import Klar.MaskedInput as MaskedInput

    type alias Model =
        { account : MaskedInput.State }

    init : Model
    init =
        { account = MaskedInput.init "supplier-iban" MaskedInput.iban }

    -- update
    AccountMsg inner ->
        let
            ( account, cmd ) =
                MaskedInput.update inner model.account
        in
        ( { model | account = account }, Cmd.map AccountMsg cmd )

    -- view
    MaskedInput.view AccountMsg
        [ MaskedInput.label "IBAN", MaskedInput.required ]
        model.account

    -- read the IBAN
    MaskedInput.value model.account -- Just "NO9386011117947" when it is complete and right

The first `String` given to `init` is the DOM id of the input, so there is no `id`
attribute. The second is the `Mask`, which says what is accepted. The application
reads the identifier with `value`, which is `Nothing` until the identifier is
complete and its check digits are right, and uses `isTouched` to show errors of its
own only after the user has been in the field once. It reacts to changes by comparing
`value` before and after `update`.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required` and `optionalText`
are the common field attributes. They come with the field wrapper
([Klar.Field](Klar-Field)) that most Klar inputs are built on, so they mean the same
in all of them. The field is always inside the wrapper, so it does not move when an
error comes and goes.

**Masks.** A `Mask` is a value, made by a function: `iban`,
`norwegianOrganisationNumber`, `norwegianBankAccount`, `norwegianPostalCode`,
`postalCode "SE"`, `phone`, or a pattern of your own with `pattern "@@-####"`. A mask
that can fail to be made (an unknown country, a pattern that makes no sense) gives
`Maybe`, so the application knows at once, not when the user is in the field. Build
the masks once, in `init`.

**What is typed is not changed behind the user's back.** Separators (spaces, hyphens,
points, slashes, parentheses) can be typed anywhere or left out: the field puts them
in the right places, and they are not part of the value. Letters are written in
capitals. Nothing else is quietly dropped: a letter in a field for digits stays where
it was typed, and the field says so at once. Text that is too long stays too, and is
reported. `value` is `Nothing` until all of that is fixed.

**Errors.** The messages are specific: "The check digit is wrong", "An IBAN from NO
has 15 characters (12 entered)", "Too short: 6 of 9 digits". An error that more typing
cannot fix (a character that does not belong, a value that is too long, a wrong check
digit in a complete value) is shown at once. An unfinished value is not an error while
the user is typing; it becomes one when the field is left or Enter is pressed (the
field is then touched), or when the application calls `touch`. The `error` and
`errorMaybe` of the application, for problems that only the server knows, show when the
field has no message of its own.

**The caret.** The field writes the text in its groups while the user types at the end
of it, which is where nearly everyone types and where a pasted identifier ends up. The
browser moves the caret to the end of the field whenever the value is set, and plain
Elm cannot put it back, so an edit in the middle of the text (a character inserted or
deleted before the end) is kept exactly as typed, and written in its groups once the
user goes on typing at the end or leaves the field. Nothing is ever lost or moved; the
groups are just a little late after such an edit.

**Not libphonenumber.** The phone mask is a help, not a validator: it requires the
international form (`+`, the country code, the rest), accepts 7 to 15 digits as the
standard for phone numbers says, and writes Norwegian (`+47 912 34 567`), Danish and
North American numbers in their usual groups and others in groups of three. It does
not know which numbers exist. National numbers without `+` are refused with a message
that says what to do, and so is the national zero in parentheses after the country code
(`+44 (0)20 7946 0958`): dropping the parentheses would leave a 0 in the number, so the
field keeps the text as typed and asks for the number without `(0)`.

**Keyboard and accessibility.** The input is a text field with the keyboard hint that
suits the mask (numeric for digits, telephone pad for a phone number) and without
automatic capitals, corrections and spell checking. Identifiers read from left to
right in every language, so the input is always left to right. Enter writes the
identifier in its groups and still lets a surrounding form submit. Errors are announced
when they appear, and a counter such as `6/9` next to the field (hidden from screen
readers) shows how far the user has come.

The built-in texts (the errors) follow `locale`.


# View

@docs view, Attribute


# State

@docs State, Msg, init, update


# Masks

@docs Mask, iban, norwegianOrganisationNumber, norwegianBankAccount, norwegianPostalCode, postalCode, phone, pattern


# The identifier

@docs value, text, setValue, reset, touch, isComplete, isValid, isTouched


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Display and browser hints

@docs placeholder, size, disabled, readOnly, name


# Language

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Field as Field
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.MaskedInput.Shape as Shape exposing (Checksum(..), Shape(..), Slot(..))
import Klar.Theme as Theme exposing (Size(..))



-- MASKS


{-| What a field accepts: the shape of the text, how it is written in groups, and
which check digits it must have. Make one with `iban`, `norwegianOrganisationNumber`,
`norwegianBankAccount`, `norwegianPostalCode`, `postalCode`, `phone` or `pattern`.
-}
type Mask
    = Mask { shape : Shape, autocomplete : String }


{-| An IBAN, the international bank account number: two letters for the country, two
check digits and the national account number, `NO93 8601 1117 947`. The length must be
the one of the country (15 for Norway, 22 for Germany), and the check digits must be
right (ISO 7064, modulus 97; the digits 00, 01 and 99, which ISO 13616 does not use, are
refused). The countries are those of the SWIFT IBAN registry as public copies of it
listed them in May 2026, 89 of them; an IBAN from a country that has joined since is
reported as "no IBAN country" until this package is updated, and so is one from a
country that has no IBANs in the registry. The value is written without spaces:
`NO9386011117947`.
-}
iban : Mask
iban =
    Mask { shape = Iban, autocomplete = "off" }


{-| A Norwegian organisation number: nine digits where the last is a check digit
(modulus 11), `974 760 673`. The value is the nine digits.
-}
norwegianOrganisationNumber : Mask
norwegianOrganisationNumber =
    Mask
        { shape = Slots (List.repeat 3 Digit ++ [ Literal ' ' ] ++ List.repeat 3 Digit ++ [ Literal ' ' ] ++ List.repeat 3 Digit) OrganisationNumber
        , autocomplete = "off"
        }


{-| A Norwegian bank account number: eleven digits where the last is a check digit
(modulus 11), written `8601.11.17947`. The value is the eleven digits. Use `iban` for
an account that may be abroad.
-}
norwegianBankAccount : Mask
norwegianBankAccount =
    Mask
        { shape = Slots (List.repeat 4 Digit ++ [ Literal '.' ] ++ List.repeat 2 Digit ++ [ Literal '.' ] ++ List.repeat 5 Digit) BankAccount
        , autocomplete = "off"
        }


{-| A Norwegian postal code: four digits, `0150`. There is no check digit, so any four
digits are accepted; the application knows which postal codes exist. It is the same
mask as `postalCode "NO"`, without the `Maybe`: where the country is fixed, this one
cannot fail.
-}
norwegianPostalCode : Mask
norwegianPostalCode =
    Mask { shape = Slots (List.repeat 4 Digit) NoChecksum, autocomplete = "postal-code" }


{-| The postal codes of a country, by its two-letter ISO 3166 code (`"SE"` for
`123 45`, `"NL"` for `1234 AB`, `"PL"` for `12-345`). Upper or lower case, and spaces
around the code, are fine. It is for a country that is not fixed, such as the one in an
address, and `postalCode "NO"` is the Norwegian mask too, so every country of the list
works the same way; where the country is Norway, `norwegianPostalCode` has no `Nothing`
to handle. `Nothing` for a country that is not in the list (Norway,
Sweden, Denmark, Finland, Iceland, Germany, Austria, Switzerland, Liechtenstein, the
Netherlands, Belgium, Luxembourg, France, Spain, Italy, Portugal, Poland, Czechia,
Slovakia, Estonia, the United States, Japan, Australia and New Zealand); the postal
codes of other countries, such as Ireland and the United Kingdom, are not a fixed
pattern, and `pattern` can make one for the others.
-}
postalCode : String -> Maybe Mask
postalCode country =
    Shape.postalPattern (String.toUpper (String.trim country))
        |> Maybe.andThen Shape.parsePattern
        |> Maybe.map (\slots -> Mask { shape = Slots slots NoChecksum, autocomplete = "postal-code" })


{-| A phone number in the international form: `+`, the country calling code and the
number, 7 to 15 digits in all, as in `+47 912 34 567`. A Norwegian number (`+47`) must
have exactly eight digits after the code. Spaces, hyphens, points and parentheses may be
typed and are not part of the value, which is `+4791234567`. This is a help for typing,
not a phone number database.
-}
phone : Mask
phone =
    Mask { shape = Phone, autocomplete = "tel" }


{-| A mask of your own from a pattern. Three characters are slots, and every other
character is a fixed one that the field writes by itself and that is not part of the
value. The characters in a pattern are these:

  - `#` takes a digit;
  - `@` takes a letter, A to Z, in capitals;
  - `*` takes a letter or a digit;
  - anything else that is not a letter or a digit (a hyphen, a space, a point) is
    shown between the slots; a backslash in front of a character makes it one of
    those, so `\#` is a hash sign.

Two examples:

    MaskedInput.pattern "@@-####" -- AB-1234

    MaskedInput.pattern "##.##.##" -- 12.34.56

The value is the characters of the slots (`AB1234`); `text` is what the field shows
(`AB-1234`). Use the shown form when the hyphen belongs to the identifier.

`Nothing` for a pattern without slots, a pattern that ends in a backslash, one with a
letter (of any alphabet, `å` and `é` too) or a digit that is not a slot (the user would
have to type it; the application can add a fixed start itself), one with a control
character, and one longer than 64 characters. There is no check digit.

-}
pattern : String -> Maybe Mask
pattern description =
    Shape.parsePattern description
        |> Maybe.map (\slots -> Mask { shape = Slots slots NoChecksum, autocomplete = "off" })


shapeOf : Mask -> Shape
shapeOf (Mask details) =
    details.shape



-- STATE


{-| The state of a field: the text it shows and whether the user has been in it. Make
one with `init`, keep it in your model and give it to `view` and `update`.
-}
type State
    = State
        { id : String
        , mask : Mask
        , text : String
        , touched : Bool
        }


{-| An empty field for a mask. The `String` is the DOM id of the input; it must be
unique on the page, because the label, hint and error point at it. To start with an
identifier, use `setValue`.

    MaskedInput.init "supplier-orgnr" MaskedInput.norwegianOrganisationNumber

-}
init : String -> Mask -> State
init id mask =
    State { id = id, mask = mask, text = "", touched = False }


{-| The identifier, or `Nothing` when the field is empty or what is in it is not a
complete, right identifier. It is the normalised value: no separators, letters in
capitals, a phone number with its `+` (`NO9386011117947`, `974760673`,
`+4791234567`). Fixed characters of a pattern are not in it; `text` has them.
-}
value : State -> Maybe String
value (State state) =
    let
        shape =
            shapeOf state.mask

        reading =
            Shape.read shape state.text
    in
    if reading.value /= "" && Shape.issue shape reading == Nothing then
        Just reading.value

    else
        Nothing


{-| The text in the field, written in its groups (`NO93 8601 1117 947`), or exactly as
typed while it holds a character that does not belong or an edit in the middle waits
to be written.
-}
text : State -> String
text (State state) =
    state.text


{-| Shows an identifier, or an empty field for `Nothing`. The text may be as it comes
from a server (`NO9386011117947`) or as a person wrote it (`no93 8601 1117 947`); the
field writes it in its groups. Whatever it is, nothing is dropped: if it has a character
that does not belong, the field shows it as it is, with the message about it.
-}
setValue : Maybe String -> State -> State
setValue maybe (State state) =
    case maybe of
        Just identifier ->
            State { state | text = Shape.afterLeaving (shapeOf state.mask) identifier }

        Nothing ->
            State { state | text = "" }


{-| Empties the field and forgets that the user has been in it (`isTouched` is
`False` again), for example for a "Clear form" button.
-}
reset : State -> State
reset (State state) =
    State { state | text = "", touched = False }


{-| Counts the field as visited, as if the user had been in it and left, so that the
messages about an unfinished value show. Use it when the application wants to show the
errors of all fields at once, such as after a failed attempt to submit.
-}
touch : State -> State
touch (State state) =
    State { state | touched = True }


{-| `True` when the field has all the characters it needs, whatever its check digits
say: nine digits for an organisation number, the length of the country for an IBAN. An
empty field is not complete.
-}
isComplete : State -> Bool
isComplete (State state) =
    Shape.isComplete (shapeOf state.mask) (Shape.read (shapeOf state.mask) state.text)


{-| `True` when the field is empty or holds a complete identifier with the right check
digits, and `False` when anything is wrong with what is in it, including an unfinished
value. It answers at once, also while the user is typing, although the messages of an
unfinished value wait until the field is left. An empty field counts as valid: for an
identifier that is required, also check `value` for `Nothing`.
-}
isValid : State -> Bool
isValid (State state) =
    let
        shape =
            shapeOf state.mask
    in
    Shape.issue shape (Shape.read shape state.text) == Nothing


{-| `True` once the user has left the field or pressed Enter in it, or `touch` was
used. Use it to show errors of your own only after the first visit. `reset` makes it
`False` again.
-}
isTouched : State -> Bool
isTouched (State state) =
    state.touched



-- UPDATE


{-| The messages a masked field sends: what was typed, focus and leaving the field.
`view` wraps them with the function you give it; hand them to `update` when they come
back.
-}
type Msg
    = Typed String Int
    | Focused
    | Blurred
    | Entered


{-| Moves the field on after one of its messages. The `Cmd` is always `Cmd.none`; it is
there so that the field is wired like the others (`Cmd.map`).
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    let
        shape =
            shapeOf state.mask
    in
    case msg of
        Typed typed caret ->
            ( State { state | text = Shape.afterTyping shape { typed = typed, caret = caret } }, Cmd.none )

        Focused ->
            ( State state, Cmd.none )

        Blurred ->
            -- the field was left
            ( State { state | text = Shape.afterLeaving shape state.text, touched = True }, Cmd.none )

        Entered ->
            -- Enter: write the identifier in its groups, but the cursor stays
            ( State { state | text = Shape.afterLeaving shape state.text, touched = True }, Cmd.none )



-- ATTRIBUTES


{-| A setting of a masked field. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { field : Field.Config
    , placeholder : Maybe String
    , disabled : Bool
    , readOnly : Bool
    , size : Size
    , name : Maybe String
    , locale : Locale
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , placeholder = Nothing
        , disabled = False
        , readOnly = False
        , size = Medium
        , name = Nothing
        , locale = Locale.default
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The label shown above the field. It is connected to the input, so clicking
it focuses the input and screen readers read it as the name of the input. Give
every field a label, or hide it with `labelHidden`.
-}
label : String -> Attribute msg
label textOfLabel =
    updateField (Field.setLabel textOfLabel)


{-| Hides the `label` visually but keeps it for screen readers. Use it when the
surroundings already show what the field is for.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| Help text shown under the field, for example what the identifier is for. Screen
readers read it together with the label (`aria-describedby`).
-}
hint : String -> Attribute msg
hint textOfHint =
    updateField (Field.setHint textOfHint)


{-| Shows an error message under the field and marks the field invalid (red
border, `aria-invalid`). Screen readers announce the message when it appears.
To show an error only sometimes, use `errorMaybe`. The field's own messages replace
this one until they are fixed, so it is the place for rules of your own, such as "This
account is already registered" from the server.
-}
error : String -> Attribute msg
error textOfError =
    updateField (Field.setError (Just textOfError))


{-| Like `error`, but takes a `Maybe`: `Just message` shows the message and
`Nothing` shows no error. It fits the result of a validator.
-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the field as required: an asterisk after the label and
`aria-required` on the input. This does not validate anything; an empty field
still counts as valid, so check `value` for `Nothing` yourself and show an
`error`.
-}
required : Attribute msg
required =
    updateField (Field.setRequired True)


{-| Text such as `"(optional)"` shown after the label of a field that is not
`required`. By default nothing is shown.
-}
optionalText : String -> Attribute msg
optionalText textOfOptional =
    updateField (Field.setOptionalText textOfOptional)


{-| Text shown inside the empty field. Without it the field shows the shape of the
identifier, such as `NO00 0000 0000 000` for an IBAN or `000 000 000` for an
organisation number, which tells how it is written. It is not a substitute for a
`label`, and it disappears as soon as the user types.
-}
placeholder : String -> Attribute msg
placeholder textOfPlaceholder =
    Attribute (\config -> { config | placeholder = Just textOfPlaceholder })


{-| The size of the field: `Small` (26px high), `Medium` (32px) or `Large`
(40px), from [Klar.Theme](Klar-Theme). Default `Medium`.
-}
size : Size -> Attribute msg
size value_ =
    Attribute (\config -> { config | size = value_ })


{-| While `True` the field is dimmed and cannot be focused or changed. Default
`False`.
-}
disabled : Bool -> Attribute msg
disabled value_ =
    Attribute (\config -> { config | disabled = value_ })


{-| While `True` the user can focus the field and select its text, but not
change it. Default `False`.
-}
readOnly : Bool -> Attribute msg
readOnly value_ =
    Attribute (\config -> { config | readOnly = value_ })


{-| The HTML `name` of the input. A native form sends the text under this name.
Default: none.
-}
name : String -> Attribute msg
name value_ =
    Attribute (\config -> { config | name = Just value_ })


{-| The language of the built-in texts, which are the error messages. Default
`Locale.default`, which is English. Texts you pass in yourself are shown as they are.
-}
locale : Locale -> Attribute msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


{-| A masked field with its label, hint and error message. The first argument wraps
the field's own messages in one of yours, and the state comes last.

    MaskedInput.view OrgnrMsg
        [ MaskedInput.label "Organisation number"
        , MaskedInput.required
        ]
        model.orgnr

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes

        shape =
            shapeOf state.mask

        (Mask details) =
            state.mask

        reading =
            Shape.read shape state.text

        -- Built-in errors win over the application's own until they are fixed.
        -- An error that more typing cannot fix shows at once; an unfinished value
        -- waits until the field is left.
        builtIn =
            Shape.issue shape reading
                |> Maybe.andThen
                    (\found ->
                        if Shape.isFinal found || state.touched then
                            Just (issueText config.locale found)

                        else
                            Nothing
                    )

        field =
            config.field
                |> Field.setId state.id
                |> Field.setError
                    (case builtIn of
                        Just message ->
                            Just message

                        Nothing ->
                            config.field.error
                    )

        inactive =
            config.disabled || config.readOnly

        counter =
            case Shape.expectedLength shape reading.value of
                Just want ->
                    if reading.value == "" then
                        Html.text ""

                    else
                        Html.span
                            [ Internal.cls [ "klar-input__counter" ]
                            , Attr.attribute "aria-hidden" "true"
                            ]
                            [ Html.text (String.fromInt (String.length reading.value) ++ "/" ++ String.fromInt want) ]

                Nothing ->
                    Html.text ""
    in
    -- stable: the field makes messages of its own while the user types
    Field.viewStable field
        (Html.div
            [ Internal.cls
                [ "klar-input"
                , "klar-input--" ++ Theme.sizeSuffix config.size
                , "klar-masked"
                , if field.error /= Nothing then
                    "klar-input--invalid"

                  else
                    ""
                , if config.disabled then
                    "klar-input--disabled"

                  else
                    ""
                , if config.readOnly then
                    "klar-input--readonly"

                  else
                    ""
                ]
            ]
            [ Html.input
                (Field.controlAttributes field
                    ++ [ Internal.cls [ "klar-input__control", "klar-masked__control" ]
                       , Attr.type_ "text"
                       , Internal.attrMaybe (Attr.attribute "inputmode") (Shape.keyboard shape)
                       , Attr.attribute "autocomplete" details.autocomplete
                       , Attr.attribute "autocapitalize" "off"
                       , Attr.attribute "autocorrect" "off"
                       , Attr.attribute "spellcheck" "false"
                       , Attr.attribute "dir" "ltr"
                       , Attr.value state.text
                       , Attr.placeholder (Maybe.withDefault (Shape.example shape) config.placeholder)
                       , Attr.disabled config.disabled
                       , Attr.readonly config.readOnly
                       , Internal.attrMaybe Attr.name config.name
                       , Events.on "input" (inputDecoder toMsg)
                       , Events.onFocus (toMsg Focused)
                       , Events.onBlur (toMsg Blurred)
                       , Internal.attrIf (not inactive) (Events.preventDefaultOn "keydown" (enterDecoder (toMsg Entered)))
                       ]
                )
                []
            , counter
            ]
        )


{-| The text and, with it, where the caret is after the edit, which tells whether the
user typed at the end. A browser always has it; an event without it counts as an edit
at the end.
-}
inputDecoder : (Msg -> msg) -> Decode.Decoder msg
inputDecoder toMsg =
    Decode.map2 (\typed caret -> toMsg (Typed typed caret))
        (Decode.at [ "target", "value" ] Decode.string)
        (Decode.oneOf [ Decode.at [ "target", "selectionStart" ] Decode.int, Decode.succeed -1 ])


{-| Enter writes the identifier in its groups, and is not cancelled: a surrounding
form still submits.
-}
enterDecoder : msg -> Decode.Decoder ( msg, Bool )
enterDecoder msg =
    Internal.keyEvent
        |> Decode.andThen
            (\event ->
                if event.key == "Enter" && not (event.ctrl || event.meta || event.alt) then
                    Decode.succeed ( msg, False )

                else
                    Decode.fail "unhandled key"
            )



-- MESSAGES


issueText : Locale -> Shape.Issue -> String
issueText lang found =
    let
        pick nb en =
            Locale.pick lang { nb = nb, en = en }

        number n =
            String.fromInt n

        unitText unit =
            case unit of
                Shape.Digits ->
                    pick "siffer" "digits"

                Shape.Characters ->
                    pick "tegn" "characters"
    in
    case found of
        Shape.Unexpected c expected ->
            pick
                ("«" ++ String.fromChar c ++ "» er ikke tillatt her: forventet " ++ expectedText True expected)
                ("“" ++ String.fromChar c ++ "” is not allowed here: expected " ++ expectedText False expected)

        Shape.TooShort details ->
            if details.exact then
                pick
                    ("For kort: " ++ number details.have ++ " av " ++ number details.want ++ " " ++ unitText details.unit)
                    ("Too short: " ++ number details.have ++ " of " ++ number details.want ++ " " ++ unitText details.unit)

            else
                pick
                    ("For kort: " ++ number details.have ++ " av minst " ++ number details.want ++ " " ++ unitText details.unit)
                    ("Too short: " ++ number details.have ++ " of at least " ++ number details.want ++ " " ++ unitText details.unit)

        Shape.TooLong details ->
            if details.exact then
                pick
                    ("For lang: " ++ number details.have ++ " av " ++ number details.want ++ " " ++ unitText details.unit)
                    ("Too long: " ++ number details.have ++ " of " ++ number details.want ++ " " ++ unitText details.unit)

            else
                pick
                    ("For lang: " ++ number details.have ++ " av maksimalt " ++ number details.want ++ " " ++ unitText details.unit)
                    ("Too long: " ++ number details.have ++ " of at most " ++ number details.want ++ " " ++ unitText details.unit)

        Shape.WrongIbanLength details ->
            pick
                ("Et IBAN-nummer fra " ++ details.country ++ " har " ++ number details.want ++ " tegn (" ++ number details.have ++ " skrevet)")
                ("An IBAN from " ++ details.country ++ " has " ++ number details.want ++ " characters (" ++ number details.have ++ " entered)")

        Shape.UnknownIbanCountry country ->
            pick
                (country ++ " er ikke et IBAN-land")
                (country ++ " is not an IBAN country")

        Shape.WrongNationalLength details ->
            pick
                ("Et nummer med +" ++ details.callingCode ++ " har " ++ number details.want ++ " siffer etter landkoden (" ++ number details.have ++ " skrevet)")
                ("A number with +" ++ details.callingCode ++ " has " ++ number details.want ++ " digits after the country code (" ++ number details.have ++ " entered)")

        Shape.NeedsCountryCode ->
            pick
                "Start med + og landkode, for eksempel +47"
                "Start with + and the country code, like +47"

        Shape.LeaveOutTrunkZero ->
            pick
                "Utelat (0) etter landkoden"
                "Leave out the (0) after the country code"

        Shape.WrongCheckDigit ->
            pick "Kontrollsifferet er feil" "The check digit is wrong"

        Shape.WrongIbanCheck ->
            pick "IBAN-kontrollsifrene er feil" "The IBAN check digits are wrong"


expectedText : Bool -> Shape.Expected -> String
expectedText norwegian expected =
    case ( expected, norwegian ) of
        ( Shape.ExpectDigit, True ) ->
            "et siffer"

        ( Shape.ExpectDigit, False ) ->
            "a digit"

        ( Shape.ExpectLetter, True ) ->
            "en bokstav"

        ( Shape.ExpectLetter, False ) ->
            "a letter"

        ( Shape.ExpectLetterOrDigit, True ) ->
            "en bokstav eller et siffer"

        ( Shape.ExpectLetterOrDigit, False ) ->
            "a letter or a digit"

        ( Shape.ExpectPlusOrDigit, True ) ->
            "+ eller et siffer"

        ( Shape.ExpectPlusOrDigit, False ) ->
            "+ or a digit"

        ( Shape.ExpectNonZeroDigit, True ) ->
            "et siffer fra 1 til 9 (en landkode starter ikke med 0)"

        ( Shape.ExpectNonZeroDigit, False ) ->
            "a digit from 1 to 9 (a country code does not start with 0)"
