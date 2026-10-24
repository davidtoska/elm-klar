module Klar.CheckboxGroup exposing
    ( view, Attribute
    , Option, option, withDescription, disabledOption, options
    , selected, onChange, selectAll, selectAllLabel
    , label, labelHidden, hint, error, errorMaybe, required, optionalText, id
    , horizontal, size, disabled, readOnly, locale
    )

{-| A group of checkboxes: choose any number of the options.

Use when: a handful of options where the user may choose any number and should see them all.
Do not use when: exactly one choice is wanted (`Klar.Radio`), the options are a compact row of toggles (`Klar.ToggleGroup`) or the list is long and needs a search box (`Klar.MultiSelect`).

    import Klar.CheckboxGroup as CheckboxGroup

    -- model:  { extras : List Extra }   (GiftWrap, PaperInvoice, Insurance: your own type)
    CheckboxGroup.view
        [ CheckboxGroup.label "Extras"
        , CheckboxGroup.options
            [ CheckboxGroup.option GiftWrap "Gift wrap"
            , CheckboxGroup.option PaperInvoice "Paper invoice"
            , CheckboxGroup.option Insurance "Shipping insurance"
                |> CheckboxGroup.withDescription "Covers loss and damage up to 500."
            ]
        , CheckboxGroup.selected model.extras
        , CheckboxGroup.onChange ExtrasChanged
        , CheckboxGroup.selectAll
        ]

    -- update
    ExtrasChanged extras ->
        ( { model | extras = extras }, Cmd.none )

**The values are your own** (`GiftWrap`, a warehouse id, an `Int`): an option is
made with its value, `selected` is the list of the values of the checked options,
and `onChange` gets the whole new selection, in the order of the options, so the
application just stores it. They are compared with `==`, so they have to be plain
data; there is nothing to convert to or from a `String`. A group without
`onChange` is read-only. `selectAll` adds a "Select all" checkbox on top that is
checked when every option is, shows a dash when only some are, and checks or
clears all of them; it leaves disabled options as they are.

The group is a `fieldset` whose legend is the label, and each option is a
[Klar.Checkbox](Klar-Checkbox). It takes the attributes that all form controls
share (`label`, `hint`, `error`, `required` ...; see [Klar.Field](Klar-Field)),
and the first checkbox that can be changed carries the `id` of the group, so
the error summary of [Klar.Form.Layout](Klar-Form-Layout) can move focus into it.

Use a group for a handful of options that people should see all at once. For
exactly one choice use [Klar.Radio](Klar-Radio), for a compact row of on and off
buttons [Klar.ToggleGroup](Klar-ToggleGroup), and for a long list, which needs a
search box, [Klar.MultiSelect](Klar-MultiSelect).


# View

@docs view, Attribute


# Options

@docs Option, option, withDescription, disabledOption, options


# Selection

@docs selected, onChange, selectAll, selectAllLabel


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText, id


# Look, behavior and language

@docs horizontal, size, disabled, readOnly, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Checkbox as Checkbox
import Klar.Field as Field
import Klar.Internal as Internal
import Klar.Internal.Choice as Choice
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme exposing (Size(..))


{-| A setting of a checkbox group. Make them with the functions below and pass
a list to `view`; later attributes win over earlier ones. `value` is the type of
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
    , selected : List value
    , onChange : Maybe (List value -> msg)
    , horizontal : Bool
    , disabled : Bool
    , readOnly : Bool
    , size : Size
    , selectAll : Bool
    , selectAllLabel : Maybe String
    , locale : Locale
    }


configure : List (Attribute value msg) -> Config value msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , options = []
        , selected = []
        , onChange = Nothing
        , horizontal = False
        , disabled = False
        , readOnly = False
        , size = Medium
        , selectAll = False
        , selectAllLabel = Nothing
        , locale = Locale.default
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute value msg
updateField change =
    Attribute (\config -> { config | field = change config.field })



-- OPTIONS


{-| `option GiftWrap "Gift wrap"`: the value that ends up in the selection when
the box is checked (of your own type), and the text next to the box. The values
of a group should differ from each other.
-}
option : value -> String -> Option value
option optionValue optionLabel =
    Option { value = optionValue, label = optionLabel, description = Nothing, disabled = False }


{-| A line of gray explanation under the text of the option.

    CheckboxGroup.option Insurance "Shipping insurance"
        |> CheckboxGroup.withDescription "Covers loss and damage up to 500."

-}
withDescription : String -> Option value -> Option value
withDescription text (Option o) =
    Option { o | description = Just text }


{-| Visible but not changeable: the user cannot check or uncheck it, and
`selectAll` leaves its value in the selection or out of it, as it was.
-}
disabledOption : Option value -> Option value
disabledOption (Option o) =
    Option { o | disabled = True }



-- ATTRIBUTES


{-| The legend of the group: its name, shown above the options. Give every
group one, or screen readers cannot say what the choices are for; `labelHidden`
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


{-| Shows an error message in red under the group and marks it: the empty boxes
get a red border. Screen readers read the message when it appears and with the
group afterwards (`aria-describedby`); a plain group has no `aria-invalid`.
-}
error : String -> Attribute value msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    CheckboxGroup.errorMaybe (Validate.errorFor "order-extras" errors)

-}
errorMaybe : Maybe String -> Attribute value msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the group as required with a `*` after the legend. It is a visual mark
and checks nothing: ARIA has no required state for a group of checkboxes, so
tell screen reader users in the `hint` too ("Choose at least one").
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


{-| The DOM id of the group. Its first checkbox that can be changed gets this
id, so an error summary can move focus into the group; the other checkboxes get
`<id>-<position>` (counting from 0) and the fieldset gets `<id>-group`. When no
checkbox can take the focus, the fieldset gets the id instead.

Without it the id is made from the label and the texts of the options. That is
enough unless two groups on a page have both the same: give those an id each.

-}
id : String -> Attribute value msg
id value =
    updateField (Field.setId value)


{-| The choices of the group, in the order they are shown.
-}
options : List (Option value) -> Attribute value msg
options value =
    Attribute (\config -> { config | options = value })


{-| The values of the checked options. A value that no option has is not shown,
but it stays in the selection that `onChange` sends. The default is the empty
list.
-}
selected : List value -> Attribute value msg
selected value =
    Attribute (\config -> { config | selected = value })


{-| The message sent when a checkbox (or the select-all box) is changed. It gets
the complete new selection, in the order of the options (values that no option
has come last, and no value comes twice), so the application can store it as it
is. Without it the group is read-only (see `readOnly`).

    CheckboxGroup.onChange ExtrasChanged

-}
onChange : (List value -> msg) -> Attribute value msg
onChange toMsg =
    Attribute (\config -> { config | onChange = Just toMsg })


{-| Adds a "Select all" checkbox above the options. It is checked when every
option that can be changed is checked, shows a dash when only some are, and
checks or clears all of them with one click. Options made with `disabledOption`
keep their state. The text is "Select all" in English; `selectAllLabel` changes
it.
-}
selectAll : Attribute value msg
selectAll =
    Attribute (\config -> { config | selectAll = True })


{-| Replaces the built-in "Select all" text of the select-all checkbox. This
also switches `selectAll` on.

    CheckboxGroup.selectAllLabel "All extras"

-}
selectAllLabel : String -> Attribute value msg
selectAllLabel text =
    Attribute (\config -> { config | selectAll = True, selectAllLabel = Just text })


{-| Lay the options out in a row, which wraps when there is not enough room,
instead of in a column.
-}
horizontal : Attribute value msg
horizontal =
    Attribute (\config -> { config | horizontal = True })


{-| Disables the whole group, including the select-all box: dimmed, skipped by
Tab, and nothing can be changed. The default is `False`.
-}
disabled : Bool -> Attribute value msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| Shows the selection without letting the user change it, for a record the
user may read but not edit. Each box is a read-only checkbox (see
`Checkbox.readOnly`): not dimmed, reached with Tab and read by screen readers,
but a click or Space changes nothing and nothing is sent to `onChange`. The
default is `False`.
-}
readOnly : Bool -> Attribute value msg
readOnly value =
    Attribute (\config -> { config | readOnly = value })


