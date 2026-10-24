module Klar.SideNav exposing
    ( view
    , Entry, item, group, section, rule, withIcon, withCount, withBadge, disabledItem
    , Attribute, entries, current, collapsed, ariaLabel, onSelect, locale
    , State, init, isExpanded, expandGroup, collapseGroup, reveal, focusLink, focusCurrent, Msg, update
    )

{-| Vertical navigation for the sidebar of an application: sections, links with
icons and counts, and groups that open and close.

Use when: the sidebar needs vertical navigation with sections, links, counts and groups that open and close.
Do not use when: you need tabs inside a page (use `Klar.Tabs`) or the path to the current page (use `Klar.Breadcrumbs`).
Quick path: `item`, `section`, `withIcon`, `entries`; the state, `init`, `update`, `view` and `reveal`, belong to the shell

**In an application, `Klar.AppShell` holds the state and the messages of the side menu**: you write the
entries (`item`, `withIcon`, with the [Klar.Ids](Klar-Ids) of your page type) and give `AppShell.sideNav ShellMsg [ SideNav.entries menu ] model.shell` to the shell's
`sidebar`. Do not add a `SideNav.State` of your own beside it. The wiring below is for a side menu
without the shell (a gallery, a drawer of your own).

    import Klar.Icon as Icon
    import Klar.Ids as Ids
    import Klar.SideNav as SideNav

    -- model: sideNav : SideNav.State String
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

    menu : List (SideNav.Entry String msg)
    menu =
        [ SideNav.section "Workspace"
            [ SideNav.item Ids.string { key = "orders", label = "Orders", href = "#/orders" }
                |> SideNav.withIcon Icon.clipboardCheck
                |> SideNav.withCount 12
            , SideNav.item Ids.string { key = "customers", label = "Customers", href = "#/customers" }
                |> SideNav.withIcon Icon.users
            , SideNav.group Ids.string { key = "reports", label = "Reports" }
                [ SideNav.item Ids.string { key = "reports-monthly", label = "Monthly report", href = "#/reports/monthly" }
                , SideNav.item Ids.string { key = "reports-exports", label = "Exports", href = "#/reports/exports" }
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
`reveal`). With the shell, `AppShell.setPage` does this. A side menu of your own calls
`reveal` with the current key when the application starts and whenever the route changes
from somewhere else (the browser's back button, a link
in the page), so the current link is never hidden inside a closed group.

`collapsed` shows icons only. The labels stay in the page for screen readers and
every link has a `title` tooltip. A group then opens as a flyout to the right of
its icon while it has the mouse or the keyboard focus. With
[Klar.AppShell](Klar-AppShell)'s state the shell keeps this flag itself (its toggle flips it);
on narrow screens the sidebar is a drawer and always shows labels.

Keyboard: Tab moves between links as usual. Arrow Up and Down also move to the
previous and next visible entry, Home and End to the first and last. Disabled
links are skipped. The menu is a `nav` landmark, named by `ariaLabel`
("Main menu" by default).


# View

@docs view


# Keys

Every link and group has a key. It is a value of your own type (a `Page`, a
`ReportId`), so a misspelled key is a compile error. Say once how it is written
as text, once, as a [Klar.Ids](Klar-Ids); the menu is then typed by it
(`SideNav.State Page`). The text is used for the DOM ids of the links, so give every key
its own text.

    pageIds : Ids Page

    -- import Klar.Ids as Ids exposing (Ids)
    pageIds =
        Ids.make { toKey = pageToString, fromKey = pageFromString }


# Entries

@docs Entry, item, group, section, rule, withIcon, withCount, withBadge, disabledItem


# Attributes

@docs Attribute, entries, current, collapsed, ariaLabel, onSelect, locale


# State

@docs State, init, isExpanded, expandGroup, collapseGroup, reveal, focusLink, focusCurrent, Msg, update

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Icon as Icon exposing (Icon)
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)


textOf : Ids key -> key -> String
textOf =
    Ids.toKey



-- ENTRIES


{-| One line of the menu: a link, a group of links, a captioned section or a thin
rule. Make entries with `item`, `group`, `section` and `rule`, and refine links
and groups with `withIcon`, `withCount`, `withBadge` and `disabledItem`. The
`msg` is the message type of the badges added with `withBadge`.
-}
type Entry key msg
    = LinkEntry (LinkData key msg)
    | GroupEntry (GroupData key msg)
    | SectionEntry String (List (Entry key msg))
    | RuleEntry


type alias LinkData key msg =
    { key : String
    , value : key
    , label : String
    , href : String
    , icon : Maybe Icon
    , count : Maybe Int
    , badge : Maybe (Html msg)
    , disabled : Bool
    }


type alias GroupData key msg =
    { key : String
    , value : key
    , label : String
    , icon : Maybe Icon
    , count : Maybe Int
    , badge : Maybe (Html msg)
    , children : List (Entry key msg)
    }


{-| A link. The `key` identifies the entry (see `current` and `reveal`) and must
be unique in the menu, the `label` is its text, and the `href` is where it goes
(`#/path` for navigation inside a single page application).

    SideNav.item Ids.string { key = "orders", label = "Orders", href = "#/orders" }

-}
item : Ids key -> { key : key, label : String, href : String } -> Entry key msg
item k options =
    LinkEntry
        { key = textOf k options.key
        , value = options.key
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

    SideNav.group Ids.string
        { key = "reports", label = "Reports" }
        [ SideNav.item Ids.string { key = "reports-monthly", label = "Monthly report", href = "#/reports/monthly" } ]

-}
group : Ids key -> { key : key, label : String } -> List (Entry key msg) -> Entry key msg
group k options children =
    GroupEntry
        { key = textOf k options.key
        , value = options.key
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
section : String -> List (Entry key msg) -> Entry key msg
section heading children =
    SectionEntry heading children


{-| A thin line between entries (`role="separator"`).
-}
rule : Entry key msg
rule =
    RuleEntry


{-| An icon before the label of a link or a group; any other entry is left
unchanged. Give every top-level entry one: the collapsed menu shows nothing else.
-}
withIcon : Icon -> Entry key msg -> Entry key msg
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
withCount : Int -> Entry key msg -> Entry key msg
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
withBadge : Html msg -> Entry key msg -> Entry key msg
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
disabledItem : Entry key msg -> Entry key msg
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
type Attribute key msg
    = Attribute (Config key msg -> Config key msg)


type alias Config key msg =
    { entries : List (Entry key msg)
    , current : Maybe key
    , collapsed : Bool
    , ariaLabel : Maybe String
    , onSelect : Maybe (key -> msg)
    , locale : Locale
    }


configure : List (Attribute key msg) -> Config key msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { entries = []
        , current = Nothing
        , collapsed = False
        , ariaLabel = Nothing
        , onSelect = Nothing
        , locale = Locale.default
        }
        attributes


{-| The menu: sections, links and groups, from top to bottom. Without entries the
menu is empty.
-}
entries : List (Entry key msg) -> Attribute key msg
entries value =
    Attribute (\config -> { config | entries = value })


{-| The key of the link that is the current page. That link gets
`aria-current="page"` and the current look, and a closed group that contains it
is marked too. By default no entry is current.
-}
current : key -> Attribute key msg
current value =
    Attribute (\config -> { config | current = Just value })


{-| Shows icons only: the labels stay in the page for screen readers, counts
become small dots, badges are hidden and a group opens as a flyout. Default
`False`. With [Klar.AppShell](Klar-AppShell)'s state the shell sets it; a hand-wired
shell passes the same flag to `AppShell.sidebarCollapsed`.
-}
collapsed : Bool -> Attribute key msg
collapsed value =
    Attribute (\config -> { config | collapsed = value })


{-| The accessible name of the `nav` landmark. Default "Main menu" (in the language
of `locale`).
-}
ariaLabel : String -> Attribute key msg
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
onSelect : (key -> msg) -> Attribute key msg
onSelect toMsg =
    Attribute (\config -> { config | onSelect = Just toMsg })


{-| The language of the built-in text, which is the default name of the `nav`
landmark. Default `Locale.en`.
-}
locale : Locale -> Attribute key msg
locale value =
    Attribute (\config -> { config | locale = value })



-- STATE


{-| The state of a menu: which groups are open. Make one with `init`, keep it in
your model, and give it to `view`.
-}
type State key
    = State
        { id : String
        , expanded : List String
        , revealed : Maybe String
        }


{-| A menu with every group closed. The id must be unique on the page: it becomes
the DOM id of the `nav` element and the prefix of the ids of the links.

    SideNav.init "main-nav"

-}
init : String -> State key
init id =
    State { id = id, expanded = [], revealed = Nothing }


{-| Whether the group with this key is open in the state.
-}
isExpanded : Ids key -> key -> State key -> Bool
isExpanded k key (State state) =
    List.member (textOf k key) state.expanded


{-| Opens the group with this key. Does nothing when it is already open.
-}
expandGroup : Ids key -> key -> State key -> State key
expandGroup k value state =
    expandText (textOf k value) state


expandText : String -> State key -> State key
expandText key (State state) =
    if List.member key state.expanded then
        State state

    else
        State { state | expanded = key :: state.expanded }


{-| Closes the group with this key. Does nothing when it is already closed.
-}
collapseGroup : Ids key -> key -> State key -> State key
collapseGroup k value state =
    collapseText (textOf k value) state


collapseText : String -> State key -> State key
collapseText key (State state) =
    State { state | expanded = List.filter (\other -> other /= key) state.expanded }


{-| Opens every group that contains the entry with this key, groups inside groups
included, so that the entry is visible; other open groups stay open. Pass the
same entries you give to `entries`, and call it when the application starts and
when the route changes from somewhere else. The state also remembers this entry as
the current one, for `focusCurrent`.

    SideNav.reveal "reports-monthly" menu model.sideNav

-}
reveal : key -> List (Entry key msg) -> State key -> State key
reveal key menu state =
    List.foldl expandText (remember key menu state) (ancestors key menu)


remember : key -> List (Entry key msg) -> State key -> State key
remember key menu (State state) =
    State { state | revealed = linkText key menu }


linkText : key -> List (Entry key msg) -> Maybe String
linkText target menu =
    menu
        |> List.filterMap
            (\entry ->
                case entry of
                    LinkEntry data ->
                        if data.value == target then
                            Just data.key

                        else
                            Nothing

                    GroupEntry data ->
                        linkText target data.children

                    SectionEntry _ children ->
                        linkText target children

                    RuleEntry ->
                        Nothing
            )
        |> List.head


ancestors : key -> List (Entry key msg) -> List String
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


containsKey : key -> List (Entry key msg) -> Bool
containsKey target menu =
    List.any
        (\entry ->
            case entry of
                LinkEntry data ->
                    data.value == target

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

    SideNav.focusLink Ids.string "orders" model.sideNav NoOp

-}
focusLink : Ids key -> key -> State key -> msg -> Cmd msg
focusLink k key (State state) done =
    Internal.focus (linkId state.id (textOf k key)) done


{-| Moves keyboard focus to the link that `reveal` was last called with, the current
page, without needing its key: `AppShell` uses it when the sidebar drawer opens.
Does nothing before `reveal`, or when the link is not on the page. The message is sent
when it is done.
-}
focusCurrent : State key -> msg -> Cmd msg
focusCurrent (State state) done =
    case state.revealed of
        Just text ->
            Internal.focus (linkId state.id text) done

        Nothing ->
            Cmd.none


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
update : Msg -> State key -> ( State key, Cmd Msg )
update msg ((State state) as currentState) =
    case msg of
        ToggleGroup key ->
            if List.member key state.expanded then
                ( collapseText key currentState, Cmd.none )

            else
                ( expandText key currentState, Cmd.none )

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


type alias Context key msg =
    { toMsg : Msg -> msg
    , config : Config key msg
    , id : String
    , expanded : List String
    , focusables : List String
    }


{-| The menu, as a `nav` landmark. The first argument wraps the menu's `Msg` in
your own message type. Put the result in `AppShell.sidebar` or in any column of
your own.
-}
view : (Msg -> msg) -> List (Attribute key msg) -> State key -> Html msg
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
focusableIds : Config key msg -> String -> List String -> List (Entry key msg) -> List String
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
viewList : Context key msg -> Int -> String -> List (Entry key msg) -> Html msg
viewList context depth path menu =
    Html.ul [ Internal.cls [ "klar-side-nav__list" ] ]
        (viewEntries context depth path menu)


viewEntries : Context key msg -> Int -> String -> List (Entry key msg) -> List (Html msg)
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
viewEntry : Context key msg -> Int -> String -> Entry key msg -> Html msg
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


viewLink : Context key msg -> Int -> LinkData key msg -> Html msg
viewLink context depth data =
    let
        isCurrent =
            Just data.value == context.config.current

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
                , Internal.attrMaybe (\toMsg -> onPlainClick (toMsg data.value)) context.config.onSelect
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


viewGroup : Context key msg -> Int -> String -> GroupData key msg -> Html msg
viewGroup context depth path data =
    let
        isOpen =
            List.member data.key context.expanded

        domId =
            groupId context.id data.key

        listId =
            childrenId context.id data.key

        holdsCurrent =
            context.config.current |> Maybe.map (\target -> containsKey target data.children) |> Maybe.withDefault False

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


arrowKeys : Context key msg -> String -> Html.Attribute msg
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
