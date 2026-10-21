module Klar.CheckboxGroup exposing
    ( view, Attribute
    , Option, option, withDescription, disabledOption, options
    , selected, onChange, selectAll, selectAllLabel
    , label, labelHidden, hint, error, errorMaybe, required, optionalText, id
    , horizontal, size, disabled, locale
    )

{-| A group of checkboxes: choose any number of the options.

    import Klar.CheckboxGroup as CheckboxGroup

    CheckboxGroup.view
        [ CheckboxGroup.label "Extras"
        , CheckboxGroup.options
            [ CheckboxGroup.option "gift-wrap" "Gift wrap"
            , CheckboxGroup.option "paper-invoice" "Paper invoice"
            , CheckboxGroup.option "insurance" "Shipping insurance"
                |> CheckboxGroup.withDescription "Covers loss and damage up to 500."
            ]
        , CheckboxGroup.selected model.extras
        , CheckboxGroup.onChange ExtrasChanged
        , CheckboxGroup.selectAll
        ]

The application owns the selection. `selected` is the list of the values of the
checked options (a `List String` in the model), and `onChange` gets the whole
new selection, in the order of the options, so the application just stores it.
`selectAll` adds a "Select all" checkbox on top that is checked when every
option is, shows a dash when only some are, and checks or clears all of them;
it leaves disabled options as they are.

The group is a `fieldset` whose legend is the label, and each option is a
[Klar.Checkbox](Klar-Checkbox). It takes the attributes that all form controls
share (`label`, `hint`, `error`, `required` ...; see [Klar.Field](Klar-Field)),
and the first checkbox that can be changed carries the `id` of the group, so
the error summary of [Klar.Form](Klar-Form) can move focus into it.

Use a group for a handful of options that people should see all at once. For
exactly one choice use [Klar.Radio](Klar-Radio), and for a long list, which
needs a search box, [Klar.MultiSelect](Klar-MultiSelect).


# View

@docs view, Attribute


# Options

@docs Option, option, withDescription, disabledOption, options


# Selection

@docs selected, onChange, selectAll, selectAllLabel


# Label, hint and error

@docs label, labelHidden, hint, error, errorMaybe, required, optionalText, id


# Look and language

@docs horizontal, size, disabled, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Checkbox as Checkbox
import Klar.Field as Field
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme exposing (Size(..))


{-| A setting of a checkbox group. Make them with the functions below and pass
a list to `view`; later attributes win over earlier ones.
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
    , selected : List String
    , onChange : Maybe (List String -> msg)
    , horizontal : Bool
    , disabled : Bool
    , size : Size
    , selectAll : Bool
    , selectAllLabel : Maybe String
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , options = []
        , selected = []
        , onChange = Nothing
        , horizontal = False
        , disabled = False
        , size = Medium
        , selectAll = False
        , selectAllLabel = Nothing
        , locale = Locale.default
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })



-- OPTIONS


{-| `option "gift-wrap" "Gift wrap"`: the value that ends up in the selection
when the box is checked, and the text next to the box. The values of a group
should differ from each other.
-}
option : String -> String -> Option
option optionValue optionLabel =
    Option { value = optionValue, label = optionLabel, description = Nothing, disabled = False }


{-| A line of gray explanation under the text of the option.

    CheckboxGroup.option "insurance" "Shipping insurance"
        |> CheckboxGroup.withDescription "Covers loss and damage up to 500."

-}
withDescription : String -> Option -> Option
withDescription text (Option o) =
    Option { o | description = Just text }


{-| Visible but not changeable: the user cannot check or uncheck it, and
`selectAll` leaves its value in the selection or out of it, as it was.
-}
disabledOption : Option -> Option
disabledOption (Option o) =
    Option { o | disabled = True }



-- ATTRIBUTES


{-| The legend of the group: its name, shown above the options. Give every
group one, or screen readers cannot say what the choices are for; `labelHidden`
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


{-| Shows an error message in red under the group and marks it: the empty boxes
get a red border. Screen readers read the message when it appears and with the
group afterwards (`aria-describedby`); a plain group has no `aria-invalid`.
-}
error : String -> Attribute msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.

    CheckboxGroup.errorMaybe (Validate.errorFor "order-extras" errors)

-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the group as required with a `*` after the legend. It is a visual mark
and checks nothing: ARIA has no required state for a group of checkboxes, so
tell screen reader users in the `hint` too ("Choose at least one").
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


{-| The DOM id of the group. Its first checkbox that can be changed gets this
id, so an error summary can move focus into the group; the other checkboxes get
`<id>-<position>` (counting from 0) and the fieldset gets `<id>-group`.

Without it the id is made from the label and the values of the options. That is
enough unless two groups on a page have both the same: give those an id each.

-}
id : String -> Attribute msg
id value =
    updateField (Field.setId value)


{-| The choices of the group, in the order they are shown.
-}
options : List Option -> Attribute msg
options value =
    Attribute (\config -> { config | options = value })


{-| The values of the checked options. A value that no option has is not shown,
but it stays in the selection that `onChange` sends. The default is the empty
list.
-}
selected : List String -> Attribute msg
selected value =
    Attribute (\config -> { config | selected = value })


{-| The message sent when a checkbox (or the select-all box) is changed. It gets
the complete new selection, in the order of the options (values that no option
has come last), so the application can store it as it is. Without it the
checkboxes send nothing.
-}
onChange : (List String -> msg) -> Attribute msg
onChange toMsg =
    Attribute (\config -> { config | onChange = Just toMsg })


{-| Adds a "Select all" checkbox above the options. It is checked when every
option that can be changed is checked, shows a dash when only some are, and
checks or clears all of them with one click. Options made with `disabledOption`
keep their state. The text is "Select all" in English; `selectAllLabel` changes
it.
-}
selectAll : Attribute msg
selectAll =
    Attribute (\config -> { config | selectAll = True })


{-| Replaces the built-in "Select all" text of the select-all checkbox. This
also switches `selectAll` on.

    CheckboxGroup.selectAllLabel "All extras"

-}
selectAllLabel : String -> Attribute msg
selectAllLabel text =
    Attribute (\config -> { config | selectAll = True, selectAllLabel = Just text })


{-| Lay the options out in a row, which wraps when there is not enough room,
instead of in a column.
-}
horizontal : Attribute msg
horizontal =
    Attribute (\config -> { config | horizontal = True })


{-| Disables the whole group, including the select-all box. The default is
`False`.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The size of the checkboxes: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar-Theme)). The default is `Medium`.
-}
size : Size -> Attribute msg
size value =
    Attribute (\config -> { config | size = value })


