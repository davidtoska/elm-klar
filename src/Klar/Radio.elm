module Klar.Radio exposing
    ( view, Attribute
    , Option, option, withDescription, disabledOption, options
    , selected, onSelect
    , label, labelHidden, hint, error, errorMaybe, required, optionalText, id
    , horizontal, size, disabled
    )

{-| A group of radio buttons: choose exactly one of a few options.

Use when: two to five options where exactly one is chosen and people should see them all.
Do not use when: there are more options (`Klar.Select`), a one-line switch between views is wanted (`Klar.SegmentedControl`) or several may be chosen (`Klar.CheckboxGroup`).

    import Klar.Radio as Radio

    Radio.view
        [ Radio.label "Delivery"
        , Radio.id "order-delivery"
        , Radio.options
            [ Radio.option "standard" "Standard"
            , Radio.option "express" "Express"
                |> Radio.withDescription "Delivered the next working day."
            , Radio.option "pickup" "Pick up in store" |> Radio.disabledOption
            ]
        , Radio.selected (Just model.delivery)
        , Radio.onSelect DeliveryChanged
        ]

The application owns the selection: `selected` says which option is chosen
(`Nothing` for none) and `onSelect` gets the value of the option the user
chooses. The group is a `fieldset` with `role="radiogroup"` whose legend is the
label. Keyboard: Tab enters the group at the chosen option (or the first one when
none is chosen), the arrow keys move to the neighboring option and choose it
(the browser's own radio behavior), and Space chooses the focused one.

Use a radio group when there are two to five options and people should see them
all; use a [Klar.Select](Klar-Select) for more. For a one-line switch between
views or modes use [Klar.SegmentedControl](Klar-SegmentedControl), and for
choosing several options at once [Klar.CheckboxGroup](Klar-CheckboxGroup).

A group takes the attributes that all form controls share (`label`, `hint`,
`error`, `required` ...; see [Klar.Field](Klar-Field)). Its `id` is also the
`name` that its radio buttons share, so two groups on a page need different ids.


# View

@docs view, Attribute


# Options

@docs Option, option, withDescription, disabledOption, options


# Selection

@docs selected, onSelect


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText, id


# Look

@docs horizontal, size, disabled

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Field as Field
import Klar.Internal as Internal
import Klar.Theme as Theme exposing (Size(..))


{-| A setting of a radio group. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


{-| One choice of the group: a value and a text, with an optional description,
and perhaps disabled. Make one with `option`.
-}
type Option
    = Option
        { value : String
        , label : String
        , description : Maybe String
        , disabled : Bool
        }


type alias Config msg =
    { field : Field.Config
    , options : List Option
    , selected : Maybe String
    , onSelect : Maybe (String -> msg)
    , horizontal : Bool
    , disabled : Bool
    , size : Size
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , options = []
        , selected = Nothing
        , onSelect = Nothing
        , horizontal = False
        , disabled = False
        , size = Medium
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })



-- OPTIONS


{-| `option "express" "Express"`: the value that `onSelect` gets when the option
is chosen, and the text next to the button. The values of a group should differ
from each other.
-}
option : String -> String -> Option
option optionValue optionLabel =
    Option { value = optionValue, label = optionLabel, description = Nothing, disabled = False }


{-| A line of gray explanation under the text of the option. A screen reader
reads it together with the option (`aria-describedby`).

    Radio.option "express" "Express"
        |> Radio.withDescription "Delivered the next working day."

-}
withDescription : String -> Option -> Option
withDescription text (Option o) =
    Option { o | description = Just text }


{-| Visible but not selectable: dimmed, and the arrow keys skip it.
-}
disabledOption : Option -> Option
disabledOption (Option o) =
    Option { o | disabled = True }



-- ATTRIBUTES


{-| The legend of the group: its name, shown above the options. Give every
group one, or screen readers cannot say what the choice is for; `labelHidden`
keeps it out of sight.
-}
label : String -> Attribute msg
label text =
    updateField (Field.setLabel text)


{-| Keep the label (the legend) for screen readers only.
-}
labelHidden : Attribute msg
labelHidden =
    updateField Field.setLabelHidden


{-| A line of help under the group, joined to it with `aria-describedby` so a
screen reader reads it with the group.
-}
hint : String -> Attribute msg
hint text =
    updateField (Field.setHint text)


{-| Shows an error message in red under the group and marks it invalid: the
buttons get a red border and the group gets `aria-invalid`. Screen readers read
the message when it appears.
-}
error : String -> Attribute msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    Radio.errorMaybe (Validate.errorFor "order-delivery" errors)

-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the group as required: a `*` after the legend and `aria-required` on
the group. It only marks the group and checks nothing.
-}
required : Attribute msg
required =
    updateField (Field.setRequired True)


{-| Text shown after the legend of a group that is not required, such as
"(optional)". There is no built-in text: without this, an optional group gets
no mark.
-}
optionalText : String -> Attribute msg
optionalText text =
    updateField (Field.setOptionalText text)


{-| The DOM id of the group. Its chosen radio button, or the first one that can
be chosen when none is, gets this id, so an error summary can move focus to the
group. It is also the `name` that all the radio buttons share, which is what
makes them one group for the browser.

Without it the group gets an id made from its label and the values of its
options. That is enough for most pages, but two groups with the same label and
the same option values on one page would be one group (choosing in one would
unselect the other): give such groups an id each.

-}
id : String -> Attribute msg
id value =
    updateField (Field.setId value)


{-| The choices of the group, in the order they are shown.
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


{-| The message sent when the user chooses an option, with the mouse or with the
arrow keys. It gets the value of that option; store it and give it back with
`selected`. Without it the group sends nothing.
-}
onSelect : (String -> msg) -> Attribute msg
onSelect toMsg =
    Attribute (\config -> { config | onSelect = Just toMsg })


{-| Lay the options out in a row, which wraps when there is not enough room,
instead of in a column.
-}
horizontal : Attribute msg
horizontal =
    Attribute (\config -> { config | horizontal = True })


{-| Disables the whole group. The default is `False`.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The size of the radio buttons and their text: `Small`, `Medium` or `Large`
(see [Klar.Theme](Klar-Theme)). The default is `Medium`.
-}
size : Size -> Attribute msg
size value =
    Attribute (\config -> { config | size = value })



-- VIEW


{-| A `fieldset` of radio buttons with its legend, hint and error message. See
the module documentation for the attributes that matter most: `options`,
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
    in
    Field.viewGroup field
        (Html.fieldset
            (Field.controlAttributes field
                ++ [ Attr.id (field.id ++ "-group")
                   , Internal.cls
                        [ "klar-radio-group"
                        , if field.error /= Nothing then
                            "klar-radio-group--invalid"

                          else
                            ""
                        ]
                   , Attr.attribute "role" "radiogroup"
                   , Internal.attrIf (field.label /= Nothing) (Attr.attribute "aria-labelledby" (field.id ++ "-legend"))
                   ]
            )
            [ viewLegend field
            , Html.div
                [ Internal.cls
                    [ "klar-radio-group__options"
                    , if config.horizontal then
                        "klar-radio-group__options--horizontal"

                      else
                        ""
                    ]
                ]
                (List.indexedMap (viewOption config field mainIndex) config.options)
            ]
        )


viewLegend : Field.Config -> Html msg
viewLegend field =
    case field.label of
        Just text ->
            Html.legend
                [ Internal.cls
                    [ "klar-field__label"
                    , "klar-radio-group__legend"
                    , if field.labelHidden then
                        "klar-sr-only"

                      else
                        ""
                    ]
                , Attr.id (field.id ++ "-legend")
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


{-| The radio button that carries the field's DOM id: the chosen one, or the
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
        inputId =
            if index == mainIndex then
                field.id

            else
                field.id ++ "-" ++ String.fromInt index

        descriptionId =
            inputId ++ "-description"

        isDisabled =
            config.disabled || o.disabled
    in
    Html.label
        [ Internal.cls
            [ "klar-radio"
            , "klar-radio--" ++ Internal.sizeSuffix config.size
            , if isDisabled then
                "klar-radio--disabled"

              else
                ""
            ]
        ]
        [ Html.input
            [ Internal.cls [ "klar-radio__input" ]
            , Attr.type_ "radio"
            , Attr.name field.id
            , Attr.id inputId
            , Attr.value o.value
            , Attr.checked (config.selected == Just o.value)
            , Attr.disabled isDisabled
            , Internal.attrMaybe (\_ -> Attr.attribute "aria-describedby" descriptionId) o.description
            , Internal.attrMaybe (\toMsg -> Events.on "change" (Decode.succeed (toMsg o.value))) config.onSelect
            ]
            []
        , Html.span [ Internal.cls [ "klar-radio__dot" ], Attr.attribute "aria-hidden" "true" ] []
        , Html.span [ Internal.cls [ "klar-radio__text" ] ]
            [ Html.span [ Internal.cls [ "klar-radio__label" ] ] [ Html.text o.label ]
            , Internal.viewMaybe
                (\text ->
                    Html.span [ Internal.cls [ "klar-radio__description" ], Attr.id descriptionId ] [ Html.text text ]
                )
                o.description
            ]
        ]


{-| The group's id (and so the `name` its radio buttons share). Without `id`
it is made from the label and the values of the options, so two groups with
the same label but other options are still two groups.
-}
ensureId : Config msg -> Field.Config
ensureId config =
    if config.field.id == "" then
        let
            values =
                List.map (\(Option o) -> o.value) config.options
        in
        Field.setId
            ("klar-radio-"
                ++ Internal.sanitizeId
                    (String.toLower (String.join "-" (Maybe.withDefault "group" config.field.label :: values)))
            )
            config.field

    else
        config.field
