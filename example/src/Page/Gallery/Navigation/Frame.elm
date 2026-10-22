module Page.Gallery.Navigation.Frame exposing
    ( Model
    , Msg
    , init
    , shellSection
    , sideNavSection
    , update
    )

{-| The frame of an application: `AppShell` with a pretend application inside
it, and `SideNav` on its own.
-}

import Html exposing (Html)
import Klar.Alert as Alert
import Klar.AppShell as AppShell
import Klar.Badge as Badge
import Klar.Breadcrumbs as Breadcrumbs
import Klar.Button as Button
import Klar.Card as Card
import Klar.DescriptionList as DescriptionList
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.PageHeader as PageHeader
import Klar.SideNav as SideNav
import Klar.Tabs as Tabs
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Page.Gallery.Navigation.Demo as Demo
import Showcase.Doc as Doc



-- MODEL


type alias Model =
    { -- the application frame
      collapsed : Bool
    , drawerOpen : Bool
    , narrow : Bool
    , modal : Bool
    , banner : Bool
    , page : String
    , nav : SideNav.State String
    , userMenu : Menu.State
    , actionsMenu : Menu.State
    , tabs : Tabs.State
    , crumbs : Breadcrumbs.State
    , lastAction : Maybe String

    -- side navigation on its own
    , navExpanded : SideNav.State String
    , navCollapsed : SideNav.State String
    , navPage : String
    }


init : Model
init =
    { collapsed = False
    , drawerOpen = False
    , narrow = False
    , modal = False
    , banner = False
    , page = "orders"
    , nav = SideNav.init "nav-demo-links" |> SideNav.reveal "orders" Demo.menu
    , userMenu = Menu.init "nav-demo-user"
    , actionsMenu = Menu.init "nav-demo-actions"
    , tabs = Tabs.init "nav-demo-tabs" "overview"
    , crumbs = Breadcrumbs.init "nav-demo-crumbs"
    , lastAction = Nothing
    , navExpanded = SideNav.init "nav-expanded" |> SideNav.reveal "reports-monthly" Demo.menu
    , navCollapsed = SideNav.init "nav-collapsed"
    , navPage = "reports-monthly"
    }



-- UPDATE


type Msg
    = ToggleSidebar
    | ToggleDrawer
    | CloseDrawer
    | ToggleNarrow
    | SetModal Bool
    | ToggleBanner
    | SkipToContent
    | PageSelected String
    | NavMsg SideNav.Msg
    | UserMenuMsg Menu.Msg
    | ActionsMenuMsg Menu.Msg
    | TabsMsg Tabs.Msg
    | CrumbsMsg Breadcrumbs.Msg
    | ExpandedMsg SideNav.Msg
    | CollapsedMsg SideNav.Msg
    | LinkSelected String
    | Action String
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ToggleSidebar ->
            ( { model | collapsed = not model.collapsed }, Cmd.none )

        ToggleDrawer ->
            if model.drawerOpen then
                update CloseDrawer model

            else
                -- Opening: the links come after the whole top bar, so the keyboard
                -- goes to the link of the current page.
                ( { model | drawerOpen = True }, SideNav.focusLink SideNav.stringKeys model.page model.nav NoOp )

        CloseDrawer ->
            -- Closing: the links can no longer hold focus; the menu button gets it.
            ( { model | drawerOpen = False }, AppShell.focusMenuButton shellId NoOp )

        ToggleNarrow ->
            ( { model | narrow = not model.narrow, drawerOpen = False }, Cmd.none )

        SetModal value ->
            ( { model | modal = value }, Cmd.none )

        ToggleBanner ->
            ( { model | banner = not model.banner }, Cmd.none )

        SkipToContent ->
            ( model, AppShell.focusContent shellId NoOp )

        PageSelected key ->
            ( { model | page = key, drawerOpen = False, tabs = Tabs.setActive "overview" model.tabs }
            , Cmd.batch
                [ AppShell.resetScroll shellId NoOp

                -- Chosen in the drawer: its link loses focus as the drawer closes.
                , if model.drawerOpen then
                    AppShell.focusContent shellId NoOp

                  else
                    Cmd.none
                ]
            )

        NavMsg inner ->
            SideNav.update inner model.nav
                |> Tuple.mapBoth (\state -> { model | nav = state }) (Cmd.map NavMsg)

        UserMenuMsg inner ->
            Menu.update inner model.userMenu
                |> Tuple.mapBoth (\state -> { model | userMenu = state }) (Cmd.map UserMenuMsg)

        ActionsMenuMsg inner ->
            Menu.update inner model.actionsMenu
                |> Tuple.mapBoth (\state -> { model | actionsMenu = state }) (Cmd.map ActionsMenuMsg)

        TabsMsg inner ->
            Tabs.update inner model.tabs
                |> Tuple.mapBoth (\state -> { model | tabs = state }) (Cmd.map TabsMsg)

        CrumbsMsg inner ->
            Breadcrumbs.update inner model.crumbs
                |> Tuple.mapBoth (\state -> { model | crumbs = state }) (Cmd.map CrumbsMsg)

        ExpandedMsg inner ->
            SideNav.update inner model.navExpanded
                |> Tuple.mapBoth (\state -> { model | navExpanded = state }) (Cmd.map ExpandedMsg)

        CollapsedMsg inner ->
            SideNav.update inner model.navCollapsed
                |> Tuple.mapBoth (\state -> { model | navCollapsed = state }) (Cmd.map CollapsedMsg)

        LinkSelected key ->
            ( { model | navPage = key }, Cmd.none )

        Action name ->
            ( { model | lastAction = Just name }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )



