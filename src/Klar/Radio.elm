module Klar.Radio exposing
    ( view, Attribute
    , Option, option, withDescription, disabledOption, options
    , selected, onChange
    , label, labelHidden, hint, error, errorMaybe, required, optionalText, id
    , horizontal, size, disabled, readOnly
    )

{-| A group of radio buttons: choose exactly one of a few options.

Use when: two to five options where exactly one is chosen and people should see them all.
Do not use when: there are more options (`Klar.Select`), a one-line switch between views is wanted (`Klar.SegmentedControl`) or several may be chosen (`Klar.CheckboxGroup`).

    import Klar.Radio as Radio

    -- model:  { delivery : Delivery }   (Standard, Express, Pickup: your own type)
    Radio.view
        [ Radio.label "Delivery"
        , Radio.id "order-delivery"
        , Radio.options
            [ Radio.option Standard "Standard"
            , Radio.option Express "Express"
                |> Radio.withDescription "Delivered the next working day."
            , Radio.option Pickup "Pick up in store" |> Radio.disabledOption
            ]
        , Radio.selected (Just model.delivery)
        , Radio.onChange DeliveryChanged
        ]

    -- update
    DeliveryChanged delivery ->
        ( { model | delivery = delivery }, Cmd.none )

**The values are your own** (`Standard`, a warehouse id, an `Int`): an option is
made with its value, `selected` is the chosen value (`Nothing` for none) and
`onChange` gets the value of the option the user chooses. They are compared with
`==`, so they have to be plain data; there is nothing to convert to or from a
`String`. The application owns the choice and gives it back in `selected`; a click
changes nothing by itself. A group without `onChange` is read-only.

The group is a `fieldset` with `role="radiogroup"` whose legend is the label.
Keyboard (the browser's own radio behavior): Tab enters the group at the chosen
option, or at the first one (Shift+Tab: the last one) when none is chosen; the arrow
keys move to the next or previous option and choose it, skip disabled options and
wrap around at the ends; Space chooses the focused one.

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

@docs selected, onChange


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText, id


# Look and behavior

@docs horizontal, size, disabled, readOnly

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Field as Field
import Klar.Internal as Internal
import Klar.Internal.Choice as Choice
import Klar.Theme as Theme exposing (Size(..))


{-| A setting of a radio group. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones. `value` is the type of
the values of the options (your own), `msg` the message of `onChange`.
-}
type Attribute value msg
    = Attribute (Config value msg -> Config value msg)


{-| One choice of the group: a value of your own and a text, with an optional
description, and perhaps disabled. Make one with `option`.
-}
type Option value
    = Option
        { value : value
        , label : String
        , description : Maybe String
        , disabled : Bool
        }


type alias Config value msg =
    { field : Field.Config
    , options : List (Option value)
    , selected : Maybe value
    , onChange : Maybe (value -> msg)
    , horizontal : Bool
    , disabled : Bool
    , readOnly : Bool
    , size : Size
    }


configure : List (Attribute value msg) -> Config value msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , options = []
        , selected = Nothing
        , onChange = Nothing
        , horizontal = False
        , disabled = False
        , readOnly = False
        , size = Medium
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute value msg
updateField change =
    Attribute (\config -> { config | field = change config.field })



-- OPTIONS


{-| `option Express "Express"`: the value that `onChange` gets when the option is
chosen (of your own type), and the text next to the button. The values of a
group should differ from each other.
-}
option : value -> String -> Option value
option optionValue optionLabel =
    Option { value = optionValue, label = optionLabel, description = Nothing, disabled = False }


{-| A line of gray explanation under the text of the option. A screen reader
reads it together with the option (`aria-describedby`).

    Radio.option Express "Express"
        |> Radio.withDescription "Delivered the next working day."

-}
withDescription : String -> Option value -> Option value
withDescription text (Option o) =
    Option { o | description = Just text }


{-| Visible but not selectable: dimmed, and the arrow keys skip it.
-}
disabledOption : Option value -> Option value
disabledOption (Option o) =
    Option { o | disabled = True }



-- ATTRIBUTES


{-| The legend of the group: its name, shown above the options. Give every
group one, or screen readers cannot say what the choice is for; `labelHidden`
keeps it out of sight.
-}
label : String -> Attribute value msg
label text =
    updateField (Field.setLabel text)


{-| Keep the label (the legend) for screen readers only.
-}
labelHidden : Attribute value msg
labelHidden =
    updateField Field.setLabelHidden


{-| A line of help under the group, joined to it with `aria-describedby` so a
screen reader reads it with the group.
-}
hint : String -> Attribute value msg
hint text =
    updateField (Field.setHint text)


{-| Shows an error message in red under the group and marks it invalid: the
buttons get a red border and the group gets `aria-invalid`. Screen readers read
the message when it appears.
-}
error : String -> Attribute value msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    Radio.errorMaybe (Validate.errorFor "order-delivery" errors)

-}
errorMaybe : Maybe String -> Attribute value msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the group as required: a `*` after the legend and `aria-required` on
the group. It only marks the group and checks nothing.
-}
required : Attribute value msg
required =
    updateField (Field.setRequired True)


{-| Text shown after the legend of a group that is not required, such as
"(optional)". There is no built-in text: without this, an optional group gets
no mark.
-}
optionalText : String -> Attribute value msg
optionalText text =
    updateField (Field.setOptionalText text)


