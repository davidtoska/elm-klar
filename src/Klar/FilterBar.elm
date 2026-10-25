module Klar.FilterBar exposing
    ( view
    , State, init, Msg, update
    , rule, setRule, clear, isOpen, close
    , Attribute, fields, quick, today, ariaLabel, addLabel, locale
    , matchCount, totalCount, onRetry
    )

{-| Quick filters above a table: the conditions that are on, shown as chips
("Status is Paid"), an "Add filter" button that opens a small editor (field,
operator, value), and optional preset pills like "Unpaid".

Use when: users filter a table with a few quick conditions shown as chips and presets.
Do not use when: users need nested groups of conditions (use `Klar.RuleBuilder`).
Quick path: `init`, `update`, `view`, `rule`

    import Klar.FilterBar as FilterBar
    import Klar.Remote as Remote
    import Klar.Rule as Rule

    -- model
    { filters : FilterBar.State } -- FilterBar.init "order-filters"

    -- update
    FiltersMsg m ->
        let
            ( filters, cmd ) =
                FilterBar.update m model.filters
        in
        ( { model | filters = filters }, Cmd.map FiltersMsg cmd )

    -- view
    FilterBar.view FiltersMsg
        [ FilterBar.fields orderFields
        , FilterBar.quick [ ( "Unpaid", unpaid ), ( "Large orders", large ) ]
        , FilterBar.matchCount (Remote.Loaded (List.length visible))
        , FilterBar.today today
        ]
        model.filters

    -- the rows to show
    visible =
        List.filter (Rule.matches today orderFields (FilterBar.rule model.filters)) model.orders

    -- the presets are rules: "Status is Open" and "Total > 1000"
    unpaid : Rule.Rule
    unpaid =
        Rule.is "status" "open"

    large : Rule.Rule
    large =
        Rule.when "total" Rule.GreaterThan [ "1000" ]

`orderFields` is a `List (Rule.Field Order)` made with `Rule.textField` and
friends. A count that takes time (a server, a large data set) is the `Remote` it
is: `Loading` shows "Counting ...", `Remote.refresh` keeps the old count, dimmed,
while the new one is on its way, and a failed count offers `onRetry`.

The filters are a [Klar.Rule](Klar-Rule) `Rule`: a root group with one child for
each chip, combined with "and". The same rule can be handed to `Rule.matches` or
opened in [Klar.RuleBuilder](Klar-RuleBuilder) with
`RuleBuilder.setRule (FilterBar.rule model.filters)`. A rule made in the builder
can be shown here too (`setRule`): conditions become chips, nested groups become
read-only chips that can be removed, and the bar says how the chips combine when
it is not "and" ("Any of:"). A new filter is always combined with "and" with
what is there.

Clicking a chip opens the editor for it, in a popover under the chip. The
filter is only changed when the user applies it; a filter that is not complete
is not added, and the editor says what is missing. A chip whose condition is not
complete (possible after `setRule`) says so (to screen readers too) and does not
filter. Removing a chip and "Clear all" can be undone with the "Undo" button that
appears at the end of the bar. A preset whose rule does not fit the fields (a
misspelled field id, an operator of another kind) is drawn disabled, with the
problem as its tooltip, so the mistake shows at once.

**Keyboard**: `Tab` moves through the pills and buttons; the chips are one stop.
Among the chips `ArrowLeft` and `ArrowRight` move, `Home` and `End` go to the
first and the last, `Enter` or `Space` opens the editor of a condition chip, and
`Delete` or `Backspace` removes a chip (focus goes to its neighbour, and the
removal can be undone). A group chip (a group made in a `RuleBuilder` or a
preset) is edited where it was made: `Enter` does nothing on it, and it can only
be removed. The remove buttons are for the mouse; they are not tab stops. In the editor `Enter` in a text or number
field applies, and `Ctrl+Enter` (`Cmd+Enter` on a Mac) applies from any control,
also from a choice or a date; in a date field `Enter` takes the date that was
typed. `Escape` closes the editor without applying and gives focus back to the
chip or the add button (`Escape` in an open picker closes only the picker), and
moving focus out of the editor closes it too.

**State and text**: the state holds the filters and the editor that is open,
with the draft the user is working on. The built-in text follows `locale`, which
is English by default; field labels and choices come from the application.


# View

@docs view


# State

@docs State, init, Msg, update


# The filters

@docs rule, setRule, clear, isOpen, close


# Attributes

@docs Attribute, fields, quick, today, ariaLabel, addLabel, locale


# Match count

@docs matchCount, totalCount, onRetry

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Button as Button
import Klar.Date exposing (Date)
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote exposing (Remote(..))
import Klar.Rule as Rule exposing (Combinator(..), Condition, Field, Group, Operator(..), Rule(..))
import Klar.RuleBuilder.Count as Count
import Klar.RuleBuilder.Editor as Editor
import Klar.RuleBuilder.Support as Support



-- STATE


{-| The state of one filter bar: the filters and the editor that is open, with
the draft the user is working on. Make one with `init`, keep it in your model and
pass it to `view` and `update`. Read the filters with `rule`.
-}
type State
    = State Inner


type alias Inner =
    { id : String
    , rule : Rule
    , editing : Maybe Editing
    , controls : Editor.Controls
    , undo : Maybe Undo
    , current : Maybe Int
    }


{-| The filters before the last removal, and where focus goes when they come back.
-}
type alias Undo =
    { rule : Rule
    , cleared : Bool
    , focus : String
    }


type alias Editing =
    { target : Target
    , draft : Condition
    , tried : Bool
    }


type Target
    = NewFilter
    | ExistingFilter Int


{-| A filter bar without filters. The `String` is the DOM id of the bar and must
be unique on the page; the ids of the controls in its editor start with it.

    FilterBar.init "order-filters"

-}
init : String -> State
init id =
    State
        { id = id
        , rule = Rule.emptyGroup
        , editing = Nothing
        , controls = Editor.emptyControls (draftPrefix id)
        , undo = Nothing
        , current = Nothing
        }


{-| The filters as a rule, for `Rule.matches`. The root is a group with the id 0
and one child for each chip. A rule made in the bar combines its chips with
"all of"; `setRule` can bring in a root that combines them in another way.
Compare it before and after `update` to find out whether the filters changed.
-}
rule : State -> Rule
rule (State s) =
    s.rule


{-| Shows these filters, for example the rule of a saved view or a rule from the
rule builder. A rule that is a lone condition is put in a group, and the nodes
are renumbered from 0 if the root does not have the id 0 or an id occurs twice.
Closes the editor.
-}
setRule : Rule -> State -> State
setRule newRule (State s) =
    State { s | rule = Support.normalize newRule, editing = Nothing, undo = Nothing }


{-| Removes every filter and closes the editor. Unlike the "Clear all" button it
does not offer to undo.
-}
clear : State -> State
clear (State s) =
    State { s | rule = Rule.emptyGroup, editing = Nothing, undo = Nothing }


{-| Is the filter editor open, for a new filter or for a chip?
-}
isOpen : State -> Bool
isOpen (State s) =
    s.editing /= Nothing


{-| Closes the filter editor without applying what the user has entered, and
gives focus back to the chip or the add button it was opened from (as `Escape`
does). Map the command with the constructor you wrap the bar's messages in.

    FilterBar.close model.filters

-}
close : State -> ( State, Cmd Msg )
close state =
    update Cancelled state


rootGroup : Rule -> Group
rootGroup given =
    case given of
        GroupRule group ->
            group

        ConditionRule condition ->
            { id = 0, combinator = All, negated = False, children = [ ConditionRule condition ] }


{-| A root whose children are simply ANDed together.
-}
isPlain : Group -> Bool
isPlain group =
    not group.negated && (group.combinator == All || List.length group.children <= 1)


{-| Adds a node so that it narrows what is there: appended when the root is
a plain "all of", otherwise the old rule becomes one part of a new "all of".
-}
addFilter : Rule -> Rule -> Rule
addFilter node current =
    let
        root =
            rootGroup current
    in
    if List.isEmpty root.children then
        GroupRule
            { id = root.id
            , combinator = All
            , negated = False
            , children = [ Support.renumberFrom (root.id + 1) node |> Tuple.first ]
            }

    else if isPlain root then
        GroupRule
            { root
                | combinator = All
                , children = root.children ++ [ Support.renumberFrom (Rule.nextId current) node |> Tuple.first ]
            }

    else
        let
            ( old, next ) =
                Support.renumberFrom 1 (GroupRule root)
        in
        GroupRule
            { id = 0
            , combinator = All
            , negated = False
            , children = [ old, Support.renumberFrom next node |> Tuple.first ]
            }



-- PRESETS


presetParts : Rule -> List Rule
presetParts preset =
    case preset of
        GroupRule group ->
            if group.combinator == All && not group.negated then
                group.children

            else
                [ preset ]

        ConditionRule _ ->
            [ preset ]


isPresetOn : Rule -> Rule -> Bool
isPresetOn preset current =
    let
        root =
            rootGroup current

        present =
            List.map Support.signature root.children

        parts =
            presetParts preset
    in
    isPlain root
        && not (List.isEmpty parts)
        && List.all (\part -> List.member (Support.signature part) present) parts


togglePreset : Rule -> Rule -> Rule
togglePreset preset current =
    let
        root =
            rootGroup current

        parts =
            presetParts preset

        signatures =
            List.map Support.signature parts
    in
    if isPresetOn preset current then
        GroupRule { root | children = List.filter (\child -> not (List.member (Support.signature child) signatures)) root.children }

    else
        let
            present =
                if isPlain root then
                    List.map Support.signature root.children

                else
                    []
        in
        parts
            |> List.filter (\part -> not (List.member (Support.signature part) present))
            |> List.foldl addFilter current



-- UPDATE


{-| A message from the filter bar. Wrap it in one of your own messages and pass
it to `update`.
-}
type Msg
    = AddOpened
    | ChipOpened Int String
    | ChipRemoved Int
    | PresetToggled Rule
    | EditorMsg Editor.Msg
    | Applied Bool String
    | Cancelled
    | Left
    | RemovedInEditor
    | ClearedAll
    | UndoClicked
    | ChipFocused Int
    | MovedTo Int
    | NoOp


{-| Applies a message from the filter bar. The command moves keyboard focus (into
the editor, back to a chip ...), so map it with `Cmd.map`. Compare `rule` before
and after to react to a change.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State s) =
    case msg of
        AddOpened ->
            if Maybe.map .target s.editing == Just NewFilter then
                ( State { s | editing = Nothing }, Cmd.none )

            else
                let
                    draftId =
                        Rule.nextId s.rule
                in
                ( State
                    { s
                        | editing = Just { target = NewFilter, draft = { id = draftId, field = "", operator = Is, values = [] }, tried = False }
                        , controls = Editor.resetControls s.controls
                    }
                , Internal.focus (Editor.fieldDomId (draftPrefix s.id) draftId) NoOp
                )

        ChipOpened id focusId ->
            if Maybe.map .target s.editing == Just (ExistingFilter id) then
                ( State { s | editing = Nothing }, Cmd.none )

            else
                case Support.findCondition id s.rule of
                    Just condition ->
                        ( State
                            { s
                                | editing = Just { target = ExistingFilter id, draft = condition, tried = False }
                                , controls = Editor.resetControls s.controls
                            }
                        , Internal.focus focusId NoOp
                        )

                    Nothing ->
                        ( State s, Cmd.none )

        ChipRemoved id ->
            removeFilter id (neighbourFocus id s) s

        PresetToggled preset ->
            ( State { s | rule = togglePreset preset s.rule, editing = Nothing, undo = Nothing }, Cmd.none )

        EditorMsg inner ->
            case s.editing of
                Just editing ->
                    let
                        outcome =
                            Editor.update inner (ConditionRule editing.draft) s.controls

                        draft =
                            case outcome.rule of
                                ConditionRule condition ->
                                    condition

                                GroupRule _ ->
                                    editing.draft
                    in
                    ( State
                        { s
                            | editing = Just { editing | draft = draft, tried = editing.tried || outcome.touched /= Nothing }
                            , controls = outcome.controls
                        }
                    , Cmd.map EditorMsg outcome.cmd
                    )

                Nothing ->
                    ( State s, Cmd.none )

        Applied valid focusId ->
            case s.editing of
                Just editing ->
                    if not valid then
                        ( State { s | editing = Just { editing | tried = True } }, Internal.focus focusId NoOp )

                    else
                        case editing.target of
                            NewFilter ->
                                ( State { s | rule = addFilter (ConditionRule editing.draft) s.rule, editing = Nothing, undo = Nothing }
                                , Internal.focus (addDomId s.id) NoOp
                                )

                            ExistingFilter id ->
                                ( State { s | rule = Support.replaceCondition editing.draft s.rule, editing = Nothing, undo = Nothing }
                                , Internal.focus (chipDomId s.id id) NoOp
                                )

                Nothing ->
                    ( State s, Cmd.none )

        Cancelled ->
            ( State { s | editing = Nothing }
            , case Maybe.map .target s.editing of
                Just (ExistingFilter id) ->
                    Internal.focus (chipDomId s.id id) NoOp

                Just NewFilter ->
                    Internal.focus (addDomId s.id) NoOp

                Nothing ->
                    Cmd.none
            )

        Left ->
            ( State { s | editing = Nothing }, Cmd.none )

        RemovedInEditor ->
            case Maybe.map .target s.editing of
                Just (ExistingFilter id) ->
                    removeFilter id (addDomId s.id) s

                _ ->
                    ( State { s | editing = Nothing }, Internal.focus (addDomId s.id) NoOp )

        ClearedAll ->
            if Rule.isEmpty s.rule && List.isEmpty (rootGroup s.rule).children then
                ( State s, Cmd.none )

            else
                ( State
                    { s
                        | rule = Rule.emptyGroup
                        , editing = Nothing
                        , undo = Just { rule = s.rule, cleared = True, focus = addDomId s.id }
                    }
                , Internal.focus (undoDomId s.id) NoOp
                )

        ChipFocused id ->
            ( State { s | current = Just id }, Cmd.none )

        MovedTo id ->
            ( State { s | current = Just id }, Internal.focus (chipDomId s.id id) NoOp )

        UndoClicked ->
            case s.undo of
                Just undo ->
                    ( State { s | rule = undo.rule, undo = Nothing, editing = Nothing }, Internal.focus undo.focus NoOp )

                Nothing ->
                    ( State s, Cmd.none )

        NoOp ->
            ( State s, Cmd.none )


removeFilter : Int -> String -> Inner -> ( State, Cmd Msg )
removeFilter id focusId s =
    let
        -- the chip comes back where it was, and so does focus
        back =
            chipDomId s.id id
    in
    ( State
        { s
            | rule = Rule.remove id s.rule
            , editing =
                if Maybe.map .target s.editing == Just (ExistingFilter id) then
                    Nothing

                else
                    s.editing
            , undo = Just { rule = s.rule, cleared = False, focus = back }
        }
    , Internal.focus focusId NoOp
    )


{-| Where focus goes when a chip is removed: the next chip, the previous one,
or the add button.
-}
neighbourFocus : Int -> Inner -> String
neighbourFocus id s =
    let
        children =
            (rootGroup s.rule).children

        index =
            children
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, child ) -> Rule.idOf child == id)
                |> List.head
                |> Maybe.map Tuple.first
                |> Maybe.withDefault 0

        others =
            List.filter (\child -> Rule.idOf child /= id) children

        neighbour =
            case List.head (List.drop index others) of
                Just next ->
                    Just next

                Nothing ->
                    List.head (List.drop (index - 1) others)
    in
    case neighbour of
        Just next ->
            chipDomId s.id (Rule.idOf next)

        Nothing ->
            addDomId s.id



