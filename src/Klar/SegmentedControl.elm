module Klar.SegmentedControl exposing
    ( view, Attribute
    , Option, option, withIcon, iconOnly, disabledOption, options
    , selected, onSelect
    , label, labelHidden, ariaLabel, hint, error, errorMaybe, required, optionalText, id
    , size, fullWidth, disabled
    )

{-| A row of joined options where exactly one is chosen: a switch between
views ("List" / "Grid"), periods ("Day" / "Week" / "Month") or modes.

Use when: a few short options that switch what the page shows, such as List or Grid, or Day, Week and Month.
Do not use when: the options need a sentence of explanation (`Klar.Radio`), there are many (`Klar.Select`) or panels of content are switched (`Klar.Tabs`).

    import Klar.Icon as Icon
    import Klar.SegmentedControl as SegmentedControl

    SegmentedControl.view
        [ SegmentedControl.ariaLabel "Layout"
        , SegmentedControl.options
            [ SegmentedControl.option "list" "List" |> SegmentedControl.withIcon Icon.list
            , SegmentedControl.option "grid" "Grid" |> SegmentedControl.withIcon Icon.grid
            ]
        , SegmentedControl.selected (Just model.layout)
        , SegmentedControl.onSelect LayoutChanged
        ]

The application owns the choice: `selected` says which option is chosen
(`Nothing` for none) and `onSelect` gets the value of the option the user
chooses.

It is a group of radio buttons that looks like joined buttons, so the
keyboard works the way people expect: Tab enters the group at the chosen
option, and the arrow keys move to the neighboring option and choose it. Give
it a visible `label` or an `ariaLabel`, which is the name of the group for
screen readers.

Use it for a few short options that change what the page shows. For options that
need a sentence of explanation use [Klar.Radio](Klar-Radio), for more than a
handful [Klar.Select](Klar-Select), and for switching between panels of content
[Klar.Tabs](Klar-Tabs). It takes the attributes that all form controls share
(`label`, `hint`, `error`, `required` ...; see [Klar.Field](Klar-Field)), and its
`id` is also the `name` that its radio buttons share.


# View

@docs view, Attribute


# Options

@docs Option, option, withIcon, iconOnly, disabledOption, options


# Selection

@docs selected, onSelect


# Label, hint and error

@docs label, labelHidden, ariaLabel, hint, error, errorMaybe, required, optionalText, id


# Look

@docs size, fullWidth, disabled

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Field as Field
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Theme as Theme exposing (Size(..))


{-| A setting of a segmented control. Make them with the functions below and
pass a list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


{-| One segment of the control: a value and a text, with an optional icon, and
perhaps disabled. Make one with `option`.
-}
type Option
    = Option
        { value : String
        , label : String
        , icon : Maybe Icon
        , iconOnly : Bool
        , disabled : Bool
        }


type alias Config msg =
    { field : Field.Config
    , ariaLabel : Maybe String
    , options : List Option
    , selected : Maybe String
    , onSelect : Maybe (String -> msg)
    , size : Size
    , fullWidth : Bool
    , disabled : Bool
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , ariaLabel = Nothing
        , options = []
        , selected = Nothing
        , onSelect = Nothing
        , size = Medium
        , fullWidth = False
        , disabled = False
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })



-- OPTIONS


{-| `option "week" "Week"`: the value that `onSelect` gets when the segment is
chosen, and the text of the segment. The values of a control should differ from
each other.
-}
option : String -> String -> Option
option optionValue optionLabel =
    Option { value = optionValue, label = optionLabel, icon = Nothing, iconOnly = False, disabled = False }


{-| An icon before the text of the segment. See [Klar.Icon](Klar-Icon), and
`iconOnly` to drop the text.

    SegmentedControl.option "list" "List" |> SegmentedControl.withIcon Icon.list

-}
withIcon : Icon -> Option -> Option
withIcon icon (Option o) =
    Option { o | icon = Just icon }


{-| Show only the icon, which needs `withIcon`. The text stays as the accessible
name and as the tooltip, so it must still say what the segment is.
-}
iconOnly : Option -> Option
iconOnly (Option o) =
    Option { o | iconOnly = True }


{-| Visible but not selectable: dimmed, and the arrow keys skip it.
-}
disabledOption : Option -> Option
disabledOption (Option o) =
    Option { o | disabled = True }



-- ATTRIBUTES


{-| The label, shown above the control and naming it for screen readers. Give
the control a `label` or an `ariaLabel`.
-}
label : String -> Attribute msg
label text =
    updateField (Field.setLabel text)


{-| Keep the label for screen readers only.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| The accessible name when there is no visible label, such as "Layout" for a
control that is clear from its icons. It becomes the `aria-label` of the group;
a `label`, when there is one, takes its place.
-}
ariaLabel : String -> Attribute msg
ariaLabel text =
    Attribute (\config -> { config | ariaLabel = Just text })


{-| A line of help under the control, joined to it with `aria-describedby` so a
screen reader reads it with the control.
-}
hint : String -> Attribute msg
hint text =
    updateField (Field.setHint text)


{-| Shows an error message in red under the control and marks it invalid: the
border turns red and the group gets `aria-invalid`. Screen readers read the
message when it appears.
-}
error : String -> Attribute msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    SegmentedControl.errorMaybe (Validate.errorFor "report-period" errors)

-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the control as required: a `*` after the label and `aria-required` on
the group. It only marks the control and checks nothing.
-}
required : Attribute msg
required =
    updateField (Field.setRequired True)


{-| Text shown after the label of a control that is not required, such as
"(optional)". There is no built-in text: without this, an optional control gets
no mark.
-}
optionalText : String -> Attribute msg
optionalText text =
    updateField (Field.setOptionalText text)


