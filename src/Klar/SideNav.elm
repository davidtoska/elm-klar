module Klar.SideNav exposing
    ( view
    , Entry, item, group, section, rule, withIcon, withCount, withBadge, disabledItem
    , Attribute, entries, current, collapsed, ariaLabel, onSelect, locale
    , State, init, isExpanded, expandGroup, collapseGroup, reveal, focusLink, Msg, update
    )

{-| Vertical navigation for the sidebar of an application: sections, links with
icons and counts, and groups that open and close.

    import Klar.Icon as Icon
    import Klar.SideNav as SideNav

    -- model: sideNav : SideNav.State
    -- init:  SideNav.init "main-nav" |> SideNav.reveal "reports-monthly" menu

    -- update
    SideNavMsg m ->
        let
            ( sideNav, cmd ) =
                SideNav.update m model.sideNav
        in
        ( { model | sideNav = sideNav }, Cmd.map SideNavMsg cmd )

    -- view
    SideNav.view SideNavMsg
        [ SideNav.entries menu
        , SideNav.current (routeKey model.route)
        , SideNav.collapsed model.sidebarCollapsed
        ]
        model.sideNav

    menu : List (SideNav.Entry msg)
    menu =
        [ SideNav.section "Workspace"
            [ SideNav.item { key = "orders", label = "Orders", href = "#/orders" }
                |> SideNav.withIcon Icon.clipboardCheck
                |> SideNav.withCount 12
            , SideNav.item { key = "customers", label = "Customers", href = "#/customers" }
                |> SideNav.withIcon Icon.users
            , SideNav.group { key = "reports", label = "Reports" }
                [ SideNav.item { key = "reports-monthly", label = "Monthly report", href = "#/reports/monthly" }
                , SideNav.item { key = "reports-exports", label = "Exports", href = "#/reports/exports" }
                ]
                |> SideNav.withIcon Icon.barChart
            ]
        ]

Links are real links (`href`), so routing, middle click and "open in new tab"
work as usual. The application says which entry is current by its `key`; that
link gets `aria-current="page"`, a blue tint and an accent bar on the left. A
closed group that contains the current entry is marked too.

**Groups are stateful**: whether a group is open lives in the `State` (a click
toggles it, and the application can call `expandGroup`, `collapseGroup` and
`reveal`). Call `reveal` with the current key when the application starts and
whenever the route changes from somewhere else (the browser's back button, a link
in the page), so the current link is never hidden inside a closed group.

`collapsed` shows icons only. The labels stay in the page for screen readers and
every link has a `title` tooltip. A group then opens as a flyout to the right of
its icon while it has the mouse or the keyboard focus. Inside the application
shell, [Klar.AppShell](Klar-AppShell), pass the same flag to
`AppShell.sidebarCollapsed`; the shell ignores it on narrow screens, where the
sidebar is a drawer and always shows labels.

Keyboard: Tab moves between links as usual. Arrow Up and Down also move to the
previous and next visible entry, Home and End to the first and last. Disabled
links are skipped. The menu is a `nav` landmark, named by `ariaLabel`
("Main menu" by default).


# View

@docs view


# Entries

@docs Entry, item, group, section, rule, withIcon, withCount, withBadge, disabledItem


# Attributes

@docs Attribute, entries, current, collapsed, ariaLabel, onSelect, locale


# State

@docs State, init, isExpanded, expandGroup, collapseGroup, reveal, focusLink, Msg, update

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)



-- ENTRIES


{-| One line of the menu: a link, a group of links, a captioned section or a thin
rule. Make entries with `item`, `group`, `section` and `rule`, and refine links
and groups with `withIcon`, `withCount`, `withBadge` and `disabledItem`. The
`msg` is the message type of the badges added with `withBadge`.
-}
type Entry msg
    = LinkEntry (LinkData msg)
    | GroupEntry (GroupData msg)
    | SectionEntry String (List (Entry msg))
    | RuleEntry


