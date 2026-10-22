# Klar.AppShell

The frame of a whole application: a top bar, a sidebar and a content area that scrolls on its own.

Import: `import Klar.AppShell as AppShell` | Group: Navigation

Types: `Attribute`

## Signatures

```elm
-- View
type Attribute msg  -- opaque: no constructors are exposed
view : List (Attribute msg) -> List (Html msg) -> Html msg

-- Top bar
brand : Html msg -> Attribute msg
brandLink : { name : String, href : String, logo : Maybe (Html msg) } -> Html msg
onSearch : msg -> Attribute msg
searchPlaceholder : String -> Attribute msg
searchShortcut : List String -> Attribute msg
actions : List (Html msg) -> Attribute msg
userName : String -> Attribute msg
userRole : String -> Attribute msg
userAvatar : Html msg -> Attribute msg
userMenu : Html msg -> Attribute msg
banner : Html msg -> Attribute msg

-- Sidebar
sidebar : Html msg -> Attribute msg
sidebarCollapsed : Bool -> Attribute msg
onToggleSidebar : msg -> Attribute msg
drawerOpen : Bool -> Attribute msg
onToggleDrawer : msg -> Attribute msg
onCloseDrawer : msg -> Attribute msg
focusMenuButton : String -> msg -> Cmd msg

-- Content
contentMaxWidth : Int -> Attribute msg
contentPadding : Int -> Attribute msg
resetScroll : String -> msg -> Cmd msg

-- Overlays and modals
overlays : List (Overlay.Overlay msg) -> Attribute msg

-- Skip link and shortcuts
onSkipToContent : msg -> Attribute msg
focusContent : String -> msg -> Cmd msg
shortcuts : Html.Attribute msg -> Attribute msg

-- Frame
id : String -> Attribute msg
height : Int -> Attribute msg
width : Int -> Attribute msg
onStrayDrop : msg -> Attribute msg

-- Language
locale : Locale.Locale -> Attribute msg
```

## Documentation

The frame of a whole application: a top bar, a sidebar and a content area
that scrolls on its own. Use it as the root of the `view` of a
`Browser.application`.

The shell keeps no state. You tell it what to draw (the brand, the sidebar, the
user, whether the sidebar is collapsed or the drawer is open) and it sends your
messages when the user clicks a toggle, the search field or the skip link. The
parts normally come from other modules: a [Klar.SideNav](Klar.SideNav.md) for the
sidebar, a [Klar.Menu](Klar.Menu.md) for the user menu and a
[Klar.PageHeader](Klar.PageHeader.md) at the top of every page.

A small application, "Acme Operations", with the pages Orders, Customers and
Reports needs this model and these messages:

    type alias Model =
        { page : Page
        , sideNav : SideNav.State Page -- SideNav.init "main-nav"
        , userMenu : Menu.State -- Menu.init "user-menu"
        , sidebarCollapsed : Bool -- icons only, on wide screens
        , drawerOpen : Bool -- the sidebar drawer, on narrow screens
        }

    type Msg
        = SideNavMsg SideNav.Msg
        | UserMenuMsg Menu.Msg
        | ToggleSidebar
        | ToggleDrawer
        | CloseDrawer
        | SkipToContent
        | OpenSearch
        | SignOut
        | LinkClicked Browser.UrlRequest
        | UrlChanged Url
        | NoOp

