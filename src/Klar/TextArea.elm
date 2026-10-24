module Klar.TextArea exposing
    ( view, Attribute
    , value, onInput, onBlur, onFocus
    , label, labelHidden, hint, error, errorMaybe, required, optionalText, id
    , rows, minRows, maxRows, Resize(..), resize
    , maxLength, placeholder, size
    , disabled, readOnly, autocomplete, name
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
        ]

The application owns the value, as in [Klar.TextInput](Klar-TextInput): the
text area shows the `value` you give it and reports every change through
`onInput`. It keeps no state of its own, so there is no `State`, `Msg` or
`update`. Enter inserts a new line; there is no `onEnter`.

`label`, `labelHidden`, `hint`, `error`, `errorMaybe`, `required`,
`optionalText` and `id` are the common field attributes. They come with the
field wrapper ([Klar.Field](Klar-Field)) that most Klar inputs are built on, so
they mean the same in all of them: the wrapper draws the label, the required
marker, the hint and the error message around the text area and connects them
for screen readers (`for`, `aria-describedby`, `aria-invalid`,
`aria-required`). An error message is announced when it appears.

**Height.** `rows 4` is a fixed height of four lines, and the user can drag the
corner unless you pass `resize ResizeNone`. `minRows` and `maxRows` make the
field grow with its text instead: never smaller than `minRows`, scrolling after
`maxRows`.

    TextArea.view [ TextArea.minRows 3, TextArea.maxRows 10 ]

With `maxRows` alone, the smallest height is `rows` (3 by default). Growing uses
the CSS property `field-sizing: content`. Browsers without it fall back to a
hidden copy of the text that sizes the field, so the behavior is the same
everywhere and needs no JavaScript.

**Counter.** `maxLength` limits the length and shows a counter such as `12/500`
at the end of the line under the field, level with the hint (hint on the left,
counter on the right). It turns amber when the limit is near and red when the
text is longer than the limit, and screen readers are told the count once the
limit is near.

The text area is always inside the field wrapper, also when there is no `label`,
`hint` or `error` to draw, so it does not move (and lose the keyboard focus) when
the application shows an error while the user is typing. The wrapper of a text
area with nothing to draw adds no space and no width of its own.

The only built-in text is the count read out to screen readers ("12 of 500
characters"); `locale` changes its language.


# View

@docs view, Attribute


# Value and events

@docs value, onInput, onBlur, onFocus


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText, id


# Height and resizing

@docs rows, minRows, maxRows, Resize, resize


# Length, placeholder and size

@docs maxLength, placeholder, size


# State and browser hints

@docs disabled, readOnly, autocomplete, name


# Language

@docs locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Field as Field
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Size(..))


