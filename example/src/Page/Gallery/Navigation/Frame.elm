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
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Modal as Modal
import Klar.PageHeader as PageHeader
import Klar.SideNav as SideNav
import Klar.Tabs as Tabs
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Page.Gallery.Navigation.Demo as Demo
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options



-- MODEL


{-| The views of a page in the demo, the keys of its tab strip.
-}
type View
    = OverviewView
    | HistoryView
    | FilesView
    | AdminView


type alias Model =
    { -- the application frame
      collapsed : Bool
    , drawerOpen : Bool
    , narrow : Bool
    , modal : Modal.State
    , banner : Bool
    , page : String
    , nav : SideNav.State String
    , userMenu : Menu.State
    , actionsMenu : Menu.State
    , tabs : Tabs.State View
    , crumbs : Breadcrumbs.State
    , lastAction : Maybe String

    -- side navigation on its own
    , navExpanded : SideNav.State String
    , navCollapsed : SideNav.State String
    , navPage : String
    }


init : Config.Config -> Model
init playground =
    { collapsed = False
    , drawerOpen = False
    , narrow = False
    , modal = Modal.init "frame-demo-dialog"
    , banner = False
    , page = "orders"
    , nav = SideNav.init "nav-demo-links" |> SideNav.reveal "orders" (Demo.menu playground)
    , userMenu = Menu.init "nav-demo-user"
    , actionsMenu = Menu.init "nav-demo-actions"
    , tabs = Tabs.init "nav-demo-tabs" OverviewView
    , crumbs = Breadcrumbs.init "nav-demo-crumbs"
    , lastAction = Nothing
    , navExpanded = SideNav.init "nav-expanded" |> SideNav.reveal "reports-monthly" (Demo.menu playground)
    , navCollapsed = SideNav.init "nav-collapsed"
    , navPage = "reports-monthly"
    }



-- UPDATE