-- DOM IDS


draftPrefix : String -> String
draftPrefix id =
    id ++ "-draft"


addDomId : String -> String
addDomId id =
    id ++ "-add"


chipDomId : String -> Int -> String
chipDomId id node =
    id ++ "-chip-" ++ String.fromInt node


popupDomId : String -> String
popupDomId id =
    id ++ "-popup"


undoDomId : String -> String
undoDomId id =
    id ++ "-undo"



-- ATTRIBUTES


{-| A setting of the filter bar. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones. The type parameters are
the row type of your fields and your message type.
-}
type Attribute row msg
    = Attribute (Config row msg -> Config row msg)


type alias Config row msg =
    { fields : List (Field row)
    , locale : Locale
    , quick : List ( String, Rule )
    , matchCount : Remote Int
    , totalCount : Maybe Int
    , onRetry : Maybe msg
    , today : Maybe Date
    , ariaLabel : Maybe String
    , addLabel : Maybe String
    }


configure : List (Attribute row msg) -> Config row msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { fields = []
        , locale = Locale.default
        , quick = []
        , matchCount = NotAsked
        , totalCount = Nothing
        , onRetry = Nothing
        , today = Nothing
        , ariaLabel = Nothing
        , addLabel = Nothing
        }
        attributes


{-| What can be filtered on: the fields the user can pick in the editor, made
with `Rule.textField` and the other field functions. The default is no fields.

    FilterBar.fields
        [ Rule.choiceField "status" "Status" statuses .status
        , Rule.numberField "total" "Total" (.total >> Just)
        ]

-}
fields : List (Field row) -> Attribute row msg
fields value =
    Attribute (\config -> { config | fields = value })