{-| The DOM id of the group. Its chosen radio button, or the first one that can
be chosen when none is, gets this id, so an error summary can move focus to the
group (when no option can take the focus, the `fieldset` gets it). It is also the
`name` that all the radio buttons share, which is what makes them one group for
the browser.

Without it the group gets an id made from its label and the texts of its
options. That is enough for most pages, but two groups with the same label and
the same option texts on one page (in the rows of a table, say) would be one
group, where choosing in one clears the other: give such groups an id each.

-}
id : String -> Attribute value msg
id value =
    updateField (Field.setId value)


{-| The choices of the group, in the order they are shown.
-}
options : List (Option value) -> Attribute value msg
options value =
    Attribute (\config -> { config | options = value })


{-| The value of the chosen option, or `Nothing` when none is chosen, which is
the default. A value that no option has chooses nothing.
-}
selected : Maybe value -> Attribute value msg
selected value =
    Attribute (\config -> { config | selected = value })


{-| The message sent when the user chooses an option, with the mouse or with the
arrow keys. It gets the value of that option; store it and give it back with
`selected`. Without it the group is read-only (see `readOnly`).

    Radio.onChange DeliveryChanged

-}
onChange : (value -> msg) -> Attribute value msg
onChange toMsg =
    Attribute (\config -> { config | onChange = Just toMsg })


{-| Lay the options out in a row, which wraps when there is not enough room,
instead of in a column.
-}
horizontal : Attribute value msg
horizontal =
    Attribute (\config -> { config | horizontal = True })


{-| Disables the whole group: dimmed, skipped by Tab, and nothing can be chosen.
The default is `False`.
-}
disabled : Bool -> Attribute value msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| Shows the choice without letting the user change it, for a record the user
may read but not edit. Unlike `disabled` it is not dimmed, and Tab still reaches
the chosen option, so a screen reader can read it ("Express, radio button,
checked"); the group has `aria-readonly`, and the other options cannot be chosen
with the mouse or the arrow keys. Nothing is sent to `onChange`. The default is
`False`.
-}
readOnly : Bool -> Attribute value msg
readOnly value =
    Attribute (\config -> { config | readOnly = value })


{-| The size of the radio buttons and their text: `Small`, `Medium` or `Large`
(see [Klar.Theme](Klar-Theme)). The default is `Medium`.
-}
size : Size -> Attribute value msg
size value =
    Attribute (\config -> { config | size = value })



-- VIEW


{-| A `fieldset` of radio buttons with its legend, hint and error message. See
the module documentation for the attributes that matter most: `options`,
`selected` and `onChange`.
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
    in
    Field.viewGroup field
        (Html.fieldset
            (Field.controlAttributes field
                ++ [ case mainIndex of
                        Just _ ->
                            Attr.id (field.id ++ "-group")

                        Nothing ->
                            -- No radio button can take the focus, so the group
                            -- does, when the error summary moves it here.
                            Attr.id field.id
                   , Internal.attrIf (mainIndex == Nothing) (Attr.tabindex -1)
                   , Internal.cls
                        [ "klar-radio-group"
                        , if field.error /= Nothing then
                            "klar-radio-group--invalid"

                          else
                            ""
                        ]
                   , Attr.attribute "role" "radiogroup"
                   , Internal.attrIf (field.label /= Nothing) (Attr.attribute "aria-labelledby" (field.id ++ "-legend"))
                   , Internal.attrIf (isReadOnly && not config.disabled) (Attr.attribute "aria-readonly" "true")
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
                (List.indexedMap (viewOption config isReadOnly field mainIndex) config.options)
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
first one that can be chosen (in a read-only group only the chosen one can take
the focus). `Nothing` when no radio button can take the focus.
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
        inputId =
            if Just index == mainIndex then
                field.id

            else
                field.id ++ "-" ++ String.fromInt index

        descriptionId =
            inputId ++ "-description"

        isChosen =
            config.selected == Just o.value

        isDisabled =
            config.disabled || o.disabled

        -- In a read-only group the options that are not chosen cannot be
        -- chosen: the arrow keys skip them and a click does nothing, and the
        -- chosen one keeps the focus. They are not dimmed like disabled ones.
        lockedByReadOnly =
            isReadOnly && not isChosen && not isDisabled
    in
    Html.label
        [ Internal.cls
            [ "klar-radio"
            , "klar-radio--" ++ Internal.sizeSuffix config.size
            , if isDisabled then
                "klar-radio--disabled"

              else
                ""
            , if isReadOnly && not isDisabled then
                "klar-radio--readonly"

              else
                ""
            ]
        ]
        [ Html.input
            [ Internal.cls [ "klar-radio__input" ]
            , Attr.type_ "radio"
            , Attr.name field.id
            , Attr.id inputId

            -- The value of the option is the application's own: the DOM gets
            -- its position, and the message carries the value itself.
            , Attr.value (String.fromInt index)
            , Attr.checked isChosen
            , Attr.disabled (isDisabled || lockedByReadOnly)
            , Internal.attrMaybe (\_ -> Attr.attribute "aria-describedby" descriptionId) o.description
            , if isReadOnly then
                Internal.noAttr

              else
                Internal.attrMaybe (\toMsg -> Events.on "change" (Decode.succeed (toMsg o.value))) config.onChange
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
it is made from the label and the texts of the options, so two groups with
the same label but other options are still two groups.
-}
ensureId : Config value msg -> Field.Config
ensureId config =
    if config.field.id == "" then
        Field.setId
            (Choice.groupId "radio" config.field.label (List.map (\(Option o) -> o.label) config.options))
            config.field

    else
        config.field