type Msg
    = ToggleSidebar
    | ToggleDrawer
    | CloseDrawer
    | ToggleNarrow
    | OpenModal
    | CloseModal
    | ModalMsg Modal.Msg
    | ToggleBanner
    | SkipToContent
    | PageSelected String
    | NavMsg SideNav.Msg
    | UserMenuMsg Menu.Msg
    | ActionsMenuMsg Menu.Msg
    | TabsMsg (Tabs.Msg View)
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
                ( { model | drawerOpen = True }, SideNav.focusLink Ids.string model.page model.nav NoOp )

        CloseDrawer ->
            -- Closing: the links can no longer hold focus; the menu button gets it.
            ( { model | drawerOpen = False }, AppShell.focusMenuButton shellId NoOp )

        ToggleNarrow ->
            ( { model | narrow = not model.narrow, drawerOpen = False }, Cmd.none )

        OpenModal ->
            let
                ( modal, cmd ) =
                    Modal.open "frame-demo-open" model.modal
            in
            ( { model | modal = modal }, Cmd.map ModalMsg cmd )

        CloseModal ->
            let
                ( modal, cmd ) =
                    Modal.close model.modal
            in
            ( { model | modal = modal }, Cmd.map ModalMsg cmd )

        ModalMsg inner ->
            let
                ( modal, cmd ) =
                    Modal.update inner model.modal
            in
            ( { model | modal = modal }, Cmd.map ModalMsg cmd )

        ToggleBanner ->
            ( { model | banner = not model.banner }, Cmd.none )

        SkipToContent ->
            ( model, AppShell.focusContent shellId NoOp )

        PageSelected key ->
            ( { model | page = key, drawerOpen = False, tabs = Tabs.setActive OverviewView model.tabs }
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


shellSection : Config.Config -> Locale -> Model -> Html Msg
shellSection playground locale model =
    Doc.configuredSection playground
        [ "AppShell" ]
        "Application shell"
        "AppShell is the root of the application: a top bar, a sidebar and a content area that scrolls on its own. The page itself never scrolls. On a wide shell (the frame is at least 900 px wide) the button at the top left collapses the sidebar to icons. Below 900 px the sidebar is a drawer, opened with the menu button and closed with Escape or a click outside it. The switch is pure CSS, so the application never needs to know how wide the window is. While a dialog is open the rest of the page is inert, so keyboard focus cannot leave the dialog. The first Tab stop is the link \"Skip to main content\". Try tabbing too, and use the arrow keys in the menu. The built-in text follows the language chosen with the EN/NO control in the top bar of this showcase."
        [ Doc.configuredExample playground
            [ "AppShell" ]
            { title = "The whole frame"
            , description =
                Just
                    (Demo.actionText model.lastAction
                        ++ ". The menu and the tabs work; choose another page to see the header and the breadcrumbs follow along. The links in the preview lead nowhere (the showcase ignores #demo/... addresses), so a click does not leave this page; a real application uses its own routes, such as #/orders. The search field reports an action here. The shortcut Ctrl K belongs to the application: in this showcase it opens the real command palette."
                    )
            , code = Just shellCode
            }
            (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "wrap" Layout.wrap, Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                    [ Options.buttonView playground
                        (Options.klarButton playground
                            (List.concat
                                [ Config.keep playground "Button" "icon" (Button.icon Icon.sidebar)
                                , Config.keep playground "Button" "pressed" (Button.pressed model.narrow)
                                , Config.keep playground "Button" "onClick" (Button.onClick ToggleNarrow)
                                ]
                            )
                        )
                        "Narrow frame"
                    , Options.buttonView playground
                        (Options.klarButton playground
                            (List.concat
                                [ Config.keep playground "Button" "icon" (Button.icon Icon.lock)
                                , Config.keep playground "Button" "id" (Button.id "frame-demo-open")
                                , Config.keep playground "Button" "onClick" (Button.onClick OpenModal)
                                ]
                            )
                        )
                        "Open a dialog"
                    , Options.buttonView playground
                        (Options.klarButton playground
                            (List.concat
                                [ Config.keep playground "Button" "icon" (Button.icon Icon.info)
                                , Config.keep playground "Button" "pressed" (Button.pressed model.banner)
                                , Config.keep playground "Button" "onClick" (Button.onClick ToggleBanner)
                                ]
                            )
                        )
                        "Banner"
                    , Text.caption "A narrow frame shows the drawer that is used below 900 px. An open dialog makes the rest of the frame inert."
                    ]
                , shell playground locale model
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
    , { name = "overlays", type_ = "List (Overlay msg)", description = "Dialogs, drawers, the palette and toasts, as their views return them. They are placed outside the part that becomes inert while one of them is open." }
    , { name = "onSkipToContent", type_ = "msg", description = "\"Skip to main content\". Answer it with AppShell.focusContent (a plain #link would change the route)." }
    , { name = "onStrayDrop", type_ = "msg", description = "Cancels a file dropped outside a drop zone, which would make the browser replace the whole application with the file." }
    , { name = "shortcuts", type_ = "Html.Attribute msg", description = "The place for Shortcut.listen: the global keyboard shortcuts of the application." }
    , { name = "height, width", type_ = "Int", description = "Draw the shell as a framed box instead of filling the window. Used by this page." }
    , { name = "id, locale", type_ = "String, Locale", description = "The DOM id (default klar-app-shell) and the language of the built-in text." }
    , { name = "focusContent, focusMenuButton, resetScroll", type_ = "String -> msg -> Cmd msg", description = "Move focus to the content or to the menu button, and scroll the content to the top (the page itself never scrolls, so do it when the route changes)." }
    ]


shell : Config.Config -> Locale -> Model -> Html Msg
shell playground locale model =
    let
        page =
            Demo.pageFor model.page
    in
    AppShell.view
        (Options.klarAppShell playground
            (List.concat
                [ Config.keep playground "AppShell" "id" (AppShell.id shellId)
                , Config.keep playground "AppShell" "locale" (AppShell.locale locale)
                , Config.keep playground "AppShell" "height" (AppShell.height 560)
                , Config.keep playground
                    "AppShell"
                    "brand"
                    (AppShell.brand
                        (AppShell.brandLink
                            { name = "Acme Logistics"
                            , href = Demo.href ""
                            , logo = Just (Icon.sized Icon.Large Icon.activity)
                            }
                        )
                    )
                , Config.keep playground
                    "AppShell"
                    "sidebar"
                    (AppShell.sidebar
                        (SideNav.view NavMsg
                            (Options.klarSideNav playground
                                (List.concat
                                    [ Config.keep playground "SideNav" "entries" (SideNav.entries (Demo.menu playground))
                                    , Config.keep playground "SideNav" "current" (SideNav.current model.page)
                                    , Config.keep playground "SideNav" "collapsed" (SideNav.collapsed model.collapsed)
                                    , Config.keep playground "SideNav" "onSelect" (SideNav.onSelect PageSelected)
                                    , Config.keep playground "SideNav" "locale" (SideNav.locale locale)
                                    ]
                                )
                            )
                            model.nav
                        )
                    )
                , Config.keep playground "AppShell" "sidebarCollapsed" (AppShell.sidebarCollapsed model.collapsed)
                , Config.keep playground "AppShell" "onToggleSidebar" (AppShell.onToggleSidebar ToggleSidebar)
                , Config.keep playground "AppShell" "drawerOpen" (AppShell.drawerOpen model.drawerOpen)
                , Config.keep playground "AppShell" "onToggleDrawer" (AppShell.onToggleDrawer ToggleDrawer)
                , Config.keep playground "AppShell" "onCloseDrawer" (AppShell.onCloseDrawer CloseDrawer)
                , Config.keep playground "AppShell" "onSearch" (AppShell.onSearch (Action "Open search"))
                , Config.keep playground
                    "AppShell"
                    "actions"
                    (AppShell.actions
                        [ Button.iconOnly (Options.klarButton playground (List.concat [ Config.keep playground "Button" "ghost" Button.ghost, Config.keep playground "Button" "onClick" (Button.onClick (Action "Notifications")) ])) Icon.bell "Notifications"
                        , Button.iconOnly (Options.klarButton playground (List.concat [ Config.keep playground "Button" "ghost" Button.ghost, Config.keep playground "Button" "onClick" (Button.onClick (Action "Help")) ])) Icon.help "Help"
                        ]
                    )
                , Config.keep playground "AppShell" "userName" (AppShell.userName "Ada Lovelace")
                , Config.keep playground "AppShell" "userRole" (AppShell.userRole "Operations manager")
                , Config.keep playground
                    "AppShell"
                    "userMenu"
                    (AppShell.userMenu
                        (Menu.view UserMenuMsg
                            (Options.klarMenu playground
                                (List.concat
                                    [ Config.keep playground "Menu" "kebab" (Menu.kebab "User menu")
                                    , Config.keep playground "Menu" "alignEnd" Menu.alignEnd
                                    , Config.keep playground "Menu" "trigger" (Menu.trigger (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small ])))
                                    , Config.keep playground
                                        "Menu"
                                        "items"
                                        (Menu.items
                                            [ Menu.item "My profile" (Action "My profile") |> Menu.withIcon Icon.user
                                            , Menu.item "Settings" (Action "User settings") |> Menu.withIcon Icon.settings
                                            , Menu.separator
                                            , Menu.item "Sign out" (Action "Sign out") |> Menu.withIcon Icon.logOut
                                            ]
                                        )
                                    ]
                                )
                            )
                            model.userMenu
                        )
                    )
                , Config.keep playground "AppShell" "contentMaxWidth" (AppShell.contentMaxWidth 1100)
                , Config.keep playground "AppShell" "onSkipToContent" (AppShell.onSkipToContent SkipToContent)
                , Config.keep playground
                    "AppShell"
                    "overlays"
                    (AppShell.overlays
                        [ Modal.view ModalMsg
                            (Options.klarModal playground
                                (List.concat
                                    [ Config.keep playground "Modal" "small" Modal.small
                                    , Config.keep playground "Modal" "footer" (Modal.footer [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "onClick" (Button.onClick CloseModal) ])) "Close" ])
                                    ]
                                )
                            )
                            model.modal
                            "A dialog"
                            [ Text.text "While the dialog is open, the menu, the top bar and the content are inert. Tab stays here, and screen readers skip the rest." ]
                        ]
                    )
                ]
            )
            ++ (if model.narrow then
                    Options.klarAppShell playground (List.concat [ Config.keep playground "AppShell" "width" (AppShell.width 640) ])

                else
                    []
               )
            ++ (if model.banner then
                    Options.klarAppShell playground
                        (List.concat
                            [ Config.keep playground
                                "AppShell"
                                "banner"
                                (AppShell.banner
                                    (Options.alertView playground
                                        (Options.klarAlert playground
                                            (List.concat
                                                [ Config.keep playground "Alert" "banner" Alert.banner
                                                , Config.keep playground "Alert" "compact" Alert.compact
                                                , Config.keep playground "Alert" "tone" (Alert.tone Info)
                                                , Config.keep playground "Alert" "onDismiss" (Alert.onDismiss ToggleBanner)
                                                , Config.keep playground "Alert" "locale" (Alert.locale locale)
                                                ]
                                            )
                                        )
                                        "Planned maintenance tonight at 02:00. The system will be unavailable for about 15 minutes."
                                    )
                                )
                            ]
                        )

                else
                    []
               )
        )
        [ shellPage playground locale model page ]