{-| The language of the built-in text, which is the label of the select-all box.
The default is `Locale.default`, which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| A `fieldset` of checkboxes with its legend, hint and error message. See the
module documentation for the attributes that matter most: `options`, `selected`
and `onChange`.
-}
view : List (Attribute msg) -> Html msg
view attributes =
    let
        config =
            configure attributes

        field =
            ensureId config

        enabled =
            config.options |> List.filter (\(Option o) -> not o.disabled)

        enabledValues =
            List.map (\(Option o) -> o.value) enabled

        chosenEnabled =
            List.filter (\v -> List.member v config.selected) enabledValues

        allChosen =
            not (List.isEmpty enabledValues) && List.length chosenEnabled == List.length enabledValues

        someChosen =
            not (List.isEmpty chosenEnabled)

        mainIndex =
            config.options
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, Option o ) -> not o.disabled)
                |> List.head
                |> Maybe.map Tuple.first
                |> Maybe.withDefault 0
    in
    -- ARIA has no required or invalid state for a plain group, so the hint and
    -- the error message are joined to the fieldset with aria-describedby only.
    Field.viewGroup field
        (Html.fieldset
            (Field.describedByAttributes field
                ++ [ Attr.id (field.id ++ "-group")
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
                         , Checkbox.size config.size
                         ]
                            ++ (case config.onChange of
                                    Just toMsg ->
                                        [ Checkbox.onCheck
                                            (\checked ->
                                                toMsg (setAll config.options enabledValues config.selected checked)
                                            )
                                        ]

                                    Nothing ->
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


viewOption : Config msg -> Field.Config -> Int -> Int -> Option -> Html msg
viewOption config field mainIndex index (Option o) =
    Checkbox.view
        ([ Checkbox.label o.label
         , Checkbox.checked (List.member o.value config.selected)
         , Checkbox.disabled (config.disabled || o.disabled)
         , Checkbox.size config.size
         , Checkbox.id
            (if index == mainIndex then
                field.id

             else
                field.id ++ "-" ++ String.fromInt index
            )
         ]
            ++ (case o.description of
                    Just text ->
                        [ Checkbox.hint text ]

                    Nothing ->
                        []
               )
            ++ (case config.onChange of
                    Just toMsg ->
                        [ Checkbox.onCheck
                            (\checked -> toMsg (toggle config.options config.selected o.value checked))
                        ]

                    Nothing ->
                        []
               )
        )


{-| Add or remove one value and keep the selection in the order of the
options (values the options do not know about stay at the end).
-}
toggle : List Option -> List String -> String -> Bool -> List String
toggle allOptions current changed checked =
    let
        without =
            List.filter (\v -> v /= changed) current
    in
    inOptionOrder allOptions
        (if checked then
            without ++ [ changed ]

         else
            without
        )


setAll : List Option -> List String -> List String -> Bool -> List String
setAll allOptions enabledValues current checked =
    let
        without =
            List.filter (\v -> not (List.member v enabledValues)) current
    in
    inOptionOrder allOptions
        (if checked then
            without ++ enabledValues

         else
            without
        )


inOptionOrder : List Option -> List String -> List String
inOptionOrder allOptions values =
    let
        known =
            List.map (\(Option o) -> o.value) allOptions
    in
    List.filter (\v -> List.member v values) known
        ++ List.filter (\v -> not (List.member v known)) values


{-| The group's id. Without `id` it is made from the label and the values of
the options, so two groups with the same label but other options do not share
DOM ids.
-}
ensureId : Config msg -> Field.Config
ensureId config =
    if config.field.id == "" then
        let
            values =
                List.map (\(Option o) -> o.value) config.options
        in
        Field.setId
            ("klar-checkgroup-"
                ++ Internal.sanitizeId
                    (String.toLower (String.join "-" (Maybe.withDefault "group" config.field.label :: values)))
            )
            config.field

    else
        config.field
