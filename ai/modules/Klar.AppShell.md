# Klar.AppShell

The frame of a whole application: a top bar, a sidebar and a content area that scrolls on its own.

Import: `import Klar.AppShell as AppShell` | Group: Navigation

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- Wiring: one state, one message
type State page  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : { id : String, key : Browser.Navigation.Key } -> State page
setPage : List (SideNav.Entry page msg) -> page -> State page -> State page
update : Msg -> State page -> ( State page, Cmd Msg, Maybe Url.Url )
state : (Msg -> msg) -> State page -> Attribute msg
sideNav : (Msg -> msg) -> List (SideNav.Attribute page msg) -> State page -> Html msg
onUrlRequest : (Msg -> msg) -> Browser.UrlRequest -> msg
onUrlChange : (Msg -> msg) -> Url.Url -> msg
toggleSidebar : State page -> Cmd Msg
goToContent : State page -> Cmd Msg

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
settings : Settings.Settings -> Attribute msg
```

## Documentation

The frame of a whole application: a top bar, a sidebar and a content area
that scrolls on its own. Use it as the root of the `view` of a
`Browser.application`.

Use when: the application needs a frame with a top bar, a sidebar and a content area, as the root of a `Browser.application` view.
Do not use when: you only need a single page without navigation chrome (build it from `Klar.Layout` and `Klar.PageHeader`).
Quick path: `init`, `update`, `view`, `onUrlRequest`, `onUrlChange`, `setPage`

You tell the shell what to draw (the brand, the sidebar, the user) and an
`AppShell.State` keeps what the user changes in it: whether the sidebar is collapsed
or the drawer is open, the side menu and the current page. The parts normally come
from other modules: a [Klar.SideNav](Klar.SideNav.md) for the
sidebar, a [Klar.Menu](Klar.Menu.md) for the user menu and a
[Klar.PageHeader](Klar.PageHeader.md) at the top of every page.

The density and the time zone of the application are stated once, in a
[Klar.Settings](Klar.Settings.md) that you keep in the model: `AppShell.settings
model.settings` makes everything inside the shell follow the density.

A small application, "Acme Operations", with the pages Orders, Customers and
Reports needs this model and these messages. The shell keeps the sidebar, the drawer,
the side menu and the skip link in one `AppShell.State`, and all its messages are one
`AppShell.Msg`:

    type alias Model =
        { page : Page
        , shell : AppShell.State Page
        , userMenu : Menu.State -- Menu.init "user-menu"
        }

    type Msg
        = ShellMsg AppShell.Msg
        | UserMenuMsg Menu.Msg
        | SignOut
        | OpenSearch

    main : Program () Model Msg
    main =
        Browser.application
            { init = init
            , view = view
            , update = update
            , subscriptions = \_ -> Sub.none
            , onUrlRequest = AppShell.onUrlRequest ShellMsg
            , onUrlChange = AppShell.onUrlChange ShellMsg
            }

    init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
    init _ url key =
        let
            page =
                pageFromUrl url
        in
        ( { page = page
          , shell = AppShell.init { id = "app-shell", key = key } |> AppShell.setPage navigation page
          , userMenu = Menu.init "user-menu"
          }
        , Cmd.none
        )

The one place that learns of a route change is the third part of `AppShell.update`,
the address:

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
        case msg of
            ShellMsg m ->
                let
                    ( shell, cmd, address ) =
                        AppShell.update m model.shell
                in
                case address of
                    Just url ->
                        let
                            page =
                                pageFromUrl url
                        in
                        ( { model | page = page, shell = AppShell.setPage navigation page shell }
                        , Cmd.map ShellMsg cmd
                        )

                    Nothing ->
                        ( { model | shell = shell }, Cmd.map ShellMsg cmd )

            ...

That is the one wiring of the frame, and the only one to write (not a `SideNav.init`, a
`LinkClicked` and a `pushUrl` of your own). It is all of it: a link is followed (`pushUrl`, or `load` for
an address elsewhere), a new address closes the drawer and scrolls the content to
the top, the sidebar toggle, the drawer, the skip link and the focus that goes with
each (the current link when the drawer opens, the menu button when it closes, the
content after the page was chosen in the drawer) are done for you. The view is one
`AppShell.view`. The first list holds the parts of the frame, the second the
content of the current page:

    import Browser
    import Klar.AppShell as AppShell
    import Klar.Icon as Icon
    import Klar.Menu as Menu
    import Klar.SideNav as SideNav

    view : Model -> Browser.Document Msg
    view model =
        { title = "Acme Operations"
        , body =
            [ AppShell.view
                [ AppShell.state ShellMsg model.shell
                , AppShell.brand
                    (AppShell.brandLink
                        { name = "Acme Operations"
                        , href = "#/"
                        , logo = Just (Icon.sized Icon.Large Icon.layers)
                        }
                    )
                , AppShell.sidebar
                    (AppShell.sideNav ShellMsg [ SideNav.entries navigation ] model.shell)
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
`viewPage` stand for your own routing and page views. `elm/url` must be a direct
dependency of the application, as for every `Browser.application`.

A command that replaces the page (the palette opened an order, a shortcut went to
another page) loses the element that had focus; send it to the content with
`AppShell.goToContent`. A shortcut that hides the sidebar is `AppShell.toggleSidebar`.
When a click on a link must be held back (a `LeaveGuard` asks about unsaved changes),
give `Browser.application` your own `onUrlRequest` message and call `Nav.pushUrl`
yourself when the click may go on; everything else stays as above.

**The sidebar is any `Html`.** `AppShell.sideNav` draws a `SideNav`, but `sidebar` takes any
`Html msg`: a `Tree` of regions, a list of saved views, a filter form. An application with one
page can leave out `AppShell.init` and use `Browser.document` with `AppShell.id` and a sidebar of
its own.

**Wiring it yourself.** `AppShell.state` and `sideNav` are made of the attributes
below (`id`, `sidebarCollapsed`, `onToggleSidebar`, `drawerOpen`, `onToggleDrawer`,
`onCloseDrawer`, `onSkipToContent`) and the commands `focusMenuButton`, `focusContent`
and `resetScroll`. They are there for a shell that keeps its flags in a model of its
own, and for showing one in a gallery; the shell never moves keyboard focus by
itself, so the branches of such an `update` end with one of these commands.

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

## Wiring: one state, one message

### `State`

```elm
type State page  -- opaque: no constructors are exposed
```

What the shell remembers for you: whether the sidebar is collapsed to icons,
whether the sidebar drawer is open, the state of the side menu (its open groups) and
the page it shows as current. `page` is the key type of the side menu (see
`SideNav.keys`), a custom type of your own such as `Orders | Customers | Reports`.
Keep one in your model, make it with `init`, and give it to `state` and `sideNav`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of the shell: its toggles, the skip link, the side menu and the
address of the page. Wrap it in one constructor of your own, `ShellMsg`.

### `init`

```elm
init : { id : String, key : Browser.Navigation.Key } -> State page
```

A shell with the sidebar open, the drawer closed and no page current. The `id` is
the DOM id of the shell, unique on the page; the ids inside it (`-content`, `-sidebar`,
`-search`, `-menu`) and the side menu (`-nav`) start with it. The `key` is the one
`Browser.application` gave to your `init`: the shell pushes the address of a link with
it, so you do not write the `LinkClicked` branch.

    AppShell.init { id = "app-shell", key = key }

### `setPage`

```elm
setPage : List (SideNav.Entry page msg) -> page -> State page -> State page
```

Tells the shell which page is current: the link of the side menu that is marked
and gets focus when the drawer opens. It also opens the groups that contain it. Pass
the same entries you give to `sideNav`. Call it when the application starts and when
the route changes; this is the one call a route change needs.

    AppShell.setPage navigation Orders model.shell

### `update`

```elm
update : Msg -> State page -> ( State page, Cmd Msg, Maybe Url.Url )
```

Handles every message of the shell and returns the commands it needs: the
sidebar and the drawer open and close, a drawer that opens sends focus to the current
link, one that closes gives it back to the menu button, the skip link goes to the
content, a link is followed, and a new address closes the drawer, scrolls the content
to the top and, when the page was chosen in the drawer, moves focus to the content.

The third part is the one place where the application learns that the route changed:
it is the address, once, after the browser has changed it (a link, the Back button, a
`pushUrl` of yours). Answer it with your routing and `setPage`.

    ShellMsg m ->
        let
            ( shell, cmd, address ) =
                AppShell.update m model.shell

            next =
                { model | shell = shell }
        in
        case address of
            Just url ->
                enter (routeFromUrl url) next |> addCmd (Cmd.map ShellMsg cmd)

            Nothing ->
                ( next, Cmd.map ShellMsg cmd )

### `state`

```elm
state : (Msg -> msg) -> State page -> Attribute msg
```

The shell's own parts of the frame, in one attribute: its id, the toggles of the
sidebar and the drawer, whether they are open, and the skip link with its answer.
Give it first in the list of `view`. Without it the shell has no state: use the
single attributes of the next sections to wire one yourself.

    AppShell.view [ AppShell.state ShellMsg model.shell, AppShell.brand brand ] [ page ]

### `sideNav`

```elm
sideNav : (Msg -> msg) -> List (SideNav.Attribute page msg) -> State page -> Html msg
```

The side menu, to put in the `sidebar` (alone, or with other things under it). It
is a [`SideNav.view`](Klar.SideNav.md#view) with the state the shell keeps: the page from
`setPage` is the current one, it is collapsed with the sidebar, and its messages are
the shell's. Give it the `entries` and any other attribute of `SideNav`.

    AppShell.sidebar (AppShell.sideNav ShellMsg [ SideNav.entries navigation ] model.shell)

### `onUrlRequest`

```elm
onUrlRequest : (Msg -> msg) -> Browser.UrlRequest -> msg
```

What to give `Browser.application` as `onUrlRequest`, with your constructor of the
shell's message: a click on a link is followed (a link inside the application with
`pushUrl`, an address elsewhere with `load`). Use your own message instead when a click
must be held back, for example by a [`LeaveGuard`](Klar.LeaveGuard.md), and call
`Nav.pushUrl` yourself when it may go on. Keep `onUrlChange` the shell's even then: its
`update` reports the `Url`, and that `Url` is what you give to `LeaveGuard.onUrlChange`
(the guard answers the clicks and the Back and Forward buttons, the shell reports the
address; the whole wiring is in the docs of [`LeaveGuard`](Klar.LeaveGuard.md)).

    Browser.application
        { onUrlRequest = AppShell.onUrlRequest ShellMsg
        , onUrlChange = AppShell.onUrlChange ShellMsg
        , ...
        }

### `onUrlChange`

```elm
onUrlChange : (Msg -> msg) -> Url.Url -> msg
```

What to give `Browser.application` as `onUrlChange`: see `onUrlRequest`. `update`
reports the address.

### `toggleSidebar`

```elm
toggleSidebar : State page -> Cmd Msg
```

Collapses the sidebar to icons on a wide shell (900px or more) and opens or closes
the drawer on a narrow one: what a shortcut such as `[` should do. The shell does not
know its width, so it asks the browser, and the answer comes back as a message of the
shell.

    ( model, Cmd.map ShellMsg (AppShell.toggleSidebar model.shell) )

### `goToContent`

```elm
goToContent : State page -> Cmd Msg
```

Moves keyboard focus to the content area: the answer to the skip link, and what
to do when a page has been replaced by a command, because the element that had
focus went with the old page.

    Cmd.map ShellMsg (AppShell.goToContent model.shell)

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
[Klar.SideNav](Klar.SideNav.md), with anything else you want in it (a caption, a filter
tree). The sidebar is an `aside` landmark named "Sidebar" ("Sidepanel" in Norwegian),
so everything in it is inside a landmark; the `SideNav` is its own `nav` inside it. The
sidebar scrolls on its own when it is long.
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

### `settings`

```elm
settings : Settings.Settings -> Attribute msg
```

The density of the application, from its `Klar.Settings`: everything inside
the shell follows it (the rows of tables, controls, cards, lists and trees), with
no attribute on the components. A component that is given its own density
(`Table.setDensity`) keeps it.

    AppShell.settings model.settings
