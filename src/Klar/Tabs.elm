module Klar.Tabs exposing
    ( view
    , State, init, active, setActive, Msg, update
    , Tab, tab, withPanel, withIcon, withCount, withTitle, disabledTab
    , Attribute, tabs, ariaLabel, boxed, small, fill, vertical, manual, locale
    )

{-| Tabs that switch between views of the same thing: the overview of an order,
its history and its files.

Use when: the user switches between views of the same thing, such as the overview, history and files of an order.
Do not use when: sections should open and close in place (use `Klar.Accordion`) or the user moves through ordered steps (use `Klar.Stepper`).
Quick path: `init`, `update`, `view`, `tab`, `withPanel`, `active`

The tabs are values of your own type, so a misspelled tab is a compile error and the
active one is matched with a `case`. The component is stateful: it owns which tab is
active. The application reads it with `active` and compares it before and after an
update to react, for instance to change the URL. To set the tab from outside, when the
route changes, use `setActive`.

    import Klar.Icon as Icon
    import Klar.Tabs as Tabs

    type Section
        = Overview
        | History
        | Files
        | Billing

    -- model: tabs : Tabs.State Section
    -- init:  Tabs.init "order-tabs" Overview
    -- Msg:   TabsMsg (Tabs.Msg Section)

    -- update
    TabsMsg m ->
        let
            ( tabs, cmd ) =
                Tabs.update m model.tabs
        in
        ( { model | tabs = tabs }, Cmd.map TabsMsg cmd )

    -- view
    Tabs.view TabsMsg
        [ Tabs.ariaLabel "Order sections"
        , Tabs.tabs
            [ Tabs.tab Overview "Overview"
                |> Tabs.withPanel (\_ -> overviewView model)
            , Tabs.tab History "History"
                |> Tabs.withCount 12
                |> Tabs.withPanel (\_ -> historyView model)
            , Tabs.tab Files "Files"
                |> Tabs.withIcon Icon.paperclip
                |> Tabs.withPanel (\_ -> filesView model)
            , Tabs.tab Billing "Billing" |> Tabs.disabledTab
            ]
        ]
        model.tabs

`view` draws the strip and, under it, the panel of the active tab: the strip and the
panel always agree, also when the active tab is disabled or not in the list (then the
first enabled tab is shown as active, and its panel). Only the panel of the active tab
is built (the function is not even called for the others), so heavy tab content costs
nothing until it is opened.

Tabs that choose a route, a filter or the contents of a table somewhere else have no
panels: leave out `withPanel`, and the strip claims no panel. That is the strip for
[Klar.PageHeader](Klar-PageHeader): the page below is the view of the route (or a `case`
on `active`).

Keyboard: Left and Right arrow (Up and Down with `vertical`) move to the previous and
next tab and select it, wrapping around at the ends; Home and End jump to the first and
last. With `manual` the arrows only move focus and Enter or Space selects, which is
better when switching is expensive. Only the active tab is in the Tab order (roving
tabindex), so Tab goes from the tab list straight into the panel. Disabled tabs are
skipped.

The strip is a `tablist` of `tab` buttons and the panel a `tabpanel` named by its tab.
Name the strip with `ariaLabel`. A strip wider than its container scrolls sideways.


# View

@docs view


# State

@docs State, init, active, setActive, Msg, update


# Tabs

@docs Tab, tab, withPanel, withIcon, withCount, withTitle, disabledTab


# Attributes

@docs Attribute, tabs, ariaLabel, boxed, small, fill, vertical, manual, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Format as Format
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)



-- TABS


{-| One tab of the strip, with a key of your own type. Make it with `tab` and refine it
with `withPanel`, `withIcon`, `withCount`, `withTitle` and `disabledTab`. The `msg` is
the message type of the content of its panel.
-}
type Tab key msg
    = Tab (TabData key msg)


