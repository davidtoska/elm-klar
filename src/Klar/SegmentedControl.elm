module Klar.SegmentedControl exposing
    ( view, Attribute
    , Option, option, iconOption, withIcon, disabledOption, options
    , selected, onChange
    , label, labelHidden, hint, error, errorMaybe, required, optionalText, id
    , size, fullWidth, disabled, readOnly
    )

{-| A row of joined options where exactly one is chosen: a switch between
views ("List" / "Grid"), periods ("Day" / "Week" / "Month") or modes.

Use when: a few short options that switch what the page shows, such as List or Grid, or Day, Week and Month.
Do not use when: the options need a sentence of explanation (`Klar.Radio`), there are many (`Klar.Select`), none or several may be on (`Klar.ToggleGroup`) or panels of content are switched (`Klar.Tabs`).

    import Klar.Icon as Icon
    import Klar.SegmentedControl as SegmentedControl

    -- model:  { layout : Layout }   (ListLayout, GridLayout: your own type)
    SegmentedControl.view
        [ SegmentedControl.label "Layout"
        , SegmentedControl.labelHidden
        , SegmentedControl.options
            [ SegmentedControl.option ListLayout "List" |> SegmentedControl.withIcon Icon.list
            , SegmentedControl.option GridLayout "Grid" |> SegmentedControl.withIcon Icon.grid
            ]
        , SegmentedControl.selected model.layout
        , SegmentedControl.onChange LayoutChanged
        ]

    -- update
    LayoutChanged layout ->
        ( { model | layout = layout }, Cmd.none )

**The values are your own** (`ListLayout`, `Week`, an `Int`): an option is made with
its value, `selected` is the chosen value and `onChange` gets the value of the
segment the user chooses. They are compared with `==`, so they have to be plain
data; there is nothing to convert to or from a `String`. The application owns the
choice and gives it back in `selected`: one value, because one segment is always
chosen. A control without `onChange` is read-only.

It is a group of radio buttons that looks like joined buttons, so the keyboard
works the way people expect: Tab enters the group at the chosen segment, and the
arrow keys move to the next or previous segment and choose it (skipping disabled
ones and wrapping around at the ends). The `label` names the group for screen
readers; `labelHidden` keeps it out of sight when the segments speak for
themselves.

Use it for a few short options that change what the page shows. For options that
need a sentence of explanation use [Klar.Radio](Klar-Radio), for more than a
handful [Klar.Select](Klar-Select), for options that are on or off
[Klar.ToggleGroup](Klar-ToggleGroup), and for switching between panels of content
[Klar.Tabs](Klar-Tabs). It takes the attributes that all form controls share
(`label`, `hint`, `error`, `required` ...; see [Klar.Field](Klar-Field)), and its
`id` is also the `name` that its radio buttons share.


# View

@docs view, Attribute


# Options

@docs Option, option, iconOption, withIcon, disabledOption, options


# Selection

@docs selected, onChange


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText, id


# Look and behavior

@docs size, fullWidth, disabled, readOnly

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Field as Field
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.Choice as Choice
import Klar.Theme as Theme exposing (Size(..))


{-| A setting of a segmented control. Make them with the functions below and
pass a list to `view`; later attributes win over earlier ones. `value` is the
type of the values of the segments (your own), `msg` the message of `onChange`.
-}
type Attribute value msg
    = Attribute (Config value msg -> Config value msg)


{-| One segment of the control: a value of your own and a text, with an optional
icon, and perhaps disabled. Make one with `option` or `iconOption`.
-}
type Option value
    = Option
        { value : value
        , label : String
        , content : Content
        , disabled : Bool
        }


type Content
    = TextOnly
    | TextAndIcon Icon
    | IconOnly Icon


type alias Config value msg =
    { field : Field.Config
    , options : List (Option value)
    , selected : Maybe value
    , onChange : Maybe (value -> msg)
    , size : Size
    , fullWidth : Bool
    , disabled : Bool
    , readOnly : Bool
    }


configure : List (Attribute value msg) -> Config value msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , options = []
        , selected = Nothing
        , onChange = Nothing
        , size = Medium
        , fullWidth = False
        , disabled = False
        , readOnly = False
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute value msg
updateField change =
    Attribute (\config -> { config | field = change config.field })



-- OPTIONS


{-| `option Week "Week"`: the value that `onChange` gets when the segment is
chosen (of your own type), and the text of the segment. The values of a control
should differ from each other.
-}
option : value -> String -> Option value
option optionValue optionLabel =
    Option { value = optionValue, label = optionLabel, content = TextOnly, disabled = False }


{-| A segment with only an icon. The text is not shown, but it is the accessible
name and the native tooltip, so it must say what the segment is:
`iconOption GridLayout Icon.grid "Grid"`.
-}
iconOption : value -> Icon -> String -> Option value
iconOption optionValue icon optionLabel =
    Option { value = optionValue, label = optionLabel, content = IconOnly icon, disabled = False }


{-| An icon before the text of the segment (see [Klar.Icon](Klar-Icon)). The icon
is decoration. On a segment made with `iconOption` it replaces the icon.

    SegmentedControl.option ListLayout "List" |> SegmentedControl.withIcon Icon.list

-}
withIcon : Icon -> Option value -> Option value
withIcon icon (Option o) =
    Option
        { o
            | content =
                case o.content of
                    IconOnly _ ->
                        IconOnly icon

                    _ ->
                        TextAndIcon icon
        }


{-| Visible but not selectable: dimmed, and the arrow keys skip it.
-}
disabledOption : Option value -> Option value
disabledOption (Option o) =
    Option { o | disabled = True }



-- ATTRIBUTES


{-| The label, shown above the control and naming it for screen readers. Give
every control one; `labelHidden` keeps it for screen readers only.
-}
label : String -> Attribute value msg
label text =
    updateField (Field.setLabel text)


{-| Keep the label for screen readers only, for a control that is clear from its
segments, such as "Layout" for List and Grid icons: it becomes the `aria-label`
of the group. The label is still needed.
-}
labelHidden : Attribute value msg
labelHidden =
    updateField Field.setLabelHidden


{-| A line of help under the control, joined to it with `aria-describedby` so a
screen reader reads it with the control.
-}
hint : String -> Attribute value msg
hint text =
    updateField (Field.setHint text)


{-| Shows an error message in red under the control and marks it invalid: the
border turns red and the group gets `aria-invalid`. Screen readers read the
message when it appears.
-}
error : String -> Attribute value msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    SegmentedControl.errorMaybe (Validate.errorFor "report-period" errors)

-}
errorMaybe : Maybe String -> Attribute value msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the control as required: a `*` after the label and `aria-required` on
the group. It only marks the control and checks nothing.
-}
required : Attribute value msg
required =
    updateField (Field.setRequired True)


