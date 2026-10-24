module Klar.PasswordInput exposing
    ( view, Attribute
    , State, Msg, init, update, isRevealed, reveal, hide
    , value, onInput, onEnter, onBlur
    , label, labelHidden, hint, error, errorMaybe, required, optionalText
    , currentPassword, newPassword, autocomplete
    , strengthMeter, strength
    , placeholder, size, disabled, readOnly, name
    , locale
    )

{-| A password field with a "show password" button and an optional strength
meter.

Use when: the user types a password and may want to see it, or you want to show its strength.
Do not use when: the text is not secret (use `Klar.TextInput`).
Quick path: `init`, `update`, `view`

    import Klar.PasswordInput as PasswordInput

    type alias Model =
        { password : String
        , passwordField : PasswordInput.State
        }

    init : Model
    init =
        { password = ""
        , passwordField = PasswordInput.init "account-password"
        }

    -- update
    PasswordChanged text ->
        ( { model | password = text }, Cmd.none )

    PasswordMsg inner ->
        let
            ( passwordField, cmd ) =
                PasswordInput.update inner model.passwordField
        in
        ( { model | passwordField = passwordField }, Cmd.map PasswordMsg cmd )

    -- view
    PasswordInput.view PasswordMsg
        [ PasswordInput.label "New password"
        , PasswordInput.value model.password
        , PasswordInput.onInput PasswordChanged
        , PasswordInput.newPassword
        , PasswordInput.strengthMeter
        ]
        model.passwordField

The text itself is owned by the application, as in
[Klar.TextInput](Klar-TextInput); the state only remembers whether the password
is shown. The `String` given to `init` is the DOM id of the input, so there is
no `id` attribute.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required` and
`optionalText` are the common field attributes. They come with the field
wrapper ([Klar.Field](Klar-Field)) that most Klar inputs are built on, so they
mean the same in all of them: the wrapper draws the label, the required marker,
the hint and the error message around the input and connects them for screen
readers (`for`, `aria-describedby`, `aria-invalid`, `aria-required`). An error
message is announced when it appears. The field is always inside the wrapper,
also when there is no `label`, `hint` or `error` to draw, so it stays where it is
(and keeps the keyboard focus) when the application shows an error while the user
is typing.

**Show and hide.** A button at the end of the field switches between dots and
plain text. Its name is "Show password" or "Hide password", and `aria-pressed`
says whether the password is shown. A mouse click on it leaves the keyboard
focus in the field, and a keyboard user stays on the button. The application can
do the same with `reveal` and `hide`. The field also switches off automatic
capital letters, autocorrect and spell checking.

**Password managers.** Use `currentPassword` on a login form and `newPassword`
when choosing one, so that password managers do the right thing.

**Strength.** `strengthMeter` shows four bars and a word under the field while
it has text, and screen readers are told the result ("Password strength:
Weak"). It is a rough guide (length, mix of characters, obvious patterns and the
most common passwords), not a security guarantee: the application should still
enforce its own rules, and can use `strength` for that. It counts the letters of
every script as letters, and it knows the common passwords of English and
Norwegian whatever the `locale`.

The built-in texts (the name of the button and the strength meter) follow
`locale`.


# View

@docs view, Attribute


# State

@docs State, Msg, init, update, isRevealed, reveal, hide


# Value and events

@docs value, onInput, onEnter, onBlur


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText


# Password managers

@docs currentPassword, newPassword, autocomplete


# Strength

@docs strengthMeter, strength


# Appearance and behavior

@docs placeholder, size, disabled, readOnly, name


# Language

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Field as Field
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Size(..))



-- STATE


{-| The state of a password field. It only remembers whether the password is
shown; the text itself lives in your model. Make one with `init`, keep it in your
model and give it to `view` and `update`.
-}
type State
    = State
        { id : String
        , revealed : Bool
        }


{-| A field that hides the password. The `String` is the DOM id of the input; it
must be unique on the page, because the label, hint and error point at it.
-}
init : String -> State
init id =
    State { id = id, revealed = False }


{-| `True` while the password is shown as plain text.
-}
isRevealed : State -> Bool
isRevealed (State state) =
    state.revealed


{-| Shows the password as plain text, as if the user had pressed the button.
-}
reveal : State -> State
reveal (State state) =
    State { state | revealed = True }


{-| Hides the password behind dots again, for example when a form is shown anew.
-}
hide : State -> State
hide (State state) =
    State { state | revealed = False }


{-| The messages of the show/hide button. `view` wraps them with the function
you give it; hand them to `update` when they come back.
-}
type Msg
    = Toggle
    | Noop


{-| Moves the field on after one of its messages: the button toggles whether the
password is shown. Call it from your own `update` and pass the `Cmd` on with
`Cmd.map`.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    case msg of
        Toggle ->
            -- Focus stays where it is: a mouse click on the button does not
            -- take it from the input (mousedown is prevented), and a keyboard
            -- user stays on the button, so a second Space toggles again
            -- instead of typing a space into the password.
            ( State { state | revealed = not state.revealed }, Cmd.none )

        Noop ->
            ( State state, Cmd.none )



-- ATTRIBUTES


{-| A setting of a password field. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { field : Field.Config
    , value : String
    , placeholder : String
    , onInput : Maybe (String -> msg)
    , onBlur : Maybe msg
    , onEnter : Maybe msg
    , disabled : Bool
    , readOnly : Bool
    , size : Size
    , autocomplete : Maybe String
    , name : Maybe String
    , strengthMeter : Bool
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , value = ""
        , placeholder = ""
        , onInput = Nothing
        , onBlur = Nothing
        , onEnter = Nothing
        , disabled = False
        , readOnly = False
        , size = Medium
        , autocomplete = Nothing
        , name = Nothing
        , strengthMeter = False
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
label text =
    updateField (Field.setLabel text)


{-| Hides the `label` visually but keeps it for screen readers. Use it when the
surroundings already show what the field is for.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| Help text shown under the field, for example the format you expect. Screen
readers read it together with the label (`aria-describedby`).
-}
hint : String -> Attribute msg
hint text =
    updateField (Field.setHint text)


{-| Shows an error message under the field and marks the field invalid (red
border, `aria-invalid`). Screen readers announce the message when it appears.
To show an error only sometimes, use `errorMaybe`.
-}
error : String -> Attribute msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, but takes a `Maybe`: `Just message` shows the message and
`Nothing` shows no error. It fits the result of a validator.
-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the field as required: an asterisk after the label and
`aria-required` on the input. This does not validate anything; check the value
yourself and show an `error`.
-}
required : Attribute msg
required =
    updateField (Field.setRequired True)


{-| Text such as `"(optional)"` shown after the label of a field that is not
`required`. By default nothing is shown.
-}
optionalText : String -> Attribute msg
optionalText text =
    updateField (Field.setOptionalText text)


{-| The password, as your model has it. The input always shows exactly this
string, as dots or as plain text, so update it from `onInput`. Default: empty.
-}
value : String -> Attribute msg
value text =
    Attribute (\config -> { config | value = text })


{-| Text shown inside the empty field. It is not a substitute for a `label`, and
it disappears as soon as the user types. Default: none.
-}
placeholder : String -> Attribute msg
placeholder text =
    Attribute (\config -> { config | placeholder = text })


{-| Sends the new password each time the user changes the field, by typing or
pasting. The function gets the whole text. Store it in your model and pass it
back with `value`.

    PasswordInput.onInput PasswordChanged -- PasswordChanged : String -> Msg

-}
onInput : (String -> msg) -> Attribute msg
onInput toMsg =
    Attribute (\config -> { config | onInput = Just toMsg })


{-| Sends this message when the field loses focus. A good moment to validate, so
that an error does not appear while the user is still typing.
-}
onBlur : msg -> Attribute msg
onBlur msg =
    Attribute (\config -> { config | onBlur = Just msg })


{-| Sends this message when the user presses Enter in the field (without Shift,
Ctrl, Alt or Cmd). The key press is cancelled, so it does not submit a
surrounding `form`; leave `onEnter` out to let Enter submit it.
-}
onEnter : msg -> Attribute msg
onEnter msg =
    Attribute (\config -> { config | onEnter = Just msg })


{-| While `True` the field and its show/hide button are dimmed and cannot be
focused or changed. Default `False`.
-}
disabled : Bool -> Attribute msg
disabled value_ =
    Attribute (\config -> { config | disabled = value_ })


{-| While `True` the user can focus the field but not change it. The show/hide
button still works. Default `False`.
-}
readOnly : Bool -> Attribute msg
readOnly value_ =
    Attribute (\config -> { config | readOnly = value_ })


{-| The size of the field: `Small` (26px high), `Medium` (32px) or `Large`
(40px), from [Klar.Theme](Klar-Theme). Default `Medium`.
-}
size : Size -> Attribute msg
size value_ =
    Attribute (\config -> { config | size = value_ })


{-| The HTML `autocomplete` token. It tells the browser and password managers
what the field contains: `"current-password"`, `"new-password"` or
`"one-time-code"`. `currentPassword` and `newPassword` are shortcuts for the
first two. Default: none, so the browser decides.
-}
autocomplete : String -> Attribute msg
autocomplete token =
    Attribute (\config -> { config | autocomplete = Just token })


{-| For a login form: the field holds the password the user already has
(`autocomplete="current-password"`), so password managers offer to fill it in.
-}
currentPassword : Attribute msg
currentPassword =
    autocomplete "current-password"


{-| For choosing a new password (`autocomplete="new-password"`): password
managers can suggest one, and browsers do not fill in the old one.
-}
newPassword : Attribute msg
newPassword =
    autocomplete "new-password"


{-| The HTML `name` of the input. Browsers use it to fill in saved values, and a
native form sends the value under this name. Default: none.
-}
name : String -> Attribute msg
name value_ =
    Attribute (\config -> { config | name = Just value_ })


{-| Shows four bars and a word ("Weak", "Fair", "Good" or "Strong") under the
field while it has text. Screen readers are told the result as a status
("Password strength: Weak"). The meter uses `strength`, which is a rough guide.
-}
strengthMeter : Attribute msg
strengthMeter =
    Attribute (\config -> { config | strengthMeter = True })


{-| The language of the built-in text: the name of the show/hide button ("Show
password" and "Hide password") and the strength meter ("Password strength:" and
the words "Weak", "Fair", "Good" and "Strong"). Default `Locale.default`, which
is English. Texts you pass in yourself are shown as they are.
-}
locale : Locale -> Attribute msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- STRENGTH


{-| A rough strength of a password, from 0 (empty) to 4. It looks at the length,
the kinds of characters (lowercase letters, uppercase letters, digits and
everything else) and a few obvious patterns, and it is what `strengthMeter`
shows.

  - 1 weak: shorter than 8 characters, only one kind of character, or an obvious
    pattern (`password123`, `abcdefgh`, `aaaaaaaa`)
  - 2 fair: at least 8 characters of two kinds
  - 3 good: at least 10 characters of three kinds
  - 4 strong: at least 16 characters of three kinds, or 12 of all four

It reads the password as Unicode text. A letter counts as a letter in any
script: `é`, `ü`, `ж` and `Ω` are lowercase or uppercase letters like `e` and
`E`, and the letters of a script without case (Chinese, Arabic, Hebrew ...) count
with the lowercase ones. Digits of other scripts are digits. Punctuation, signs
and emoji are the "everything else" kind, and a combining accent counts for
nothing on its own. The length is the number of characters, not of UTF-16 units,
so an emoji is one.

A password that contains one of the most common passwords (`password`, `qwerty`,
`letmein` ... and the usual Norwegian ones) is weak however long it is. The meter
has no locale, so the English and the Norwegian entries always count. The list is
short, as is every other pattern the meter knows: it is a guide for the user, not
a security check.

-}
strength : String -> Int
strength password =
    let
        characters =
            String.toList password

        length =
            List.length characters

        present =
            List.map kindOf characters

        kinds =
            [ Lowercase, Uppercase, Digit, Other ]
                |> List.filter (\kind -> List.member kind present)
                |> List.length

        base =
            if length == 0 then
                0

            else if length < 8 || kinds < 2 then
                1

            else if (length >= 16 && kinds >= 3) || (length >= 12 && kinds >= 4) then
                4

            else if length >= 10 && kinds >= 3 then
                3

            else
                2
    in
    if hasWeakPattern password then
        Basics.min 1 base

    else
        base


{-| What a character adds to the variety of a password. `Mark` is a combining
accent: it belongs to the letter before it and is not a kind of its own.
-}
type Kind
    = Lowercase
    | Uppercase
    | Digit
    | Other
    | Mark


{-| `Char.isLower` and its friends know the ASCII letters only, so every
character beyond ASCII is sorted here without a table of Unicode: a letter that
has a case is known by its other case (`Char.toLower`, `Char.toUpper`), the
digits and the symbols by their blocks, and the rest are the letters of scripts
without case.
-}
kindOf : Char -> Kind
kindOf c =
    let
        code =
            Char.toCode c
    in
    if code < 128 then
        if Char.isLower c then
            Lowercase

        else if Char.isUpper c then
            Uppercase

        else if Char.isDigit c then
            Digit

        else
            Other

    else if inBlocks combiningMarks code then
        Mark

    else if Char.toLower c /= c then
        Uppercase

    else if Char.toUpper c /= c then
        Lowercase

    else if List.any (\start -> code >= start && code < start + 10) decimalDigits then
        Digit

    else if inBlocks symbols code then
        Other

    else
        Lowercase


inBlocks : List ( Int, Int ) -> Int -> Bool
inBlocks blocks code =
    List.any (\( first, last ) -> code >= first && code <= last) blocks


{-| The first character of each block of decimal digits (ten in a row) of the
common scripts: Arabic-Indic, Devanagari, Bengali, Thai, Khmer, full-width ...
-}
decimalDigits : List Int
decimalDigits =
    [ 0x0660, 0x06F0, 0x07C0, 0x0966, 0x09E6, 0x0A66, 0x0AE6, 0x0B66, 0x0BE6, 0x0C66, 0x0CE6, 0x0D66, 0x0DE6, 0x0E50, 0x0ED0, 0x0F20, 0x1040, 0x1090, 0x17E0, 0x1810, 0xFF10 ]


combiningMarks : List ( Int, Int )
combiningMarks =
    [ ( 0x0300, 0x036F ), ( 0x1AB0, 0x1AFF ), ( 0x1DC0, 0x1DFF ), ( 0x20D0, 0x20FF ), ( 0xFE20, 0xFE2F ) ]


{-| Blocks beyond ASCII that hold punctuation, signs and pictures, not letters.
-}
symbols : List ( Int, Int )
symbols =
    [ ( 0x80, 0xBF ) -- controls, no-break space, Latin-1 punctuation and signs
    , ( 0xD7, 0xD7 ) -- multiplication sign
    , ( 0xF7, 0xF7 ) -- division sign
    , ( 0x2000, 0x2BFF ) -- punctuation, currency, arrows, mathematics, shapes, dingbats
    , ( 0x2E00, 0x2E7F ) -- more punctuation
    , ( 0x3000, 0x303F ) -- punctuation of Chinese, Japanese and Korean
    , ( 0x3200, 0x33FF ) -- enclosed letters and compatibility signs
    , ( 0xE000, 0xF8FF ) -- private use
    , ( 0xFE00, 0xFE0F ) -- variation selectors
    , ( 0xFE30, 0xFE6F ) -- compatibility and small forms
    , ( 0xFF00, 0xFF0F ) -- full-width punctuation
    , ( 0xFF1A, 0xFF20 )
    , ( 0xFF3B, 0xFF40 )
    , ( 0xFF5B, 0xFF65 )
    , ( 0xFFE0, 0xFFFF ) -- full-width signs, specials
    , ( 0x0001F000, 0x0001FAFF ) -- emoji, pictographs, symbols
    , ( 0x000E0000, 0x000E01EF ) -- tags and variation selectors
    ]


hasWeakPattern : String -> Bool
hasWeakPattern password =
    let
        lower =
            String.toLower password

        codes =
            List.map Char.toCode (String.toList password)

        steps =
            List.map2 (\a b -> b - a) codes (List.drop 1 codes)
    in
    List.any (\word -> String.contains word lower) commonPasswords
        || (List.length steps >= 2 && (List.all (\d -> d == 1) steps || List.all (\d -> d == -1) steps))
        || (List.length steps >= 1 && List.all (\d -> d == 0) steps)


{-| The most common passwords of both languages. The meter has no locale: people
choose English passwords on a Norwegian page and the other way round, so both
lists are always used.
-}
commonPasswords : List String
commonPasswords =
    commonEnglish ++ commonNorwegian


commonEnglish : List String
commonEnglish =
    [ "password"
    , "passw0rd"
    , "p@ssw0rd"
    , "p@ssword"
    , "qwerty"
    , "qwertyuiop"
    , "123456"
    , "654321"
    , "111111"
    , "000000"
    , "121212"
    , "123123"
    , "112233"
    , "1q2w3e"
    , "1qaz2wsx"
    , "qazwsx"
    , "zxcvbn"
    , "asdfgh"
    , "abc123"
    , "letmein"
    , "welcome"
    , "admin"
    , "iloveyou"
    , "monkey"
    , "dragon"
    , "football"
    , "baseball"
    , "soccer"
    , "sunshine"
    , "princess"
    , "superman"
    , "batman"
    , "starwars"
    , "trustno1"
    , "shadow"
    , "mustang"
    , "changeme"
    , "freedom"
    , "whatever"
    ]


commonNorwegian : List String
commonNorwegian =
    [ "passord"
    , "norge"
    , "hemmelig"
    , "velkommen"
    , "sommer"
    , "fotball"
    , "elskerdeg"
    , "jegelsker"
    , "kjaerlighet"
    , "kjærlighet"
    ]



-- VIEW


{-| A password field with its label, hint and error message, and a button that
shows or hides the password. The first argument wraps the field's own messages
in one of yours, and the state comes last.

    PasswordInput.view PasswordMsg
        [ PasswordInput.label "Password"
        , PasswordInput.currentPassword
        , PasswordInput.value model.password
        , PasswordInput.onInput PasswordChanged
        ]
        model.passwordField

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes

        field =
            Field.setId state.id config.field

        toggleLabel =
            if state.revealed then
                Locale.pick config.locale { nb = "Skjul passord", en = "Hide password" }

            else
                Locale.pick config.locale { nb = "Vis passord", en = "Show password" }
    in
    -- stable: the application may show an error while the user types, and the
    -- input must not move into the wrapper then (it would lose the focus)
    Field.view field
        (Html.div [ Internal.cls [ "klar-password" ] ]
            [ Html.div
                [ Internal.cls
                    [ "klar-input"
                    , "klar-input--" ++ Internal.sizeSuffix config.size
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
                        ++ [ Internal.cls [ "klar-input__control" ]
                           , Attr.type_
                                (if state.revealed then
                                    "text"

                                 else
                                    "password"
                                )
                           , Attr.value config.value
                           , Attr.placeholder config.placeholder
                           , Attr.disabled config.disabled
                           , Attr.readonly config.readOnly
                           , Attr.attribute "autocapitalize" "off"
                           , Attr.attribute "autocorrect" "off"
                           , Attr.attribute "spellcheck" "false"
                           , Internal.attrMaybe (Attr.attribute "autocomplete") config.autocomplete
                           , Internal.attrMaybe Attr.name config.name
                           , Internal.attrMaybe Events.onInput config.onInput
                           , Internal.attrMaybe Events.onBlur config.onBlur
                           , Internal.attrMaybe (\msg -> Internal.onKeys [ ( "Enter", msg ) ]) config.onEnter
                           ]
                    )
                    []
                , Html.button
                    [ Internal.cls [ "klar-password__toggle" ]
                    , Attr.type_ "button"
                    , Attr.attribute "aria-label" toggleLabel
                    , Attr.attribute "aria-pressed"
                        (if state.revealed then
                            "true"

                         else
                            "false"
                        )
                    , Attr.title toggleLabel
                    , Attr.disabled config.disabled
                    , Internal.onMouseDownPrevent (toMsg Noop)
                    , Events.onClick (toMsg Toggle)
                    ]
                    [ Icon.view
                        (if state.revealed then
                            Icon.eyeOff

                         else
                            Icon.eye
                        )
                    ]
                ]
            , if config.strengthMeter && config.value /= "" then
                viewMeter config.locale (strength config.value)

              else
                Html.text ""
            ]
        )


viewMeter : Locale -> Int -> Html msg
viewMeter lang level =
    let
        word =
            case level of
                1 ->
                    Locale.pick lang { nb = "Svakt", en = "Weak" }

                2 ->
                    Locale.pick lang { nb = "Middels", en = "Fair" }

                3 ->
                    Locale.pick lang { nb = "Godt", en = "Good" }

                _ ->
                    Locale.pick lang { nb = "Sterkt", en = "Strong" }

        caption =
            Locale.pick lang { nb = "Passordstyrke: ", en = "Password strength: " }
    in
    Html.div
        [ Internal.cls [ "klar-password__meter", "klar-password__meter--" ++ String.fromInt level ]
        , Attr.attribute "role" "status"
        ]
        [ Html.span [ Internal.cls [ "klar-password__bars" ], Attr.attribute "aria-hidden" "true" ]
            (List.map
                (\bar ->
                    Html.span
                        [ Internal.cls
                            [ "klar-password__bar"
                            , if bar <= level then
                                "klar-password__bar--on"

                              else
                                ""
                            ]
                        ]
                        []
                )
                [ 1, 2, 3, 4 ]
            )
        , Html.span [ Internal.cls [ "klar-password__strength" ] ] [ Html.text (caption ++ word) ]
        ]
