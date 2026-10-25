module Klar.TextInput exposing
    ( view, Attribute
    , value, onInput, onEnter, onBlur, onFocus
    , label, labelHidden, hint, error, errorMaybe, required, optionalText, id
    , email, tel, url, search, verbatim
    , placeholder, prefixIcon, prefixText, suffixIcon, suffixText, clearable, maxLength, size
    , disabled, readOnly, autofocus, autocomplete, inputMode, name
    , locale
    )

{-| A single-line text input with a label, a hint and an error message.

Use when: you need one line of text and want to own the value in your model.
Do not use when: the value is a number, a password, a search that waits for a pause, tags or several lines (use `Klar.NumberInput`, `Klar.PasswordInput`, `Klar.SearchInput`, `Klar.TagInput` or `Klar.TextArea`).

    import Klar.TextInput as TextInput

    TextInput.view
        [ TextInput.label "Customer name"
        , TextInput.required
        , TextInput.value model.customerName
        , TextInput.onInput CustomerNameChanged
        , TextInput.errorMaybe model.customerNameError
        ]

The application owns the value (a "controlled input"): the input shows the
`value` you give it and reports every change through `onInput`. It keeps no
state of its own, so there is no `State`, `Msg` or `update`. For numbers,
passwords, searches, tags and text of several lines use
[Klar.NumberInput](Klar-NumberInput), [Klar.PasswordInput](Klar-PasswordInput),
[Klar.SearchInput](Klar-SearchInput), [Klar.TagInput](Klar-TagInput) and
[Klar.TextArea](Klar-TextArea) instead. `search` makes a filter box that reports
every keystroke, for a list that is filtered in the browser.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required`,
`optionalText` and `id` are the common field attributes. They come with the
field wrapper ([Klar.Field](Klar-Field)) that most Klar inputs are built on, so
they mean the same in all of them: the wrapper draws the label, the required
marker, the hint and the error message around the input and connects them for
screen readers (`for`, `aria-describedby`, `aria-invalid`, `aria-required`). An
error message is announced when it appears.

Every input needs an `id` that is unique on the page, because its label, hint
and error point at it. If you do not set one, it is made from the label (or,
failing that, the placeholder, the name, the hint or the error). An input with
none of them gets no id, so two such inputs never share one; give it an `id`
when something else must point at it.

The input is always inside the wrapper, also when there is no `label`, `hint` or
`error` to draw. It therefore stays where it is when the application shows an
error while the user is typing, and the keyboard focus is not lost. The wrapper
of an input with nothing to draw takes the place and the width of the input
alone, so the layout of a bare input does not change.

**Length.** `maxLength` shows a counter such as `12/200` at the end of the line
under the field, as [Klar.TextArea](Klar-TextArea) does. It never cuts what the
user types or pastes: a longer text stays, the counter and the field turn red,
and screen readers are told. Check the length when the form is sent, with
`Validate.maxLength` from [Klar.Validate](Klar-Validate).

The only texts the input brings itself are the name of the clear button ("Clear
field") and what the counter tells screen readers; `locale` changes their
language.


# View

@docs view, Attribute


# Value and events

@docs value, onInput, onEnter, onBlur, onFocus


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText, id


# Kind of input

@docs email, tel, url, search, verbatim


# Decoration and helpers

@docs placeholder, prefixIcon, prefixText, suffixIcon, suffixText, clearable, maxLength, size


# State and browser hints

@docs disabled, readOnly, autofocus, autocomplete, inputMode, name


# Language

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Field as Field
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.TextField as TextField
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Size(..))


{-| A setting of a text input. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type Adornment
    = AdornIcon Icon
    | AdornText String


type alias Config msg =
    { field : Field.Config
    , value : String
    , placeholder : String
    , type_ : String
    , onInput : Maybe (String -> msg)
    , onBlur : Maybe msg
    , onFocus : Maybe msg
    , onEnter : Maybe msg
    , disabled : Bool
    , readOnly : Bool
    , size : Size
    , prefix : Maybe Adornment
    , suffix : Maybe Adornment
    , clearable : Bool
    , maxLength : Maybe Int
    , autocomplete : Maybe String
    , name : Maybe String
    , inputMode : Maybe String
    , autofocus : Bool
    , verbatim : Bool
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , value = ""
        , placeholder = ""
        , type_ = "text"
        , onInput = Nothing
        , onBlur = Nothing
        , onFocus = Nothing
        , onEnter = Nothing
        , disabled = False
        , readOnly = False
        , size = Medium
        , prefix = Nothing
        , suffix = Nothing
        , clearable = False
        , maxLength = Nothing
        , autocomplete = Nothing
        , name = Nothing
        , inputMode = Nothing
        , autofocus = False
        , verbatim = False
        , locale = Locale.default
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })



-- FIELD ATTRIBUTES


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

    TextInput.errorMaybe (Validate.run Locale.en Validate.email model.email)

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


{-| The DOM id of the input. It must be unique on the page, because the label,
hint and error point at it. Without one, an id is made from the label (or the
placeholder, the name, the hint or the error), so two inputs with the same label
need explicit ids; an input with none of them gets no id.
-}
id : String -> Attribute msg
id value_ =
    updateField (Field.setId value_)



-- CONTROL ATTRIBUTES


{-| The text in the input. The input always shows exactly this string, so keep
it in your model and update it from `onInput`. Default: empty.
-}
value : String -> Attribute msg
value text =
    Attribute (\config -> { config | value = text })


{-| Text shown inside the empty input, for example a sample value. It is not a
substitute for a `label`, and it disappears as soon as the user types. Default:
none.
-}
placeholder : String -> Attribute msg
placeholder text =
    Attribute (\config -> { config | placeholder = text })


{-| An email address: sets the HTML type `email`, so phones show a keyboard with
the `@` key. To check the address, use `Validate.email` from
[Klar.Validate](Klar-Validate).
-}
email : Attribute msg
email =
    kind "email"


{-| A telephone number: sets the HTML type `tel`, so phones show a dial pad. The
text is not checked or reformatted.
-}
tel : Attribute msg
tel =
    kind "tel"


{-| A web address: sets the HTML type `url`, so phones show a keyboard made for
addresses. The text is not checked.
-}
url : Attribute msg
url =
    kind "url"


{-| A filter box: a magnifying glass at the start of the field and the search
keyboard on phones. It is still a plain text input, and every keystroke reaches
`onInput`, which suits a list that is filtered in the browser. It replaces an
earlier prefix. For a search that waits until the user stops typing (a request
to a server), use [Klar.SearchInput](Klar-SearchInput).
-}
search : Attribute msg
search =
    Attribute (\config -> { config | type_ = "text", prefix = Just (AdornIcon Icon.search), inputMode = Just "search" })


kind : String -> Attribute msg
kind type_ =
    Attribute (\config -> { config | type_ = type_ })


{-| For codes, not words: order numbers, SKUs, IBANs, user names. Switches off
spell checking (no red lines under `SKU-4471`), automatic capital letters and
autocorrect on phones. Default: the browser decides.
-}
verbatim : Attribute msg
verbatim =
    Attribute (\config -> { config | verbatim = True })


{-| Sends the new text each time the user changes the input, by typing,
pasting or pressing the clear button (which sends `""`). The function gets the
whole text. Store it in your model and pass it back with `value`.

    TextInput.onInput NameChanged -- NameChanged : String -> Msg

-}
onInput : (String -> msg) -> Attribute msg
onInput toMsg =
    Attribute (\config -> { config | onInput = Just toMsg })


{-| Sends this message when the input loses focus. A good moment to validate, so
that an error does not appear while the user is still typing.
-}
onBlur : msg -> Attribute msg
onBlur msg =
    Attribute (\config -> { config | onBlur = Just msg })


{-| Sends this message when the input gets focus.
-}
onFocus : msg -> Attribute msg
onFocus msg =
    Attribute (\config -> { config | onFocus = Just msg })


{-| Sends this message when the user presses Enter in the input (without Shift,
Ctrl, Alt or Cmd). The key press is cancelled, so it does not submit a
surrounding `form`; leave `onEnter` out to let Enter submit it. The Enter that
confirms a word in an input method (Chinese, Japanese, Korean) sends nothing.
-}
onEnter : msg -> Attribute msg
onEnter msg =
    Attribute (\config -> { config | onEnter = Just msg })


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


{-| The size of the field: `Small` (26px high), `Medium` (32px) or `Large`
(40px) at the default density (see `Klar.Theme` for the others), from
[Klar.Theme](Klar-Theme). Default `Medium`.

    TextInput.size Theme.Small

-}
size : Size -> Attribute msg
size value_ =
    Attribute (\config -> { config | size = value_ })


{-| Shows an icon at the start of the field, inside the border. A later
`prefixIcon`, `prefixText` or `search` replaces it.

    TextInput.prefixIcon Icon.mail

-}
prefixIcon : Icon -> Attribute msg
prefixIcon icon =
    Attribute (\config -> { config | prefix = Just (AdornIcon icon) })


{-| Shows a short text at the start of the field, inside the border, such as a
currency code or `"https://"`. A later `prefixIcon`, `prefixText` or `search`
replaces it.
-}
prefixText : String -> Attribute msg
prefixText text =
    Attribute (\config -> { config | prefix = Just (AdornText text) })


{-| Shows an icon at the end of the field, inside the border. A later
`suffixIcon` or `suffixText` replaces it.
-}
suffixIcon : Icon -> Attribute msg
suffixIcon icon =
    Attribute (\config -> { config | suffix = Just (AdornIcon icon) })


{-| Shows a short text at the end of the field, inside the border, such as a
unit (`"kg"`). A later `suffixIcon` or `suffixText` replaces it.
-}
suffixText : String -> Attribute msg
suffixText text =
    Attribute (\config -> { config | suffix = Just (AdornText text) })


{-| Shows a small clear button at the end of the field while there is text. The
button sends an empty string through `onInput`, once for each use, so it needs
`onInput`. It is not in the Tab order, its accessible name is "Clear field" (see
`locale`), and it is hidden while the field is `disabled` or `readOnly`.
-}
clearable : Attribute msg
clearable =
    Attribute (\config -> { config | clearable = True })


{-| Shows a counter such as `12/200` at the end of the line under the field. It
turns amber when the limit is near (10 characters or a tenth of the limit left,
whichever is more) and red past it, and the field is then marked invalid
(`aria-invalid`). Nothing is cut: a longer text that is typed or pasted stays,
so that the user can see it and shorten it, so check the length yourself when
the form is sent (`Validate.maxLength`). Screen readers hear "12 of 200
characters" with the field, and are told once when the text comes near the
limit, reaches it and passes it.
-}
maxLength : Int -> Attribute msg
maxLength n =
    Attribute (\config -> { config | maxLength = Just n })


{-| The HTML `autocomplete` token. It tells the browser (and password managers)
what the field contains, such as `"email"`, `"given-name"` or `"off"`. Default:
none, so the browser decides.
-}
autocomplete : String -> Attribute msg
autocomplete value_ =
    Attribute (\config -> { config | autocomplete = Just value_ })


{-| The HTML `name` of the input. Browsers use it to fill in saved values, and a
native form sends the value under this name. Default: none.
-}
name : String -> Attribute msg
name value_ =
    Attribute (\config -> { config | name = Just value_ })


{-| The HTML `inputmode`: which on-screen keyboard phones show, such as
`"numeric"`, `"decimal"`, `"email"`, `"tel"`, `"url"` or `"search"`. Default:
none, so the keyboard follows the type of the input.
-}
inputMode : String -> Attribute msg
inputMode value_ =
    Attribute (\config -> { config | inputMode = Just value_ })


{-| Asks the browser to focus the input when it is shown (the HTML `autofocus`
attribute). Browsers honor it for one element at most, and not once the user has
started to move the focus around, so it is unreliable for an input that appears
later, in a dialog for example. To move the focus yourself, use
`Klar.focus` with the `id` of the input.
-}
autofocus : Attribute msg
autofocus =
    Attribute (\config -> { config | autofocus = True })


{-| The language of the built-in text: the name of the clear button ("Clear
field" in English) and what the counter of `maxLength` tells screen readers ("12
of 200 characters"). Default `Locale.default`, which is English. Texts you pass
in yourself are shown as they are.
-}
locale : Locale -> Attribute msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


{-| An input with its label, hint and error message. The value, the events and
everything else are set with attributes.

    TextInput.view
        [ TextInput.label "Email"
        , TextInput.email
        , TextInput.clearable
        , TextInput.value model.email
        , TextInput.onInput EmailChanged
        ]

-}
view : List (Attribute msg) -> Html msg
view attributes =
    let
        config =
            configure attributes

        field =
            ensureId config

        hasValue =
            config.value /= ""

        showClear =
            config.clearable && hasValue && not config.disabled && not config.readOnly && config.onInput /= Nothing

        clearLabel =
            Locale.pick config.locale { nb = "Tøm feltet", en = "Clear field" }

        length =
            String.length config.value

        over =
            case config.maxLength of
                Just limit ->
                    TextField.isOver limit length

                Nothing ->
                    False

        counterId =
            if field.id == "" || config.maxLength == Nothing then
                ""

            else
                field.id ++ "-counter"

        control =
            Html.div
                [ Internal.cls
                    [ "klar-input"
                    , "klar-input--" ++ Internal.sizeSuffix config.size
                    , if field.error /= Nothing || over then
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
                [ viewAdornment "prefix" config.prefix
                , Html.input
                    (TextField.controlAttributes field { describedBy = [ counterId ], invalid = over }
                        ++ [ Internal.cls [ "klar-input__control" ]
                           , Attr.type_ config.type_
                           , Attr.value config.value
                           , Attr.placeholder config.placeholder
                           , Attr.disabled config.disabled
                           , Attr.readonly config.readOnly
                           , Internal.attrMaybe (Attr.attribute "autocomplete") config.autocomplete
                           , Internal.attrMaybe Attr.name config.name
                           , Internal.attrMaybe (Attr.attribute "inputmode") config.inputMode
                           , Internal.attrIf config.autofocus (Attr.autofocus True)
                           , Internal.attrIf config.verbatim (Attr.attribute "spellcheck" "false")
                           , Internal.attrIf config.verbatim (Attr.attribute "autocapitalize" "off")
                           , Internal.attrIf config.verbatim (Attr.attribute "autocorrect" "off")
                           , Internal.attrMaybe Events.onInput config.onInput
                           , Internal.attrMaybe Events.onBlur config.onBlur
                           , Internal.attrMaybe Events.onFocus config.onFocus
                           , Internal.attrMaybe (\msg -> Events.preventDefaultOn "keydown" (enterDecoder msg)) config.onEnter
                           ]
                    )
                    []
                , case ( showClear, config.onInput ) of
                    ( True, Just toMsg ) ->
                        Html.button
                            [ Internal.cls [ "klar-input__clear" ]
                            , Attr.type_ "button"
                            , Attr.tabindex -1
                            , Attr.attribute "aria-label" clearLabel

                            -- Cleared on mouse down, which is kept from moving the
                            -- focus: the button disappears with the text, and the
                            -- focus would otherwise fall back to the page instead of
                            -- staying in the field. The click that follows a press is
                            -- ignored, so the message is sent once; a click without a
                            -- press (a key, assistive technology) clears.
                            , Internal.onMouseDownPrevent (toMsg "")
                            , Events.on "click" (unpressedClick (toMsg ""))
                            ]
                            [ Icon.view Icon.close ]

                    _ ->
                        Html.text ""
                , viewAdornment "suffix" config.suffix
                ]
    in
    -- stable: the application may show an error while the user types, and the
    -- input must not move into the wrapper then (it would lose the focus)
    case config.maxLength of
        Just limit ->
            Field.viewWithAside field
                (TextField.counter { id = counterId, locale = config.locale, length = length, limit = limit })
                control

        Nothing ->
            Field.view field control


{-| Enter without a modifier, and not the Enter that confirms the word of an
input method.
-}
enterDecoder : msg -> Decode.Decoder ( msg, Bool )
enterDecoder msg =
    Decode.map2 Tuple.pair TextField.composing Internal.keyEvent
        |> Decode.andThen
            (\( isComposing, event ) ->
                if not isComposing && event.key == "Enter" && not (event.ctrl || event.meta || event.alt || event.shift) then
                    Decode.succeed ( msg, True )

                else
                    Decode.fail "not a plain Enter"
            )


{-| A `click` that no press of the mouse button came before. A click that follows
a press has `detail` 1 or more. One from a key or from assistive technology has
`detail` 0, and so has an event without that field.
-}
unpressedClick : msg -> Decode.Decoder msg
unpressedClick msg =
    Decode.oneOf [ Decode.field "detail" Decode.int, Decode.succeed 0 ]
        |> Decode.andThen
            (\clicks ->
                if clicks > 0 then
                    Decode.fail "the mouse down has done it"

                else
                    Decode.succeed msg
            )


viewAdornment : String -> Maybe Adornment -> Html msg
viewAdornment position adornment =
    case adornment of
        Nothing ->
            Html.text ""

        Just (AdornIcon icon) ->
            Html.span [ Internal.cls [ "klar-input__adornment", "klar-input__" ++ position ] ] [ Icon.view icon ]

        Just (AdornText text) ->
            Html.span [ Internal.cls [ "klar-input__adornment", "klar-input__adornment--text", "klar-input__" ++ position ] ] [ Html.text text ]


ensureId : Config msg -> Field.Config
ensureId config =
    if config.field.id == "" then
        Field.setId
            (TextField.generatedId "klar-input-"
                [ config.field.label, Just config.placeholder, config.name, config.field.hint, config.field.error ]
            )
            config.field

    else
        config.field