{-| Text shown after the label of a control that is not required, such as
"(optional)". There is no built-in text: without this, an optional control gets
no mark.
-}
optionalText : String -> Attribute value msg
optionalText text =
    updateField (Field.setOptionalText text)


{-| The DOM id of the group. The chosen segment, or the first one that can be
chosen when none is, gets this id, so an error summary can move focus to the
control (when no segment can take the focus, the group gets it). It is also the
`name` that the segments share, which makes them one group for the browser:
without an id it is made from the label and the texts of the segments, and two
controls with the same label and the same texts on one page need an id each.
-}
id : String -> Attribute value msg
id value =
    updateField (Field.setId value)


{-| The segments, in the order they are shown.
-}
options : List (Option value) -> Attribute value msg
options value =
    Attribute (\config -> { config | options = value })


{-| The value of the chosen segment. One segment is always chosen, so it is a
value, not a `Maybe`; a value that no segment has (or no `selected`) chooses
nothing, which only makes sense while the options are loading.
-}
selected : value -> Attribute value msg
selected value =
    Attribute (\config -> { config | selected = Just value })


{-| The message sent when the user chooses a segment, with the mouse or with the
arrow keys. It gets the value of that segment; store it and give it back with
`selected`. Without it the control is read-only (see `readOnly`).

    SegmentedControl.onChange PeriodChanged

-}
onChange : (value -> msg) -> Attribute value msg
onChange toMsg =
    Attribute (\config -> { config | onChange = Just toMsg })


