# Klar.SideNav

Vertical navigation for the sidebar of an application: sections, links with icons and counts, and groups that open and close.

Import: `import Klar.SideNav as SideNav` | Group: Navigation

Types: `Msg`, `Entry`, `State`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute key msg) -> State key -> Html msg

-- Entries
type Entry key msg  -- opaque: no constructors are exposed
item : Ids.Ids key -> { key : key, label : String, href : String } -> Entry key msg
group : Ids.Ids key -> { key : key, label : String } -> List (Entry key msg) -> Entry key msg
section : String -> List (Entry key msg) -> Entry key msg
rule : Entry key msg
withIcon : Icon.Icon -> Entry key msg -> Entry key msg
withCount : Int -> Entry key msg -> Entry key msg
withBadge : Html msg -> Entry key msg -> Entry key msg
disabledItem : Entry key msg -> Entry key msg

-- Attributes
type Attribute key msg  -- opaque: no constructors are exposed
entries : List (Entry key msg) -> Attribute key msg
current : key -> Attribute key msg
collapsed : Bool -> Attribute key msg
ariaLabel : String -> Attribute key msg
onSelect : (key -> msg) -> Attribute key msg
locale : Locale.Locale -> Attribute key msg

-- State
type State key  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State key
isExpanded : Ids.Ids key -> key -> State key -> Bool
expandGroup : Ids.Ids key -> key -> State key -> State key
collapseGroup : Ids.Ids key -> key -> State key -> State key
reveal : key -> List (Entry key msg) -> State key -> State key
focusLink : Ids.Ids key -> key -> State key -> msg -> Cmd msg
focusCurrent : State key -> msg -> Cmd msg
update : Msg -> State key -> ( State key, Cmd Msg )
```

## Documentation

Vertical navigation for the sidebar of an application: sections, links with
icons and counts, and groups that open and close.

Use when: the sidebar needs vertical navigation with sections, links, counts and groups that open and close.
Do not use when: you need tabs inside a page (use `Klar.Tabs`) or the path to the current page (use `Klar.Breadcrumbs`).
Quick path: `item`, `section`, `withIcon`, `entries`; the state, `init`, `update`, `view` and `reveal`, belong to the shell

**In an application, `Klar.AppShell` holds the state and the messages of the side menu**: you write the
entries (`item`, `withIcon`, with the [Klar.Ids](Klar.Ids.md) of your page type) and give `AppShell.sideNav ShellMsg [ SideNav.entries menu ] model.shell` to the shell's
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
[Klar.AppShell](Klar.AppShell.md)'s state the shell keeps this flag itself (its toggle flips it);
on narrow screens the sidebar is a drawer and always shows labels.

Keyboard: Tab moves between links as usual. Arrow Up and Down also move to the
previous and next visible entry, Home and End to the first and last. Disabled
links are skipped. The menu is a `nav` landmark, named by `ariaLabel`
("Main menu" by default).

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute key msg) -> State key -> Html msg
```

The menu, as a `nav` landmark. The first argument wraps the menu's `Msg` in
your own message type. Put the result in `AppShell.sidebar` or in any column of
your own.

## Keys

Every link and group has a key. It is a value of your own type (a `Page`, a
`ReportId`), so a misspelled key is a compile error. Say once how it is written
as text, once, as a [Klar.Ids](Klar.Ids.md); the menu is then typed by it
(`SideNav.State Page`). The text is used for the DOM ids of the links, so give every key
its own text.

    pageIds : Ids Page

    -- import Klar.Ids as Ids exposing (Ids)
    pageIds =
        Ids.make { toKey = pageToString, fromKey = pageFromString }

## Entries

### `Entry`

```elm
type Entry key msg  -- opaque: no constructors are exposed
```

One line of the menu: a link, a group of links, a captioned section or a thin
rule. Make entries with `item`, `group`, `section` and `rule`, and refine links
and groups with `withIcon`, `withCount`, `withBadge` and `disabledItem`. The
`msg` is the message type of the badges added with `withBadge`.

### `item`

```elm
item : Ids.Ids key -> { key : key, label : String, href : String } -> Entry key msg
```

A link. The `key` identifies the entry (see `current` and `reveal`) and must
be unique in the menu, the `label` is its text, and the `href` is where it goes
(`#/path` for navigation inside a single page application).

    SideNav.item Ids.string { key = "orders", label = "Orders", href = "#/orders" }

### `group`

```elm
group : Ids.Ids key -> { key : key, label : String } -> List (Entry key msg) -> Entry key msg
```

A group of entries that opens and closes; groups can contain groups. The `key`
identifies the group in the state (`isExpanded`, `expandGroup` and the others) and
must be unique in the menu. A group is a button, not a link, so it has no `href`.

    SideNav.group Ids.string
        { key = "reports", label = "Reports" }
        [ SideNav.item Ids.string { key = "reports-monthly", label = "Monthly report", href = "#/reports/monthly" } ]

### `section`

```elm
section : String -> List (Entry key msg) -> Entry key msg
```

A captioned block of entries, such as "Workspace" (shown in capitals, as a
small `h2` heading). An empty caption gives a block without a heading. When the
menu is collapsed the caption is replaced by a thin line.

    SideNav.section "Workspace" [ ordersLink, customersLink ]

### `rule`

