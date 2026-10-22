module Klar.AppShell exposing
    ( State, init, setPage, Msg, update, state, sideNav, onUrlRequest, onUrlChange, toggleSidebar, goToContent
    , view, Attribute
    , brand, brandLink, onSearch, searchPlaceholder, searchShortcut, actions, userName, userRole, userAvatar, userMenu, banner
    , sidebar, sidebarCollapsed, onToggleSidebar, drawerOpen, onToggleDrawer, onCloseDrawer, focusMenuButton
    , contentMaxWidth, contentPadding, resetScroll
    , overlays
    , onSkipToContent, focusContent, shortcuts
    , id, height, width, onStrayDrop
    , locale, settings
    )

{-| The frame of a whole application: a top bar, a sidebar and a content area
that scrolls on its own. Use it as the root of the `view` of a
`Browser.application`.

Use when: the application needs a frame with a top bar, a sidebar and a content area, as the root of a `Browser.application` view.
Do not use when: you only need a single page without navigation chrome (build it from `Klar.Layout` and `Klar.PageHeader`).
Quick path: `init`, `update`, `view`, `onUrlRequest`, `onUrlChange`, `setPage`

You tell the shell what to draw (the brand, the sidebar, the user) and an
`AppShell.State` keeps what the user changes in it: whether the sidebar is collapsed
or the drawer is open, the side menu and the current page. The parts normally come
from other modules: a [Klar.SideNav](Klar-SideNav) for the
sidebar, a [Klar.Menu](Klar-Menu) for the user menu and a
[Klar.PageHeader](Klar-PageHeader) at the top of every page.

The density and the time zone of the application are stated once, in a
[Klar.Settings](Klar-Settings) that you keep in the model: `AppShell.settings
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
                    ( shell, cmd, changed ) =
                        AppShell.update m model.shell
                in
                case changed of
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

That is all the wiring of the frame: a link is followed (`pushUrl`, or `load` for
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
[Klar.Shortcut](Klar-Shortcut) and `shortcuts`).

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
[`Overlay.host`](Klar-Overlay#host) for an application that uses the shell.

**Skip link.** The first Tab stop is a skip link, "Skip to main content", which
is visible only while it has focus. With hash routing a plain `#anchor` link would
change the route, so pass `onSkipToContent` and answer it with `focusContent`.
The content area is the `main` landmark of the page.

**Stray file drops.** A file dropped anywhere that is not a
[Klar.FileDrop](Klar-FileDrop) zone is opened by the browser, which replaces the
whole application with the file. Pass `onStrayDrop` with a message that does
nothing and the shell cancels such drops.

**Language.** The built-in text (the skip link, the search field, the toggle
buttons) follows `locale`, English by default. The shell also puts the matching
`lang` on its own root element, because the `lang` of the `html` element cannot
change without JavaScript.


# Wiring: one state, one message

@docs State, init, setPage, Msg, update, state, sideNav, onUrlRequest, onUrlChange, toggleSidebar, goToContent


# View

@docs view, Attribute


# Top bar

@docs brand, brandLink, onSearch, searchPlaceholder, searchShortcut, actions, userName, userRole, userAvatar, userMenu, banner


# Sidebar

@docs sidebar, sidebarCollapsed, onToggleSidebar, drawerOpen, onToggleDrawer, onCloseDrawer, focusMenuButton


# Content

@docs contentMaxWidth, contentPadding, resetScroll


# Overlays and modals

@docs overlays


# Skip link and shortcuts

@docs onSkipToContent, focusContent, shortcuts


# Frame

@docs id, height, width, onStrayDrop


# Language

@docs locale, settings

-}

import Browser
import Browser.Dom as Dom
import Browser.Navigation as Nav
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Overlay as Overlay exposing (Overlay)
import Klar.Settings as Settings exposing (Settings)
import Klar.SideNav as SideNav
import Klar.Text as Text
import Klar.Theme exposing (Density(..))
import Task
import Url exposing (Url)



-- ATTRIBUTES


