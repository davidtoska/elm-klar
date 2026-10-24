module Klar.ToggleGroup exposing
    ( single, multiple
    , Option, option, iconOption, withIcon, disabledOption
    , Attribute, label, labelHidden, hint, error, errorMaybe, required, optionalText, id, size, fullWidth, disabled
    )

{-| A row of toggle buttons for choices that can be on or off: "Bold / Italic /
Underline", the statuses to show in a list, the days of the week.

Use when: the user turns options on or off in a compact row, such as "Bold / Italic / Underline" or a set of statuses.
Do not use when: exactly one view is always chosen (as `Klar.SegmentedControl`) or each choice needs an explanation (as `Klar.CheckboxGroup` or `Klar.Radio`).

    import Klar.Icon as Icon
    import Klar.ToggleGroup as ToggleGroup

    -- model:  { styles : List Style }   (Bold, Italic, Underline: your own type)
    ToggleGroup.multiple [ ToggleGroup.label "Text style", ToggleGroup.size Small ]
        { selected = model.styles, onChange = StylesChanged }
        [ ToggleGroup.iconOption Bold Icon.bold "Bold"
        , ToggleGroup.iconOption Italic Icon.italic "Italic"
        , ToggleGroup.iconOption Underline Icon.underline "Underline"
        ]

    -- update
    StylesChanged styles ->
        ( { model | styles = styles }, Cmd.none )

There are two kinds, and a group is exactly one of them, so they cannot be mixed:

  - `multiple`: any number of options are on. `onChange` gets the whole new
    selection, a `List` of ids.
  - `single`: none or one option is on. Clicking the one that is on turns it off, and
    `onChange` gets `Nothing`; clicking another one moves the choice. That is
    what sets it apart from [Klar.SegmentedControl](Klar-SegmentedControl), where
    exactly one view is always chosen (use that for "List / Grid" or "Day / Week /
    Month"), and from [Klar.CheckboxGroup](Klar-CheckboxGroup) and
    [Klar.Radio](Klar-Radio), which have a sentence of explanation for each choice.

**The ids are your own values** (`Bold`, `Open`, `Monday`, an order id): an
option is made with its id, the selection is made of ids, and they are compared
with `==`, so they have to be plain data. The application keeps the selection and
gives it back in `selected`. Clicking never changes anything by itself: the message
carries the new selection, worked out from the selection the group was drawn
with, so there is nothing to read or fix up afterwards. The list a `multiple` group
sends is in the order of the options, whatever order the user clicked in, and an
id that no option has (the options changed) stays in it.

**Keyboard and screen readers.** Each option is a button with `aria-pressed`,
announced as "Bold, toggle button, pressed". Tab moves between the options, and
Space or Enter toggles the focused one. The arrow keys are not used: the group
is a plain `group` named by its label, not a widget with its own key map (as in
[Klar.Toolbar](Klar-Toolbar)), and a stateless component cannot move focus by
itself. It could have been built from radio buttons and checkboxes, which would give the
arrow keys, but a radio button cannot be turned off again (so it cannot
do `single`), and a screen reader announces it as "1 of 4", which is wrong for a
choice of none or one. A group of toggle buttons says what it is. A `disabled`
group and a `disabledOption` stay in the tab order (`aria-disabled`): an option
that is turned off while the user is on it (the last day that must stay on, a
group that waits for a request) keeps the focus.

Give every group a `label`: it names the group for screen readers and is shown
above it unless `labelHidden`, with the marks of `required` and `optionalText`,
as on the other fields of a form. An option with only an icon (`iconOption`)
needs its text just as much: the text is the accessible name and the tooltip, so
it cannot be forgotten. The group has no text of its own, so there is no
`locale`; `hint` and `error` come from your application. It takes the look of a
[Klar.ButtonGroup](Klar-ButtonGroup).


# Groups

@docs single, multiple


# Options

@docs Option, option, iconOption, withIcon, disabledOption


# Attributes

@docs Attribute, label, labelHidden, hint, error, errorMaybe, required, optionalText, id, size, fullWidth, disabled

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Button as Button
import Klar.Field as Field
import Klar.Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Theme exposing (Size(..))
import Klar.ToggleGroup.Ids as Ids
import Klar.ToggleGroup.Selection as Selection



-- OPTIONS


{-| One toggle button of the group, with the id of your application. Make it with
`option` or `iconOption`; `withIcon` and `disabledOption` refine it.
-}
type Option id
    = Option
        { id : id
        , label : String
        , content : Content
        , disabled : Bool
        }


type Content
    = TextOnly
    | TextAndIcon Icon
    | IconOnly Icon


{-| An option with a text: `option Open "Open"` is the id first, then the text.
The ids of a group should differ from each other.
-}
option : id -> String -> Option id
option optionId text =
    Option { id = optionId, label = text, content = TextOnly, disabled = False }


{-| An option with only an icon. The text is not shown, but it is the accessible
name and the tooltip, so it must say what the option does:
`iconOption Bold Icon.bold "Bold"`.
-}
iconOption : id -> Icon -> String -> Option id
iconOption optionId icon text =
    Option { id = optionId, label = text, content = IconOnly icon, disabled = False }


{-| An icon before the text of an option. The icon is decoration. On an option made
with `iconOption` it replaces the icon.

    ToggleGroup.option Open "Open" |> ToggleGroup.withIcon Icon.circle

-}
withIcon : Icon -> Option id -> Option id
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


{-| Visible but not clickable: dimmed, announced as unavailable
(`aria-disabled`), and left as it is in the selection (a disabled option that is
on stays on). It stays in the tab order, so an option that is disabled while it
has focus keeps it.
-}
disabledOption : Option id -> Option id
disabledOption (Option o) =
    Option { o | disabled = True }



-- ATTRIBUTES


{-| A setting of a group. Make them with the functions below and pass a list to
`single` or `multiple`; later attributes win over earlier ones. The messages are
in the arguments of those functions.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { field : Field.Config
    , size : Size
    , fullWidth : Bool
    , disabled : Bool
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { field = Field.empty
        , size = Medium
        , fullWidth = False
        , disabled = False
        }
        attributes


updateField : (Field.Config -> Field.Config) -> Attribute msg
updateField change =
    Attribute (\config -> { config | field = change config.field })


{-| The height and text size of the buttons: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar-Theme)). The default is `Medium`.
-}
size : Size -> Attribute msg
size value =
    Attribute (\config -> { config | size = value })


{-| Stretch over the whole width, every option equally wide.
-}
fullWidth : Attribute msg
fullWidth =
    Attribute (\config -> { config | fullWidth = True })


{-| Disables the whole group: the options are dimmed, announced as unavailable
(`aria-disabled`) and send nothing, and the selection stays as it is. They stay in
the tab order, so a group that is disabled while the user is on it (while a
request runs) keeps the focus. The default is `False`.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The name of the group, shown above it. Screen readers announce it when the
focus enters the group (`aria-labelledby`). Give every group one; `labelHidden`
keeps it for screen readers only.

    ToggleGroup.single [ ToggleGroup.label "Status" ] { selected = model.status, onChange = StatusChanged } options

-}
label : String -> Attribute msg
label text =
    updateField (Field.setLabel text)


{-| Keeps the label for screen readers only. Use it when the buttons are clear
without it, such as the icons of an editor. The group still needs its `label`.
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


{-| Shows an error message in red under the group and draws the buttons with a red
border. Screen readers read the message when it appears.
-}
error : String -> Attribute msg
error text =
    updateField (Field.setError (Just text))


{-| Like `error`, for a message that may not be there: `Nothing` shows no
error. It goes well with `Validate.errorFor`.
-}
errorMaybe : Maybe String -> Attribute msg
errorMaybe maybe =
    updateField (Field.setError maybe)


{-| Marks the group as required with a `*` after the label. It is a visual mark
and checks nothing: ARIA has no required state for a group of buttons, so tell
screen reader users in the `hint` too ("Choose at least one day").
-}
required : Attribute msg
required =
    updateField (Field.setRequired True)


{-| Text shown after the label of a group that is not required, such as
"(optional)". There is no built-in text: without this, an optional group gets no
mark.
-}
optionalText : String -> Attribute msg
optionalText text =
    updateField (Field.setOptionalText text)


{-| The DOM id of the group; the ids of its label, hint and error start with it.
Without one it is made from the label and the texts of the options, with a number
worked out from them, so a label in any language (or an empty one) gives a valid id,
and two groups with the same label and other options do not share one. Two groups
with the same label and the same options on one page need an id each; the label,
the hint and the error of the second would otherwise be found by the first.
-}
id : String -> Attribute msg
id value =
    updateField (Field.setId value)



-- VIEW


{-| A group where none or one option is on. `selected` is the id of the option that
is on, or `Nothing`; `onChange` gets the new choice: the id that was clicked, or
`Nothing` when the one that was on is clicked again.

    ToggleGroup.single [ ToggleGroup.label "Status" ]
        { selected = model.status -- Maybe Status
        , onChange = StatusChanged
        }
        [ ToggleGroup.option Open "Open"
        , ToggleGroup.option Shipped "Shipped"
        , ToggleGroup.option Cancelled "Cancelled"
        ]

-}
single :
    List (Attribute msg)
    -> { selected : Maybe id, onChange : Maybe id -> msg }
    -> List (Option id)
    -> Html msg
single attributes config options =
    render attributes
        (\optionId -> config.selected == Just optionId)
        (\optionId -> config.onChange (Selection.toggleOne optionId config.selected))
        options


{-| A group where any number of options are on. `selected` lists the ids that are
on; `onChange` gets the new list, in the order of the options. The new list is
worked out when an option is clicked, not when the group is drawn, so a group of
a few hundred options costs nothing until it is used.

    ToggleGroup.multiple [ ToggleGroup.label "Working days" ]
        { selected = model.days -- List Weekday
        , onChange = DaysChanged
        }
        [ ToggleGroup.option Mon "Mon"
        , ToggleGroup.option Tue "Tue"
        , ToggleGroup.option Wed "Wed"
        ]

-}
multiple :
    List (Attribute msg)
    -> { selected : List id, onChange : List id -> msg }
    -> List (Option id)
    -> Html msg
multiple attributes config options =
    let
        ids =
            List.map (\(Option o) -> o.id) options
    in
    render attributes
        (\optionId -> List.member optionId config.selected)
        (\optionId -> config.onChange (Selection.toggleMany ids optionId config.selected))
        options


render : List (Attribute msg) -> (id -> Bool) -> (id -> msg) -> List (Option id) -> Html msg
render attributes isOn messageFor options =
    let
        config =
            configure attributes

        labelText =
            Maybe.withDefault "" config.field.label

        -- always a label (an empty one too), so the field keeps one shape
        field =
            ensureId labelText options config.field
                |> Field.setLabel labelText

        labelId =
            Field.labelId field
    in
    -- The field wrapper is inside one more element, so that a toolbar, which gives a
    -- text field that is its direct child a width of 240px, leaves the group alone.
    Html.div [ Internal.cls [ "klar-toggle" ] ]
        [ Field.viewGroup field
            (Html.div [ Internal.cls [ "klar-toggle-field" ] ]
                [ Html.span
                    [ Internal.cls
                        [ "klar-field__label"
                        , if field.labelHidden then
                            "klar-sr-only"

                          else
                            ""
                        ]
                    , Attr.id labelId
                    ]
                    [ Html.text labelText
                    , Internal.viewIf field.required
                        (Html.span [ Internal.cls [ "klar-field__required" ], Attr.attribute "aria-hidden" "true" ] [ Html.text "*" ])
                    , case ( field.required, field.optionalText ) of
                        ( False, Just optional ) ->
                            Html.span [ Internal.cls [ "klar-field__optional" ] ] [ Html.text optional ]

                        _ ->
                            Html.text ""
                    ]
                , Html.div
                    (Attr.id field.id
                        :: Field.describedByAttributes field
                        ++ [ Internal.cls
                                [ "klar-btn-group"
                                , "klar-toggle-group"
                                , if config.fullWidth then
                                    "klar-toggle-group--full"

                                  else
                                    ""
                                , if field.error /= Nothing then
                                    "klar-toggle-group--invalid"

                                  else
                                    ""
                                ]
                           , Attr.attribute "role" "group"
                           , Attr.attribute "aria-labelledby" labelId
                           ]
                    )
                    (List.map (viewOption config isOn messageFor) options)
                ]
            )
        ]


viewOption : Config -> (id -> Bool) -> (id -> msg) -> Option id -> Html msg
viewOption config isOn messageFor (Option o) =
    let
        off =
            config.disabled || o.disabled

        attributes =
            [ Button.size config.size
            , Button.pressed (isOn o.id)

            -- not `disabled`: an option that is turned off while it has focus keeps it
            , Button.ariaDisabled off

            -- The new selection is worked out on the click (a lazy decoder), not for
            -- every option on every redraw.
            , if off then
                Button.htmlAttrs []

              else
                Button.htmlAttrs [ Events.on "click" (Decode.lazy (\_ -> Decode.succeed (messageFor o.id))) ]
            ]
    in
    case o.content of
        TextOnly ->
            Button.view attributes o.label

        TextAndIcon icon ->
            Button.view (Button.icon icon :: attributes) o.label

        IconOnly icon ->
            Button.iconOnly attributes icon o.label


{-| The id of the group: the one given, or one made from the label and the texts of
the options (see `Klar.ToggleGroup.Ids`).
-}
ensureId : String -> List (Option id) -> Field.Config -> Field.Config
ensureId labelText options field =
    if field.id == "" then
        Field.setId (Ids.groupId labelText (List.map (\(Option o) -> o.label) options)) field

    else
        field