{-| The size of the checkboxes and their text: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar-Theme)). The default is `Medium`.
-}
size : Size -> Attribute value msg
size value =
    Attribute (\config -> { config | size = value })


{-| The language of the built-in text, which is the label of the select-all box.
The default is `Locale.default`, which is English.
-}
locale : Locale -> Attribute value msg
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| A `fieldset` of checkboxes with its legend, hint and error message. See the
module documentation for the attributes that matter most: `options`, `selected`
and `onChange`.
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

        optionValues =
            List.map (\(Option o) -> o.value) config.options

        enabledValues =
            config.options
                |> List.filter (\(Option o) -> not o.disabled)
                |> List.map (\(Option o) -> o.value)

        chosenEnabled =
            List.filter (\v -> List.member v config.selected) enabledValues

        allChosen =
            not (List.isEmpty enabledValues) && List.length chosenEnabled == List.length enabledValues

        someChosen =
            not (List.isEmpty chosenEnabled)

        -- The checkbox that carries the id of the group: the first one that can
        -- take the focus (a read-only box can; a disabled one cannot).
        mainIndex =
            if config.disabled then
                Nothing

            else
                config.options
                    |> List.indexedMap Tuple.pair
                    |> List.filter (\( _, Option o ) -> not o.disabled)
                    |> List.head
                    |> Maybe.map Tuple.first

        common =
            [ Checkbox.size config.size
            , Checkbox.readOnly (isReadOnly && not config.disabled)
            ]
    in
    -- ARIA has no required or invalid state for a plain group, so the hint and
    -- the error message are joined to the fieldset with aria-describedby only.
    Field.viewGroup field
        (Html.fieldset
            (Field.describedByAttributes field
                ++ [ case mainIndex of
                        Just _ ->
                            Attr.id (field.id ++ "-group")

                        Nothing ->
                            -- No checkbox can take the focus, so the group does,
                            -- when the error summary moves it here.
                            Attr.id field.id
                   , Internal.attrIf (mainIndex == Nothing) (Attr.tabindex -1)
                   , Internal.cls
                        [ "klar-checkgroup"
                        , if field.error /= Nothing then
                            "klar-checkgroup--invalid"

                          else
                            ""
                        ]
                   , Attr.attribute "role" "group"
                   , Internal.attrIf (field.label /= Nothing) (Attr.attribute "aria-labelledby" (field.id ++ "-legend"))
                   ]
            )
            [ viewLegend field
            , if config.selectAll && not (List.isEmpty config.options) then
                Html.div [ Internal.cls [ "klar-checkgroup__all" ] ]
                    [ Checkbox.view
                        ([ Checkbox.label
                            (config.selectAllLabel
                                |> Maybe.withDefault (Locale.pick config.locale { nb = "Velg alle", en = "Select all" })
                            )
                         , Checkbox.checked allChosen
                         , Checkbox.indeterminate (someChosen && not allChosen)
                         , Checkbox.disabled (config.disabled || List.isEmpty enabledValues)
                         ]
                            ++ common
                            ++ (case ( isReadOnly, config.onChange ) of
                                    ( False, Just toMsg ) ->
                                        [ Checkbox.onCheck
                                            (\checked ->
                                                toMsg (Choice.setAll optionValues enabledValues config.selected checked)
                                            )
                                        ]

                                    _ ->
                                        []
                               )
                        )
                    ]

              else
                Html.text ""
            , Html.div
                [ Internal.cls
                    [ "klar-checkgroup__options"
                    , if config.horizontal then
                        "klar-checkgroup__options--horizontal"

                      else
                        ""
                    ]
                ]
                (List.indexedMap (viewOption config isReadOnly common optionValues field mainIndex) config.options)
            ]
        )