{-| The language of the bar's own text: buttons, hints and the words that say how
the chips are combined. The default is `Locale.default`, which is `Locale.en`. Field
labels and choices come from the application.
-}
locale : Locale -> Attribute row msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| Ready-made filters, shown as toggle pills in front of the chips. Each one is
a name and a `Rule`.

    FilterBar.quick [ ( "Unpaid", unpaid ), ( "Large orders", large ) ]

A pill is on when the conditions of its rule are among the filters. Turning it
on adds them (the ones that are missing), turning it off removes them. A preset
that is an "all of" group adds each of its conditions as a chip of its own; any
other preset is added as one chip. The ids of a preset do not matter. A preset
that `Rule.validate` finds a problem in, for the fields of the bar, is drawn
disabled with the problem as its tooltip.

-}
quick : List ( String, Rule ) -> Attribute row msg
quick value =
    Attribute (\config -> { config | quick = value })


{-| How many rows the filters let through, shown at the end of the bar as
"1,482 matches". Give `Remote.Loaded n` for a count you have (`Rule.matches`), or
the `Remote` of a count that takes time:

  - `Loading`: a spinner and "Counting ...".
  - `Failed`: "The count failed", with a retry button when there is `onRetry`.
  - Refreshing (`Remote.refresh` of a count): the old count stays, dimmed, with
    a spinner.
  - Old (`Remote.Kept` after a failed refresh): the old count, marked old, with
    the retry; while that retry runs the button stays, busy, and keeps focus.

`NotAsked`, the default, shows no count. The count is in a polite live region,
which is in the page from the start, so a screen reader hears the first count too.

    FilterBar.matchCount (Remote.Loaded (List.length visible))

-}
matchCount : Remote Int -> Attribute row msg
matchCount value =
    Attribute (\config -> { config | matchCount = value })