{-| The breadcrumbs of a page: home, the levels above it, the page itself.
-}
trail : Demo.Page -> List (Breadcrumbs.Crumb Msg)
trail page =
    (Breadcrumbs.link { label = "Home", href = Demo.href "" } |> Breadcrumbs.withIcon Icon.home)
        :: List.map (\parent -> Breadcrumbs.link { label = parent, href = Demo.href (String.toLower parent) }) page.parents
        ++ [ Breadcrumbs.text page.title ]


shellPage : Config.Config -> Locale -> Model -> Demo.Page -> Html Msg
shellPage playground locale model page =
    Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 0) ]))
        [ PageHeader.view
            (Options.klarPageHeader playground
                (List.concat
                    [ Config.keep playground "PageHeader" "sticky" PageHeader.sticky
                    , Config.keep playground "PageHeader" "headingLevel" (PageHeader.headingLevel 3)
                    , Config.keep playground
                        "PageHeader"
                        "breadcrumbs"
                        (PageHeader.breadcrumbs
                            (Breadcrumbs.view CrumbsMsg
                                (Options.klarBreadcrumbs playground (List.concat [ Config.keep playground "Breadcrumbs" "items" (Breadcrumbs.items (trail page)), Config.keep playground "Breadcrumbs" "locale" (Breadcrumbs.locale locale) ]))
                                model.crumbs
                            )
                        )
                    , Config.keep playground "PageHeader" "title" (PageHeader.title page.title)
                    , Config.keep playground "PageHeader" "subtitle" (PageHeader.subtitle page.subtitle)
                    , Config.keep playground "PageHeader" "badges" (PageHeader.badges [ Options.badgeView playground (Options.klarBadge playground (List.concat [ Config.keep playground "Badge" "tone" (Badge.tone Success), Config.keep playground "Badge" "dot" Badge.dot ])) "Up to date" ])
                    , Config.keep playground
                        "PageHeader"
                        "actions"
                        (PageHeader.actions
                            [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "icon" (Button.icon Icon.plus), Config.keep playground "Button" "onClick" (Button.onClick (Action "New")) ])) "New"
                            , Menu.view ActionsMenuMsg
                                (Options.klarMenu playground
                                    (List.concat
                                        [ Config.keep playground "Menu" "kebab" (Menu.kebab "More actions")
                                        , Config.keep playground "Menu" "alignEnd" Menu.alignEnd
                                        , Config.keep playground
                                            "Menu"
                                            "items"
                                            (Menu.items
                                                [ Menu.item "Export" (Action "Export") |> Menu.withIcon Icon.download
                                                , Menu.item "Print" (Action "Print") |> Menu.withIcon Icon.print
                                                ]
                                            )
                                        ]
                                    )
                                )
                                model.actionsMenu
                            ]
                        )
                    , Config.keep playground
                        "PageHeader"
                        "tabs"
                        (PageHeader.tabs
                            (Tabs.view TabsMsg
                                (Options.klarTabs playground
                                    (List.concat
                                        [ Config.keep playground
                                            "Tabs"
                                            "tabs"
                                            (Tabs.tabs
                                                [ Tabs.tab OverviewView "Overview"
                                                , Tabs.tab HistoryView "History" |> Tabs.withCount 12
                                                , Tabs.tab FilesView "Files"
                                                , Tabs.tab AdminView "Administration"
                                                    |> Tabs.disabledTab
                                                    |> Tabs.withTitle "Requires administrator access"
                                                ]
                                            )
                                        , Config.keep playground "Tabs" "ariaLabel" (Tabs.ariaLabel "View")
                                        ]
                                    )
                                )
                                model.tabs
                            )
                        )
                    ]
                )
            )
        , Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
            [ -- The strip is in the header, the view of the active tab is the page.
              case Tabs.active model.tabs of
                OverviewView ->
                    overviewPanel playground locale page

                HistoryView ->
                    filler playground "History"

                FilesView ->
                    filler playground "Files"

                AdminView ->
                    filler playground "Administration"
            ]
        ]