{-| A part or a setting of the shell. Make them with the functions below and pass
a list to `view`; later attributes win over earlier ones, and the order of the
parts does not matter. The `msg` is your message type.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { id : String
    , brand : Maybe (Html msg)
    , sidebar : Maybe (Html msg)
    , collapsed : Bool
    , drawerOpen : Bool
    , onToggleSidebar : Maybe msg
    , onToggleDrawer : Maybe msg
    , onCloseDrawer : Maybe msg
    , onSearch : Maybe msg
    , searchPlaceholder : Maybe String
    , searchShortcut : List String
    , actions : List (Html msg)
    , userName : Maybe String
    , userRole : Maybe String
    , userAvatar : Maybe (Html msg)
    , userMenu : Maybe (Html msg)
    , banner : Maybe (Html msg)
    , contentMaxWidth : Maybe Int
    , contentPadding : Int
    , overlays : List (Overlay msg)
    , height : Maybe Int
    , width : Maybe Int
    , onSkip : Maybe msg
    , onStrayDrop : Maybe msg
    , shortcuts : Maybe (Html.Attribute msg)
    , locale : Locale
    , density : Density
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { id = "klar-app-shell"
        , brand = Nothing
        , sidebar = Nothing
        , collapsed = False
        , drawerOpen = False
        , onToggleSidebar = Nothing
        , onToggleDrawer = Nothing
        , onCloseDrawer = Nothing
        , onSearch = Nothing
        , searchPlaceholder = Nothing
        , searchShortcut = [ "Ctrl", "K" ]
        , actions = []
        , userName = Nothing
        , userRole = Nothing
        , userAvatar = Nothing
        , userMenu = Nothing
        , banner = Nothing
        , contentMaxWidth = Nothing
        , contentPadding = 6
        , overlays = []
        , height = Nothing
        , width = Nothing
        , onSkip = Nothing
        , onStrayDrop = Nothing
        , shortcuts = Nothing
        , locale = Locale.default
        , density = Normal
        }
        attributes


{-| A DOM id for the shell, unique on the page. Default `klar-app-shell`. Pass the
same id to `focusContent`, `focusMenuButton` and `resetScroll`; the content area,
the sidebar, the search button and the menu button get ids made of it plus a
suffix: `-content`, `-sidebar`, `-search` and `-menu`.
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = value })


{-| The product name or logo at the left of the top bar, after the sidebar toggle.
Usually the result of `brandLink`; any Html will do. On a shell narrower than
430px the name of a `brandLink` that has a logo is hidden and only the logo is
left.
-}
brand : Html msg -> Attribute msg
brand value =
    Attribute (\config -> { config | brand = Just value })


{-| The content of the sidebar, normally a `SideNav.view` from
[Klar.SideNav](Klar-SideNav), with anything else you want in it (a caption, a filter
tree). The sidebar is an `aside` landmark named "Sidebar" ("Sidepanel" in Norwegian),
so everything in it is inside a landmark; the `SideNav` is its own `nav` inside it. The
sidebar scrolls on its own when it is long.
Without it the shell has no sidebar and no toggle buttons.
-}
sidebar : Html msg -> Attribute msg
sidebar value =
    Attribute (\config -> { config | sidebar = Just value })


{-| Collapses the sidebar to a narrow strip of icons when the shell is 900px wide
or more (default `False`). Pass the same flag to `SideNav.collapsed`, so that the
menu itself draws icons only. The shell does not remember the flag, so keep it in
your model and flip it when `onToggleSidebar` arrives; on narrow shells the
sidebar is a drawer, which always shows the full menu.
-}
sidebarCollapsed : Bool -> Attribute msg
sidebarCollapsed value =
    Attribute (\config -> { config | collapsed = value })


{-| Sent by the sidebar toggle in the top bar on wide shells (900px or more). Its
accessible name is "Hide the sidebar" or "Show the sidebar", and `aria-expanded`
follows `sidebarCollapsed`. Without `onToggleSidebar` there is no toggle there and
the sidebar keeps its size; the menu button on narrow shells sends it too when
you give no `onToggleDrawer`.
-}
onToggleSidebar : msg -> Attribute msg
onToggleSidebar msg =
    Attribute (\config -> { config | onToggleSidebar = Just msg })


{-| Whether the sidebar drawer is open (default `False`). It only matters on
narrow shells, below 900px; on wide ones the sidebar is always in place. The shell
does not remember the flag: keep it in your model, set it when `onToggleDrawer`
arrives, and clear it on `onCloseDrawer` and when the route changes.
-}
drawerOpen : Bool -> Attribute msg
drawerOpen value =
    Attribute (\config -> { config | drawerOpen = value })


{-| Sent by the menu button ("Menu") in the top bar on narrow shells (below
900px), the only way to open the drawer; its `aria-expanded` follows `drawerOpen`.
If you give only `onToggleSidebar`, that message is used there too. The button
also sends it when the drawer is open, so one message can both open and close the
drawer.
-}
onToggleDrawer : msg -> Attribute msg
onToggleDrawer msg =
    Attribute (\config -> { config | onToggleDrawer = Just msg })


{-| Sent when the open drawer should close: a click on the backdrop, or Escape
pressed while the drawer is open and focus is in the top bar, the sidebar or the
content. Without it the backdrop and Escape do nothing, and the menu button is
the only way to close the drawer.
-}
onCloseDrawer : msg -> Attribute msg
onCloseDrawer msg =
    Attribute (\config -> { config | onCloseDrawer = Just msg })


{-| Shows the global search field in the middle of the top bar and sends the
message when it is clicked. It is a button that looks like a search field, so
connect it to whatever opens your search, such as a command palette; the keyboard
shortcut belongs to the application (see [Klar.Shortcut](Klar-Shortcut)). On
narrow shells the field shrinks to an icon button, and without `onSearch` there
is no field at all.
-}
onSearch : msg -> Attribute msg
onSearch msg =
    Attribute (\config -> { config | onSearch = Just msg })


{-| The text in the search field, which is also its accessible name. Default
"Search ..." (in the language of `locale`).
-}
searchPlaceholder : String -> Attribute msg
searchPlaceholder value =
    Attribute (\config -> { config | searchPlaceholder = Just value })


{-| The key caps shown at the right of the search field. Default
`[ "Ctrl", "K" ]`; an empty list shows none. They only describe the shortcut
(also in the tooltip and in `aria-keyshortcuts`): the shell does not listen for
the keys, so bind them yourself with [Klar.Shortcut](Klar-Shortcut).

    AppShell.searchShortcut [ "Ctrl", "K" ]

-}
searchShortcut : List String -> Attribute msg
searchShortcut value =
    Attribute (\config -> { config | searchShortcut = value })


{-| Buttons at the right of the top bar, before the user: a language switch, help,
notifications. Pass small, quiet buttons, for example
`Button.iconOnly [ Button.ghost, Button.onClick OpenHelp ] Icon.help "Help"`.
-}
actions : List (Html msg) -> Attribute msg
actions value =
    Attribute (\config -> { config | actions = value })


{-| The name of the signed-in user, shown at the right end of the top bar next to
a circle with the initials (the first letters of the first and last word: "Ada
Lovelace" gives "AL"). Use `userAvatar` to replace the circle. On shells 640px
wide or less only the circle is shown.
-}
userName : String -> Attribute msg
userName value =
    Attribute (\config -> { config | userName = Just value })


{-| A line of small gray text under the user's name, such as a role or the name of
the organization. It is only shown together with `userName`.
-}
userRole : String -> Attribute msg
userRole value =
    Attribute (\config -> { config | userRole = Just value })


{-| Your own avatar, such as a photo or a [Klar.Avatar](Klar-Avatar), instead of
the circle with initials. It is decorative (hidden from screen readers; the name
is text next to it) and is only shown together with `userName`.
-}
userAvatar : Html msg -> Attribute msg
userAvatar value =
    Attribute (\config -> { config | userAvatar = Just value })


{-| A [Klar.Menu](Klar-Menu) placed after the name, with the actions on the account:
profile, settings, sign out. Without `userName` the menu is shown on its own.
-}
userMenu : Html msg -> Attribute msg
userMenu value =
    Attribute (\config -> { config | userMenu = Just value })


{-| A full-width message above the top bar, such as a notice about planned
maintenance. Usually an alert from [Klar.Alert](Klar-Alert) with the `banner`
look.

    AppShell.banner
        (Alert.view [ Alert.banner, Alert.tone Warning ] "Maintenance tonight at 22:00.")

-}
banner : Html msg -> Attribute msg
banner value =
    Attribute (\config -> { config | banner = Just value })


{-| Limits the width of the page content, in pixels, and centers it in the content
area. Default: no limit, the content uses the full width. Wide screens are easier
to read with a limit, 1280 for example.
-}
contentMaxWidth : Int -> Attribute msg
contentMaxWidth px =
    Attribute (\config -> { config | contentMaxWidth = Just px })


{-| The padding around the content, in steps of the 4px spacing scale; default 6,
which is 24px, and 0 lets the page go edge to edge. The valid steps are 1 to 6, 8,
10 and 12, and other numbers are moved down to the nearest step (7 becomes 6). On
narrow shells, below 900px, the padding never exceeds 16px.
-}
contentPadding : Int -> Attribute msg
contentPadding n =
    Attribute (\config -> { config | contentPadding = n })


{-| The overlays of the page: dialogs, drawers, the command palette, the shortcut
sheet and the toasts, each as the [`Overlay`](Klar-Overlay#Overlay) that its `view`
returns. They are drawn after the page, outside the part that becomes `inert`
while one of them is open. See [Klar.Overlay](Klar-Overlay) for everything the
list takes care of.

    AppShell.overlays
        [ Modal.view ModalMsg [ Modal.title "Edit order" ] model.modal [ orderForm model ]
        , Toast.view ToastMsg [] model.toasts
        ]

-}
overlays : List (Overlay msg) -> Attribute msg
overlays value =
    Attribute (\config -> { config | overlays = value })


{-| Draws the shell as a framed box this many pixels high, with a border and
rounded corners, instead of filling the viewport. For demos and for embedding the
shell in another page. Default: the shell fills the viewport.
-}
height : Int -> Attribute msg
height px =
    Attribute (\config -> { config | height = Just px })


{-| The largest width in pixels of the framed box. It only has an effect together
with `height`. A shell narrower than 900px switches to the drawer layout,
whatever the size of the window.
-}
width : Int -> Attribute msg
width px =
    Attribute (\config -> { config | width = Just px })


{-| Makes the skip link ("Skip to main content") a button that sends this message
when it is used. Answer it with `focusContent`. Without it the skip link is an
ordinary `#anchor` link to the content area, which is fine unless you route on
the URL fragment (it would count as a navigation).
-}
onSkipToContent : msg -> Attribute msg
onSkipToContent msg =
    Attribute (\config -> { config | onSkip = Just msg })


{-| Stops the browser from opening a file that is dropped outside a drop zone,
which would replace the whole application. Give it a message that does nothing:
it is sent over and over while a file is dragged across the shell, and once more
for the drop. A [Klar.FileDrop](Klar-FileDrop) zone inside the shell still takes
its own drops, and other drags (text, links) are left alone.

    AppShell.onStrayDrop NoOp

-}
onStrayDrop : msg -> Attribute msg
onStrayDrop msg =
    Attribute (\config -> { config | onStrayDrop = Just msg })


{-| The place for the application's global keyboard shortcuts. Pass the result of
`Shortcut.listen` from [Klar.Shortcut](Klar-Shortcut); the shell root becomes
focusable (`tabindex="-1"`) so that key presses anywhere inside it reach the
listener, and the browser's own action for a key like Ctrl+K is prevented.

    AppShell.shortcuts (Shortcut.listen ShortcutMsg allShortcuts model.shortcuts)

-}
shortcuts : Html.Attribute msg -> Attribute msg
shortcuts value =
    Attribute (\config -> { config | shortcuts = Just value })


{-| The language of the built-in text: the skip link, the search field and the
toggle buttons. Default `Locale.en`. The shell also sets the `lang` attribute of
its root element to match, so that screen readers pronounce the application in
the right language.

    AppShell.locale Locale.nb

-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| The density of the application, from its `Klar.Settings`: everything inside
the shell follows it (the rows of tables, controls, cards, lists and trees), with
no attribute on the components. A component that is given its own density
(`Table.setDensity`) keeps it.

    AppShell.settings model.settings

-}
settings : Settings -> Attribute msg
settings value =
    Attribute (\config -> { config | density = Settings.density value })



-- COMMANDS


contentId : String -> String
contentId shellId =
    shellId ++ "-content"


sidebarId : String -> String
sidebarId shellId =
    shellId ++ "-sidebar"


searchId : String -> String
searchId shellId =
    shellId ++ "-search"


menuButtonId : String -> String
menuButtonId shellId =
    shellId ++ "-menu"


{-| Moves keyboard focus to the menu button in the top bar (the one that opens
the sidebar drawer on narrow shells). Use it when the drawer closes, so that a
keyboard user does not lose their place: the links of a closed drawer cannot
take focus any more. The first argument is the id of the shell (see `id`); the
message is sent when the command is done, whether the button was found or not,
so use one that changes nothing.

    AppShell.focusMenuButton "app-shell" NoOp

-}
focusMenuButton : String -> msg -> Cmd msg
focusMenuButton shellId done =
    Internal.focus (menuButtonId shellId) done


{-| Moves keyboard focus to the content area: the answer to `onSkipToContent`, and
a good thing to do after the user navigated from the sidebar drawer. The first
argument is the id of the shell (see `id`); the message is sent when the command
is done, whether the content area was found or not, so use one that changes
nothing.

    AppShell.focusContent "app-shell" NoOp

-}
focusContent : String -> msg -> Cmd msg
focusContent shellId done =
    Internal.focus (contentId shellId) done


{-| Scrolls the content area back to the top. The page itself never scrolls, so
the browser does not do this for you when the route changes. The first argument
is the id of the shell (see `id`); the message is sent when the command is done,
whether the content area was found or not, so use one that changes nothing.

    AppShell.resetScroll "app-shell" NoOp

-}
resetScroll : String -> msg -> Cmd msg
resetScroll shellId done =
    Dom.setViewportOf (contentId shellId) 0 0
        |> Task.attempt (\_ -> done)



-- STATE


{-| What the shell remembers for you: whether the sidebar is collapsed to icons,
whether the sidebar drawer is open, the state of the side menu (its open groups) and
the page it shows as current. `page` is the key type of the side menu (see
`SideNav.keys`), a custom type of your own such as `Orders | Customers | Reports`.
Keep one in your model, make it with `init`, and give it to `state` and `sideNav`.
-}
type State page
    = State
        { id : String
        , key : Nav.Key
        , sideNav : SideNav.State page
        , current : Maybe page
        , collapsed : Bool
        , drawerOpen : Bool
        }


{-| A shell with the sidebar open, the drawer closed and no page current. The `id` is
the DOM id of the shell, unique on the page; the ids inside it (`-content`, `-sidebar`,
`-search`, `-menu`) and the side menu (`-nav`) start with it. The `key` is the one
`Browser.application` gave to your `init`: the shell pushes the address of a link with
it, so you do not write the `LinkClicked` branch.

    AppShell.init { id = "app-shell", key = key }

-}
init : { id : String, key : Nav.Key } -> State page
init options =
    State
        { id = options.id
        , key = options.key
        , sideNav = SideNav.init (options.id ++ "-nav")
        , current = Nothing
        , collapsed = False
        , drawerOpen = False
        }


{-| Tells the shell which page is current: the link of the side menu that is marked
and gets focus when the drawer opens. It also opens the groups that contain it. Pass
the same entries you give to `sideNav`. Call it when the application starts and when
the route changes; this is the one call a route change needs.

    AppShell.setPage navigation Orders model.shell

-}
setPage : List (SideNav.Entry page msg) -> page -> State page -> State page
setPage entries page (State inner) =
    State
        { inner
            | current = Just page
            , sideNav = SideNav.reveal page entries inner.sideNav
        }


{-| The messages of the shell: its toggles, the skip link, the side menu and the
address of the page. Wrap it in one constructor of your own, `ShellMsg`.
-}
type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | SideNavMsg SideNav.Msg
    | ToggleSidebar
    | ToggleDrawer
    | CloseDrawer
    | SkipToContent
    | WidthKnown Float
    | NoOp


{-| Handles every message of the shell and returns the commands it needs: the
sidebar and the drawer open and close, a drawer that opens sends focus to the current
link, one that closes gives it back to the menu button, the skip link goes to the
content, a link is followed, and a new address closes the drawer, scrolls the content
to the top and, when the page was chosen in the drawer, moves focus to the content.

The third part is the one place where the application learns that the route changed:
it is the address, once, after the browser has changed it (a link, the Back button, a
`pushUrl` of yours). Answer it with your routing and `setPage`.

    ShellMsg m ->
        let
            ( shell, cmd, changed ) =
                AppShell.update m model.shell

            next =
                { model | shell = shell }
        in
        case changed of
            Just url ->
                enter (routeFromUrl url) next |> addCmd (Cmd.map ShellMsg cmd)

            Nothing ->
                ( next, Cmd.map ShellMsg cmd )

-}
update : Msg -> State page -> ( State page, Cmd Msg, Maybe Url )
update msg (State inner) =
    case msg of
        UrlRequested (Browser.Internal url) ->
            ( State inner, Nav.pushUrl inner.key (Url.toString url), Nothing )

        UrlRequested (Browser.External href) ->
            ( State inner, Nav.load href, Nothing )

        UrlChanged url ->
            ( State { inner | drawerOpen = False }
            , Cmd.batch
                [ resetScroll inner.id NoOp

                -- Chosen in the drawer: it closes and its link loses focus, so the
                -- new page gets it.
                , if inner.drawerOpen then
                    focusContent inner.id NoOp

                  else
                    Cmd.none
                ]
            , Just url
            )

        SideNavMsg m ->
            let
                ( menu, cmd ) =
                    SideNav.update m inner.sideNav
            in
            ( State { inner | sideNav = menu }, Cmd.map SideNavMsg cmd, Nothing )

        ToggleSidebar ->
            ( State { inner | collapsed = not inner.collapsed }, Cmd.none, Nothing )

        ToggleDrawer ->
            if inner.drawerOpen then
                update CloseDrawer (State inner)

            else
                -- The links come after the whole top bar: take the keyboard to the
                -- current page instead of making it tab there.
                ( State { inner | drawerOpen = True }
                , SideNav.focusCurrent inner.sideNav NoOp
                , Nothing
                )

        CloseDrawer ->
            -- The links of a closed drawer cannot hold focus: give it to the button.
            ( State { inner | drawerOpen = False }, focusMenuButton inner.id NoOp, Nothing )

        SkipToContent ->
            ( State inner, focusContent inner.id NoOp, Nothing )

        WidthKnown pixels ->
            update
                (if pixels < 900 then
                    ToggleDrawer

                 else
                    ToggleSidebar
                )
                (State inner)

        NoOp ->
            ( State inner, Cmd.none, Nothing )


{-| The shell's own parts of the frame, in one attribute: its id, the toggles of the
sidebar and the drawer, whether they are open, and the skip link with its answer.
Give it first in the list of `view`. Without it the shell has no state: use the
single attributes of the next sections to wire one yourself.

    AppShell.view [ AppShell.state ShellMsg model.shell, AppShell.brand brand ] [ page ]

-}
state : (Msg -> msg) -> State page -> Attribute msg
state toMsg (State inner) =
    Attribute
        (\config ->
            { config
                | id = inner.id
                , collapsed = inner.collapsed
                , drawerOpen = inner.drawerOpen
                , onToggleSidebar = Just (toMsg ToggleSidebar)
                , onToggleDrawer = Just (toMsg ToggleDrawer)
                , onCloseDrawer = Just (toMsg CloseDrawer)
                , onSkip = Just (toMsg SkipToContent)
            }
        )


{-| The side menu, to put in the `sidebar` (alone, or with other things under it). It
is a [`SideNav.view`](Klar-SideNav#view) with the state the shell keeps: the page from
`setPage` is the current one, it is collapsed with the sidebar, and its messages are
the shell's. Give it the `entries` and any other attribute of `SideNav`.

    AppShell.sidebar (AppShell.sideNav ShellMsg [ SideNav.entries navigation ] model.shell)

-}
sideNav : (Msg -> msg) -> List (SideNav.Attribute page msg) -> State page -> Html msg
sideNav toMsg attributes (State inner) =
    SideNav.view (\m -> toMsg (SideNavMsg m))
        (SideNav.collapsed inner.collapsed
            :: (case inner.current of
                    Just page ->
                        [ SideNav.current page ]

                    Nothing ->
                        []
               )
            ++ attributes
        )
        inner.sideNav


{-| What to give `Browser.application` as `onUrlRequest`, with your constructor of the
shell's message: a click on a link is followed (a link inside the application with
`pushUrl`, an address elsewhere with `load`). Use your own message instead when a click
must be held back, for example by a [`LeaveGuard`](Klar-LeaveGuard), and call
`Nav.pushUrl` yourself when it may go on.

    Browser.application
        { onUrlRequest = AppShell.onUrlRequest ShellMsg
        , onUrlChange = AppShell.onUrlChange ShellMsg
        , ...
        }

-}
onUrlRequest : (Msg -> msg) -> Browser.UrlRequest -> msg
onUrlRequest toMsg request =
    toMsg (UrlRequested request)


{-| What to give `Browser.application` as `onUrlChange`: see `onUrlRequest`. `update`
reports the address.
-}
onUrlChange : (Msg -> msg) -> Url -> msg
onUrlChange toMsg url =
    toMsg (UrlChanged url)


{-| Collapses the sidebar to icons on a wide shell (900px or more) and opens or closes
the drawer on a narrow one: what a shortcut such as `[` should do. The shell does not
know its width, so it asks the browser, and the answer comes back as a message of the
shell.

    ( model, Cmd.map ShellMsg (AppShell.toggleSidebar model.shell) )

-}
toggleSidebar : State page -> Cmd Msg
toggleSidebar _ =
    Dom.getViewport |> Task.perform (\viewport -> WidthKnown viewport.viewport.width)


{-| Moves keyboard focus to the content area: the answer to the skip link, and what
to do when a page has been replaced by a command, because the element that had
focus went with the old page.

    Cmd.map ShellMsg (AppShell.goToContent model.shell)

-}
goToContent : State page -> Cmd Msg
goToContent (State inner) =
    focusContent inner.id NoOp



-- VIEW


type alias Texts =
    { skip : String
    , search : String
    , searchLabel : String
    , collapse : String
    , expand : String
    , menu : String
    , sidebar : String
    }


texts : Locale -> Texts
texts locale_ =
    Locale.pick locale_
        { nb =
            { skip = "Hopp til hovedinnhold"
            , search = "Søk ..."
            , searchLabel = "Søk"
            , collapse = "Skjul sidemenyen"
            , expand = "Vis sidemenyen"
            , menu = "Meny"
            , sidebar = "Sidepanel"
            }
        , en =
            { skip = "Skip to main content"
            , search = "Search ..."
            , searchLabel = "Search"
            , collapse = "Hide the sidebar"
            , expand = "Show the sidebar"
            , menu = "Menu"
            , sidebar = "Sidebar"
            }
        }


{-| A product name with an optional logo, as a link to the start page; pass the
result to `brand`. `href` is where the link goes (`#/` for the start page of a
single page application). With a `logo`, shells narrower than 430px hide the name
and show only the logo; without one the name stays, cut with an ellipsis when it
does not fit.

    AppShell.brandLink
        { name = "Acme Operations"
        , href = "#/"
        , logo = Just (Icon.sized Icon.Large Icon.layers)
        }

-}
brandLink : { name : String, href : String, logo : Maybe (Html msg) } -> Html msg
brandLink options =
    Html.a
        [ Internal.cls
            [ "klar-app-shell__brand-link"
            , if isJust options.logo then
                "klar-app-shell__brand-link--logo"

              else
                ""
            ]
        , Attr.href options.href
        ]
        [ Internal.viewMaybe (\logo -> Html.span [ Internal.cls [ "klar-app-shell__logo" ] ] [ logo ]) options.logo
        , Html.span [ Internal.cls [ "klar-app-shell__brand-name" ], Attr.title options.name ] [ Html.text options.name ]
        ]


{-| The shell around the page. The attributes fill the top bar, the sidebar and the
other parts; the second argument is the content of the current page, which is
placed in the scrolling `main` area. The module documentation walks through a
complete example.
-}
view : List (Attribute msg) -> List (Html msg) -> Html msg
view attributes content =
    let
        config =
            configure attributes

        strings =
            texts config.locale

        layer =
            Overlay.layer config.overlays

        frame =
            List.filterMap identity
                [ config.height |> Maybe.map (\px -> ( "--klar-app-shell-h", String.fromInt px ++ "px" ))
                , config.width |> Maybe.map (\px -> ( "--klar-app-shell-w", String.fromInt px ++ "px" ))
                ]
    in
    Html.div
        ([ Internal.cls
            [ "klar-app-shell"
            , if config.collapsed then
                "klar-app-shell--collapsed"

              else
                ""
            , if config.drawerOpen then
                "klar-app-shell--drawer-open"

              else
                ""
            , if isJust config.height then
                "klar-app-shell--framed"

              else
                ""
            , if layer.blocked then
                "klar-app-shell--modal-open"

              else
                ""
            , if isJust config.sidebar then
                ""

              else
                "klar-app-shell--no-sidebar"
            ]
         , Attr.id config.id
         , Internal.densityAttr config.density

         -- `<html lang>` cannot change without JavaScript; the language of the
         -- application's own subtree can, so screen readers pronounce it right.
         , Attr.lang (Locale.pick config.locale { nb = "nb", en = "en" })
         , Internal.styleVars frame
         , Internal.attrMaybe identity config.shortcuts
         , Internal.attrIf (isJust config.shortcuts) (Attr.tabindex -1)
         ]
            ++ strayDropGuard config.onStrayDrop
        )
        (layer.watch
            [ Html.div
                ([ Internal.cls [ "klar-app-shell__chrome" ]
                 , Internal.attrIf layer.blocked (Attr.attribute "inert" "")
                 ]
                    -- Not on the root: a node keeps one keydown handler only, and the
                    -- root already has the application's shortcuts. Here it also
                    -- leaves Escape inside dialogs alone.
                    ++ (case ( config.drawerOpen, config.onCloseDrawer ) of
                            ( True, Just close ) ->
                                [ Internal.onKeysPassive [ ( "Escape", close ) ] ]

                            _ ->
                                []
                       )
                )
                [ viewSkipLink config strings
                , Internal.viewMaybe (\html -> Html.div [ Internal.cls [ "klar-app-shell__banner" ] ] [ html ]) config.banner
                , viewBar config strings
                , Html.div [ Internal.cls [ "klar-app-shell__body" ] ]
                    [ viewSidebar config
                    , viewBackdrop config
                    , viewContent config content
                    ]
                ]
            , Html.div [ Internal.cls [ "klar-app-shell__overlays" ] ] layer.overlays
            ]
        )


{-| The two events that make the page a place where a file can be dropped, and
cancel the drop, so the browser does not open the file. Only drags that carry
files; the dragover of a `FileDrop` zone bubbles up here too and is harmless.
-}
strayDropGuard : Maybe msg -> List (Html.Attribute msg)
strayDropGuard maybeMsg =
    case maybeMsg of
        Nothing ->
            []

        Just msg ->
            let
                filesOnly =
                    Decode.at [ "dataTransfer", "types" ] (Decode.list Decode.string)
                        |> Decode.andThen
                            (\types ->
                                if List.member "Files" types then
                                    Decode.succeed ( msg, True )

                                else
                                    Decode.fail "not a file"
                            )
            in
            [ Events.preventDefaultOn "dragover" filesOnly
            , Events.preventDefaultOn "drop" filesOnly
            ]


viewSkipLink : Config msg -> Texts -> Html msg
viewSkipLink config strings =
    case config.onSkip of
        Just msg ->
            Html.button
                [ Internal.cls [ "klar-app-shell__skip" ]
                , Attr.type_ "button"
                , Events.onClick msg
                ]
                [ Html.text strings.skip ]

        Nothing ->
            Html.a
                [ Internal.cls [ "klar-app-shell__skip" ]
                , Attr.href ("#" ++ contentId config.id)
                ]
                [ Html.text strings.skip ]


viewBar : Config msg -> Texts -> Html msg
viewBar config strings =
    let
        hasSidebar =
            isJust config.sidebar

        wideToggle =
            Button.iconOnly
                ([ Button.ghost
                 , Button.expanded (not config.collapsed)
                 , Button.htmlAttrs
                    [ Internal.cls [ "klar-app-shell__toggle", "klar-app-shell__toggle--wide" ]
                    , Attr.attribute "aria-controls" (sidebarId config.id)
                    ]
                 ]
                    ++ (case config.onToggleSidebar of
                            Just msg ->
                                [ Button.onClick msg ]

                            Nothing ->
                                []
                       )
                )
                Icon.sidebar
                (if config.collapsed then
                    strings.expand

                 else
                    strings.collapse
                )

        narrowToggle =
            Button.iconOnly
                ([ Button.ghost
                 , Button.id (menuButtonId config.id)
                 , Button.expanded config.drawerOpen
                 , Button.htmlAttrs
                    [ Internal.cls [ "klar-app-shell__toggle", "klar-app-shell__toggle--narrow" ]
                    , Attr.attribute "aria-controls" (sidebarId config.id)
                    ]
                 ]
                    ++ (case firstJust config.onToggleDrawer config.onToggleSidebar of
                            Just msg ->
                                [ Button.onClick msg ]

                            Nothing ->
                                []
                       )
                )
                Icon.menu
                strings.menu
    in
    Html.header [ Internal.cls [ "klar-app-shell__bar" ] ]
        [ Html.div [ Internal.cls [ "klar-app-shell__bar-start" ] ]
            [ Internal.viewIf (hasSidebar && isJust config.onToggleSidebar) wideToggle
            , Internal.viewIf (hasSidebar && isJust (firstJust config.onToggleDrawer config.onToggleSidebar)) narrowToggle
            , Internal.viewMaybe (\html -> Html.div [ Internal.cls [ "klar-app-shell__brand" ] ] [ html ]) config.brand
            ]
        , Html.div [ Internal.cls [ "klar-app-shell__bar-middle" ] ]
            [ case config.onSearch of
                Just msg ->
                    viewSearch config strings msg

                Nothing ->
                    Html.text ""
            ]
        , Html.div [ Internal.cls [ "klar-app-shell__bar-end" ] ]
            [ Internal.viewIf (not (List.isEmpty config.actions))
                (Html.div [ Internal.cls [ "klar-app-shell__actions" ] ] config.actions)
            , viewUser config
            ]
        ]


viewSearch : Config msg -> Texts -> msg -> Html msg
viewSearch config strings msg =
    Html.button
        [ Internal.cls [ "klar-app-shell__search" ]
        , Attr.id (searchId config.id)
        , Attr.type_ "button"

        -- The name contains the visible text (WCAG "label in name").
        , Attr.attribute "aria-label" (Maybe.withDefault strings.searchLabel config.searchPlaceholder)
        , Attr.title
            (if List.isEmpty config.searchShortcut then
                strings.searchLabel

             else
                strings.searchLabel ++ " (" ++ String.join "+" config.searchShortcut ++ ")"
            )
        , Internal.attrIf (not (List.isEmpty config.searchShortcut))
            (Attr.attribute "aria-keyshortcuts" (String.join "+" (List.map ariaKey config.searchShortcut)))
        , Events.onClick msg
        ]
        [ Icon.view Icon.search
        , Html.span [ Internal.cls [ "klar-app-shell__search-text" ] ]
            [ Html.text (Maybe.withDefault strings.search config.searchPlaceholder) ]
        , Internal.viewIf (not (List.isEmpty config.searchShortcut))
            (Html.span [ Internal.cls [ "klar-app-shell__search-keys" ] ] [ Text.kbdCombo config.searchShortcut ])
        ]


ariaKey : String -> String
ariaKey cap =
    if cap == "Ctrl" then
        "Control"

    else
        cap


viewUser : Config msg -> Html msg
viewUser config =
    case config.userName of
        Nothing ->
            Internal.viewMaybe identity config.userMenu

        Just name ->
            Html.div [ Internal.cls [ "klar-app-shell__user" ] ]
                [ case config.userAvatar of
                    Just avatar ->
                        Html.span [ Internal.cls [ "klar-app-shell__avatar-slot" ], Attr.attribute "aria-hidden" "true" ] [ avatar ]

                    Nothing ->
                        Html.span
                            [ Internal.cls [ "klar-app-shell__avatar" ]
                            , Attr.attribute "aria-hidden" "true"
                            ]
                            [ Html.text (initials name) ]
                , Html.span [ Internal.cls [ "klar-app-shell__user-text" ] ]
                    [ Html.span [ Internal.cls [ "klar-app-shell__user-name" ], Attr.title name ] [ Html.text name ]
                    , Internal.viewMaybe
                        (\role -> Html.span [ Internal.cls [ "klar-app-shell__user-role" ], Attr.title role ] [ Html.text role ])
                        config.userRole
                    ]
                , Internal.viewMaybe identity config.userMenu
                ]


{-| "Ada Lovelace" -> "AL", "Ada" -> "A"
-}
initials : String -> String
initials name =
    let
        words =
            String.words (String.trim name)

        first word =
            String.left 1 word |> String.toUpper
    in
    case ( List.head words, List.head (List.reverse words) ) of
        ( Just a, Just b ) ->
            if a == b then
                first a

            else
                first a ++ first b

        _ ->
            "?"


viewSidebar : Config msg -> Html msg
viewSidebar config =
    case config.sidebar of
        Just content ->
            Html.aside
                [ Internal.cls [ "klar-app-shell__sidebar" ]
                , Attr.id (sidebarId config.id)
                , Attr.attribute "aria-label" (texts config.locale).sidebar
                ]
                [ content ]

        Nothing ->
            Html.text ""


viewBackdrop : Config msg -> Html msg
viewBackdrop config =
    case ( config.drawerOpen, config.onCloseDrawer ) of
        ( True, Just close ) ->
            Html.div
                [ Internal.cls [ "klar-app-shell__backdrop" ]
                , Attr.attribute "aria-hidden" "true"
                , Events.onClick close
                ]
                []

        ( True, Nothing ) ->
            Html.div [ Internal.cls [ "klar-app-shell__backdrop" ], Attr.attribute "aria-hidden" "true" ] []

        _ ->
            Html.text ""


viewContent : Config msg -> List (Html msg) -> Html msg
viewContent config content =
    Html.main_
        [ Internal.cls [ "klar-app-shell__content" ]
        , Attr.id (contentId config.id)
        , Attr.tabindex -1
        , Internal.styleVars
            [ ( "--klar-content-pad-wide"
              , if config.contentPadding <= 0 then
                    "0px"

                else
                    "var(--klar-space-" ++ String.fromInt (spaceStep config.contentPadding) ++ ")"
              )
            ]
        ]
        [ Html.div
            ([ Internal.cls [ "klar-app-shell__page" ]
             , Attr.id Internal.pageStartId
             , Attr.tabindex -1
             ]
                ++ (case config.contentMaxWidth of
                        Just px ->
                            [ Internal.styleVars [ ( "max-width", String.fromInt px ++ "px" ) ] ]

                        Nothing ->
                            []
                   )
            )
            content
        ]


{-| The nearest step of the 4px spacing scale (1 to 6, 8, 10, 12).
-}
spaceStep : Int -> Int
spaceStep n =
    if n == 7 then
        6

    else if n == 9 then
        8

    else if n == 11 then
        10

    else
        clamp 1 12 n


firstJust : Maybe a -> Maybe a -> Maybe a
firstJust first second =
    case first of
        Just _ ->
            first

        Nothing ->
            second


isJust : Maybe a -> Bool
isJust maybe =
    case maybe of
        Just _ ->
            True

        Nothing ->
            False