{-| The number of rows before filtering. With a `matchCount` the count reads
"1,482 of 3,000 matches". Without a `matchCount` nothing is shown.
-}
totalCount : Int -> Attribute row msg
totalCount value =
    Attribute (\config -> { config | totalCount = Just value })


{-| The message of the retry button that a failed or old `matchCount` shows.
Without it there is no retry button.
-}
onRetry : msg -> Attribute row msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| Today's date, for the date picker in the editor: it marks the day, powers its
"Today" button and completes short input. It does not change what the filters
match; give the same date to `Rule.matches`.
-}
today : Date -> Attribute row msg
today value =
    Attribute (\config -> { config | today = Just value })


{-| The name of the bar for screen readers. The default is "Filters".
-}
ariaLabel : String -> Attribute row msg
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Just value })


{-| The text of the add button. The default is "Add filter".
-}
addLabel : String -> Attribute row msg
addLabel value =
    Attribute (\config -> { config | addLabel = Just value })



-- VIEW


type alias Ctx row msg =
    { toMsg : Msg -> msg
    , config : Config row msg
    , state : Inner
    , texts : Texts
    }


{-| The bar: preset pills, the active filters as chips, the add button, a "Clear
all" button when there are filters, and the count. The editor opens in a popover
under the chip or the button. The first argument turns the bar's messages into
yours.

    FilterBar.view FiltersMsg [ FilterBar.fields orderFields ] model.filters

-}
view : (Msg -> msg) -> List (Attribute row msg) -> State -> Html msg
view toMsg attributes (State s) =
    let
        config =
            configure attributes

        t =
            texts config.locale

        ctx =
            { toMsg = toMsg, config = config, state = s, texts = t }

        root =
            rootGroup s.rule

        count =
            List.length root.children
    in
    Html.div
        [ Internal.cls [ "klar-filterbar" ]
        , Attr.id s.id
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label" (Maybe.withDefault t.filters config.ariaLabel)
        ]
        [ viewPresets ctx
        , viewPrefix ctx root
        , if count > 0 then
            Html.ul [ Internal.cls [ "klar-filterbar__chips" ], Attr.attribute "aria-label" t.active ]
                (List.indexedMap (viewChip ctx root) root.children)

          else
            Html.text ""
        , viewAdd ctx
        , if count > 0 then
            Button.view
                [ Button.ghost
                , Button.small
                , Button.id (s.id ++ "-clear")
                , Button.onClick (toMsg ClearedAll)
                ]
                t.clearAll

          else
            Html.text ""
        , viewCount ctx
        , Html.span [ Internal.cls [ "klar-filterbar__undo" ], Attr.attribute "role" "status" ]
            (case s.undo of
                Just undo ->
                    [ Html.span []
                        [ Html.text
                            (if undo.cleared then
                                t.cleared

                             else
                                t.removed
                            )
                        ]
                    , Button.view
                        [ Button.link
                        , Button.id (undoDomId s.id)
                        , Button.onClick (toMsg UndoClicked)
                        ]
                        t.undo
                    ]

                Nothing ->
                    []
            )
        ]