```elm
rule : Entry key msg
```

A thin line between entries (`role="separator"`).

### `withIcon`

```elm
withIcon : Icon.Icon -> Entry key msg -> Entry key msg
```

An icon before the label of a link or a group; any other entry is left
unchanged. Give every top-level entry one: the collapsed menu shows nothing else.

### `withCount`

```elm
withCount : Int -> Entry key msg -> Entry key msg
```

A number pill after the label of a link or a group, such as the number of open
orders; any other entry is left unchanged. It reads "99+" above 99, and the exact
number is in the tooltip. In the collapsed menu it becomes a small dot.

### `withBadge`

```elm
withBadge : Html msg -> Entry key msg -> Entry key msg
```

Any badge after the label of a link or a group, for example
`Badge.view [ Badge.tone Warning ] "New"`; any other entry is left unchanged. The
badge is hidden in the collapsed menu.

### `disabledItem`

```elm
disabledItem : Entry key msg -> Entry key msg
```

Makes a link visible but not usable, for a page the user lacks access to or a
feature that is not ready. It is drawn muted, marked `aria-disabled`, and skipped
by Tab and the arrow keys. Only links can be disabled: a group, a section or a
rule is left unchanged.

## Attributes

### `Attribute`

```elm
type Attribute key msg  -- opaque: no constructors are exposed
```

A setting of the menu. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones. The `msg` is your message type,
used by `onSelect` and by the badges in the entries.

### `entries`

```elm
entries : List (Entry key msg) -> Attribute key msg
```

The menu: sections, links and groups, from top to bottom. Without entries the
menu is empty.

### `current`

```elm
current : key -> Attribute key msg
```

The key of the link that is the current page. That link gets
`aria-current="page"` and the current look, and a closed group that contains it
is marked too. By default no entry is current.

### `collapsed`

```elm
collapsed : Bool -> Attribute key msg
```

Shows icons only: the labels stay in the page for screen readers, counts
become small dots, badges are hidden and a group opens as a flyout. Default
`False`. With [Klar.AppShell](Klar.AppShell.md)'s state the shell sets it; a hand-wired
shell passes the same flag to `AppShell.sidebarCollapsed`.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute key msg
```

The accessible name of the `nav` landmark. Default "Main menu" (in the language
of `locale`).

### `onSelect`

```elm
onSelect : (key -> msg) -> Attribute key msg
```

Also tells the application which link was used, by calling the function with
the `key` of the entry. It reacts to an ordinary click or a keyboard activation,
not to a click with Ctrl, Cmd, Shift or Alt or with another mouse button (the
browser handles those itself, for example by opening a new tab). The link still
navigates, so this is only useful when the application does not read the route to
decide what is current.

    SideNav.onSelect PageSelected

### `locale`

```elm
locale : Locale.Locale -> Attribute key msg
```

The language of the built-in text, which is the default name of the `nav`
landmark. Default `Locale.en`.

## State

### `State`

```elm
type State key  -- opaque: no constructors are exposed
```

The state of a menu: which groups are open. Make one with `init`, keep it in
your model, and give it to `view`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of a menu: a group was clicked, an arrow key was pressed. Wrap it
in a constructor of your own message type, pass that constructor to `view`, and
hand the messages you get back to `update`.

### `init`

```elm
init : String -> State key
```

A menu with every group closed. The id must be unique on the page: it becomes
the DOM id of the `nav` element and the prefix of the ids of the links.

    SideNav.init "main-nav"

### `isExpanded`

```elm
isExpanded : Ids.Ids key -> key -> State key -> Bool
```

Whether the group with this key is open in the state.

### `expandGroup`

```elm
expandGroup : Ids.Ids key -> key -> State key -> State key
```

Opens the group with this key. Does nothing when it is already open.

### `collapseGroup`

```elm
collapseGroup : Ids.Ids key -> key -> State key -> State key
```

Closes the group with this key. Does nothing when it is already closed.

### `reveal`

```elm
reveal : key -> List (Entry key msg) -> State key -> State key
```

Opens every group that contains the entry with this key, groups inside groups
included, so that the entry is visible; other open groups stay open. Pass the
same entries you give to `entries`, and call it when the application starts and
when the route changes from somewhere else. The state also remembers this entry as
the current one, for `focusCurrent`.

    SideNav.reveal "reports-monthly" menu model.sideNav

### `focusLink`

```elm
focusLink : Ids.Ids key -> key -> State key -> msg -> Cmd msg
```

Moves keyboard focus to the link with this key: the current page, when the
sidebar opens as a drawer. Does nothing if that link is not in the page (inside a
closed group, say). The message is sent when it is done, whether the link was
found or not, so use one that changes nothing.

    SideNav.focusLink Ids.string "orders" model.sideNav NoOp

### `focusCurrent`

```elm
focusCurrent : State key -> msg -> Cmd msg
```

Moves keyboard focus to the link that `reveal` was last called with, the current
page, without needing its key: `AppShell` uses it when the sidebar drawer opens.
Does nothing before `reveal`, or when the link is not on the page. The message is sent
when it is done.

### `update`

```elm
update : Msg -> State key -> ( State key, Cmd Msg )
```

Opens and closes groups and moves keyboard focus between the entries. The
`Cmd` does the focus move, so map it with your message constructor.