The view is one `AppShell.view`. The first list holds the parts of the frame, the
second the content of the current page:

    import Browser
    import Klar.AppShell as AppShell
    import Klar.Icon as Icon
    import Klar.Menu as Menu
    import Klar.SideNav as SideNav

    shellId : String
    shellId =
        "app-shell"

    view : Model -> Browser.Document Msg
    view model =
        { title = "Acme Operations"
        , body =
            [ AppShell.view
                [ AppShell.id shellId
                , AppShell.brand
                    (AppShell.brandLink
                        { name = "Acme Operations"
                        , href = "#/"
                        , logo = Just (Icon.sized Icon.Large Icon.layers)
                        }
                    )
                , AppShell.sidebar
                    (SideNav.view SideNavMsg
                        [ SideNav.entries navigation
                        , SideNav.current model.page
                        , SideNav.collapsed model.sidebarCollapsed
                        ]
                        model.sideNav
                    )
                , AppShell.sidebarCollapsed model.sidebarCollapsed
                , AppShell.onToggleSidebar ToggleSidebar
                , AppShell.drawerOpen model.drawerOpen
                , AppShell.onToggleDrawer ToggleDrawer
                , AppShell.onCloseDrawer CloseDrawer
                , AppShell.onSearch OpenSearch
                , AppShell.userName "Ada Lovelace"
                , AppShell.userRole "Operations manager"
                , AppShell.userMenu
                    (Menu.view UserMenuMsg
                        [ Menu.kebab "Account menu"
                        , Menu.alignEnd
                        , Menu.items [ Menu.item "Sign out" SignOut ]
                        ]
                        model.userMenu
                    )
                , AppShell.contentMaxWidth 1280
                , AppShell.onSkipToContent SkipToContent
                ]
                [ viewPage model ]
            ]
        }

    pageKeys : SideNav.Keys Page
    pageKeys =
        SideNav.keys pageToString

    navigation : List (SideNav.Entry Page msg)
    navigation =
        [ SideNav.section "Workspace"
            [ SideNav.item pageKeys { key = Orders, label = "Orders", href = "#/orders" }
                |> SideNav.withIcon Icon.clipboardCheck
            , SideNav.item pageKeys { key = Customers, label = "Customers", href = "#/customers" }
                |> SideNav.withIcon Icon.users
            , SideNav.item pageKeys { key = Reports, label = "Reports", href = "#/reports" }
                |> SideNav.withIcon Icon.barChart
            ]
        ]

`Page` (here `Orders | Customers | Reports`) is also the key type of the menu,
`pageToString` writes a page as text (see `SideNav.keys`), and `pageFromUrl` and
`viewPage` stand for your own routing and page views.

The shell never moves keyboard focus by itself, so the branches of `update` that
belong to it end with a command from this module. `NoOp` is a message that does
nothing; the commands send it when they are done.

    ToggleSidebar ->
        ( { model | sidebarCollapsed = not model.sidebarCollapsed }, Cmd.none )

    ToggleDrawer ->
        if model.drawerOpen then
            ( { model | drawerOpen = False }
            , AppShell.focusMenuButton shellId NoOp
            )

        else
            ( { model | drawerOpen = True }
            , SideNav.focusLink pageKeys model.page model.sideNav NoOp
            )

    CloseDrawer ->
        ( { model | drawerOpen = False }
        , AppShell.focusMenuButton shellId NoOp
        )

    SkipToContent ->
        ( model, AppShell.focusContent shellId NoOp )

    UrlChanged url ->
        ( { model | page = pageFromUrl url, drawerOpen = False }
        , Cmd.batch
            [ AppShell.resetScroll shellId NoOp
            , if model.drawerOpen then
                AppShell.focusContent shellId NoOp

              else
                Cmd.none
            ]
        )

The `SideNavMsg` and `UserMenuMsg` branches are the usual wiring of those two
components, and `LinkClicked` is the usual `Browser.application` message for a
click on a link.

**Layout.** The shell fills the viewport and the page itself never scrolls: the
top bar stays in place, the sidebar scrolls if it is long, and the content area
scrolls on its own. That is why a route change needs `resetScroll`. Give the shell
a `height` (and a `width`) to draw it as a framed box inside another page
instead, for a demo.

**Top bar.** From left to right: the sidebar toggle, the `brand`, the search
field (`onSearch`), your `actions`, and the signed-in user (`userName`,
`userRole`, `userAvatar`, `userMenu`). A `banner` sits above the bar. Every part
appears only when you give it. On narrower shells the bar gives way step by step:
below 900px the search field shrinks to an icon button, at 640px or less the name
and role of the user disappear, and below 430px the brand name too, when
`brandLink` has a logo to stand for it. The search field is a button that looks
like a text field: connect `onSearch` to whatever opens your search, such as a
command palette. The shell only draws the key caps (`searchShortcut`); the
keyboard shortcut itself belongs to the application (see
[Klar.Shortcut](Klar.Shortcut.md) and `shortcuts`).

**Sidebar.** On wide shells (900px or more) it sits to the left, at full width or
collapsed to icons (`sidebarCollapsed`, flipped by the toggle in the top bar,
which sends `onToggleSidebar`). Below 900px it turns into an off-canvas drawer
that the other toggle opens (`drawerOpen`, `onToggleDrawer`). A click on the
backdrop or Escape sends `onCloseDrawer`; close the drawer when the route changes
too. The switch between the two layouts is pure CSS, a container query on the
shell itself, so the application never needs to know the window width. A shell
that is narrower than 900px because of its `width` uses the drawer whatever the
size of the window.