viewPresets : Ctx row msg -> Html msg
viewPresets ctx =
    if List.isEmpty ctx.config.quick then
        Html.text ""

    else
        Html.div [ Internal.cls [ "klar-filterbar__presets" ] ]
            [ Html.div
                [ Internal.cls [ "klar-filterbar__quick" ]
                , Attr.attribute "role" "group"
                , Attr.attribute "aria-label" ctx.texts.quickFilters
                ]
                (List.indexedMap
                    (\index ( name, preset ) ->
                        let
                            on =
                                isPresetOn preset ctx.state.rule

                            problem =
                                Rule.validate ctx.config.locale ctx.config.fields (Support.normalize preset)
                                    |> List.head
                                    |> Maybe.map .message
                        in
                        Html.button
                            [ Internal.cls
                                [ "klar-filterbar__pill"
                                , if on then
                                    "klar-filterbar__pill--on"

                                  else
                                    ""
                                , if problem /= Nothing then
                                    "klar-filterbar__pill--invalid"

                                  else
                                    ""
                                ]
                            , Attr.type_ "button"
                            , Attr.id (ctx.state.id ++ "-quick-" ++ String.fromInt index)
                            , Attr.attribute "aria-pressed"
                                (if on then
                                    "true"

                                 else
                                    "false"
                                )
                            , Attr.disabled (problem /= Nothing)
                            , Internal.attrMaybe (\message -> Attr.title (name ++ ": " ++ message)) problem
                            , Events.onClick (ctx.toMsg (PresetToggled preset))
                            ]
                            [ Html.span [ Internal.cls [ "klar-filterbar__pill-check" ] ] [ Icon.sized Icon.ExtraSmall Icon.check ]
                            , Html.span [] [ Html.text name ]
                            ]
                    )
                    ctx.config.quick
                )
            , Html.span [ Internal.cls [ "klar-filterbar__divider" ], Attr.attribute "aria-hidden" "true" ] []
            ]


