# Klar.AppShell

The frame of a whole application: a top bar, a sidebar and a content area that scrolls on its own.

Import: `import Klar.AppShell as AppShell` | Group: Navigation

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- Wiring: one state, one message
type State page  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : { id : String, key : Browser.Navigation.Key, url : Url.Url } -> State page
setPage : List (SideNav.Entry page msg) -> page -> State page -> State page
update : Msg -> State page -> ( State page, Cmd Msg, Maybe Url.Url )
state : (Msg -> msg) -> State page -> Attribute msg
sideNav : (Msg -> msg) -> List (SideNav.Attribute page msg) -> State page -> Html msg
onUrlRequest : (Msg -> msg) -> Browser.UrlRequest -> msg
onUrlChange : (Msg -> msg) -> Url.Url -> msg
follow : Browser.UrlRequest -> State page -> ( State page, Cmd Msg )
toggleSidebar : State page -> Cmd Msg
goToContent : State page -> Cmd Msg

-- What the state keeps
isSidebarCollapsed : State page -> Bool
setSidebarCollapsed : Bool -> State page -> State page
isDrawerOpen : State page -> Bool
closeDrawer : State page -> ( State page, Cmd Msg )

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

-- Content
pageTitle : String -> Attribute msg
contentMaxWidth : Int -> Attribute msg
contentPadding : Int -> Attribute msg

-- Overlays and modals
overlays : List (Overlay.Overlay msg) -> Attribute msg

-- Shortcuts
shortcuts : Html.Attribute msg -> Attribute msg

-- Frame
id : String -> Attribute msg
height : Int -> Attribute msg
width : Int -> Attribute msg
onStrayDrop : msg -> Attribute msg

-- Language
locale : Locale.Locale -> Attribute msg
settings : Settings.Settings -> Attribute msg

-- Without a State
sidebarCollapsed : Bool -> Attribute msg
onToggleSidebar : msg -> Attribute msg
drawerOpen : Bool -> Attribute msg
onToggleDrawer : msg -> Attribute msg
onCloseDrawer : msg -> Attribute msg
onSkipToContent : msg -> Attribute msg
focusMenuButton : String -> msg -> Cmd msg
focusContent : String -> msg -> Cmd msg
resetScroll : String -> msg -> Cmd msg
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
          , shell = AppShell.init { id = "app-shell", key = key, url = url } |> AppShell.setPage navigation page
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
`LinkClicked` and a `pushUrl` of your own). It is all of it:

  - A link is followed: `pushUrl` for another address of the application, `load` for an
    address elsewhere. A link to the address the user is on (the current page in the side
    menu) enters the page again with `replaceUrl`, so Back never needs one press per click.
    A link to an element of the page (`#field-id`, not a route like `#/orders`) moves focus
    to that element and adds nothing to the history: a route in the fragment starts with
    `/`, and any other fragment never changes the page.
  - A new page (another path, or another route before the `?` of a `#/route?query`) closes
    the drawer, scrolls the content to the top and moves focus to the content, because the
    element that had it went with the old page. When the user chose the page with Enter on
    a link of the side menu, focus stays on that link. An address that only changes the
    query (filters, the sort, a tab kept in the address with `replaceUrl`) keeps the
    scroll position, the drawer and the focus; it is still reported to you.
  - The sidebar toggle, the drawer, the skip link and the focus that goes with each (the
    current link when the drawer opens, the menu button when it closes) are done for you.

The view is one `AppShell.view`. The first list holds the parts of the frame, the second
the content of the current page:

    import Browser
    import Klar
    import Klar.AppShell as AppShell
    import Klar.Icon as Icon
    import Klar.Ids as Ids exposing (Ids)
    import Klar.Menu as Menu
    import Klar.SideNav as SideNav

    view : Model -> Browser.Document Msg
    view model =
        { title = "Acme Operations"
        , body =
            [ Klar.stylesheet
            , AppShell.view
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
                , AppShell.pageTitle (pageTitle model.page)
                , AppShell.contentMaxWidth 1280
                ]
                [ viewPage model ]
            ]
        }

    pageKeys : Ids Page
    pageKeys =
        Ids.list pageToString [ Orders, Customers, Reports ]

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
`pageToString` writes a page as text and `Ids.list` (from [Klar.Ids](Klar.Ids.md)) reads it back, and `pageFromUrl`,
`pageTitle` (the title of a page, also for `Browser.Document.title` and the
`PageHeader.title`) and `viewPage` stand for your own routing and page views. `elm/url` must be a direct
dependency of the application, as for every `Browser.application`.

A command of yours that goes to another page (the palette opened an order, a shortcut)
needs nothing more: the new address is a new page, so focus goes to the content as for a
link. A command that replaces the page without a new address loses the element that had
focus; send it to the content with `AppShell.goToContent`. A shortcut that hides the
sidebar is `AppShell.toggleSidebar`.