{-| The DOM id of the group. The chosen segment, or the first one that can be
chosen when none is, gets this id, so an error summary can move focus to the
control. It is also the `name` that the segments share, which makes them one
group for the browser: without an id it is made from the label (or `ariaLabel`)
and the option values, and two controls with the same label and the same option
values on one page need an id each.
-}
id : String -> Attribute msg
id value =
    updateField (Field.setId value)


{-| The segments, in the order they are shown.
-}
options : List Option -> Attribute msg
options value =
    Attribute (\config -> { config | options = value })


{-| The value of the chosen option, or `Nothing` when none is chosen, which is
the default.
-}
selected : Maybe String -> Attribute msg
selected value =
    Attribute (\config -> { config | selected = value })


{-| The message sent when the user chooses a segment, with the mouse or with the
arrow keys. It gets the value of that option; store it and give it back with
`selected`. Without it the control sends nothing.

    SegmentedControl.onSelect PeriodChanged

-}
onSelect : (String -> msg) -> Attribute msg
onSelect toMsg =
    Attribute (\config -> { config | onSelect = Just toMsg })


{-| The height and text size of the segments: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar-Theme)). The default is `Medium`.
-}
size : Size -> Attribute msg
size value =
    Attribute (\config -> { config | size = value })


{-| Stretch over the whole width, every segment equally wide.
-}
fullWidth : Attribute msg
fullWidth =
    Attribute (\config -> { config | fullWidth = True })


{-| Disables the whole control. The default is `False`.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })



-- VIEW


{-| A row of joined segments with an optional label, hint and error message.
See the module documentation for the attributes that matter most: `options`,
`selected` and `onSelect`.
-}
view : List (Attribute msg) -> Html msg
view attributes =
    let
        config =
            configure attributes

        field =
            ensureId config

        mainIndex =
            mainOptionIndex config

        labelId =
            field.id ++ "-label"
    in
    Field.viewGroup field
        (Html.div [ Internal.cls [ "klar-segmented-field" ] ]
            [ case field.label of
                Just text ->
                    Html.span
                        [ Internal.cls
                            [ "klar-field__label"
                            , if field.labelHidden then
                                "klar-sr-only"

                              else
                                ""
                            ]
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

                Nothing ->
                    Html.text ""
            , Html.div
                (Field.controlAttributes field
                    ++ [ Attr.id (field.id ++ "-group")
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
                       , case ( field.label, config.ariaLabel ) of
                            ( Just _, _ ) ->
                                Attr.attribute "aria-labelledby" labelId

                            ( Nothing, Just text ) ->
                                Attr.attribute "aria-label" text

                            _ ->
                                Internal.noAttr
                       ]
                )
                (List.indexedMap (viewOption config field mainIndex) config.options)
            ]
        )


{-| The segment that carries the field's DOM id: the chosen one, or the
first one that can be chosen.
-}
mainOptionIndex : Config msg -> Int
mainOptionIndex config =
    let
        indexed =
            List.indexedMap Tuple.pair config.options

        isChosen ( _, Option o ) =
            config.selected == Just o.value

        isEnabled ( _, Option o ) =
            not o.disabled
    in
    case List.filter isChosen indexed of
        ( index, _ ) :: _ ->
            index

        [] ->
            case List.filter isEnabled indexed of
                ( index, _ ) :: _ ->
                    index

                [] ->
                    0


viewOption : Config msg -> Field.Config -> Int -> Int -> Option -> Html msg
viewOption config field mainIndex index (Option o) =
    let
        isDisabled =
            config.disabled || o.disabled
    in
    Html.label
        [ Internal.cls
            [ "klar-segmented__item"
            , if isDisabled then
                "klar-segmented__item--disabled"

              else
                ""
            ]
        ]
        [ Html.input
            [ Internal.cls [ "klar-segmented__input" ]
            , Attr.type_ "radio"
            , Attr.name field.id
            , Attr.id
                (if index == mainIndex then
                    field.id

                 else
                    field.id ++ "-" ++ String.fromInt index
                )
            , Attr.value o.value
            , Attr.checked (config.selected == Just o.value)
            , Attr.disabled isDisabled
            , Internal.attrMaybe (\toMsg -> Events.on "change" (Decode.succeed (toMsg o.value))) config.onSelect
            ]
            []
        , Html.span
            [ Internal.cls
                [ "klar-segmented__content"
                , if o.iconOnly then
                    "klar-segmented__content--icon-only"

                  else
                    ""
                ]
            , Internal.attrIf o.iconOnly (Attr.title o.label)
            ]
            [ Internal.viewMaybe Icon.view o.icon
            , Html.span
                [ Internal.cls
                    [ "klar-segmented__label"
                    , if o.iconOnly then
                        "klar-sr-only"

                      else
                        ""
                    ]

                -- a label cut short with an ellipsis can still be read
                , Internal.attrIf (not o.iconOnly) (Attr.title o.label)
                ]
                [ Html.text o.label ]
            ]
        ]


{-| The group's id, which is also the `name` its radio buttons share. Without
`id` it is made from the label (or `ariaLabel`) and the values of the options,
so two controls with the same label but other options are two groups.
-}
ensureId : Config msg -> Field.Config
ensureId config =
    if config.field.id == "" then
        let
            values =
                List.map (\(Option o) -> o.value) config.options
        in
        Field.setId
            ("klar-segmented-"
                ++ Internal.sanitizeId
                    (String.toLower
                        (String.join "-"
                            (Maybe.withDefault (Maybe.withDefault "control" config.ariaLabel) config.field.label :: values)
                        )
                    )
            )
            config.field

    else
        config.field