{-| A root that is not a plain "all of" (a rule from the builder) says how
its chips combine.
-}
viewPrefix : Ctx row msg -> Group -> Html msg
viewPrefix ctx root =
    let
        t =
            ctx.texts

        words =
            case ( root.negated, root.combinator ) of
                ( True, All ) ->
                    -- "not all of" a single filter reads oddly; it simply means "none of" it
                    if List.length root.children > 1 then
                        Just t.notAllOf

                    else
                        Just t.noneOf

                ( True, Any ) ->
                    Just t.noneOf

                ( False, Any ) ->
                    if List.length root.children > 1 then
                        Just t.anyOf

                    else
                        Nothing

                ( False, All ) ->
                    Nothing
    in
    case words of
        Just text ->
            Html.span [ Internal.cls [ "klar-filterbar__prefix" ] ] [ Html.text text ]

        Nothing ->
            Html.text ""


viewChip : Ctx row msg -> Group -> Int -> Rule -> Html msg
viewChip ctx root index child =
    let
        t =
            ctx.texts

        s =
            ctx.state

        config =
            ctx.config

        joiner =
            if index > 0 && root.combinator == Any && List.length root.children > 1 then
                Html.span [ Internal.cls [ "klar-filterbar__joiner" ] ] [ Html.text t.or ]

            else
                Html.text ""

        ids =
            List.map Rule.idOf root.children

        -- one chip is the tab stop: the one the user was on, else the first
        currentId =
            case s.current of
                Just id ->
                    if List.member id ids then
                        id

                    else
                        List.head ids |> Maybe.withDefault -1

                Nothing ->
                    List.head ids |> Maybe.withDefault -1

        roving id =
            let
                at offset =
                    List.drop (index + offset) ids |> List.head

                move key target =
                    Maybe.map (\other -> ( key, ctx.toMsg (MovedTo other) )) target
            in
            [ Attr.tabindex
                (if id == currentId then
                    0

                 else
                    -1
                )
            , Events.onFocus (ctx.toMsg (ChipFocused id))
            , Internal.onKeys
                (List.filterMap identity
                    [ if index > 0 then
                        move "ArrowLeft" (at -1)

                      else
                        Nothing
                    , move "ArrowRight" (at 1)
                    , if index > 0 then
                        move "Home" (List.head ids)

                      else
                        Nothing
                    , if index < List.length ids - 1 then
                        move "End" (List.reverse ids |> List.head)

                      else
                        Nothing
                    , Just ( "Delete", ctx.toMsg (ChipRemoved id) )
                    , Just ( "Backspace", ctx.toMsg (ChipRemoved id) )
                    ]
                )
            ]

        -- for the mouse: the keyboard removes a chip with Delete
        removeButton id name =
            Html.button
                [ Internal.cls [ "klar-filterbar__chip-remove" ]
                , Attr.type_ "button"
                , Attr.id (chipDomId s.id id ++ "-remove")
                , Attr.attribute "aria-label" (t.removeFilter ++ ": " ++ name)
                , Attr.title (t.removeFilter ++ ": " ++ name)
                , Events.onClick (ctx.toMsg (ChipRemoved id))
                , Attr.tabindex -1
                ]
                [ Icon.sized Icon.ExtraSmall Icon.close ]
    in
    Html.li [ Internal.cls [ "klar-filterbar__item" ] ]
        [ joiner
        , case child of
            ConditionRule condition ->
                let
                    parts =
                        Editor.chipParts config.locale config.fields condition

                    open =
                        Maybe.map .target s.editing == Just (ExistingFilter condition.id)

                    title =
                        if parts.complete then
                            parts.title

                        else
                            parts.title ++ " (" ++ t.incomplete ++ ")"
                in
                Html.div [ Internal.cls [ "klar-anchor", "klar-filterbar__anchor" ] ]
                    [ Html.span
                        [ Internal.cls
                            [ "klar-filterbar__chip"
                            , if parts.complete then
                                ""

                              else
                                "klar-filterbar__chip--incomplete"
                            , if open then
                                "klar-filterbar__chip--open"

                              else
                                ""
                            ]
                        ]
                        [ Html.button
                            ([ Internal.cls [ "klar-filterbar__chip-main" ]
                             , Attr.type_ "button"
                             , Attr.id (chipDomId s.id condition.id)
                             , Attr.title title
                             , Attr.attribute "aria-haspopup" "dialog"
                             , Attr.attribute "aria-expanded"
                                (if open then
                                    "true"

                                 else
                                    "false"
                                )
                             , Internal.attrIf open (Attr.attribute "aria-controls" (popupDomId s.id))
                             , Attr.attribute "aria-keyshortcuts" "Delete"
                             , Events.onClick
                                (ctx.toMsg
                                    (ChipOpened condition.id (Editor.focusDomId (draftPrefix s.id) config.fields condition))
                                )
                             ]
                                ++ roving condition.id
                            )
                            [ Html.span [ Internal.cls [ "klar-filterbar__chip-field" ] ] [ Html.text parts.field ]
                            , if parts.operator /= "" then
                                Html.span [ Internal.cls [ "klar-filterbar__chip-op" ] ] [ Html.text parts.operator ]

                              else
                                Html.text ""
                            , if parts.value /= "" then
                                Html.span [ Internal.cls [ "klar-filterbar__chip-value" ] ] [ Html.text parts.value ]

                              else
                                Html.text ""
                            , if parts.complete then
                                Html.text ""

                              else
                                Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (" (" ++ t.incomplete ++ ")") ]
                            ]
                        , removeButton condition.id title
                        ]
                    , case s.editing of
                        Just editing ->
                            if open then
                                viewPopup ctx editing

                            else
                                Html.text ""

                        Nothing ->
                            Html.text ""
                    ]

            GroupRule group ->
                let
                    words =
                        Rule.describe config.locale config.fields (GroupRule group)

                    -- nothing in the group filters: it reads "All rows", which is no filter
                    complete =
                        not (Rule.isEmpty (Rule.settled config.fields (GroupRule group)))

                    described =
                        if not complete then
                            t.emptyGroup ++ " (" ++ t.incomplete ++ ")"

                        else if group.negated then
                            -- already reads "not (...)"
                            words

                        else
                            "(" ++ words ++ ")"
                in
                Html.span
                    [ Internal.cls
                        [ "klar-filterbar__chip"
                        , "klar-filterbar__chip--group"
                        , if complete then
                            ""

                          else
                            "klar-filterbar__chip--incomplete"
                        ]
                    ]
                    -- The group is edited where it was made (a RuleBuilder, a preset): its
                    -- main part is the chip's tab stop, a button that is unavailable,
                    -- so Enter does nothing, and Delete removes the group as on any chip.
                    [ Html.span
                        ([ Internal.cls [ "klar-filterbar__chip-main", "klar-filterbar__chip-main--static" ]
                         , Attr.id (chipDomId s.id group.id)
                         , Attr.attribute "role" "button"
                         , Attr.attribute "aria-disabled" "true"
                         , Attr.attribute "aria-label" described
                         , Attr.attribute "aria-keyshortcuts" "Delete"
                         , Attr.title described
                         ]
                            ++ roving group.id
                        )
                        [ Html.span [ Internal.cls [ "klar-filterbar__chip-value" ] ] [ Html.text described ] ]
                    , removeButton group.id described
                    ]
        ]