-- APPLICATION SHELL


shellId : String
shellId =
    "nav-demo-shell"


shellSection : Locale -> Model -> Html Msg
shellSection locale model =
    Doc.section "Application shell"
        "AppShell is the root of the application: a top bar, a sidebar and a content area that scrolls on its own. The page itself never scrolls. On a wide shell (the frame is at least 900 px wide) the button at the top left collapses the sidebar to icons. Below 900 px the sidebar is a drawer, opened with the menu button and closed with Escape or a click outside it. The switch is pure CSS, so the application never needs to know how wide the window is. While a dialog is open the rest of the page is inert, so keyboard focus cannot leave the dialog. The first Tab stop is the link \"Skip to main content\". Try tabbing too, and use the arrow keys in the menu. The built-in text follows the language chosen with the EN/NO control in the top bar of this showcase."
        [ Doc.example
            { title = "The whole frame"
            , description =
                Just
                    (Demo.actionText model.lastAction
                        ++ ". The menu and the tabs work; choose another page to see the header and the breadcrumbs follow along. The links in the preview lead nowhere (the showcase ignores #demo/... addresses), so a click does not leave this page; a real application uses its own routes, such as #/orders. The search field reports an action here. The shortcut Ctrl K belongs to the application: in this showcase it opens the real command palette."
                    )
            , code = Just shellCode
            }
            (Layout.stack [ Layout.gap 3 ]
                [ Layout.row [ Layout.gap 2, Layout.wrap, Layout.alignCenter ]
                    [ Button.view
                        [ Button.icon Icon.sidebar
                        , Button.pressed model.narrow
                        , Button.onClick ToggleNarrow
                        ]
                        "Narrow frame"
                    , Button.view
                        [ Button.icon Icon.lock
                        , Button.pressed model.modal
                        , Button.onClick (SetModal (not model.modal))
                        ]
                        "Simulate an open dialog"
                    , Button.view
                        [ Button.icon Icon.info
                        , Button.pressed model.banner
                        , Button.onClick ToggleBanner
                        ]
                        "Banner"
                    , Text.caption "A narrow frame shows the drawer that is used below 900 px. An open dialog makes the rest of the frame inert."
                    ]
                , shell locale model
                ]
            )
        , Doc.props shellProps
        ]