{-| The height and text size of the segments: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar-Theme)). The default is `Medium`.
-}
size : Size -> Attribute value msg
size value =
    Attribute (\config -> { config | size = value })


{-| Stretch over the whole width, every segment equally wide.
-}
fullWidth : Attribute value msg
fullWidth =
    Attribute (\config -> { config | fullWidth = True })


{-| Disables the whole control: dimmed, skipped by Tab, and nothing can be
chosen. The default is `False`.
-}
disabled : Bool -> Attribute value msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| Shows the choice without letting the user change it, for example while a
report is being made. Unlike `disabled` it is not dimmed, and Tab still reaches
the chosen segment, so a screen reader can read it; the group has
`aria-readonly`, and the other segments cannot be chosen with the mouse or the
arrow keys. Nothing is sent to `onChange`. The default is `False`.
-}
readOnly : Bool -> Attribute value msg
readOnly value =
    Attribute (\config -> { config | readOnly = value })



-- VIEW


{-| A row of joined segments with a label (shown or hidden), a hint and an error
message. See the module documentation for the attributes that matter most:
`label`, `options`, `selected` and `onChange`.
-}
view : List (Attribute value msg) -> Html msg
view attributes =
    let
        config =
            configure attributes

        field =
            ensureId config

        isReadOnly =
            config.readOnly || not (Choice.isSet config.onChange)

        mainIndex =
            mainOptionIndex config isReadOnly

        labelId =
            field.id ++ "-label"
    in
    Field.viewGroup field
        (Html.div [ Internal.cls [ "klar-segmented-field" ] ]
            [ case ( field.label, field.labelHidden ) of
                ( Just text, False ) ->
                    Html.span
                        [ Internal.cls [ "klar-field__label" ]
                        , Attr.id labelId
                        ]
                        [ Html.text text
                        , Internal.viewIf field.required
                            (Html.span [ Internal.cls [ "klar-field__required" ], Attr.attribute "aria-hidden" "true" ] [ Html.text "*" ])
                        , case ( field.required, field.optionalText ) of
                            ( False, Just optional ) ->
                                Html.span [ Internal.cls [ "klar-field__optional" ] ] [ Html.text optional ]

                            _ ->
                                Html.text ""
                        ]

                _ ->
                    Html.text ""
            , Html.div
                (Field.controlAttributes field
                    ++ [ case mainIndex of
                            Just _ ->
                                Attr.id (field.id ++ "-group")

                            Nothing ->
                                -- No segment can take the focus, so the group
                                -- does, when the error summary moves it here.
                                Attr.id field.id
                       , Internal.attrIf (mainIndex == Nothing) (Attr.tabindex -1)
                       , Internal.cls
                            [ "klar-segmented"
                            , "klar-segmented--" ++ Internal.sizeSuffix config.size
                            , if config.fullWidth then
                                "klar-segmented--full"

                              else
                                ""
                            , if config.disabled then
                                "klar-segmented--disabled"

                              else
                                ""
                            , if field.error /= Nothing then
                                "klar-segmented--invalid"

                              else
                                ""
                            ]
                       , Attr.attribute "role" "radiogroup"

                       -- A hidden label names the group directly, so it adds no
                       -- element and no id that a surrounding field could have.
                       , case ( field.label, field.labelHidden ) of
                            ( Just _, False ) ->
                                Attr.attribute "aria-labelledby" labelId

                            ( Just text, True ) ->
                                Attr.attribute "aria-label" text

                            ( Nothing, _ ) ->
                                Internal.noAttr
                       , Internal.attrIf (isReadOnly && not config.disabled) (Attr.attribute "aria-readonly" "true")
                       ]
                )
                (List.indexedMap (viewOption config isReadOnly field mainIndex) config.options)
            ]
        )