overviewPanel : Config.Config -> Locale -> Demo.Page -> Html Msg
overviewPanel playground locale page =
    Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
        [ Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title "Summary"), Config.keep playground "Card" "subtitle" (Card.subtitle page.title) ]))
            [ DescriptionList.view (Options.klarDescriptionList playground (List.concat [ Config.keep playground "DescriptionList" "columns" (DescriptionList.columns 3), Config.keep playground "DescriptionList" "locale" (DescriptionList.locale locale) ]))
                [ DescriptionList.text "Created" "12 March 2026"
                , DescriptionList.text "Owner" "Ada Lovelace"
                , DescriptionList.maybe "Cost center" Nothing
                , DescriptionList.html "Status" (Badge.status Success "Active")
                ]
            ]
        , filler playground "Recent activity"
        , filler playground "Notes"
        , filler playground "Attachments"
        , filler playground "Change log"
        ]


filler : Config.Config -> String -> Html Msg
filler playground title =
    Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title title) ]))
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
    , AppShell.overlays [ Modal.view DialogMsg [] model.dialog "Edit order" [ orderForm model ] ]
    , AppShell.onSkipToContent SkipToContent -- answer with AppShell.focusContent "app" NoOp
    ]
    [ viewPage model ]"""



-- SIDE NAVIGATION


sideNavSection : Config.Config -> Locale -> Model -> Html Msg
sideNavSection playground locale model =
    Doc.configuredSection playground
        [ "SideNav" ]
        "Side navigation"
        "SideNav is the menu in the sidebar: sections with a heading, links with an icon and a count, groups that open and close, and disabled entries. The links are ordinary links (href), so routing, middle click and \"open in a new tab\" work. The current page gets aria-current, a blue tint and an accent bar on the left. Which groups are open lives in the state of the menu. Keyboard: Tab moves between the links, Arrow Up and Down move to the previous and next entry, Home and End to the first and last. A collapsed menu shows only icons, with the label as a tooltip (title); a group opens as a small flyout next to its icon while it has the mouse or the keyboard focus."
        [ Doc.configuredExample playground
            [ "SideNav" ]
            { title = "Expanded and collapsed"
            , description = Just "The same menu in two states, sharing the current page: choose a link and both menus follow (onSelect). Hover over, or tab to, the Reports group in the collapsed menu. There the count becomes a dot and the badge is hidden."
            , code = Just sideNavCode
            }
            (Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 10), Config.keep playground "Layout" "alignStart" Layout.alignStart, Config.keep playground "Layout" "wrap" Layout.wrap ]))
                [ navPreview playground
                    "Expanded"
                    (SideNav.view ExpandedMsg
                        (Options.klarSideNav playground
                            (List.concat
                                [ Config.keep playground "SideNav" "entries" (SideNav.entries (Demo.menu playground))
                                , Config.keep playground "SideNav" "current" (SideNav.current model.navPage)
                                , Config.keep playground "SideNav" "onSelect" (SideNav.onSelect LinkSelected)
                                , Config.keep playground "SideNav" "locale" (SideNav.locale locale)
                                , Config.keep playground "SideNav" "ariaLabel" (SideNav.ariaLabel "Expanded menu")
                                ]
                            )
                        )
                        model.navExpanded
                    )
                , navPreview playground
                    "Collapsed"
                    (SideNav.view CollapsedMsg
                        (Options.klarSideNav playground
                            (List.concat
                                [ Config.keep playground "SideNav" "entries" (SideNav.entries (Demo.menu playground))
                                , Config.keep playground "SideNav" "current" (SideNav.current model.navPage)
                                , Config.keep playground "SideNav" "collapsed" (SideNav.collapsed True)
                                , Config.keep playground "SideNav" "onSelect" (SideNav.onSelect LinkSelected)
                                , Config.keep playground "SideNav" "locale" (SideNav.locale locale)
                                , Config.keep playground "SideNav" "ariaLabel" (SideNav.ariaLabel "Collapsed menu")
                                ]
                            )
                        )
                        model.navCollapsed
                    )
                ]
            )
        , Doc.props sideNavProps
        ]


navPreview : Config.Config -> String -> Html Msg -> Html Msg
navPreview playground caption nav =
    Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ]))
        [ Text.overline caption
        , Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "flush" Card.flush ]))
            [ Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "padding" (Layout.padding 2), Config.keep playground "Layout" "gap" (Layout.gap 0) ])) [ nav ] ]
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
        [ SideNav.item Ids.string { key = "overview", label = "Overview", href = "#/" }
            |> SideNav.withIcon Icon.home
        , SideNav.item Ids.string { key = "orders", label = "Orders", href = "#/orders" }
            |> SideNav.withIcon Icon.clipboardCheck
            |> SideNav.withCount 12
        , SideNav.group Ids.string { key = "reports", label = "Reports" }
            [ SideNav.item Ids.string { key = "monthly", label = "Monthly report", href = "#/reports/monthly" } ]
            |> SideNav.withIcon Icon.barChart
        ]
    ]


-- start with the right group open:
SideNav.init "main-nav" |> SideNav.reveal "monthly" menu"""