shellProps : List { name : String, type_ : String, description : String }
shellProps =
    [ { name = "brand, brandLink", type_ = "Html msg, { name, href, logo } -> Html msg", description = "The product name or logo at the top left. brandLink makes a link to the start page; give it a logo, because below 430 px only the logo is left." }
    , { name = "sidebar", type_ = "Html msg", description = "The content of the sidebar, usually SideNav.view. Without a sidebar there is no column and no menu button." }
    , { name = "sidebarCollapsed", type_ = "Bool", description = "Icons only on wide screens. Owned by the application." }
    , { name = "onToggleSidebar", type_ = "msg", description = "Sent by the button in the top bar on wide screens." }
    , { name = "drawerOpen", type_ = "Bool", description = "Is the drawer open on narrow screens? Owned by the application." }
    , { name = "onToggleDrawer", type_ = "msg", description = "Sent by the menu button on narrow screens (onToggleSidebar is used when this is missing)." }
    , { name = "onCloseDrawer", type_ = "msg", description = "A click on the backdrop, and Escape. Close the drawer when the address changes too." }
    , { name = "onSearch", type_ = "msg", description = "Shows the search field in the middle of the top bar. The shortcut (Ctrl K) belongs to the application." }
    , { name = "searchPlaceholder, searchShortcut", type_ = "String, List String", description = "The text and the key caps in the search field. An empty list hides the shortcut." }
    , { name = "actions", type_ = "List (Html msg)", description = "Buttons at the right of the top bar, before the user: language, help, notifications." }
    , { name = "userName, userRole, userAvatar", type_ = "String, String, Html msg", description = "Name and role next to a circle with the initials. userAvatar replaces the circle (an Avatar, a photo)." }
    , { name = "userMenu", type_ = "Html msg", description = "A Menu.view after the name: my profile, sign out." }
    , { name = "banner", type_ = "Html msg", description = "A message above the top bar, for example Alert.banner." }
    , { name = "contentMaxWidth, contentPadding", type_ = "Int", description = "The largest width in pixels, and the space around the content (the 4px scale, default 6)." }
    , { name = "overlays", type_ = "List (Html msg)", description = "Dialogs, drawers and toasts. They are placed outside the inert part." }
    , { name = "modalOpen", type_ = "Bool", description = "Makes the banner, top bar, sidebar and content inert." }
    , { name = "onSkipToContent", type_ = "msg", description = "\"Skip to main content\". Answer it with AppShell.focusContent (a plain #link would change the route)." }
    , { name = "onStrayDrop", type_ = "msg", description = "Cancels a file dropped outside a drop zone, which would make the browser replace the whole application with the file." }
    , { name = "shortcuts", type_ = "Html.Attribute msg", description = "The place for Shortcut.listen: the global keyboard shortcuts of the application." }
    , { name = "height, width", type_ = "Int", description = "Draw the shell as a framed box instead of filling the window. Used by this page." }
    , { name = "id, locale", type_ = "String, Locale", description = "The DOM id (default klar-app-shell) and the language of the built-in text." }
    , { name = "focusContent, focusMenuButton, resetScroll", type_ = "String -> msg -> Cmd msg", description = "Move focus to the content or to the menu button, and scroll the content to the top (the page itself never scrolls, so do it when the route changes)." }
    ]