**Links that must ask first.** When a click on a link must be held back (a
[Klar.LeaveGuard](Klar.LeaveGuard.md) asks about unsaved changes), give `Browser.application`
a message of your own as `onUrlRequest` and hand the request to `AppShell.follow` when it
may go on. `onUrlChange` stays the shell's, and the address that `update` reports goes to
`LeaveGuard.onUrlChange` (the whole wiring of the guard is in its docs):

    LinkClicked (Browser.Internal url) ->
        case LeaveGuard.request (pageFromUrl url) model.guard of
            Proceed _ ->
                followLink (Browser.Internal url) model

            Hold guard cmd ->
                ( { model | guard = guard }, Cmd.map GuardMsg cmd )

    LinkClicked request ->
        followLink request model

    followLink : Browser.UrlRequest -> Model -> ( Model, Cmd Msg )
    followLink request model =
        let
            ( shell, cmd ) =
                AppShell.follow request model.shell
        in
        ( { model | shell = shell }, Cmd.map ShellMsg cmd )

**The sidebar is any `Html`.** `AppShell.sideNav` draws a `SideNav`, but `sidebar` takes any
`Html msg`: a `Tree` of regions, a list of saved views, a filter form.

**Without a `State`.** A program without addresses (`Browser.document`, `Browser.element`, a
demo in a gallery) has no `Nav.Key` for `init`. It can still draw the frame: the attributes
of the last section (`sidebarCollapsed`, `onToggleSidebar`, `drawerOpen`, `onToggleDrawer`,
`onCloseDrawer`, `onSkipToContent`) and the commands `focusMenuButton`, `focusContent` and
`resetScroll` are what `AppShell.state` is made of. Such a shell keeps its flags in the model
and never moves focus by itself. With `AppShell.state` in the list they are not needed, and
`state` wins over them wherever it stands.

**Layout.** The shell fills the viewport and the page itself never scrolls: the
top bar stays in place, the sidebar scrolls if it is long, and the content area
scrolls on its own. Give the shell a `height` (and a `width`) to draw it as a framed box
inside another page instead, for a demo; a framed shell is a named region, not the `main`
landmark of the page.

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
collapsed to icons by the toggle in the top bar (`isSidebarCollapsed` reads it and
`setSidebarCollapsed` restores a saved preference). Below 900px it turns into an
off-canvas drawer that the menu button opens. A click on the backdrop, Escape (unless a
control inside, such as an open popup, used it already) or a link closes it, and so does
`closeDrawer`. The switch between the two layouts is pure CSS, a container query on the
shell itself, so the application never needs to know the window width. A shell
that is narrower than 900px because of its `width` uses the drawer whatever the
size of the window.

The drawer is not modal (the top bar stays usable). When it opens, focus goes to the
current link (the links come after the whole top bar in the tab order); when it closes,
back to the menu button, because the links of a closed drawer cannot hold it; after a
page was chosen in it, to the content.

**Modals.** Give the dialogs, drawers, the palette and the toasts to `overlays`,
which draws them outside the page. While any of them is open the banner, top bar,
sidebar and content are `inert`: focus cannot leave an open dialog and screen
readers ignore the page behind it. The shell finds that out from the list itself;
there is no flag to keep in step. This takes the place of
[`Overlay.host`](Klar.Overlay.md#host) for an application that uses the shell.

**Skip link.** The first Tab stop is a skip link, "Skip to main content", which
is visible only while it has focus. It is a button that moves focus to the content area,
the `main` landmark of the page.

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
[Klar.Ids](Klar.Ids.md)), a custom type of your own such as `Orders | Customers | Reports`.
Keep one in your model, make it with `init`, and give it to `state` and `sideNav`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of the shell: its toggles, the skip link, the side menu and the
address of the page. Wrap it in one constructor of your own, `ShellMsg`.

### `init`

```elm
init : { id : String, key : Browser.Navigation.Key, url : Url.Url } -> State page
```

A shell with the sidebar open, the drawer closed and no page current. The `id` is
the DOM id of the shell, unique on the page; the ids inside it (`-content`, `-sidebar`,
`-search`, `-menu`) and the side menu (`-nav`) start with it. The `key` and the `url`
are the ones `Browser.application` gave to your `init`: the shell pushes the address of
a link with the key, so you do not write the `LinkClicked` branch, and compares every
new address with the last one, to tell a new page from a new query.

    AppShell.init { id = "app-shell", key = key, url = url }

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
content, and a link is followed (see the module docs for the rules). A new page closes
the drawer, scrolls the content to the top and moves focus to the content, unless the
user chose it with Enter in the side menu; a new query on the same page changes none of
that.