viewAdd : Ctx row msg -> Html msg
viewAdd ctx =
    let
        s =
            ctx.state

        open =
            Maybe.map .target s.editing == Just NewFilter
    in
    Html.div [ Internal.cls [ "klar-anchor", "klar-filterbar__add" ] ]
        [ Button.view
            [ Button.small
            , Button.icon Icon.plus
            , Button.id (addDomId s.id)
            , Button.expanded open
            , Button.htmlAttrs
                [ Attr.attribute "aria-haspopup" "dialog"
                , Internal.attrIf open (Attr.attribute "aria-controls" (popupDomId s.id))
                ]
            , Button.onClick (ctx.toMsg AddOpened)
            ]
            (Maybe.withDefault ctx.texts.addFilter ctx.config.addLabel)
        , case s.editing of
            Just editing ->
                if open then
                    viewPopup ctx editing

                else
                    Html.text ""

            Nothing ->
                Html.text ""
        ]


viewPopup : Ctx row msg -> Editing -> Html msg
viewPopup ctx editing =
    let
        t =
            ctx.texts

        s =
            ctx.state

        config =
            ctx.config

        draft =
            editing.draft

        issues =
            Rule.validate config.locale config.fields (ConditionRule draft)

        valid =
            List.isEmpty issues

        issue =
            if editing.tried then
                List.head issues |> Maybe.map .message

            else
                Nothing

        focusId =
            Editor.focusDomId (draftPrefix s.id) config.fields draft

        applyMsg =
            ctx.toMsg (Applied valid focusId)

        settings =
            { toMsg = ctx.toMsg << EditorMsg
            , fields = config.fields
            , locale = config.locale
            , controls = s.controls
            , issue = issue
            , layout = Editor.Stacked
            , today = config.today
            , onEnter = Just applyMsg
            }

        isNew =
            editing.target == NewFilter

        title =
            if isNew then
                t.addFilter

            else
                t.editFilter

        row caption content =
            Html.div [ Internal.cls [ "klar-filterbar__row" ] ]
                [ Html.span [ Internal.cls [ "klar-filterbar__caption" ], Attr.attribute "aria-hidden" "true" ] [ Html.text caption ]
                , content
                ]
    in
    Html.div
        [ Internal.cls [ "klar-layer" ]
        , Events.onClick (ctx.toMsg Cancelled)
        , if Editor.anyOpen s.controls then
            Internal.noAttr

          else
            Internal.onLayerKeys (ctx.toMsg Cancelled) []
        ]
        [ Html.div
            [ Internal.cls [ "klar-popup", "klar-filterbar__popup" ]
            , Attr.id (popupDomId s.id)
            , Attr.attribute "role" "dialog"
            , Attr.attribute "aria-label" title
            , Attr.tabindex -1
            , Internal.onClickStop (ctx.toMsg NoOp)
            , if Editor.anyOpen s.controls then
                Internal.noAttr

              else
                Internal.onKeys [ ( "Ctrl+Enter", applyMsg ), ( "Meta+Enter", applyMsg ) ]
            , Support.onFocusLeave (popupDomId s.id) (ctx.toMsg Left)
            ]
            [ Html.div [ Internal.cls [ "klar-filterbar__popup-title" ] ] [ Html.text title ]
            , row t.field (Editor.viewField settings draft)
            , if Editor.isKnownField config.fields draft then
                row t.operator (Editor.viewOperator settings draft)

              else
                Html.text ""
            , if Editor.hasValueEditor config.fields draft then
                row t.value (Editor.viewValues settings draft)

              else
                Html.text ""
            , case issue of
                Just message ->
                    Html.p [ Internal.cls [ "klar-filterbar__issue" ], Attr.attribute "role" "alert" ]
                        [ Icon.sized Icon.Small Icon.errorCircle
                        , Html.span [] [ Html.text message ]
                        ]

                Nothing ->
                    Html.text ""
            , Html.div [ Internal.cls [ "klar-filterbar__popup-footer" ] ]
                [ if isNew then
                    Html.text ""

                  else
                    Button.view
                        [ Button.ghost
                        , Button.small
                        , Button.icon Icon.trash
                        , Button.onClick (ctx.toMsg RemovedInEditor)
                        ]
                        t.remove
                , Html.span [ Internal.cls [ "klar-filterbar__spacer" ] ] []
                , Button.view [ Button.small, Button.onClick (ctx.toMsg Cancelled) ] t.cancel
                , Button.view [ Button.primary, Button.small, Button.onClick applyMsg ]
                    (if isNew then
                        t.add

                     else
                        t.apply
                    )
                ]
            ]
        ]