type alias LinkData msg =
    { key : String
    , label : String
    , href : String
    , icon : Maybe Icon
    , count : Maybe Int
    , badge : Maybe (Html msg)
    , disabled : Bool
    }


type alias GroupData msg =
    { key : String
    , label : String
    , icon : Maybe Icon
    , count : Maybe Int
    , badge : Maybe (Html msg)
    , children : List (Entry msg)
    }


{-| A link. The `key` identifies the entry (see `current` and `reveal`) and must
be unique in the menu, the `label` is its text, and the `href` is where it goes
(`#/path` for navigation inside a single page application).

    SideNav.item { key = "orders", label = "Orders", href = "#/orders" }

-}
item : { key : String, label : String, href : String } -> Entry msg
item options =
    LinkEntry
        { key = options.key
        , label = options.label
        , href = options.href
        , icon = Nothing
        , count = Nothing
        , badge = Nothing
        , disabled = False
        }


{-| A group of entries that opens and closes; groups can contain groups. The `key`
identifies the group in the state (`isExpanded`, `expandGroup` and the others) and
must be unique in the menu. A group is a button, not a link, so it has no `href`.

    SideNav.group { key = "reports", label = "Reports" }
        [ SideNav.item { key = "reports-monthly", label = "Monthly report", href = "#/reports/monthly" } ]

-}
group : { key : String, label : String } -> List (Entry msg) -> Entry msg
group options children =
    GroupEntry
        { key = options.key
        , label = options.label
        , icon = Nothing
        , count = Nothing
        , badge = Nothing
        , children = children
        }


{-| A captioned block of entries, such as "Workspace" (shown in capitals, as a
small `h2` heading). An empty caption gives a block without a heading. When the
menu is collapsed the caption is replaced by a thin line.

    SideNav.section "Workspace" [ ordersLink, customersLink ]

-}
section : String -> List (Entry msg) -> Entry msg
section heading children =
    SectionEntry heading children


{-| A thin line between entries (`role="separator"`).
-}
rule : Entry msg
rule =
    RuleEntry


{-| An icon before the label of a link or a group; any other entry is left
unchanged. Give every top-level entry one: the collapsed menu shows nothing else.
-}
withIcon : Icon -> Entry msg -> Entry msg
withIcon icon entry =
    case entry of
        LinkEntry data ->
            LinkEntry { data | icon = Just icon }

        GroupEntry data ->
            GroupEntry { data | icon = Just icon }

        other ->
            other


{-| A number pill after the label of a link or a group, such as the number of open
orders; any other entry is left unchanged. It reads "99+" above 99, and the exact
number is in the tooltip. In the collapsed menu it becomes a small dot.
-}
withCount : Int -> Entry msg -> Entry msg
withCount n entry =
    case entry of
        LinkEntry data ->
            LinkEntry { data | count = Just n }

        GroupEntry data ->
            GroupEntry { data | count = Just n }

        other ->
            other


{-| Any badge after the label of a link or a group, for example
`Badge.view [ Badge.tone Warning ] "New"`; any other entry is left unchanged. The
badge is hidden in the collapsed menu.
-}
withBadge : Html msg -> Entry msg -> Entry msg
withBadge badge entry =
    case entry of
        LinkEntry data ->
            LinkEntry { data | badge = Just badge }

        GroupEntry data ->
            GroupEntry { data | badge = Just badge }

        other ->
            other


{-| Makes a link visible but not usable, for a page the user lacks access to or a
feature that is not ready. It is drawn muted, marked `aria-disabled`, and skipped
by Tab and the arrow keys. Only links can be disabled: a group, a section or a
rule is left unchanged.
-}
disabledItem : Entry msg -> Entry msg
disabledItem entry =
    case entry of
        LinkEntry data ->
            LinkEntry { data | disabled = True }

        other ->
            other



-- ATTRIBUTES