type alias TabData key msg =
    { key : key
    , label : String
    , icon : Maybe Icon
    , count : Maybe Int
    , disabled : Bool
    , title : Maybe String
    , panel : Maybe (() -> Html msg)
    }


{-| A tab: its key (a value of your own type, unique within the strip and compared with
`==`), then the label, the text of the tab.

    Tabs.tab History "History"

-}
tab : key -> String -> Tab key msg
tab key label =
    Tab { key = key, label = label, icon = Nothing, count = Nothing, disabled = False, title = Nothing, panel = Nothing }


{-| The content shown under the strip while this tab is active, as a function that is
only called then. A strip whose tabs have no panel claims none (`aria-controls` is left
out), for tabs that choose a route or a filter.

    Tabs.tab History "History"
        |> Tabs.withPanel (\_ -> historyView model)

-}
withPanel : (() -> Html msg) -> Tab key msg -> Tab key msg
withPanel content (Tab data) =
    Tab { data | panel = Just content }


{-| An icon before the label. It is decorative: the label still names the tab.
-}
withIcon : Icon -> Tab key msg -> Tab key msg
withIcon icon (Tab data) =
    Tab { data | icon = Just icon }


{-| A small number after the label, such as the number of items behind the tab. It is
shown whole, grouped the way the language of `locale` writes numbers ("12 345" in
Norwegian).
-}
withCount : Int -> Tab key msg -> Tab key msg
withCount n (Tab data) =
    Tab { data | count = Just n }


{-| Visible but not selectable: the tab is a disabled button and the arrow keys
skip it. Combine with `withTitle` to say why.
-}
disabledTab : Tab key msg -> Tab key msg
disabledTab (Tab data) =
    Tab { data | disabled = True }


{-| A native tooltip (the `title` attribute) for the tab, for example to explain
why it is disabled.

    Tabs.tab Billing "Billing"
        |> Tabs.disabledTab
        |> Tabs.withTitle "Available once the order is confirmed"

-}
withTitle : String -> Tab key msg -> Tab key msg
withTitle text (Tab data) =
    Tab { data | title = Just text }



-- ATTRIBUTES


{-| A setting of the tab strip. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones. `key` is the type of your tabs and `msg`
your message type, of the content of the panels.
-}
type Attribute key msg
    = Attribute (Config key msg -> Config key msg)


type alias Config key msg =
    { tabs : List (Tab key msg)
    , boxed : Bool
    , small : Bool
    , fill : Bool
    , vertical : Bool
    , manual : Bool
    , ariaLabel : Maybe String
    , locale : Locale
    }


configure : List (Attribute key msg) -> Config key msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { tabs = []
        , boxed = False
        , small = False
        , fill = False
        , vertical = False
        , manual = False
        , ariaLabel = Nothing
        , locale = Locale.default
        }
        attributes


{-| The tabs, in order. At least one of them should be enabled; when the active key
belongs to no enabled tab, the first enabled one is shown as active.
-}
tabs : List (Tab key msg) -> Attribute key msg
tabs value =
    Attribute (\config -> { config | tabs = value })


{-| Draws the tabs as boxes joined to the panel below, which gets a border of its
own. The default is a plain line under the strip with the active tab underlined.
A `vertical` strip always has the line look.
-}
boxed : Attribute key msg
boxed =
    Attribute (\config -> { config | boxed = True })


{-| Lower tabs with smaller text, for tight spaces.
-}
small : Attribute key msg
small =
    Attribute (\config -> { config | small = True })


{-| The tabs share the full width of the strip equally, instead of being only as
wide as their labels. No effect on a `vertical` strip.
-}
fill : Attribute key msg
fill =
    Attribute (\config -> { config | fill = True })


{-| Stacks the tabs from top to bottom, with the panel beside them, for settings pages
and detail panes. The arrow keys are Up and Down, and the list says
`aria-orientation="vertical"`. The default is a horizontal strip.
-}
vertical : Attribute key msg
vertical =
    Attribute (\config -> { config | vertical = True })