{-| The segment that carries the field's DOM id: the chosen one, or the first
one that can be chosen (in a read-only control only the chosen one can take the
focus). `Nothing` when no segment can take the focus.
-}
mainOptionIndex : Config value msg -> Bool -> Maybe Int
mainOptionIndex config isReadOnly =
    let
        indexed =
            List.indexedMap Tuple.pair config.options

        isChosen ( _, Option o ) =
            config.selected == Just o.value

        isEnabled ( _, Option o ) =
            not o.disabled
    in
    if config.disabled then
        Nothing

    else
        case List.filter (\entry -> isChosen entry && isEnabled entry) indexed of
            ( index, _ ) :: _ ->
                Just index

            [] ->
                if isReadOnly then
                    Nothing

                else
                    List.filter isEnabled indexed
                        |> List.head
                        |> Maybe.map Tuple.first


viewOption : Config value msg -> Bool -> Field.Config -> Maybe Int -> Int -> Option value -> Html msg
viewOption config isReadOnly field mainIndex index (Option o) =
    let
        isChosen =
            config.selected == Just o.value

        isDisabled =
            config.disabled || o.disabled

        -- In a read-only control the segments that are not chosen cannot be
        -- chosen: the arrow keys skip them and a click does nothing, and the
        -- chosen one keeps the focus. They are not dimmed like disabled ones.
        lockedByReadOnly =
            isReadOnly && not isChosen && not isDisabled

        iconOnly =
            case o.content of
                IconOnly _ ->
                    True

                _ ->
                    False

        icon =
            case o.content of
                TextOnly ->
                    Nothing

                TextAndIcon i ->
                    Just i

                IconOnly i ->
                    Just i
    in
    Html.label
        [ Internal.cls
            [ "klar-segmented__item"
            , if isDisabled then
                "klar-segmented__item--disabled"

              else
                ""
            , if isReadOnly && not isDisabled then
                "klar-segmented__item--readonly"

              else
                ""
            ]
        ]
        [ Html.input
            [ Internal.cls [ "klar-segmented__input" ]
            , Attr.type_ "radio"
            , Attr.name field.id
            , Attr.id
                (if Just index == mainIndex then
                    field.id

                 else
                    field.id ++ "-" ++ String.fromInt index
                )

            -- The value of the segment is the application's own: the DOM gets
            -- its position, and the message carries the value itself.
            , Attr.value (String.fromInt index)
            , Attr.checked isChosen
            , Attr.disabled (isDisabled || lockedByReadOnly)
            , if isReadOnly then
                Internal.noAttr

              else
                Internal.attrMaybe (\toMsg -> Events.on "change" (Decode.succeed (toMsg o.value))) config.onChange
            ]
            []
        , Html.span
            [ Internal.cls
                [ "klar-segmented__content"
                , if iconOnly then
                    "klar-segmented__content--icon-only"

                  else
                    ""
                ]
            , Internal.attrIf iconOnly (Attr.title o.label)
            ]
            [ Internal.viewMaybe Icon.view icon
            , Html.span
                [ Internal.cls
                    [ "klar-segmented__label"
                    , if iconOnly then
                        "klar-sr-only"

                      else
                        ""
                    ]

                -- a label cut short with an ellipsis can still be read
                , Internal.attrIf (not iconOnly) (Attr.title o.label)
                ]
                [ Html.text o.label ]
            ]
        ]


{-| The group's id, which is also the `name` its radio buttons share. Without
`id` it is made from the label and the texts of the segments, so two controls
with the same label but other segments are two groups.
-}
ensureId : Config value msg -> Field.Config
ensureId config =
    if config.field.id == "" then
        Field.setId
            (Choice.groupId "segmented" config.field.label (List.map (\(Option o) -> o.label) config.options))
            config.field

    else
        config.field
