module Klar.Tabs exposing
    ( view, panel, panels
    , State, init, active, setActive, resolve, Msg, update
    , Tab, tab, withIcon, withCount, withTitle, disabledTab
    , Attribute, tabs, ariaLabel, boxed, small, fill, manual, withoutPanels
    )

{-| Tabs that switch between views of the same thing: the overview of an order,
its history and its files.

Use when: the user switches between views of the same thing, such as the overview, history and files of an order.
Do not use when: sections should open and close in place (use `Klar.Accordion`) or the user moves through ordered steps (use `Klar.Stepper`).
Quick path: `init`, `update`, `view`, `panel`, `active`, `setActive`

The component is stateful: it owns which tab is active and which tab has
keyboard focus. The application reads the active tab with `active` and compares
it before and after an update to react, for instance to change the URL. To set
the tab from outside, when the route changes, use `setActive`.

    import Klar.Icon as Icon
    import Klar.Tabs as Tabs

    -- model: tabs : Tabs.State
    -- init:  Tabs.init "order-tabs" "overview"

    -- update
    TabsMsg m ->
        let
            ( tabs, cmd ) =
                Tabs.update m model.tabs
        in
        ( { model | tabs = tabs }, Cmd.map TabsMsg cmd )

    -- view
    Html.div []
        [ Tabs.view TabsMsg
            [ Tabs.ariaLabel "Order sections"
            , Tabs.tabs
                [ Tabs.tab "overview" "Overview"
                , Tabs.tab "history" "History" |> Tabs.withCount 12
                , Tabs.tab "files" "Files" |> Tabs.withIcon Icon.paperclip
                , Tabs.tab "billing" "Billing" |> Tabs.disabledTab
                ]
            ]
            model.tabs
        , Tabs.panel model.tabs "overview" (\_ -> overviewView model)
        , Tabs.panel model.tabs "history" (\_ -> historyView model)
        ]

`panel` renders its content only while its tab is active (the function is not
even called for the others), so heavy tab content costs nothing until it is
opened. Tabs that choose a route, a filter or the contents of a table somewhere
else have no panels: add `withoutPanels` so that they do not point at panels
that are not in the page. [Klar.PageHeader](Klar-PageHeader) takes such a strip.

The active key should belong to an enabled tab. When it may not, because it comes
from the URL or because a tab becomes disabled while it is active, the strip shows
the first enabled tab as selected, but `panel` and `panels` only see the state.
Pass the state through `resolve` once and give the result to `view`, `panel` and
`panels`: all three then agree on the same tab.

Keyboard: Left and Right arrow move to the previous and next tab and select it,
wrapping around at the ends (Home and End jump to the first and last). With
`manual` the arrows only move focus and Enter or Space selects, which is better
when switching is expensive. Only one tab is in the Tab order (roving tabindex),
the active one or, with `manual`, the one that last had focus, so Tab goes from
the tab list straight into the panel. Disabled tabs are skipped.

The strip is a `tablist` of `tab` buttons and each panel a `tabpanel` named by
its tab. Name the strip with `ariaLabel`. A strip wider than its container
scrolls sideways.


# Views

@docs view, panel, panels


# State

@docs State, init, active, setActive, resolve, Msg, update


# Tabs

@docs Tab, tab, withIcon, withCount, withTitle, disabledTab


# Attributes

@docs Attribute, tabs, ariaLabel, boxed, small, fill, manual, withoutPanels

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal



-- TABS


{-| One tab of the strip. Make it with `tab` and refine it with `withIcon`,
`withCount`, `withTitle` and `disabledTab`.
-}
type Tab
    = Tab
        { key : String
        , label : String
        , icon : Maybe Icon
        , count : Maybe Int
        , disabled : Bool
        , title : Maybe String
        }


{-| A tab: the key first, then the label. The key identifies the tab in the
state (`active`, `setActive`) and names its panel (`panel`), so it must be
unique within the strip. The label is the text of the tab.

    Tabs.tab "history" "History"

-}
tab : String -> String -> Tab
tab key label =
    Tab { key = key, label = label, icon = Nothing, count = Nothing, disabled = False, title = Nothing }


{-| An icon before the label. It is decorative: the label still names the tab.
-}
withIcon : Icon -> Tab -> Tab
withIcon icon (Tab config) =
    Tab { config | icon = Just icon }


{-| A small number after the label, such as the number of items behind the tab.
It is shown as it is, without shortening large numbers.
-}
withCount : Int -> Tab -> Tab
withCount n (Tab config) =
    Tab { config | count = Just n }


{-| Visible but not selectable: the tab is a disabled button and the arrow keys
skip it. Combine with `withTitle` to say why.
-}
disabledTab : Tab -> Tab
disabledTab (Tab config) =
    Tab { config | disabled = True }


{-| A native tooltip (the `title` attribute) for the tab, for example to explain
why it is disabled.

    Tabs.tab "billing" "Billing"
        |> Tabs.disabledTab
        |> Tabs.withTitle "Available once the order is confirmed"

-}
withTitle : String -> Tab -> Tab
withTitle text (Tab config) =
    Tab { config | title = Just text }



-- ATTRIBUTES


{-| A setting of the tab strip. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones. The strip's messages are
the separate `Msg`, so the type has no `msg` parameter.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { tabs : List Tab
    , boxed : Bool
    , small : Bool
    , fill : Bool
    , manual : Bool
    , ariaLabel : Maybe String
    , controlsPanels : Bool
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { tabs = []
        , boxed = False
        , small = False
        , fill = False
        , manual = False
        , ariaLabel = Nothing
        , controlsPanels = True
        }
        attributes


{-| The tabs, in order. At least one of them should be enabled, and the key of
the active tab (see `init` and `setActive`) should belong to an enabled tab;
`resolve` makes sure of it.
-}
tabs : List Tab -> Attribute
tabs value =
    Attribute (\config -> { config | tabs = value })


{-| Draws the tabs as boxes joined to the panel below, which gets a border of its
own. The default is a plain line under the strip with the active tab underlined.
-}
boxed : Attribute
boxed =
    Attribute (\config -> { config | boxed = True })


{-| Lower tabs with smaller text, for tight spaces.
-}
small : Attribute
small =
    Attribute (\config -> { config | small = True })


{-| The tabs share the full width of the strip equally, instead of being only as
wide as their labels.
-}
fill : Attribute
fill =
    Attribute (\config -> { config | fill = True })


{-| Manual activation: the arrow keys only move the focus, and Enter or Space
selects the focused tab. Without it the arrows move and select in one go, which
is right when switching is cheap. Use `manual` when switching is expensive, such
as a tab that loads data.
-}
manual : Attribute
manual =
    Attribute (\config -> { config | manual = True })


{-| The accessible name of the tab list: what the tabs switch between, for example
"Order sections". There is no default; without it the list has no name.
-}
ariaLabel : String -> Attribute
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Just value })


{-| Says that no `panel` or `panels` follows the strip: the tabs choose a route, a
filter or the contents of a table somewhere else. Without panels the active tab
must not claim a panel that is not in the page, so it leaves out `aria-controls`.
-}
withoutPanels : Attribute
withoutPanels =
    Attribute (\config -> { config | controlsPanels = False })



-- STATE


{-| The state of a tab strip: which tab is active and which tab has keyboard
focus. Make one with `init`, keep it in your model, and give it to `view`,
`panel` and `panels`.
-}
type State
    = State
        { id : String
        , active : String
        , focused : String
        }


{-| A tab strip with one tab active. The first argument is a DOM id that must be
unique on the page: it is the prefix of the ids of the tabs and panels. The second
is the key of the tab that is active at first.

    Tabs.init "order-tabs" "overview"

-}
init : String -> String -> State
init id initial =
    State { id = id, active = initial, focused = initial }


{-| The key of the active tab. Compare it before and after `update` to react when
the user picks another tab.

    Tabs.active tabs /= Tabs.active model.tabs

-}
active : State -> String
active (State state) =
    state.active


{-| Selects a tab from the application, for instance when the route changes. It
does not move keyboard focus. The key should belong to an enabled tab; when you
cannot be sure of that, draw the tabs from `resolve`.
-}
setActive : String -> State -> State
setActive key (State state) =
    State { state | active = key, focused = key }


{-| The state as the strip shows it: when the active key belongs to no tab, or to
a disabled one, the first enabled tab becomes the active one (the key is empty
when no tab is enabled); otherwise nothing changes. `view` does this for itself,
but `panel` and `panels` only see the state, so resolve it once, with the same
tabs that you give to `tabs`, and hand the result to all three.

    let
        resolved =
            Tabs.resolve orderTabs model.tabs
    in
    Html.div []
        [ Tabs.view TabsMsg [ Tabs.tabs orderTabs ] resolved
        , Tabs.panel resolved "overview" (\_ -> overviewView model)
        , Tabs.panel resolved "history" (\_ -> historyView model)
        ]

-}
resolve : List Tab -> State -> State
resolve tabList (State state) =
    State { state | active = resolveKey (enabledKeysOf tabList) state.active }


enabledKeysOf : List Tab -> List String
enabledKeysOf tabList =
    List.filterMap
        (\(Tab data) ->
            if data.disabled then
                Nothing

            else
                Just data.key
        )
        tabList


{-| The key that is selected: the given one when it belongs to an enabled tab,
otherwise the first enabled tab (or "" when there is none).
-}
resolveKey : List String -> String -> String
resolveKey enabledKeys key =
    if List.member key enabledKeys then
        key

    else
        Maybe.withDefault "" (List.head enabledKeys)


{-| The messages of a tab strip: a tab was clicked, an arrow key was pressed.
Wrap it in a constructor of your own message type, pass that constructor to
`view`, and hand the messages you get back to `update`.
-}
type Msg
    = Select String
    | Move String
    | FocusOnly String
    | Noop


{-| Selects tabs and moves keyboard focus between them. The `Cmd` moves the focus
to the tab the arrow keys reached, so map it with your message constructor.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State state) =
    case msg of
        Select key ->
            ( State { state | active = key, focused = key }, Cmd.none )

        Move key ->
            ( State { state | active = key, focused = key }
            , Internal.focus (tabId state.id key) Noop
            )

        FocusOnly key ->
            ( State { state | focused = key }
            , Internal.focus (tabId state.id key) Noop
            )

        Noop ->
            ( State state, Cmd.none )


tabId : String -> String -> String
tabId id key =
    id ++ "-tab-" ++ Internal.sanitizeId key


panelId : String -> String -> String
panelId id key =
    id ++ "-panel-" ++ Internal.sanitizeId key



-- VIEW


{-| The tab list. The first argument wraps the strip's `Msg` in your own message
type. The panels are separate: see `panel` and `panels`. When the active key
belongs to no enabled tab, the first enabled tab is shown as selected; give the
panels the state from `resolve` so that they follow.
-}
view : (Msg -> msg) -> List Attribute -> State -> Html msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes

        enabledKeys =
            enabledKeysOf config.tabs

        activeKey =
            resolveKey enabledKeys state.active

        -- the one tab that is in the Tab order
        stopKey =
            if config.manual && List.member state.focused enabledKeys then
                state.focused

            else
                activeKey

        move key =
            if config.manual then
                toMsg (FocusOnly key)

            else
                toMsg (Move key)
    in
    Html.div
        [ Internal.cls
            [ "klar-tabs"
            , if config.boxed then
                "klar-tabs--boxed"

              else
                "klar-tabs--line"
            , if config.small then
                "klar-tabs--sm"

              else
                ""
            , if config.fill then
                "klar-tabs--fill"

              else
                ""
            ]
        ]
        [ Html.div [ Internal.cls [ "klar-tabs__scroller" ] ]
            [ Html.div
                [ Internal.cls [ "klar-tabs__list" ]
                , Attr.attribute "role" "tablist"
                , Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
                ]
                (List.map (viewTab toMsg move state.id config.controlsPanels enabledKeys activeKey stopKey) config.tabs)
            ]
        ]


viewTab : (Msg -> msg) -> (String -> msg) -> String -> Bool -> List String -> String -> String -> Tab -> Html msg
viewTab toMsg move id controlsPanels enabledKeys activeKey stopKey (Tab data) =
    let
        isActive =
            data.key == activeKey

        neighbour offset =
            case indexOf data.key enabledKeys of
                Just index ->
                    enabledKeys |> List.drop (modBy (List.length enabledKeys) (index + offset)) |> List.head

                Nothing ->
                    Nothing

        keys =
            List.filterMap identity
                [ neighbour 1 |> Maybe.map (\key -> ( "ArrowRight", move key ))
                , neighbour -1 |> Maybe.map (\key -> ( "ArrowLeft", move key ))
                , List.head enabledKeys |> Maybe.map (\key -> ( "Home", move key ))
                , List.head (List.reverse enabledKeys) |> Maybe.map (\key -> ( "End", move key ))
                ]
    in
    Html.button
        [ Internal.cls
            [ "klar-tabs__tab"
            , if isActive then
                "klar-tabs__tab--active"

              else
                ""
            , if data.disabled then
                "klar-tabs__tab--disabled"

              else
                ""
            ]
        , Attr.id (tabId id data.key)
        , Attr.type_ "button"
        , Attr.attribute "role" "tab"
        , Attr.attribute "aria-selected"
            (if isActive then
                "true"

             else
                "false"
            )
        , Internal.attrIf (isActive && controlsPanels) (Attr.attribute "aria-controls" (panelId id data.key))
        , Attr.tabindex
            (if data.key == stopKey then
                0

             else
                -1
            )
        , Attr.disabled data.disabled
        , Internal.attrMaybe Attr.title data.title
        , if data.disabled then
            Internal.noAttr

          else
            Events.onClick (toMsg (Select data.key))
        , if data.disabled then
            Internal.noAttr

          else
            Internal.onKeys keys
        ]
        [ Internal.viewMaybe Icon.view data.icon
        , Html.span [ Internal.cls [ "klar-tabs__label" ] ] [ Html.text data.label ]
        , Internal.viewMaybe
            (\n -> Html.span [ Internal.cls [ "klar-tabs__count", "klar-tabular" ] ] [ Html.text (String.fromInt n) ])
            data.count
        ]


indexOf : String -> List String -> Maybe Int
indexOf target list =
    list
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, key ) -> key == target)
        |> List.head
        |> Maybe.map Tuple.first