{-| Manual activation: the arrow keys only move the focus, and Enter or Space
selects the focused tab. Without it the arrows move and select in one go, which
is right when switching is cheap. Use `manual` when switching is expensive, such
as a tab that loads data. The active tab stays the one in the Tab order.
-}
manual : Attribute key msg
manual =
    Attribute (\config -> { config | manual = True })


{-| The accessible name of the tab list: what the tabs switch between, for example
"Order sections". There is no default; without it the list has no name.
-}
ariaLabel : String -> Attribute key msg
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Just value })


{-| The language the counts of `withCount` are written in (digit grouping). Default
`Locale.en`.
-}
locale : Locale -> Attribute key msg
locale value =
    Attribute (\config -> { config | locale = value })



-- STATE


{-| The state of a tab strip: which tab is active. Make one with `init`, keep it in your
model, and give it to `view`.
-}
type State key
    = State
        { id : String
        , active : key
        }


{-| A tab strip with one tab active. The first argument is a DOM id that must be
unique on the page: it is the prefix of the ids of the tabs and of the panel. The second
is the key of the tab that is active at first.

    Tabs.init "order-tabs" Overview

-}
init : String -> key -> State key
init id initial =
    State { id = id, active = initial }


{-| The key of the active tab: the one given to `init` or `setActive`, or the one the
user picked. Compare it before and after `update` to react when the user picks another
tab.

    Tabs.active tabs /= Tabs.active model.tabs

-}
active : State key -> key
active (State state) =
    state.active


{-| Selects a tab from the application, for instance when the route changes. It
does not move keyboard focus. When the key belongs to no enabled tab, `view` shows the
first enabled tab as active.
-}
setActive : key -> State key -> State key
setActive key (State state) =
    State { state | active = key }


{-| The messages of a tab strip: a tab was clicked, an arrow key was pressed. Wrap it in
a constructor of your own message type (`TabsMsg (Tabs.Msg Section)`), pass that
constructor to `view`, and hand the messages you get back to `update`.
-}
type Msg key
    = Select key
    | Move key Int
    | FocusOnly Int
    | Noop


{-| Selects tabs and moves keyboard focus between them. The `Cmd` moves the focus
to the tab the arrow keys reached, so map it with your message constructor.
-}
update : Msg key -> State key -> ( State key, Cmd (Msg key) )
update msg (State state) =
    case msg of
        Select key ->
            ( State { state | active = key }, Cmd.none )

        Move key index ->
            ( State { state | active = key }
            , Internal.focus (tabId state.id index) Noop
            )

        FocusOnly index ->
            ( State state, Internal.focus (tabId state.id index) Noop )

        Noop ->
            ( State state, Cmd.none )


tabId : String -> Int -> String
tabId id index =
    id ++ "-tab-" ++ String.fromInt index


panelId : String -> Int -> String
panelId id index =
    id ++ "-panel-" ++ String.fromInt index



-- VIEW