The third part is the one place where the application learns that the route changed:
it is the address, once, after the browser has changed it (a link, the Back button, a
`pushUrl` or `replaceUrl` of yours), also when only the query changed. Answer it with
your routing and `setPage`.

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
sidebar and the drawer, whether they are open, and the skip link with its answer. It
wins over the attributes of the section "Without a State" wherever it stands in the
list.

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
shell's message: a click on a link is followed as `follow` describes. Use your own message
instead only when a click must be held back, for example by a
[`LeaveGuard`](Klar.LeaveGuard.md), and hand the request to `follow` when it may go on. Keep
`onUrlChange` the shell's even then: its `update` reports the `Url`, and that `Url` is what
you give to `LeaveGuard.onUrlChange` (the guard answers the clicks and the Back and Forward
buttons, the shell reports the address).

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

### `follow`

```elm
follow : Browser.UrlRequest -> State page -> ( State page, Cmd Msg )
```

Follows a click on a link the way the shell does it: another address of the
application with `pushUrl`, the address the user is on with `replaceUrl` (the page is
entered again, without another entry in the history), a link to an element of the page
(`#field-id`) by moving focus to that element, and an address elsewhere with `load`. A
link chosen in the open drawer closes it.

`AppShell.onUrlRequest` does this for every click. Call it yourself only from an
`onUrlRequest` of your own that asks first, such as a
[`LeaveGuard`](Klar.LeaveGuard.md) (see "Links that must ask first" above).

    ( shell, cmd ) =
        AppShell.follow request model.shell

### `toggleSidebar`

```elm
toggleSidebar : State page -> Cmd Msg
```

Collapses the sidebar to icons on a wide shell (900px or more) and opens or closes
the drawer on a narrow one: what a shortcut such as `[` should do. The layout follows the
width of the shell itself, not of the window (a framed shell, a shell beside a splitter
pane), so it measures the shell, and the answer comes back as a message of the shell.

    ( model, Cmd.map ShellMsg (AppShell.toggleSidebar model.shell) )

### `goToContent`

```elm
goToContent : State page -> Cmd Msg
```

Moves keyboard focus to the content area: the answer to the skip link, and what
to do when a page has been replaced by a command, because the element that had
focus went with the old page.

    Cmd.map ShellMsg (AppShell.goToContent model.shell)

This is the one to use with `AppShell.state`; `focusContent` does the same for a shell
wired by hand, which has no `State`.

## What the state keeps

### `isSidebarCollapsed`

```elm
isSidebarCollapsed : State page -> Bool
```

Whether the sidebar is collapsed to icons on a wide shell (the toggle in the top bar
flips it). Save it with the user's settings to restore it with `setSidebarCollapsed`.

### `setSidebarCollapsed`

```elm
setSidebarCollapsed : Bool -> State page -> State page
```

Collapses the sidebar to icons (`True`) or shows it at full width (`False`), for
instance to restore the preference the user had last time, right after `init`.

    AppShell.init { id = "app-shell", key = key, url = url }
        |> AppShell.setSidebarCollapsed flags.sidebarCollapsed

### `isDrawerOpen`

```elm
isDrawerOpen : State page -> Bool
```

Whether the sidebar drawer of a narrow shell is open.

### `closeDrawer`

```elm
closeDrawer : State page -> ( State page, Cmd Msg )
```

Closes the sidebar drawer from your own code (a command of the palette, a shortcut)
and gives keyboard focus back to the menu button, because the links of a closed drawer
cannot hold it. Does nothing when the drawer is closed.

    let
        ( shell, cmd ) =
            AppShell.closeDrawer model.shell
    in
    ( { model | shell = shell }, Cmd.map ShellMsg cmd )

## View

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A part or a setting of the shell. Make them with the functions below and pass
a list to `view`; later attributes win over earlier ones, except `state`, which wins
wherever it stands, and the order of the parts does not matter. The `msg` is your
message type.

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

## Content

### `pageTitle`

```elm
pageTitle : String -> Attribute msg
```

The title of the current page, such as "Orders" or "Order 10482": the text of its
`PageHeader.title`, and of `Browser.Document.title` without the name of the application.
The shell keeps it in a hidden polite live region, so a screen reader says the new title
after a route change, as it would after a page load; focus has gone to the content by
then. Without it nothing is announced. Default: none.

    AppShell.pageTitle (pageTitle model.page)

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
        [ Modal.view ModalMsg [] model.modal "Edit order" [ orderForm model ]
        , Toast.view ToastMsg [] model.toasts
        ]

## Shortcuts

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