shell : Locale -> Model -> Html Msg
shell locale model =
    let
        page =
            Demo.pageFor model.page
    in
    AppShell.view
        ([ AppShell.id shellId
         , AppShell.locale locale
         , AppShell.height 560
         , AppShell.brand
            (AppShell.brandLink
                { name = "Acme Logistics"
                , href = Demo.href ""
                , logo = Just (Icon.sized Icon.Large Icon.activity)
                }
            )
         , AppShell.sidebar
            (SideNav.view NavMsg
                [ SideNav.entries Demo.menu
                , SideNav.current model.page
                , SideNav.collapsed model.collapsed
                , SideNav.onSelect PageSelected
                , SideNav.locale locale
                ]
                model.nav
            )
         , AppShell.sidebarCollapsed model.collapsed
         , AppShell.onToggleSidebar ToggleSidebar
         , AppShell.drawerOpen model.drawerOpen
         , AppShell.onToggleDrawer ToggleDrawer
         , AppShell.onCloseDrawer CloseDrawer
         , AppShell.onSearch (Action "Open search")
         , AppShell.actions
            [ Button.iconOnly [ Button.ghost, Button.onClick (Action "Notifications") ] Icon.bell "Notifications"
            , Button.iconOnly [ Button.ghost, Button.onClick (Action "Help") ] Icon.help "Help"
            ]
         , AppShell.userName "Ada Lovelace"
         , AppShell.userRole "Operations manager"
         , AppShell.userMenu
            (Menu.view UserMenuMsg
                [ Menu.kebab "User menu"
                , Menu.alignEnd
                , Menu.trigger [ Button.small ]
                , Menu.items
                    [ Menu.item "My profile" (Action "My profile") |> Menu.withIcon Icon.user
                    , Menu.item "Settings" (Action "User settings") |> Menu.withIcon Icon.settings
                    , Menu.separator
                    , Menu.item "Sign out" (Action "Sign out") |> Menu.withIcon Icon.logOut
                    ]
                ]
                model.userMenu
            )
         , AppShell.contentMaxWidth 1100
         , AppShell.modalOpen model.modal
         , AppShell.onSkipToContent SkipToContent
         , AppShell.overlays
            (if model.modal then
                [ Alert.viewWith
                    [ Alert.tone Warning
                    , Alert.title "Dialog (simulated)"
                    , Alert.actions [ Button.view [ Button.small, Button.onClick (SetModal False) ] "Close the dialog" ]
                    ]
                    [ Text.text "While the dialog is open, the menu, the top bar and the content are inert. Tab stays here, and screen readers skip the rest." ]
                ]

             else
                []
            )
         ]
            ++ (if model.narrow then
                    [ AppShell.width 640 ]

                else
                    []
               )
            ++ (if model.banner then
                    [ AppShell.banner
                        (Alert.view
                            [ Alert.banner
                            , Alert.compact
                            , Alert.tone Info
                            , Alert.onDismiss ToggleBanner
                            , Alert.locale locale
                            ]
                            "Planned maintenance tonight at 02:00. The system will be unavailable for about 15 minutes."
                        )
                    ]

                else
                    []
               )
        )
        [ shellPage locale model page ]


{-| The breadcrumbs of a page: home, the levels above it, the page itself.
-}
trail : Demo.Page -> List Breadcrumbs.Crumb
trail page =
    (Breadcrumbs.link "Home" (Demo.href "") |> Breadcrumbs.withIcon Icon.home)
        :: List.map (\parent -> Breadcrumbs.link parent (Demo.href (String.toLower parent))) page.parents
        ++ [ Breadcrumbs.text page.title ]


shellPage : Locale -> Model -> Demo.Page -> Html Msg
shellPage locale model page =
    Layout.stack [ Layout.gap 0 ]
        [ PageHeader.view
            [ PageHeader.sticky
            , PageHeader.headingLevel 3
            , PageHeader.breadcrumbs
                (Breadcrumbs.view CrumbsMsg
                    [ Breadcrumbs.items (trail page), Breadcrumbs.locale locale ]
                    model.crumbs
                )
            , PageHeader.title page.title
            , PageHeader.subtitle page.subtitle
            , PageHeader.badges [ Badge.view [ Badge.tone Success, Badge.dot ] "Up to date" ]
            , PageHeader.actions
                [ Button.view [ Button.primary, Button.icon Icon.plus, Button.onClick (Action "New") ] "New"
                , Menu.view ActionsMenuMsg
                    [ Menu.kebab "More actions"
                    , Menu.alignEnd
                    , Menu.items
                        [ Menu.item "Export" (Action "Export") |> Menu.withIcon Icon.download
                        , Menu.item "Print" (Action "Print") |> Menu.withIcon Icon.print
                        ]
                    ]
                    model.actionsMenu
                ]
            , PageHeader.tabs
                (Tabs.view TabsMsg
                    [ Tabs.tabs
                        [ Tabs.tab "overview" "Overview"
                        , Tabs.tab "history" "History" |> Tabs.withCount 12
                        , Tabs.tab "files" "Files"
                        , Tabs.tab "admin" "Administration"
                            |> Tabs.disabledTab
                            |> Tabs.withTitle "Requires administrator access"
                        ]
                    , Tabs.ariaLabel "View"
                    ]
                    model.tabs
                )
            ]
        , Layout.stack [ Layout.gap 4 ]
            [ Tabs.panels model.tabs
                [ ( "overview", \_ -> overviewPanel locale page )
                , ( "history", \_ -> filler "History" )
                , ( "files", \_ -> filler "Files" )
                ]
            ]
        ]