-- PANELS


{-| The content of one tab: the state, the key of the tab, and a function that
builds the content. The panel is rendered only while the tab is active; the
function is not called otherwise. Put it below the strip, and give it the state
from `resolve` when the active key may not belong to an enabled tab.

    Tabs.panel model.tabs "history" (\_ -> historyView model)

-}
panel : State -> String -> (() -> Html msg) -> Html msg
panel (State state) key content =
    if state.active == key then
        Html.div
            [ Internal.cls [ "klar-tabs__panel" ]
            , Attr.id (panelId state.id key)
            , Attr.attribute "role" "tabpanel"
            , Attr.attribute "aria-labelledby" (tabId state.id key)
            , Attr.tabindex 0
            ]
            [ content () ]

    else
        Html.text ""


{-| All the panels in one go, as a list of keys with their content functions.
Only the panel of the active tab is built; as for `panel`, the state from
`resolve` makes it the tab that the strip shows.

    Tabs.panels model.tabs
        [ ( "overview", \_ -> overviewView model )
        , ( "history", \_ -> historyView model )
        ]

-}
panels : State -> List ( String, () -> Html msg ) -> Html msg
panels state entries =
    case List.filter (\( key, _ ) -> key == active state) entries |> List.head of
        Just ( key, content ) ->
            panel state key content

        Nothing ->
            Html.text ""