{-| A setting of the menu. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones. The `msg` is your message type,
used by `onSelect` and by the badges in the entries.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { entries : List (Entry msg)
    , current : String
    , collapsed : Bool
    , ariaLabel : Maybe String
    , onSelect : Maybe (String -> msg)
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { entries = []
        , current = ""
        , collapsed = False
        , ariaLabel = Nothing
        , onSelect = Nothing
        , locale = Locale.default
        }
        attributes


{-| The menu: sections, links and groups, from top to bottom. Without entries the
menu is empty.
-}
entries : List (Entry msg) -> Attribute msg
entries value =
    Attribute (\config -> { config | entries = value })


{-| The key of the link that is the current page. That link gets
`aria-current="page"` and the current look, and a closed group that contains it
is marked too. By default no entry is current.
-}
current : String -> Attribute msg
current value =
    Attribute (\config -> { config | current = value })


{-| Shows icons only: the labels stay in the page for screen readers, counts
become small dots, badges are hidden and a group opens as a flyout. Default
`False`. Inside [Klar.AppShell](Klar-AppShell) pass the same flag to
`AppShell.sidebarCollapsed`.
-}
collapsed : Bool -> Attribute msg
collapsed value =
    Attribute (\config -> { config | collapsed = value })


{-| The accessible name of the `nav` landmark. Default "Main menu" (in the language
of `locale`).
-}
ariaLabel : String -> Attribute msg
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Just value })


{-| Also tells the application which link was used, by calling the function with
the `key` of the entry. It reacts to an ordinary click or a keyboard activation,
not to a click with Ctrl, Cmd, Shift or Alt or with another mouse button (the
browser handles those itself, for example by opening a new tab). The link still
navigates, so this is only useful when the application does not read the route to
decide what is current.

    SideNav.onSelect PageSelected

-}
onSelect : (String -> msg) -> Attribute msg
onSelect toMsg =
    Attribute (\config -> { config | onSelect = Just toMsg })