A DOM id for the shell, unique on the page, for a shell without a `State` (with
one, the id is the one given to `init`, and `state` sets it). Default `klar-app-shell`.
Pass the same id to `focusContent`, `focusMenuButton` and `resetScroll`; the content
area, the sidebar, the search button and the menu button get ids made of it plus a
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

## Without a State

Only for a shell that has no `AppShell.state` (a program without addresses, a demo in a
gallery): the parts that `state` sets, given one by one from a model of your own, and the
focus and scroll commands that `update` sends for you otherwise.

### `sidebarCollapsed`

```elm
sidebarCollapsed : Bool -> Attribute msg
```

Only for a shell without `AppShell.state` (`isSidebarCollapsed` and
`setSidebarCollapsed` are the way with one). Collapses the sidebar to a narrow strip of
icons when the shell is 900px wide or more (default `False`). Pass the same flag to
`SideNav.collapsed`, so that the menu itself draws icons only, and flip it in your model
when `onToggleSidebar` arrives; on narrow shells the sidebar is a drawer, which always
shows the full menu.

### `onToggleSidebar`

```elm
onToggleSidebar : msg -> Attribute msg
```

Only for a shell without `AppShell.state`, which sends its own message. Sent by the
sidebar toggle in the top bar on wide shells (900px or more). Its accessible name is
"Hide the sidebar" or "Show the sidebar", and `aria-expanded` follows
`sidebarCollapsed`. Without `onToggleSidebar` there is no toggle there and the sidebar
keeps its size; the menu button on narrow shells sends it too when you give no
`onToggleDrawer`.

### `drawerOpen`

```elm
drawerOpen : Bool -> Attribute msg
```

Only for a shell without `AppShell.state` (`isDrawerOpen` and `closeDrawer` are the
way with one). Whether the sidebar drawer is open (default `False`). It only matters on
narrow shells, below 900px; on wide ones the sidebar is always in place. Set it in your
model when `onToggleDrawer` arrives, and clear it on `onCloseDrawer` and when the route
changes.

### `onToggleDrawer`

```elm
onToggleDrawer : msg -> Attribute msg
```

Only for a shell without `AppShell.state`, which sends its own message. Sent by the
menu button ("Menu") in the top bar on narrow shells (below 900px), the only way to open
the drawer; its `aria-expanded` follows `drawerOpen`. If you give only `onToggleSidebar`,
that message is used there too. The button also sends it when the drawer is open, so one
message can both open and close the drawer.

### `onCloseDrawer`

```elm
onCloseDrawer : msg -> Attribute msg
```

Only for a shell without `AppShell.state`, which sends its own message. Sent when
the open drawer should close: a click on the backdrop, or Escape pressed while the
drawer is open and focus is in the top bar, the sidebar or the content (an Escape that a
control inside used already, such as an open popup closing, does not count). Without it
the backdrop and Escape do nothing, and the menu button is the only way to close the
drawer.

### `onSkipToContent`

```elm
onSkipToContent : msg -> Attribute msg
```

Only for a shell without `AppShell.state`, whose skip link works by itself. Makes
the skip link ("Skip to main content") a button that sends this message when it is
used; answer it with `focusContent`. Without it the skip link is an ordinary `#anchor`
link to the content area, which is fine unless you route on the URL fragment (it would
count as a navigation).

### `focusMenuButton`

```elm
focusMenuButton : String -> msg -> Cmd msg
```

Only for a shell without `AppShell.state`, whose `update` does it (or
`closeDrawer`). Moves keyboard focus to the menu button in the top bar (the one that
opens the sidebar drawer on narrow shells). Use it when the drawer closes, so that a
keyboard user does not lose their place: the links of a closed drawer cannot
take focus any more. The first argument is the id of the shell (see `id`); the
message is sent when the command is done, whether the button was found or not,
so use one that changes nothing.

    AppShell.focusMenuButton "app-shell" NoOp

### `focusContent`

```elm
focusContent : String -> msg -> Cmd msg
```

Only for a shell without `AppShell.state` (with a `State`, use `goToContent`).
Moves keyboard focus to the content area: the answer to `onSkipToContent`, and what to
do after a route change, because the element that had focus went with the old page. The first
argument is the id of the shell (see `id`); the message is sent when the command
is done, whether the content area was found or not, so use one that changes
nothing.

    AppShell.focusContent "app-shell" NoOp

### `resetScroll`

```elm
resetScroll : String -> msg -> Cmd msg
```

Only for a shell without `AppShell.state`, whose `update` does it when the page
changes. Scrolls the content area back to the top. The page itself never scrolls, so
the browser does not do this for you when the route changes. The first argument
is the id of the shell (see `id`); the message is sent when the command is done,
whether the content area was found or not, so use one that changes nothing.

    AppShell.resetScroll "app-shell" NoOp
