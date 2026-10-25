module Klar.TextArea exposing
    ( view, Attribute
    , value, onInput, onBlur, onFocus, onCtrlEnter
    , label, labelHidden, hint, error, errorMaybe, required, optionalText, id
    , rows, minRows, maxRows, noResize
    , maxLength, placeholder, size
    , disabled, readOnly, autofocus, verbatim, autocomplete, name
    , locale
    )

{-| A multi-line text field with a label, a hint and an error message.

Use when: you need text of several lines, such as a note or a description.
Do not use when: one line is enough (use `Klar.TextInput`).

    import Klar.TextArea as TextArea

    TextArea.view
        [ TextArea.label "Delivery note"
        , TextArea.value model.note
        , TextArea.onInput NoteChanged
        , TextArea.maxLength 500
        , TextArea.onCtrlEnter SaveNote
        ]

The application owns the value, as in [Klar.TextInput](Klar-TextInput): the
text area shows the `value` you give it and reports every change through
`onInput`. It keeps no state of its own, so there is no `State`, `Msg` or
`update`. Enter inserts a new line; Ctrl+Enter (Cmd+Enter on a Mac) sends the
message of `onCtrlEnter`, the usual way to send a comment or a note.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required`,
`optionalText` and `id` are the common field attributes. They come with the
field wrapper ([Klar.Field](Klar-Field)) that most Klar inputs are built on, so
they mean the same in all of them: the wrapper draws the label, the required
marker, the hint and the error message around the text area and connects them
for screen readers (`for`, `aria-describedby`, `aria-invalid`,
`aria-required`). An error message is announced when it appears. Without an
`id`, one is made from the label (or the placeholder, the name, the hint or the
error); a text area with none of them gets no id.

**Height.** `rows 4` is a fixed height of four lines, and the user can drag the
corner unless you pass `noResize`. `minRows` and `maxRows` make the field grow
with its text instead: never smaller than `minRows`, scrolling after `maxRows`.

    TextArea.view [ TextArea.minRows 3, TextArea.maxRows 10 ]

With `maxRows` alone, the smallest height is `rows` (3 by default). Growing uses
the CSS property `field-sizing: content`. Browsers without it fall back to a
hidden copy of the text that sizes the field, so the behavior is the same
everywhere and needs no JavaScript.

**Counter.** `maxLength` shows a counter such as `12/500` at the end of the line
under the field, level with the hint (hint on the left, counter on the right),
the same counter as in [Klar.TextInput](Klar-TextInput). It turns amber when the
limit is near and red when the text is longer than the limit. Nothing is ever
cut: a pasted text that is too long stays, so that the user sees it and can
shorten it, and the field is marked invalid; check the length when the form is
sent (`Validate.maxLength`). Screen readers hear "12 of 500 characters" with the
field, and are told once when the text comes near the limit, reaches it and
passes it, not on every keystroke.

The text area is always inside the field wrapper, also when there is no `label`,
`hint` or `error` to draw, so it does not move (and lose the keyboard focus) when
the application shows an error while the user is typing. The wrapper of a text
area with nothing to draw adds no space and no width of its own.

The only built-in text is what the counter tells screen readers ("12 of 500
characters"); `locale` changes its language.


# View

@docs view, Attribute


# Value and events

@docs value, onInput, onBlur, onFocus, onCtrlEnter


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText, id


# Height and resizing

@docs rows, minRows, maxRows, noResize


# Length, placeholder and size

@docs maxLength, placeholder, size


# State and browser hints

@docs disabled, readOnly, autofocus, verbatim, autocomplete, name


# Language

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Field as Field
import Klar.Internal as Internal
import Klar.Internal.TextField as TextField
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Size(..))


{-| A setting of a text area. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { field : Field.Config
    , value : String
    , placeholder : String
    , rows : Int
    , minRows : Maybe Int
    , maxRows : Maybe Int
    , noResize : Bool
    , maxLength : Maybe Int
    , onInput : Maybe (String -> msg)
    , onBlur : Maybe msg
    , onFocus : Maybe msg
    , onCtrlEnter : Maybe msg
    , disabled : Bool
    , readOnly : Bool
    , autofocus : Bool
    , verbatim : Bool
    , size : Size
    , autocomplete : Maybe String
    , name : Maybe String
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , value = ""
        , placeholder = ""
        , rows = 3
        , minRows = Nothing
        , maxRows = Nothing
        , noResize = False
        , maxLength = Nothing
        , onInput = Nothing
        , onBlur = Nothing
        , onFocus = Nothing
        , onCtrlEnter = Nothing
        , disabled = False
        , readOnly = False
        , autofocus = False
        , verbatim = False
        , size = Medium
        , autocomplete = Nothing
        , name = Nothing
        , locale = Locale.default
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })



-- FIELD ATTRIBUTES


{-| The label shown above the field. It is connected to the text area, so
clicking it focuses the text area and screen readers read it as the name of the
text area. Give every field a label, or hide it with `labelHidden`.
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
`aria-required` on the text area. This does not validate anything; check the
value yourself and show an `error`.
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


{-| The DOM id of the text area. It must be unique on the page, because the
label, hint and error point at it. Without one, an id is made from the label (or
the placeholder, the name, the hint or the error), so two fields with the same
label need explicit ids; a field with none of them gets no id.
-}
id : String -> Attribute msg
id value_ =
    updateField (Field.setId value_)



-- CONTROL ATTRIBUTES


{-| The text in the text area. It always shows exactly this string, so keep it
in your model and update it from `onInput`. Default: empty.
-}
value : String -> Attribute msg
value text =
    Attribute (\config -> { config | value = text })


{-| Text shown inside the empty text area, for example a sample value. It is not
a substitute for a `label`, and it disappears as soon as the user types.
Default: none.
-}
placeholder : String -> Attribute msg
placeholder text =
    Attribute (\config -> { config | placeholder = text })


{-| A fixed height of this many visible lines. Default 3, and never less than 1.
`minRows` and `maxRows` make the field grow instead; with `maxRows` alone this
is the smallest height.

    TextArea.rows 5

-}
rows : Int -> Attribute msg
rows n =
    Attribute (\config -> { config | rows = max 1 n })


{-| Makes the field grow with its text, but never be smaller than this many
lines (at least 1). `rows` is then ignored. Combine it with `maxRows`.
-}
minRows : Int -> Attribute msg
minRows n =
    Attribute (\config -> { config | minRows = Just (max 1 n) })


{-| Makes the field grow with its text up to this many lines (at least 1), and
then scroll. If this is less than the smallest height, the smallest height wins.
-}
maxRows : Int -> Attribute msg
maxRows n =
    Attribute (\config -> { config | maxRows = Just (max 1 n) })


{-| Takes away the handle in the corner of a field with a fixed height, so that
the user cannot drag it taller. A field that grows with its text (`minRows`,
`maxRows`) never has the handle. Default: a fixed height can be dragged.
-}
noResize : Attribute msg
noResize =
    Attribute (\config -> { config | noResize = True })


{-| Shows a counter such as `12/500` under the field, at the end of the line
with the hint. The counter turns amber when the limit is near (a tenth of the
limit left, or a fifth up to 10 characters, whichever is more: 50 of 500, 10 of
60, 2 of 10) and red when the text is longer,
and the field is then marked invalid (`aria-invalid`). Nothing is cut: a longer
text that is typed or pasted stays, so check the length yourself when the form
is sent (`Validate.maxLength`). Screen readers hear "12 of 500 characters" with
the field, and are told once when the text comes near the limit, reaches it and
passes it.
-}
maxLength : Int -> Attribute msg
maxLength n =
    Attribute (\config -> { config | maxLength = Just n })


{-| Sends the new text each time the user changes the text area, by typing,
pasting or cutting. The function gets the whole text. Store it in your model and
pass it back with `value`.

    TextArea.onInput NoteChanged -- NoteChanged : String -> Msg

-}
onInput : (String -> msg) -> Attribute msg
onInput toMsg =
    Attribute (\config -> { config | onInput = Just toMsg })


{-| Sends this message when the text area loses focus. A good moment to
validate, so that an error does not appear while the user is still typing.
-}
onBlur : msg -> Attribute msg
onBlur msg =
    Attribute (\config -> { config | onBlur = Just msg })


{-| Sends this message when the text area gets focus.
-}
onFocus : msg -> Attribute msg
onFocus msg =
    Attribute (\config -> { config | onFocus = Just msg })


{-| Sends this message when the user presses Ctrl+Enter (Cmd+Enter on a Mac) in
the text area, the usual key to send a comment or a note. The key press is
cancelled, so no new line is added; a plain Enter still adds one, and the Enter
that confirms a word in an input method sends nothing. Default: none.

    TextArea.onCtrlEnter SaveNote

-}
onCtrlEnter : msg -> Attribute msg
onCtrlEnter msg =
    Attribute (\config -> { config | onCtrlEnter = Just msg })


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


{-| Asks the browser to focus the text area when it is shown (the HTML
`autofocus` attribute), as `TextInput.autofocus` does: browsers honor it for one
element at most, so to move the focus yourself, use `Klar.focus` with the `id`.
-}
autofocus : Attribute msg
autofocus =
    Attribute (\config -> { config | autofocus = True })


{-| For codes and data rather than prose (JSON, a list of SKUs): switches off
spell checking, automatic capital letters and autocorrect, as
`TextInput.verbatim` does. Default: the browser decides.
-}
verbatim : Attribute msg
verbatim =
    Attribute (\config -> { config | verbatim = True })


{-| The padding and text size of the field: `Small`, `Medium` or `Large`, from
[Klar.Theme](Klar-Theme). Default `Medium`. The height follows `rows` (or
`minRows` and `maxRows`).
-}
size : Size -> Attribute msg
size value_ =
    Attribute (\config -> { config | size = value_ })


{-| The HTML `autocomplete` token. It tells the browser what the field contains,
such as `"street-address"` or `"off"`. Default: none, so the browser decides.
-}
autocomplete : String -> Attribute msg
autocomplete value_ =
    Attribute (\config -> { config | autocomplete = Just value_ })


{-| The HTML `name` of the text area. Browsers use it to fill in saved values,
and a native form sends the value under this name. Default: none.
-}
name : String -> Attribute msg
name value_ =
    Attribute (\config -> { config | name = Just value_ })


{-| The language of the built-in text, which here is what the counter tells
screen readers ("12 of 500 characters" in English). Default `Locale.default`,
which is English. Texts you pass in yourself are shown as they are.
-}
locale : Locale -> Attribute msg
locale value_ =
    Attribute (\config -> { config | locale = value_ })



-- VIEW


{-| A text area with its label, hint and error message. The value, the events
and everything else are set with attributes.

    TextArea.view
        [ TextArea.label "Comments"
        , TextArea.optionalText "(optional)"
        , TextArea.minRows 2
        , TextArea.maxRows 8
        , TextArea.value model.comments
        , TextArea.onInput CommentsChanged
        ]

-}
view : List (Attribute msg) -> Html msg
view attributes =
    let
        config =
            configure attributes

        field =
            ensureId config

        autoGrow =
            config.minRows /= Nothing || config.maxRows /= Nothing

        lowest =
            config.minRows |> Maybe.withDefault config.rows

        resizable =
            not autoGrow && not config.noResize

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

        growVars =
            ( "--klar-rows-min", String.fromInt lowest )
                :: (case config.maxRows of
                        Just most ->
                            [ ( "--klar-rows-max", String.fromInt (max lowest most) ) ]

                        Nothing ->
                            []
                   )

        control =
            Html.div [ Internal.cls [ "klar-textarea-wrap" ] ]
                [ Html.div
                    [ Internal.cls
                        [ "klar-textarea"
                        , "klar-textarea--" ++ Internal.sizeSuffix config.size
                        , if resizable then
                            "klar-textarea--resize-vertical"

                          else
                            "klar-textarea--resize-none"
                        , if autoGrow then
                            "klar-textarea--autogrow"

                          else
                            ""
                        , if field.error /= Nothing || over then
                            "klar-textarea--invalid"

                          else
                            ""
                        , if config.disabled then
                            "klar-textarea--disabled"

                          else
                            ""
                        , if config.readOnly then
                            "klar-textarea--readonly"

                          else
                            ""
                        ]
                    , Internal.attrIf autoGrow (Internal.styleVars growVars)
                    , Internal.attrIf autoGrow (Attr.attribute "data-replica" config.value)
                    ]
                    [ Html.textarea
                        (TextField.controlAttributes field { describedBy = [ counterId ], invalid = over }
                            ++ [ Internal.cls [ "klar-textarea__control" ]
                               , Attr.value config.value
                               , Attr.placeholder config.placeholder
                               , Attr.rows lowest
                               , Attr.disabled config.disabled
                               , Attr.readonly config.readOnly
                               , Internal.attrIf config.autofocus (Attr.autofocus True)
                               , Internal.attrIf config.verbatim (Attr.attribute "spellcheck" "false")
                               , Internal.attrIf config.verbatim (Attr.attribute "autocapitalize" "off")
                               , Internal.attrIf config.verbatim (Attr.attribute "autocorrect" "off")
                               , Internal.attrMaybe (Attr.attribute "autocomplete") config.autocomplete
                               , Internal.attrMaybe Attr.name config.name
                               , Internal.attrMaybe Events.onInput config.onInput
                               , Internal.attrMaybe Events.onBlur config.onBlur
                               , Internal.attrMaybe Events.onFocus config.onFocus
                               , Internal.attrMaybe (\msg -> Events.preventDefaultOn "keydown" (ctrlEnterDecoder msg)) config.onCtrlEnter
                               ]
                        )
                        []
                    ]
                ]
    in
    -- With a limit, the counter sits at the end of the line under the field,
    -- level with the hint. Either way the text area is always inside the
    -- wrapper, so it does not move into it (and lose the focus) when the
    -- application shows an error while the user types.
    case config.maxLength of
        Just limit ->
            Field.viewWithAside field
                (TextField.counter { id = counterId, locale = config.locale, length = length, limit = limit })
                control

        Nothing ->
            Field.view field control


{-| Ctrl+Enter or Cmd+Enter (and not the Enter that ends a composition).
-}
ctrlEnterDecoder : msg -> Decode.Decoder ( msg, Bool )
ctrlEnterDecoder msg =
    Decode.map2 Tuple.pair TextField.composing Internal.keyEvent
        |> Decode.andThen
            (\( isComposing, event ) ->
                if not isComposing && event.key == "Enter" && (event.ctrl || event.meta) && not event.alt then
                    Decode.succeed ( msg, True )

                else
                    Decode.fail "not Ctrl+Enter"
            )


ensureId : Config msg -> Field.Config
ensureId config =
    if config.field.id == "" then
        Field.setId
            (TextField.generatedId "klar-textarea-"
                [ config.field.label, Just config.placeholder, config.name, config.field.hint, config.field.error ]
            )
            config.field

    else
        config.field