{-| A setting of a text area. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


{-| Whether the user can drag the corner of the text area to change its height:
`ResizeVertical` allows it, `ResizeNone` does not. Used with `resize`.
-}
type Resize
    = ResizeNone
    | ResizeVertical


type alias Config msg =
    { field : Field.Config
    , value : String
    , placeholder : String
    , rows : Int
    , minRows : Maybe Int
    , maxRows : Maybe Int
    , resize : Maybe Resize
    , maxLength : Maybe Int
    , onInput : Maybe (String -> msg)
    , onBlur : Maybe msg
    , onFocus : Maybe msg
    , disabled : Bool
    , readOnly : Bool
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
        , resize = Nothing
        , maxLength = Nothing
        , onInput = Nothing
        , onBlur = Nothing
        , onFocus = Nothing
        , disabled = False
        , readOnly = False
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
the placeholder), so two fields with the same label need explicit ids.
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


{-| Whether the user can drag the corner to change the height. Default:
`ResizeVertical` for a fixed height, `ResizeNone` for a field that grows
(`minRows` or `maxRows`).

    TextArea.resize TextArea.ResizeNone

-}
resize : Resize -> Attribute msg
resize value_ =
    Attribute (\config -> { config | resize = Just value_ })


{-| Limits the text to this many characters (the HTML `maxlength`, so the user
cannot type more) and shows a counter such as `12/500` under the field, at the
end of the line with the hint. The counter turns amber when the limit is near
(10 characters or a tenth of the limit are left, whichever is more) and red when
the text is longer than the limit, which can happen when your `value` is.
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


{-| The language of the built-in text, which here is the count read out to
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

        resizeMode =
            case config.resize of
                Just mode ->
                    mode

                Nothing ->
                    if autoGrow then
                        ResizeNone

                    else
                        ResizeVertical

        growVars =
            ( "--klar-rows-min", String.fromInt lowest )
                :: (case config.maxRows of
                        Just most ->
                            [ ( "--klar-rows-max", String.fromInt (max lowest most) ) ]

                        Nothing ->
                            []
                   )
    in
    withCounter field
        config
        (Html.div [ Internal.cls [ "klar-textarea-wrap" ] ]
            [ Html.div
                [ Internal.cls
                    [ "klar-textarea"
                    , "klar-textarea--" ++ Internal.sizeSuffix config.size
                    , case resizeMode of
                        ResizeNone ->
                            "klar-textarea--resize-none"

                        ResizeVertical ->
                            "klar-textarea--resize-vertical"
                    , if autoGrow then
                        "klar-textarea--autogrow"

                      else
                        ""
                    , if field.error /= Nothing then
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
                    (Field.controlAttributes field
                        ++ [ Internal.cls [ "klar-textarea__control" ]
                           , Attr.value config.value
                           , Attr.placeholder config.placeholder
                           , Attr.rows lowest
                           , Attr.disabled config.disabled
                           , Attr.readonly config.readOnly
                           , Internal.attrMaybe Attr.maxlength config.maxLength
                           , Internal.attrMaybe (Attr.attribute "autocomplete") config.autocomplete
                           , Internal.attrMaybe Attr.name config.name
                           , Internal.attrMaybe Events.onInput config.onInput
                           , Internal.attrMaybe Events.onBlur config.onBlur
                           , Internal.attrMaybe Events.onFocus config.onFocus
                           ]
                    )
                    []
                ]
            ]
        )


{-| With a limit, the counter sits at the end of the line under the field, level
with the hint (hint on the left, counter on the right). Either way the text area
is always inside the wrapper, so it does not move into it (and lose the focus)
when the application shows an error while the user types.
-}
withCounter : Field.Config -> Config msg -> Html msg -> Html msg
withCounter field config control =
    case config.maxLength of
        Just limit ->
            Field.viewWithAside field (viewCounter config.locale (String.length config.value) limit) control

        Nothing ->
            Field.view field control


viewCounter : Locale -> Int -> Int -> Html msg
viewCounter lang length limit =
    let
        remaining =
            limit - length

        near =
            remaining <= max 10 (limit // 10)

        unit =
            Locale.pick lang { nb = "tegn", en = "characters" }

        spoken =
            Locale.pick lang
                { nb = String.fromInt length ++ " av " ++ String.fromInt limit ++ " " ++ unit
                , en = String.fromInt length ++ " of " ++ String.fromInt limit ++ " " ++ unit
                }
    in
    Html.span
        [ Internal.cls
            [ "klar-textarea__counter"
            , if remaining < 0 then
                "klar-textarea__counter--over"

              else if near then
                "klar-textarea__counter--near"

              else
                ""
            ]
        , Internal.attrIf near (Attr.attribute "aria-live" "polite")
        ]
        [ Html.span [ Attr.attribute "aria-hidden" "true" ] [ Html.text (String.fromInt length ++ "/" ++ String.fromInt limit) ]
        , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text spoken ]
        ]


ensureId : Config msg -> Field.Config
ensureId config =
    if config.field.id == "" then
        let
            seed =
                config.field.label
                    |> Maybe.withDefault
                        (if config.placeholder /= "" then
                            config.placeholder

                         else
                            "field"
                        )
        in
        Field.setId ("klar-textarea-" ++ Internal.sanitizeId (String.toLower seed)) config.field

    else
        config.field