The drawer is not modal (the top bar stays usable) and does not move focus by
itself, because the shell is stateless. When it opens, send keyboard focus to the
current link (`SideNav.focusLink`): the links come after the whole top bar in the
tab order. When it closes, give focus back to the menu button
(`focusMenuButton`): the links of a closed drawer cannot hold it. After
navigating from the drawer, `focusContent`.

**Modals.** Give the dialogs, drawers, the palette and the toasts to `overlays`,
which draws them outside the page. While any of them is open the banner, top bar,
sidebar and content are `inert`: focus cannot leave an open dialog and screen
readers ignore the page behind it. The shell finds that out from the list itself;
there is no flag to keep in step. This takes the place of
[`Overlay.host`](Klar.Overlay.md#host) for an application that uses the shell.

**Skip link.** The first Tab stop is a skip link, "Skip to main content", which
is visible only while it has focus. With hash routing a plain `#anchor` link would
change the route, so pass `onSkipToContent` and answer it with `focusContent`.
The content area is the `main` landmark of the page.

**Stray file drops.** A file dropped anywhere that is not a
[Klar.FileDrop](Klar.FileDrop.md) zone is opened by the browser, which replaces the
whole application with the file. Pass `onStrayDrop` with a message that does
nothing and the shell cancels such drops.

**Language.** The built-in text (the skip link, the search field, the toggle
buttons) follows `locale`, English by default. The shell also puts the matching
`lang` on its own root element, because the `lang` of the `html` element cannot
change without JavaScript.

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A part or a setting of the shell. Make them with the functions below and pass
a list to `view`; later attributes win over earlier ones, and the order of the
parts does not matter. The `msg` is your message type.

### `view`

```elm
view : List (Attribute msg) -> List (Html msg) -> Html msg
```

The shell around the page. The attributes fill the top bar, the sidebar and the
other parts; the second argument is the content of the current page, which is
placed in the scrolling `main` area. The module documentation walks through a
complete example.

## Top bar

### `brand`

```elm
brand : Html msg -> Attribute msg
```

The product name or logo at the left of the top bar, after the sidebar toggle.
Usually the result of `brandLink`; any Html will do. On a shell narrower than
430px the name of a `brandLink` that has a logo is hidden and only the logo is
left.

### `brandLink`

```elm
brandLink : { name : String, href : String, logo : Maybe (Html msg) } -> Html msg
```

A product name with an optional logo, as a link to the start page; pass the
result to `brand`. `href` is where the link goes (`#/` for the start page of a
single page application). With a `logo`, shells narrower than 430px hide the name
and show only the logo; without one the name stays, cut with an ellipsis when it
does not fit.

    AppShell.brandLink
        { name = "Acme Operations"
        , href = "#/"
        , logo = Just (Icon.sized Icon.Large Icon.layers)
        }

### `onSearch`

```elm
onSearch : msg -> Attribute msg
```

Shows the global search field in the middle of the top bar and sends the
message when it is clicked. It is a button that looks like a search field, so
connect it to whatever opens your search, such as a command palette; the keyboard
shortcut belongs to the application (see [Klar.Shortcut](Klar.Shortcut.md)). On
narrow shells the field shrinks to an icon button, and without `onSearch` there
is no field at all.

### `searchPlaceholder`

```elm
searchPlaceholder : String -> Attribute msg
```

The text in the search field, which is also its accessible name. Default
"Search ..." (in the language of `locale`).

### `searchShortcut`

```elm
searchShortcut : List String -> Attribute msg
```

The key caps shown at the right of the search field. Default
`[ "Ctrl", "K" ]`; an empty list shows none. They only describe the shortcut
(also in the tooltip and in `aria-keyshortcuts`): the shell does not listen for
the keys, so bind them yourself with [Klar.Shortcut](Klar.Shortcut.md).

    AppShell.searchShortcut [ "Ctrl", "K" ]

### `actions`

```elm
actions : List (Html msg) -> Attribute msg
```

Buttons at the right of the top bar, before the user: a language switch, help,
notifications. Pass small, quiet buttons, for example
`Button.iconOnly [ Button.ghost, Button.onClick OpenHelp ] Icon.help "Help"`.

### `userName`

```elm
userName : String -> Attribute msg
```

The name of the signed-in user, shown at the right end of the top bar next to
a circle with the initials (the first letters of the first and last word: "Ada
Lovelace" gives "AL"). Use `userAvatar` to replace the circle. On shells 640px
wide or less only the circle is shown.

### `userRole`

```elm
userRole : String -> Attribute msg
```

A line of small gray text under the user's name, such as a role or the name of
the organization. It is only shown together with `userName`.

### `userAvatar`

```elm
userAvatar : Html msg -> Attribute msg
```

Your own avatar, such as a photo or a [Klar.Avatar](Klar.Avatar.md), instead of
the circle with initials. It is decorative (hidden from screen readers; the name
is text next to it) and is only shown together with `userName`.

### `userMenu`

```elm
userMenu : Html msg -> Attribute msg
```

A [Klar.Menu](Klar.Menu.md) placed after the name, with the actions on the account:
profile, settings, sign out. Without `userName` the menu is shown on its own.

### `banner`

```elm
banner : Html msg -> Attribute msg
```

A full-width message above the top bar, such as a notice about planned
maintenance. Usually an alert from [Klar.Alert](Klar.Alert.md) with the `banner`
look.

    AppShell.banner
        (Alert.view [ Alert.banner, Alert.tone Warning ] "Maintenance tonight at 22:00.")

## Sidebar

### `sidebar`

```elm
sidebar : Html msg -> Attribute msg
```

The content of the sidebar, normally a `SideNav.view` from
[Klar.SideNav](Klar.SideNav.md). The sidebar scrolls on its own when it is long.
Without it the shell has no sidebar and no toggle buttons.

### `sidebarCollapsed`

```elm
sidebarCollapsed : Bool -> Attribute msg
```

Collapses the sidebar to a narrow strip of icons when the shell is 900px wide
or more (default `False`). Pass the same flag to `SideNav.collapsed`, so that the
menu itself draws icons only. The shell does not remember the flag, so keep it in
your model and flip it when `onToggleSidebar` arrives; on narrow shells the
sidebar is a drawer, which always shows the full menu.

### `onToggleSidebar`

```elm
onToggleSidebar : msg -> Attribute msg
```

Sent by the sidebar toggle in the top bar on wide shells (900px or more). Its
accessible name is "Hide the sidebar" or "Show the sidebar", and `aria-expanded`
follows `sidebarCollapsed`. Without `onToggleSidebar` there is no toggle there and
the sidebar keeps its size; the menu button on narrow shells sends it too when
you give no `onToggleDrawer`.

### `drawerOpen`

```elm
drawerOpen : Bool -> Attribute msg
```

Whether the sidebar drawer is open (default `False`). It only matters on
narrow shells, below 900px; on wide ones the sidebar is always in place. The shell
does not remember the flag: keep it in your model, set it when `onToggleDrawer`
arrives, and clear it on `onCloseDrawer` and when the route changes.

### `onToggleDrawer`

```elm
onToggleDrawer : msg -> Attribute msg
```

Sent by the menu button ("Menu") in the top bar on narrow shells (below
900px), the only way to open the drawer; its `aria-expanded` follows `drawerOpen`.
If you give only `onToggleSidebar`, that message is used there too. The button
also sends it when the drawer is open, so one message can both open and close the
drawer.

### `onCloseDrawer`

```elm
onCloseDrawer : msg -> Attribute msg
```

Sent when the open drawer should close: a click on the backdrop, or Escape
pressed while the drawer is open and focus is in the top bar, the sidebar or the
content. Without it the backdrop and Escape do nothing, and the menu button is
the only way to close the drawer.

### `focusMenuButton`

```elm
focusMenuButton : String -> msg -> Cmd msg
```

Moves keyboard focus to the menu button in the top bar (the one that opens
the sidebar drawer on narrow shells). Use it when the drawer closes, so that a
keyboard user does not lose their place: the links of a closed drawer cannot
take focus any more. The first argument is the id of the shell (see `id`); the
message is sent when the command is done, whether the button was found or not,
so use one that changes nothing.

    AppShell.focusMenuButton "app-shell" NoOp

## Content

### `contentMaxWidth`

```elm
contentMaxWidth : Int -> Attribute msg
```

Limits the width of the page content, in pixels, and centers it in the content
area. Default: no limit, the content uses the full width. Wide screens are easier
to read with a limit, 1280 for example.

### `contentPadding`

```elm
contentPadding : Int -> Attribute msg
```

The padding around the content, in steps of the 4px spacing scale; default 6,
which is 24px, and 0 lets the page go edge to edge. The valid steps are 1 to 6, 8,
10 and 12, and other numbers are moved down to the nearest step (7 becomes 6). On
narrow shells, below 900px, the padding never exceeds 16px.

### `resetScroll`

```elm
resetScroll : String -> msg -> Cmd msg
```

Scrolls the content area back to the top. The page itself never scrolls, so
the browser does not do this for you when the route changes. The first argument
is the id of the shell (see `id`); the message is sent when the command is done,
whether the content area was found or not, so use one that changes nothing.

    AppShell.resetScroll "app-shell" NoOp

## Overlays and modals

### `overlays`

```elm
overlays : List (Overlay.Overlay msg) -> Attribute msg
```

The overlays of the page: dialogs, drawers, the command palette, the shortcut
sheet and the toasts, each as the [`Overlay`](Klar.Overlay.md#overlay) that its `view`
returns. They are drawn after the page, outside the part that becomes `inert`
while one of them is open. See [Klar.Overlay](Klar.Overlay.md) for everything the
list takes care of.

    AppShell.overlays
        [ Modal.view ModalMsg [ Modal.title "Edit order" ] model.modal [ orderForm model ]
        , Toast.view ToastMsg [] model.toasts
        ]

## Skip link and shortcuts

### `onSkipToContent`

```elm
onSkipToContent : msg -> Attribute msg
```

Makes the skip link ("Skip to main content") a button that sends this message
when it is used. Answer it with `focusContent`. Without it the skip link is an
ordinary `#anchor` link to the content area, which is fine unless you route on
the URL fragment (it would count as a navigation).

### `focusContent`

```elm
focusContent : String -> msg -> Cmd msg
```

Moves keyboard focus to the content area: the answer to `onSkipToContent`, and
a good thing to do after the user navigated from the sidebar drawer. The first
argument is the id of the shell (see `id`); the message is sent when the command
is done, whether the content area was found or not, so use one that changes
nothing.

    AppShell.focusContent "app-shell" NoOp

### `shortcuts`

```elm
shortcuts : Html.Attribute msg -> Attribute msg
```

The place for the application's global keyboard shortcuts. Pass the result of
`Shortcut.listen` from [Klar.Shortcut](Klar.Shortcut.md); the shell root becomes
focusable (`tabindex="-1"`) so that key presses anywhere inside it reach the
listener, and the browser's own action for a key like Ctrl+K is prevented.

    AppShell.shortcuts (Shortcut.listen ShortcutMsg allShortcuts model.shortcuts)

## Frame

### `id`

```elm
id : String -> Attribute msg
```

A DOM id for the shell, unique on the page. Default `klar-app-shell`. Pass the
same id to `focusContent`, `focusMenuButton` and `resetScroll`; the content area,
the sidebar, the search button and the menu button get ids made of it plus a
suffix: `-content`, `-sidebar`, `-search` and `-menu`.

### `height`

```elm
height : Int -> Attribute msg
```

Draws the shell as a framed box this many pixels high, with a border and
rounded corners, instead of filling the viewport. For demos and for embedding the
shell in another page. Default: the shell fills the viewport.

### `width`

```elm
width : Int -> Attribute msg
```

The largest width in pixels of the framed box. It only has an effect together
with `height`. A shell narrower than 900px switches to the drawer layout,
whatever the size of the window.

### `onStrayDrop`

```elm
onStrayDrop : msg -> Attribute msg
```

Stops the browser from opening a file that is dropped outside a drop zone,
which would replace the whole application. Give it a message that does nothing:
it is sent over and over while a file is dragged across the shell, and once more
for the drop. A [Klar.FileDrop](Klar.FileDrop.md) zone inside the shell still takes
its own drops, and other drags (text, links) are left alone.

    AppShell.onStrayDrop NoOp

## Language

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the skip link, the search field and the
toggle buttons. Default `Locale.en`. The shell also sets the `lang` attribute of
its root element to match, so that screen readers pronounce the application in
the right language.

    AppShell.locale Locale.nb