viewCount : Ctx row msg -> Html msg
viewCount ctx =
    Count.view
        { locale = ctx.config.locale
        , count = ctx.config.matchCount
        , total = ctx.config.totalCount
        , onRetry = ctx.config.onRetry
        , retryId = ctx.state.id ++ "-count-retry"
        , classes = [ "klar-filterbar__count" ]
        }



-- TEXT


type alias Texts =
    { filters : String
    , active : String
    , quickFilters : String
    , addFilter : String
    , editFilter : String
    , field : String
    , operator : String
    , value : String
    , add : String
    , apply : String
    , cancel : String
    , remove : String
    , removeFilter : String
    , clearAll : String
    , anyOf : String
    , notAllOf : String
    , noneOf : String
    , or : String
    , incomplete : String
    , emptyGroup : String
    , undo : String
    , cleared : String
    , removed : String
    }


texts : Locale -> Texts
texts lang =
    Locale.pick lang
        { nb =
            { filters = "Filtre"
            , active = "Aktive filtre"
            , quickFilters = "Hurtigfiltre"
            , addFilter = "Legg til filter"
            , editFilter = "Endre filter"
            , field = "Felt"
            , operator = "Betingelse"
            , value = "Verdi"
            , add = "Legg til"
            , apply = "Bruk"
            , cancel = "Avbryt"
            , remove = "Fjern"
            , removeFilter = "Fjern filteret"
            , clearAll = "Nullstill alle"
            , anyOf = "Minst én av:"
            , notAllOf = "Ikke alle av:"
            , noneOf = "Ingen av:"
            , or = "eller"
            , incomplete = "ufullstendig, filtrerer ikke"
            , emptyGroup = "Gruppe uten fullstendige filtre"
            , undo = "Angre"
            , cleared = "Alle filtre ble fjernet."
            , removed = "Filteret ble fjernet."
            }
        , en =
            { filters = "Filters"
            , active = "Active filters"
            , quickFilters = "Quick filters"
            , addFilter = "Add filter"
            , editFilter = "Edit filter"
            , field = "Field"
            , operator = "Operator"
            , value = "Value"
            , add = "Add"
            , apply = "Apply"
            , cancel = "Cancel"
            , remove = "Remove"
            , removeFilter = "Remove filter"
            , clearAll = "Clear all"
            , anyOf = "Any of:"
            , notAllOf = "Not all of:"
            , noneOf = "None of:"
            , or = "or"
            , incomplete = "incomplete, not filtering"
            , emptyGroup = "Group without complete filters"
            , undo = "Undo"
            , cleared = "All filters were cleared."
            , removed = "The filter was removed."
            }
        }