{-| The language of the built-in text, which is the default name of the `nav`
landmark. Default `Locale.en`.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- STATE


{-| The state of a menu: which groups are open. Make one with `init`, keep it in
your model, and give it to `view`.
-}
type State
    = State
        { id : String
        , expanded : List String
        }


{-| A menu with every group closed. The id must be unique on the page: it becomes
the DOM id of the `nav` element and the prefix of the ids of the links.

    SideNav.init "main-nav"

-}
init : String -> State
init id =
    State { id = id, expanded = [] }


{-| Whether the group with this key is open in the state.
-}
isExpanded : String -> State -> Bool
isExpanded key (State state) =
    List.member key state.expanded


{-| Opens the group with this key. Does nothing when it is already open.
-}
expandGroup : String -> State -> State
expandGroup key (State state) =
    if List.member key state.expanded then
        State state

    else
        State { state | expanded = key :: state.expanded }


{-| Closes the group with this key. Does nothing when it is already closed.
-}
collapseGroup : String -> State -> State
collapseGroup key (State state) =
    State { state | expanded = List.filter (\other -> other /= key) state.expanded }


{-| Opens every group that contains the entry with this key, groups inside groups
included, so that the entry is visible; other open groups stay open. Pass the
same entries you give to `entries`, and call it when the application starts and
when the route changes from somewhere else.

    SideNav.reveal "reports-monthly" menu model.sideNav

-}
reveal : String -> List (Entry msg) -> State -> State
reveal key menu state =
    List.foldl expandGroup state (ancestors key menu)


ancestors : String -> List (Entry msg) -> List String
ancestors target menu =
    List.concatMap
        (\entry ->
            case entry of
                GroupEntry data ->
                    if containsKey target data.children then
                        data.key :: ancestors target data.children

                    else
                        []

                SectionEntry _ children ->
                    ancestors target children

                _ ->
                    []
        )
        menu


containsKey : String -> List (Entry msg) -> Bool
containsKey target menu =
    List.any
        (\entry ->
            case entry of
                LinkEntry data ->
                    data.key == target

                GroupEntry data ->
                    containsKey target data.children

                SectionEntry _ children ->
                    containsKey target children

                RuleEntry ->
                    False
        )
        menu


{-| Moves keyboard focus to the link with this key: the current page, when the
sidebar opens as a drawer. Does nothing if that link is not in the page (inside a
closed group, say). The message is sent when it is done, whether the link was
found or not, so use one that changes nothing.

    SideNav.focusLink "orders" model.sideNav NoOp

-}
focusLink : String -> State -> msg -> Cmd msg
focusLink key (State state) done =
    Internal.focus (linkId state.id key) done


{-| The messages of a menu: a group was clicked, an arrow key was pressed. Wrap it
in a constructor of your own message type, pass that constructor to `view`, and
hand the messages you get back to `update`.
-}
type Msg
    = ToggleGroup String
    | Focus String
    | Noop


{-| Opens and closes groups and moves keyboard focus between the entries. The
`Cmd` does the focus move, so map it with your message constructor.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as currentState) =
    case msg of
        ToggleGroup key ->
            if isExpanded key currentState then
                ( collapseGroup key currentState, Cmd.none )

            else
                ( expandGroup key currentState, Cmd.none )

        Focus domId ->
            ( State state, Internal.focus domId Noop )

        Noop ->
            ( State state, Cmd.none )


linkId : String -> String -> String
linkId id key =
    id ++ "-link-" ++ Internal.sanitizeId key


groupId : String -> String -> String
groupId id key =
    id ++ "-group-" ++ Internal.sanitizeId key


childrenId : String -> String -> String
childrenId id key =
    id ++ "-children-" ++ Internal.sanitizeId key



-- VIEW


type alias Context msg =
    { toMsg : Msg -> msg
    , config : Config msg
    , id : String
    , expanded : List String
    , focusables : List String
    }


{-| The menu, as a `nav` landmark. The first argument wraps the menu's `Msg` in
your own message type. Put the result in `AppShell.sidebar` or in any column of
your own.
-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State state) =
    let
        config =
            configure attributes

        context =
            { toMsg = toMsg
            , config = config
            , id = state.id
            , expanded = state.expanded
            , focusables = focusableIds config state.id state.expanded config.entries
            }
    in
    Html.nav
        [ Internal.cls
            [ "klar-side-nav"
            , if config.collapsed then
                "klar-side-nav--collapsed"

              else
                ""
            ]
        , Attr.id state.id
        , Attr.attribute "aria-label"
            (Maybe.withDefault (Locale.pick config.locale { nb = "Hovedmeny", en = "Main menu" }) config.ariaLabel)
        ]
        [ viewList context 0 "" config.entries ]


{-| The DOM ids of everything the arrow keys can reach, in visual order.
-}
focusableIds : Config msg -> String -> List String -> List (Entry msg) -> List String
focusableIds config id expanded menu =
    List.concatMap
        (\entry ->
            case entry of
                LinkEntry data ->
                    if data.disabled then
                        []

                    else
                        [ linkId id data.key ]

                GroupEntry data ->
                    groupId id data.key
                        :: (if List.member data.key expanded && not config.collapsed then
                                focusableIds config id expanded data.children

                            else
                                []
                           )

                SectionEntry _ children ->
                    focusableIds config id expanded children

                RuleEntry ->
                    []
        )
        menu


{-| `path` is the place of the entries in the menu: "" for the top level, "2" for
the children of the third entry, "2-0" for those of its first child, and so on.
-}
viewList : Context msg -> Int -> String -> List (Entry msg) -> Html msg
viewList context depth path menu =
    Html.ul [ Internal.cls [ "klar-side-nav__list" ] ]
        (viewEntries context depth path menu)


viewEntries : Context msg -> Int -> String -> List (Entry msg) -> List (Html msg)
viewEntries context depth path menu =
    List.indexedMap (\index entry -> viewEntry context depth (childPath path index) entry) menu


childPath : String -> Int -> String
childPath path index =
    if path == "" then
        String.fromInt index

    else
        path ++ "-" ++ String.fromInt index


{-| `path` is the place of this entry in the menu (see `viewList`). It makes the
ids that are not made from a key unique, also for two sections with the same
caption.
-}
viewEntry : Context msg -> Int -> String -> Entry msg -> Html msg
viewEntry context depth path entry =
    case entry of
        LinkEntry data ->
            viewLink context depth data

        GroupEntry data ->
            viewGroup context depth path data

        SectionEntry heading children ->
            let
                headingId =
                    context.id ++ "-section-" ++ path
            in
            Html.li [ Internal.cls [ "klar-side-nav__section" ] ]
                [ Internal.viewIf (heading /= "")
                    (Html.h2 [ Internal.cls [ "klar-side-nav__heading" ], Attr.id headingId ] [ Html.text heading ])
                , Html.ul
                    [ Internal.cls [ "klar-side-nav__list" ]
                    , Internal.attrIf (heading /= "") (Attr.attribute "aria-labelledby" headingId)
                    ]
                    (viewEntries context depth path children)
                ]

        RuleEntry ->
            Html.li [ Internal.cls [ "klar-side-nav__rule" ], Attr.attribute "role" "separator" ] []


depthStyle : Int -> Html.Attribute msg
depthStyle depth =
    Internal.styleVars [ ( "--klar-depth", String.fromInt depth ) ]


viewLink : Context msg -> Int -> LinkData msg -> Html msg
viewLink context depth data =
    let
        isCurrent =
            data.key == context.config.current

        domId =
            linkId context.id data.key

        classes =
            [ "klar-side-nav__link"
            , if depth == 0 then
                "klar-side-nav__link--root"

              else
                "klar-side-nav__link--nested"
            , if isCurrent then
                "klar-side-nav__link--current"

              else
                ""
            , if data.disabled then
                "klar-side-nav__link--disabled"

              else
                ""
            ]

        content =
            [ Internal.viewMaybe (\icon -> Html.span [ Internal.cls [ "klar-side-nav__icon" ] ] [ Icon.view icon ]) data.icon
            , Html.span [ Internal.cls [ "klar-side-nav__label" ] ] [ Html.text data.label ]
            , viewAside data.count data.badge
            ]
    in
    Html.li [ Internal.cls [ "klar-side-nav__item" ] ]
        [ if data.disabled then
            Html.span
                [ Internal.cls classes
                , Attr.attribute "role" "link"
                , Attr.attribute "aria-disabled" "true"
                , Attr.title data.label
                , depthStyle depth
                ]
                content

          else
            Html.a
                [ Internal.cls classes
                , Attr.href data.href
                , Attr.id domId
                , Attr.title data.label
                , Internal.attrIf isCurrent (Attr.attribute "aria-current" "page")
                , Internal.attrMaybe (\toMsg -> onPlainClick (toMsg data.key)) context.config.onSelect
                , arrowKeys context domId
                , depthStyle depth
                ]
                content
        ]


viewAside : Maybe Int -> Maybe (Html msg) -> Html msg
viewAside count badge =
    case ( count, badge ) of
        ( Nothing, Nothing ) ->
            Html.text ""

        _ ->
            Html.span [ Internal.cls [ "klar-side-nav__aside" ] ]
                [ Internal.viewMaybe
                    (\n ->
                        Html.span
                            [ Internal.cls [ "klar-side-nav__count", "klar-tabular" ]
                            , Attr.title (String.fromInt n)
                            ]
                            [ Html.text
                                (if n > 99 then
                                    "99+"

                                 else
                                    String.fromInt n
                                )
                            ]
                    )
                    count
                , Internal.viewMaybe (\html -> Html.span [ Internal.cls [ "klar-side-nav__badge" ] ] [ html ]) badge
                ]


viewGroup : Context msg -> Int -> String -> GroupData msg -> Html msg
viewGroup context depth path data =
    let
        isOpen =
            List.member data.key context.expanded

        domId =
            groupId context.id data.key

        listId =
            childrenId context.id data.key

        holdsCurrent =
            containsKey context.config.current data.children

        -- A collapsed menu keeps the children in the page: they become the flyout.
        showChildren =
            isOpen || context.config.collapsed

        -- In the flyout the arrow keys move between the children of this group.
        childContext =
            if context.config.collapsed then
                { context | focusables = focusableIds context.config context.id context.expanded data.children }

            else
                context
    in
    Html.li
        [ Internal.cls
            [ "klar-side-nav__item"
            , "klar-side-nav__group"
            , "klar-anchor"
            , "klar-anchor--block"
            , if isOpen then
                "klar-side-nav__group--open"

              else
                ""
            , if holdsCurrent then
                "klar-side-nav__group--active"

              else
                ""
            ]
        ]
        [ Html.button
            [ Internal.cls
                [ "klar-side-nav__link"
                , "klar-side-nav__link--group"
                , if depth == 0 then
                    "klar-side-nav__link--root"

                  else
                    "klar-side-nav__link--nested"
                ]
            , Attr.id domId
            , Attr.type_ "button"
            , Attr.title data.label
            , Attr.attribute "aria-expanded"
                (if isOpen then
                    "true"

                 else
                    "false"
                )
            , Internal.attrIf showChildren (Attr.attribute "aria-controls" listId)
            , Events.onClick (context.toMsg (ToggleGroup data.key))
            , arrowKeys context domId
            , depthStyle depth
            ]
            [ Internal.viewMaybe (\icon -> Html.span [ Internal.cls [ "klar-side-nav__icon" ] ] [ Icon.view icon ]) data.icon
            , Html.span [ Internal.cls [ "klar-side-nav__label" ] ] [ Html.text data.label ]
            , viewAside data.count data.badge
            , Html.span [ Internal.cls [ "klar-side-nav__chevron" ] ] [ Icon.sized Icon.Small Icon.chevronRight ]
            ]
        , if showChildren then
            Html.ul
                [ Internal.cls [ "klar-side-nav__children", "klar-side-nav__list" ]
                , Attr.id listId
                , depthStyle (depth + 1)
                ]
                (Html.li [ Internal.cls [ "klar-side-nav__flyout-title" ], Attr.attribute "aria-hidden" "true" ] [ Html.text data.label ]
                    :: viewEntries childContext (depth + 1) path data.children
                )

          else
            Html.text ""
        ]


arrowKeys : Context msg -> String -> Html.Attribute msg
arrowKeys context domId =
    let
        ids =
            context.focusables

        position =
            ids
                |> List.indexedMap Tuple.pair
                |> List.filter (\( _, other ) -> other == domId)
                |> List.head
                |> Maybe.map Tuple.first

        at index =
            ids |> List.drop index |> List.head

        focus target =
            context.toMsg (Focus target)
    in
    Internal.onKeys
        (List.filterMap identity
            [ position |> Maybe.andThen (\i -> at (i + 1)) |> Maybe.map (\target -> ( "ArrowDown", focus target ))
            , position
                |> Maybe.andThen
                    (\i ->
                        if i > 0 then
                            at (i - 1)

                        else
                            Nothing
                    )
                |> Maybe.map (\target -> ( "ArrowUp", focus target ))
            , List.head ids |> Maybe.map (\target -> ( "Home", focus target ))
            , List.head (List.reverse ids) |> Maybe.map (\target -> ( "End", focus target ))
            ]
        )


{-| A click that is an ordinary left click: no Ctrl, Cmd, Shift or Alt (those open a
new tab or window) and no other mouse button.
-}
onPlainClick : msg -> Html.Attribute msg
onPlainClick msg =
    Events.on "click"
        (Decode.map5 (\ctrl meta shift alt button -> not ctrl && not meta && not shift && not alt && button == 0)
            (Decode.field "ctrlKey" Decode.bool)
            (Decode.field "metaKey" Decode.bool)
            (Decode.field "shiftKey" Decode.bool)
            (Decode.field "altKey" Decode.bool)
            (Decode.field "button" Decode.int)
            |> Decode.andThen
                (\plain ->
                    if plain then
                        Decode.succeed msg

                    else
                        Decode.fail "modified click"
                )
        )