{-| The tab list, and under it (beside it, with `vertical`) the panel of the active tab
when the tabs have panels. The first argument wraps the strip's `Msg` in your own message
type. When the active key belongs to no enabled tab, the first enabled tab is shown as
active, with its panel.
-}
view : (Msg key -> msg) -> List (Attribute key msg) -> State key -> Html msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes

        indexed =
            List.indexedMap Tuple.pair config.tabs

        enabled =
            List.filter (\( _, Tab data ) -> not data.disabled) indexed

        activeIndex =
            case List.filter (\( _, Tab data ) -> data.key == state.active) enabled of
                ( index, _ ) :: _ ->
                    Just index

                [] ->
                    List.head enabled |> Maybe.map Tuple.first

        activeTab =
            activeIndex |> Maybe.andThen (\index -> indexed |> List.drop index |> List.head)

        hasPanels =
            List.any (\(Tab data) -> data.panel /= Nothing) config.tabs

        strip =
            Html.div
                [ Internal.cls
                    [ "klar-tabs"
                    , if config.boxed && not config.vertical then
                        "klar-tabs--boxed"

                      else
                        "klar-tabs--line"
                    , if config.small then
                        "klar-tabs--sm"

                      else
                        ""
                    , if config.fill && not config.vertical then
                        "klar-tabs--fill"

                      else
                        ""
                    , if config.vertical then
                        "klar-tabs--vertical"

                      else
                        ""
                    ]
                ]
                [ Html.div [ Internal.cls [ "klar-tabs__scroller" ] ]
                    [ Html.div
                        [ Internal.cls [ "klar-tabs__list" ]
                        , Attr.attribute "role" "tablist"
                        , Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
                        , Internal.attrIf config.vertical (Attr.attribute "aria-orientation" "vertical")
                        ]
                        (List.map (viewTab toMsg config state.id (List.map Tuple.first enabled) enabled activeIndex) indexed)
                    ]
                ]
    in
    if hasPanels then
        -- The same element tree whatever tab is active, so that focus on a tab
        -- survives the switch.
        Html.div
            [ Internal.cls
                [ "klar-tabs-layout"
                , if config.vertical then
                    "klar-tabs-layout--vertical"

                  else
                    ""
                ]
            ]
            [ strip
            , case activeTab of
                Just ( index, Tab data ) ->
                    case data.panel of
                        Just content ->
                            Html.div
                                [ Internal.cls [ "klar-tabs__panel" ]
                                , Attr.id (panelId state.id index)
                                , Attr.attribute "role" "tabpanel"
                                , Attr.attribute "aria-labelledby" (tabId state.id index)
                                , Attr.tabindex 0
                                ]
                                [ content () ]

                        Nothing ->
                            Html.text ""

                Nothing ->
                    Html.text ""
            ]

    else
        strip


viewTab : (Msg key -> msg) -> Config key msg -> String -> List Int -> List ( Int, Tab key msg ) -> Maybe Int -> ( Int, Tab key msg ) -> Html msg
viewTab toMsg config id enabledIndexes enabled activeIndex ( index, Tab data ) =
    let
        isActive =
            activeIndex == Just index

        move ( target, Tab targetData ) =
            if config.manual then
                toMsg (FocusOnly target)

            else
                toMsg (Move targetData.key target)

        neighbour offset =
            case indexOf index enabledIndexes of
                Just position ->
                    enabled |> List.drop (modBy (List.length enabled) (position + offset)) |> List.head

                Nothing ->
                    Nothing

        ( previousKey, nextKey ) =
            if config.vertical then
                ( "ArrowUp", "ArrowDown" )

            else
                ( "ArrowLeft", "ArrowRight" )

        keys =
            List.filterMap identity
                [ neighbour 1 |> Maybe.map (\target -> ( nextKey, move target ))
                , neighbour -1 |> Maybe.map (\target -> ( previousKey, move target ))
                , List.head enabled |> Maybe.map (\target -> ( "Home", move target ))
                , List.head (List.reverse enabled) |> Maybe.map (\target -> ( "End", move target ))
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
        , Attr.id (tabId id index)
        , Attr.type_ "button"
        , Attr.attribute "role" "tab"
        , Attr.attribute "aria-selected"
            (if isActive then
                "true"

             else
                "false"
            )
        , Internal.attrIf (isActive && data.panel /= Nothing) (Attr.attribute "aria-controls" (panelId id index))

        -- the one tab in the Tab order: the active one, also in manual mode
        , Attr.tabindex
            (if isActive then
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
            (\n -> Html.span [ Internal.cls [ "klar-tabs__count", "klar-tabular" ] ] [ Html.text (Format.int config.locale n) ])
            data.count
        ]


indexOf : Int -> List Int -> Maybe Int
indexOf target list =
    list
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, value ) -> value == target)
        |> List.head
        |> Maybe.map Tuple.first