overviewPanel : Locale -> Demo.Page -> Html Msg
overviewPanel locale page =
    Layout.stack [ Layout.gap 4 ]
        [ Card.view [ Card.title "Summary", Card.subtitle page.title ]
            [ DescriptionList.view [ DescriptionList.columns 3, DescriptionList.locale locale ]
                [ DescriptionList.text "Created" "12 March 2026"
                , DescriptionList.text "Owner" "Ada Lovelace"
                , DescriptionList.maybe "Cost center" Nothing
                , DescriptionList.html "Status" (Badge.status Success "Active")
                ]
            ]
        , filler "Recent activity"
        , filler "Notes"
        , filler "Attachments"
        , filler "Change log"
        ]


filler : String -> Html Msg
filler title =
    Card.view [ Card.title title ]
        [ Text.paragraph "The content of this area is placeholder text, there to make the page long enough to scroll. Scroll the content area and see that the header with its tabs stays at the top, while the top bar and the sidebar stand still."
        , Text.paragraph "The page as a whole never scrolls, only the content area does. That is also why keyboard focus never moves in behind the top bar."
        ]


shellCode : String
shellCode =
    """AppShell.view
    [ AppShell.id "app"
    , AppShell.brand
        (AppShell.brandLink
            { name = "Acme Logistics"
            , href = "#/"
            , logo = Just (Icon.sized Icon.Large Icon.layers)
            }
        )
    , AppShell.sidebar
        (SideNav.view SideNavMsg
            [ SideNav.entries menu
            , SideNav.current model.page
            , SideNav.collapsed model.sidebarCollapsed
            ]
            model.sideNav
        )
    , AppShell.sidebarCollapsed model.sidebarCollapsed
    , AppShell.onToggleSidebar ToggleSidebar -- wide screen: collapse to icons
    , AppShell.drawerOpen model.drawerOpen
    , AppShell.onToggleDrawer ToggleDrawer -- narrow screen: open the drawer
    , AppShell.onCloseDrawer CloseDrawer -- click outside it, and Escape
    , AppShell.onSearch OpenSearch
    , AppShell.actions [ helpButton, notificationsButton ]
    , AppShell.userName "Ada Lovelace"
    , AppShell.userRole "Operations manager"
    , AppShell.userMenu (Menu.view UserMenuMsg [ Menu.kebab "User menu", Menu.alignEnd, Menu.items [ Menu.item "Sign out" SignOut ] ] model.userMenu)
    , AppShell.modalOpen (Modal.isOpen model.dialog)
    , AppShell.overlays [ Modal.view DialogMsg [ Modal.title "Edit order" ] model.dialog [ orderForm model ] ]
    , AppShell.onSkipToContent SkipToContent -- answer with AppShell.focusContent "app" NoOp
    ]
    [ viewPage model ]"""



-- SIDE NAVIGATION


sideNavSection : Locale -> Model -> Html Msg
sideNavSection locale model =
    Doc.section "Side navigation"
        "SideNav is the menu in the sidebar: sections with a heading, links with an icon and a count, groups that open and close, and disabled entries. The links are ordinary links (href), so routing, middle click and \"open in a new tab\" work. The current page gets aria-current, a blue tint and an accent bar on the left. Which groups are open lives in the state of the menu. Keyboard: Tab moves between the links, Arrow Up and Down move to the previous and next entry, Home and End to the first and last. A collapsed menu shows only icons, with the label as a tooltip (title); a group opens as a small flyout next to its icon while it has the mouse or the keyboard focus."
        [ Doc.example
            { title = "Expanded and collapsed"
            , description = Just "The same menu in two states, sharing the current page: choose a link and both menus follow (onSelect). Hover over, or tab to, the Reports group in the collapsed menu. There the count becomes a dot and the badge is hidden."
            , code = Just sideNavCode
            }
            (Layout.row [ Layout.gap 10, Layout.alignStart, Layout.wrap ]
                [ navPreview "Expanded"
                    (SideNav.view ExpandedMsg
                        [ SideNav.entries Demo.menu
                        , SideNav.current model.navPage
                        , SideNav.onSelect LinkSelected
                        , SideNav.locale locale
                        , SideNav.ariaLabel "Expanded menu"
                        ]
                        model.navExpanded
                    )
                , navPreview "Collapsed"
                    (SideNav.view CollapsedMsg
                        [ SideNav.entries Demo.menu
                        , SideNav.current model.navPage
                        , SideNav.collapsed True
                        , SideNav.onSelect LinkSelected
                        , SideNav.locale locale
                        , SideNav.ariaLabel "Collapsed menu"
                        ]
                        model.navCollapsed
                    )
                ]
            )
        , Doc.props sideNavProps
        ]