viewLegend : Field.Config -> Html msg
viewLegend field =
    case field.label of
        Just text ->
            Html.legend
                [ Internal.cls
                    [ "klar-field__label"
                    , "klar-checkgroup__legend"
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


viewOption : Config value msg -> Bool -> List (Checkbox.Attribute msg) -> List value -> Field.Config -> Maybe Int -> Int -> Option value -> Html msg
viewOption config isReadOnly common optionValues field mainIndex index (Option o) =
    Checkbox.view
        ([ Checkbox.label o.label
         , Checkbox.checked (List.member o.value config.selected)
         , Checkbox.disabled (config.disabled || o.disabled)
         , Checkbox.id
            (if Just index == mainIndex then
                field.id

             else
                field.id ++ "-" ++ String.fromInt index
            )
         ]
            ++ common
            ++ (case o.description of
                    Just text ->
                        [ Checkbox.hint text ]

                    Nothing ->
                        []
               )
            ++ (case ( isReadOnly, config.onChange ) of
                    ( False, Just toMsg ) ->
                        [ Checkbox.onCheck
                            (\checked -> toMsg (Choice.toggle optionValues config.selected o.value checked))
                        ]

                    _ ->
                        []
               )
        )


{-| The group's id. Without `id` it is made from the label and the texts of the
options, so two groups with the same label but other options do not share DOM
ids.
-}
ensureId : Config value msg -> Field.Config
ensureId config =
    if config.field.id == "" then
        Field.setId
            (Choice.groupId "checkgroup" config.field.label (List.map (\(Option o) -> o.label) config.options))
            config.field

    else
        config.field