navPreview : String -> Html Msg -> Html Msg
navPreview caption nav =
    Layout.stack [ Layout.gap 2 ]
        [ Text.overline caption
        , Card.view [ Card.flush ]
            [ Layout.stack [ Layout.padding 2, Layout.gap 0 ] [ nav ] ]
        ]


sideNavProps : List { name : String, type_ : String, description : String }
sideNavProps =
    [ { name = "item", type_ = "{ key, label, href } -> Entry msg", description = "A link. The key says which link is the current page." }
    , { name = "group", type_ = "{ key, label } -> List (Entry msg) -> Entry msg", description = "A group that opens and closes. Groups can contain groups." }
    , { name = "section, rule", type_ = "String -> List (Entry msg) -> Entry msg, Entry msg", description = "A block with a heading, and a thin line between entries." }
    , { name = "withIcon, withCount, withBadge", type_ = "Entry msg -> Entry msg", description = "An icon, a count (99+ above 99) and any badge. In the collapsed menu the count becomes a dot and the badge is hidden." }
    , { name = "disabledItem", type_ = "Entry msg -> Entry msg", description = "Visible but not clickable. Skipped by Tab and the arrow keys." }
    , { name = "entries, current", type_ = "List (Entry msg), String", description = "The menu, and the key of the current page (aria-current)." }
    , { name = "collapsed", type_ = "Bool", description = "Icons only. Give the same value to AppShell.sidebarCollapsed." }
    , { name = "onSelect", type_ = "String -> msg", description = "A plain left click on a link (not with Ctrl, Cmd or Shift). The link still navigates." }
    , { name = "ariaLabel, locale", type_ = "String, Locale", description = "The name of the nav landmark (default \"Main menu\") and the language of the built-in text." }
    , { name = "init, reveal", type_ = "String -> State, String -> List (Entry msg) -> State -> State", description = "An empty state with a unique id, and opening the groups that hold a link so that it is not hidden." }
    , { name = "expandGroup, collapseGroup, isExpanded", type_ = "String -> State -> ...", description = "Open and close groups from the application." }
    , { name = "focusLink", type_ = "String -> State -> msg -> Cmd msg", description = "Moves keyboard focus to a link, for example when the drawer opens." }
    ]


sideNavCode : String
sideNavCode =
    """SideNav.view SideNavMsg
    [ SideNav.entries menu
    , SideNav.current "orders"
    ]
    model.sideNav


menu : List (SideNav.Entry String msg)
menu =
    [ SideNav.section "Workspace"
        [ SideNav.item SideNav.stringKeys { key = "overview", label = "Overview", href = "#/" }
            |> SideNav.withIcon Icon.home
        , SideNav.item SideNav.stringKeys { key = "orders", label = "Orders", href = "#/orders" }
            |> SideNav.withIcon Icon.clipboardCheck
            |> SideNav.withCount 12
        , SideNav.group SideNav.stringKeys { key = "reports", label = "Reports" }
            [ SideNav.item SideNav.stringKeys { key = "monthly", label = "Monthly report", href = "#/reports/monthly" } ]
            |> SideNav.withIcon Icon.barChart
        ]
    ]


-- start with the right group open:
SideNav.init "main-nav" |> SideNav.reveal "monthly" menu"""
