module Page.Gallery.Navigation.Header exposing
    ( Model
    , Msg
    , breadcrumbsSection
    , init
    , pageHeaderSection
    , tabsSection
    , update
    )

{-| What sits at the top of a page: `PageHeader`, `Breadcrumbs` and `Tabs`.
-}

import Html exposing (Html)
import Klar.Badge as Badge
import Klar.Breadcrumbs as Breadcrumbs
import Klar.Button as Button
import Klar.DescriptionList as DescriptionList
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.PageHeader as PageHeader
import Klar.Tabs as Tabs
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Page.Gallery.Navigation.Demo as Demo
import Showcase.Doc as Doc



-- MODEL


type alias Model =
    { -- page header
      headerMenu : Menu.State
    , headerTabs : Tabs.State
    , lastAction : Maybe String

    -- breadcrumbs
    , crumbs : Breadcrumbs.State
    , crumbsDeep : Breadcrumbs.State

    -- tabs
    , lineTabs : Tabs.State
    , boxedTabs : Tabs.State
    , iconTabs : Tabs.State
    , manualTabs : Tabs.State
    , overflowTabs : Tabs.State
    }


init : Model
init =
    { headerMenu = Menu.init "nav-header-menu"
    , headerTabs = Tabs.init "nav-header-tabs" "overview"
    , lastAction = Nothing
    , crumbs = Breadcrumbs.init "nav-crumbs"
    , crumbsDeep = Breadcrumbs.init "nav-crumbs-deep"
    , lineTabs = Tabs.init "nav-line-tabs" "overview"
    , boxedTabs = Tabs.init "nav-boxed-tabs" "history"
    , iconTabs = Tabs.init "nav-icon-tabs" "inbox"
    , manualTabs = Tabs.init "nav-manual-tabs" "a"
    , overflowTabs = Tabs.init "nav-overflow-tabs" "t1"
    }



-- UPDATE


type Msg
    = HeaderMenuMsg Menu.Msg
    | HeaderTabsMsg Tabs.Msg
    | CrumbsMsg Breadcrumbs.Msg
    | CrumbsDeepMsg Breadcrumbs.Msg
    | LineTabsMsg Tabs.Msg
    | BoxedTabsMsg Tabs.Msg
    | IconTabsMsg Tabs.Msg
    | ManualTabsMsg Tabs.Msg
    | OverflowTabsMsg Tabs.Msg
    | Action String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        HeaderMenuMsg inner ->
            Menu.update inner model.headerMenu
                |> Tuple.mapBoth (\state -> { model | headerMenu = state }) (Cmd.map HeaderMenuMsg)

        HeaderTabsMsg inner ->
            Tabs.update inner model.headerTabs
                |> Tuple.mapBoth (\state -> { model | headerTabs = state }) (Cmd.map HeaderTabsMsg)

        CrumbsMsg inner ->
            Breadcrumbs.update inner model.crumbs
                |> Tuple.mapBoth (\state -> { model | crumbs = state }) (Cmd.map CrumbsMsg)

        CrumbsDeepMsg inner ->
            Breadcrumbs.update inner model.crumbsDeep
                |> Tuple.mapBoth (\state -> { model | crumbsDeep = state }) (Cmd.map CrumbsDeepMsg)

        LineTabsMsg inner ->
            Tabs.update inner model.lineTabs
                |> Tuple.mapBoth (\state -> { model | lineTabs = state }) (Cmd.map LineTabsMsg)

        BoxedTabsMsg inner ->
            Tabs.update inner model.boxedTabs
                |> Tuple.mapBoth (\state -> { model | boxedTabs = state }) (Cmd.map BoxedTabsMsg)

        IconTabsMsg inner ->
            Tabs.update inner model.iconTabs
                |> Tuple.mapBoth (\state -> { model | iconTabs = state }) (Cmd.map IconTabsMsg)

        ManualTabsMsg inner ->
            Tabs.update inner model.manualTabs
                |> Tuple.mapBoth (\state -> { model | manualTabs = state }) (Cmd.map ManualTabsMsg)

        OverflowTabsMsg inner ->
            Tabs.update inner model.overflowTabs
                |> Tuple.mapBoth (\state -> { model | overflowTabs = state }) (Cmd.map OverflowTabsMsg)

        Action name ->
            ( { model | lastAction = Just name }, Cmd.none )



-- PAGE HEADER


pageHeaderSection : Locale -> Model -> Html Msg
pageHeaderSection locale model =
    Doc.section "Page header"
        "PageHeader gathers what belongs at the top of a page: breadcrumbs, title, subtitle, status badges, key facts, actions and tabs. Everything except the title is optional, and a part you leave out takes no room. The title is the h1 of the page, so a real page has one header; this page shows several side by side and gives them headingLevel 3, which changes the element and nothing else. band makes the header a white band across the full width, and sticky keeps the band at the top while the page scrolls (see the frame above)."
        [ Doc.example
            { title = "Full header"
            , description = Just (Demo.actionText model.lastAction ++ ". Every part is used: breadcrumbs, title, subtitle, badges, key facts, actions (one of them a menu) and tabs.")
            , code = Just pageHeaderCode
            }
            (PageHeader.view
                [ PageHeader.headingLevel 3
                , PageHeader.breadcrumbs
                    (Breadcrumbs.static
                        [ Breadcrumbs.items
                            [ Breadcrumbs.link "Home" (Demo.href "") |> Breadcrumbs.withIcon Icon.home
                            , Breadcrumbs.link "Orders" (Demo.href "orders")
                            , Breadcrumbs.text "Order 10482"
                            ]
                        , Breadcrumbs.locale locale
                        ]
                    )
                , PageHeader.title "Order 10482"
                , PageHeader.subtitle "Placed by Ada Lovelace on 12 March 2026"
                , PageHeader.badges
                    [ Badge.view [ Badge.tone Info, Badge.dot ] "Confirmed"
                    , Badge.view [ Badge.tone Warning ] "Waiting for documents"
                    ]
                , PageHeader.meta
                    [ PageHeader.metaItem "Order number" "10482"
                    , PageHeader.metaItem "Warehouse" "Rotterdam"
                    , PageHeader.metaItem "Last changed" "2 hours ago"
                    ]
                , PageHeader.actions
                    [ Button.view [ Button.primary, Button.icon Icon.edit, Button.onClick (Action "Edit") ] "Edit"
                    , Button.view [ Button.icon Icon.mail, Button.onClick (Action "Send confirmation") ] "Send confirmation"
                    , Menu.view HeaderMenuMsg
                        [ Menu.kebab "More actions"
                        , Menu.alignEnd
                        , Menu.items
                            [ Menu.item "Duplicate" (Action "Duplicate") |> Menu.withIcon Icon.copy
                            , Menu.item "Archive" (Action "Archive") |> Menu.withIcon Icon.archive
                            , Menu.separator
                            , Menu.item "Delete" (Action "Delete") |> Menu.withIcon Icon.trash |> Menu.danger
                            ]
                        ]
                        model.headerMenu
                    ]
                , PageHeader.tabs
                    (Tabs.view HeaderTabsMsg
                        [ Tabs.ariaLabel "Order"
                        , Tabs.withoutPanels
                        , Tabs.tabs
                            [ Tabs.tab "overview" "Overview"
                            , Tabs.tab "activity" "Activity" |> Tabs.withCount 48
                            , Tabs.tab "documents" "Documents" |> Tabs.withCount 3
                            ]
                        ]
                        model.headerTabs
                    )
                ]
            )
        , Doc.example
            { title = "Simple, with a back link, and with a long title"
            , description = Just "Only a title and a subtitle; a back link, a status badge and two buttons; and a title that wraps over several lines without pushing the buttons out of the picture."
            , code = Just pageHeaderSimpleCode
            }
            (Layout.stack [ Layout.gap 6 ]
                [ PageHeader.view
                    [ PageHeader.headingLevel 3
                    , PageHeader.title "Reports"
                    , PageHeader.subtitle "Choose a report in the menu on the left."
                    ]
                , Layout.divider
                , PageHeader.view
                    [ PageHeader.headingLevel 3
                    , PageHeader.backLink { href = Demo.href "orders", label = "Back to orders" }
                    , PageHeader.title "New order"
                    , PageHeader.badges [ Badge.view [ Badge.tone Info ] "Draft" ]
                    , PageHeader.actions
                        [ Button.view [ Button.onClick (Action "Cancel") ] "Cancel"
                        , Button.view [ Button.primary, Button.onClick (Action "Save") ] "Save"
                        ]
                    ]
                , Layout.divider
                , PageHeader.view
                    [ PageHeader.headingLevel 3
                    , PageHeader.title "A very long title that goes on and on, so that it has to wrap over several lines without pushing the buttons out of the picture"
                    , PageHeader.subtitle "A long title and many actions wrap neatly."
                    , PageHeader.actions
                        [ Button.view [ Button.primary ] "Primary"
                        , Button.view [] "Secondary"
                        , Button.view [] "Tertiary"
                        ]
                    ]
                ]
            )
        ]


pageHeaderCode : String
pageHeaderCode =
    """PageHeader.view
    [ PageHeader.breadcrumbs (Breadcrumbs.view CrumbsMsg [ Breadcrumbs.items trail ] model.crumbs)
    , PageHeader.title "Order 10482"
    , PageHeader.subtitle "Placed by Ada Lovelace on 12 March 2026"
    , PageHeader.badges [ Badge.view [ Badge.tone Info, Badge.dot ] "Confirmed" ]
    , PageHeader.meta [ PageHeader.metaItem "Order number" "10482" ]
    , PageHeader.actions
        [ Button.view [ Button.primary, Button.icon Icon.edit, Button.onClick Edit ] "Edit"
        , Menu.view MenuMsg [ Menu.kebab "More actions", Menu.alignEnd, Menu.items [ Menu.item "Duplicate" Duplicate ] ] model.menu
        ]
    , PageHeader.tabs
        (Tabs.view TabsMsg
            [ Tabs.withoutPanels
            , Tabs.tabs [ Tabs.tab "overview" "Overview", Tabs.tab "activity" "Activity" |> Tabs.withCount 48 ]
            ]
            model.tabs
        )
    , PageHeader.sticky -- a white band that stays at the top
    ]"""


pageHeaderSimpleCode : String
pageHeaderSimpleCode =
    """PageHeader.view
    [ PageHeader.backLink { href = "#/orders", label = "Back to orders" }
    , PageHeader.title "New order"
    , PageHeader.badges [ Badge.view [ Badge.tone Info ] "Draft" ]
    , PageHeader.actions
        [ Button.view [ Button.onClick Cancel ] "Cancel"
        , Button.view [ Button.primary, Button.onClick Save ] "Save"
        ]
    ]"""



-- BREADCRUMBS


{-| Six levels: home, four places and the page itself.
-}
crumbTrail : List Breadcrumbs.Crumb
crumbTrail =
    [ Breadcrumbs.link "Home" (Demo.href "") |> Breadcrumbs.withIcon Icon.home
    , Breadcrumbs.link "Europe" (Demo.href "europe")
    , Breadcrumbs.link "Netherlands" (Demo.href "netherlands")
    , Breadcrumbs.link "Rotterdam" (Demo.href "rotterdam")
    , Breadcrumbs.link "Warehouse 3" (Demo.href "warehouse-3")
    , Breadcrumbs.text "Aisle 3B"
    ]


breadcrumbsSection : Locale -> Model -> Html Msg
breadcrumbsSection locale model =
    Doc.section "Breadcrumbs"
        "The path to the current page, with a chevron between the levels. The last level is the current page (aria-current) and is not a link. When the trail is longer than maxItems, the levels in the middle fold into a \"more\" button that opens a list of links (Escape closes it, Arrow Up and Down move between the links). Long names are cut with an ellipsis and show the whole name as a tooltip."
        [ Doc.example
            { title = "Short trail without state"
            , description = Just "A trail that never grows long needs no state: use static."
            , code = Just breadcrumbsStaticCode
            }
            (Breadcrumbs.static
                [ Breadcrumbs.items
                    [ Breadcrumbs.link "Home" (Demo.href "") |> Breadcrumbs.withIcon Icon.home
                    , Breadcrumbs.link "Orders" (Demo.href "orders")
                    , Breadcrumbs.text "Order 10482"
                    ]
                , Breadcrumbs.locale locale
                ]
            )
        , Doc.example
            { title = "Long trail that folds"
            , description = Just "Six levels, at most four visible: the first level and the last three stay. Below it the same trail with at most three visible, and at the bottom a static trail (it never folds) with long names in a narrow space, where the names are cut."
            , code = Just "Breadcrumbs.view CrumbsMsg\n    [ Breadcrumbs.items trail, Breadcrumbs.maxItems 4 ]\n    model.crumbs"
            }
            (Layout.stack [ Layout.gap 4 ]
                [ Breadcrumbs.view CrumbsMsg
                    [ Breadcrumbs.items crumbTrail, Breadcrumbs.maxItems 4, Breadcrumbs.locale locale ]
                    model.crumbs
                , Breadcrumbs.view CrumbsDeepMsg
                    [ Breadcrumbs.items crumbTrail, Breadcrumbs.maxItems 3, Breadcrumbs.locale locale ]
                    model.crumbsDeep
                , Layout.container [ Layout.maxWidth 420, Layout.alignStart ]
                    [ Breadcrumbs.static
                        [ Breadcrumbs.items
                            [ Breadcrumbs.link "Home" (Demo.href "")
                            , Breadcrumbs.link "A very long name of an intermediate level that has to be cut down" (Demo.href "long")
                            , Breadcrumbs.text "And an equally long title of the page itself that does not fit either"
                            ]
                        , Breadcrumbs.locale locale
                        ]
                    ]
                ]
            )
        ]


breadcrumbsStaticCode : String
breadcrumbsStaticCode =
    """Breadcrumbs.static
    [ Breadcrumbs.items
        [ Breadcrumbs.link "Home" "#/"
        , Breadcrumbs.link "Orders" "#/orders"
        , Breadcrumbs.text "Order 10482"
        ]
    ]"""



-- TABS


tabsSection : Locale -> Model -> Html Msg
tabsSection locale model =
    Doc.section "Tabs"
        "Tabs switch between views of the same thing. The component has a state of its own (the active tab and the focus), so the application reads Tabs.active and compares before and after an update. A panel is only built while its tab is active. Keyboard: Arrow Left and Right move to the previous and next tab and select it, wrapping around at the ends (Home and End jump to the first and last). Only the active tab is in the Tab order, so Tab goes straight from the tab list into the panel. With manual the arrows only move focus, and Enter or Space selects."
        [ Doc.example
            { title = "Line with panels"
            , description = Just "The default look. A panel is only built for the active tab. The last tab is disabled and explains why in a tooltip."
            , code = Just tabsCode
            }
            (Layout.stack [ Layout.gap 0 ]
                [ Tabs.view LineTabsMsg
                    [ Tabs.ariaLabel "Order sections"
                    , Tabs.tabs
                        [ Tabs.tab "overview" "Overview"
                        , Tabs.tab "history" "History" |> Tabs.withCount 12
                        , Tabs.tab "files" "Files" |> Tabs.withIcon Icon.paperclip
                        , Tabs.tab "admin" "Administration"
                            |> Tabs.disabledTab
                            |> Tabs.withTitle "Requires administrator access"
                        ]
                    ]
                    model.lineTabs
                , Tabs.panels model.lineTabs
                    [ ( "overview"
                      , \_ ->
                            DescriptionList.view [ DescriptionList.columns 2, DescriptionList.locale locale ]
                                [ DescriptionList.text "Customer" "Northwind Traders"
                                , DescriptionList.text "Order number" "10482"
                                ]
                      )
                    , ( "history", \_ -> Text.paragraph "The history would be here: 12 events in the last 90 days." )
                    , ( "files", \_ -> Text.paragraph "The files would be here." )
                    ]
                ]
            )
        , Doc.example
            { title = "Boxed tabs"
            , description = Just "The tabs are joined to the panel below them. Counts are shown as they are, without shortening."
            , code = Just "Tabs.view TabsMsg [ Tabs.boxed, Tabs.tabs tabs ] model.tabs"
            }
            (Layout.stack [ Layout.gap 0 ]
                [ Tabs.view BoxedTabsMsg
                    [ Tabs.boxed
                    , Tabs.ariaLabel "Order details"
                    , Tabs.tabs
                        [ Tabs.tab "overview" "Overview"
                        , Tabs.tab "history" "History" |> Tabs.withCount 12
                        , Tabs.tab "notes" "Notes" |> Tabs.withCount 120
                        ]
                    ]
                    model.boxedTabs
                , Tabs.panels model.boxedTabs
                    [ ( "overview", \_ -> Text.paragraph "Overview in a boxed panel." )
                    , ( "history", \_ -> Text.paragraph "History in a boxed panel." )
                    , ( "notes", \_ -> Text.paragraph "Notes in a boxed panel." )
                    ]
                ]
            )
        , Doc.example
            { title = "Icons, counts and small tabs"
            , description = Just "Small tabs that share the width equally (fill), without panels: they choose something else, so they do not point at a panel that is not there."
            , code = Just "Tabs.tab \"inbox\" \"Inbox\" |> Tabs.withIcon Icon.inbox |> Tabs.withCount 7"
            }
            (Tabs.view IconTabsMsg
                [ Tabs.small
                , Tabs.fill
                , Tabs.ariaLabel "Messages"
                , Tabs.withoutPanels
                , Tabs.tabs
                    [ Tabs.tab "inbox" "Inbox" |> Tabs.withIcon Icon.inbox |> Tabs.withCount 7
                    , Tabs.tab "sent" "Sent" |> Tabs.withIcon Icon.send
                    , Tabs.tab "drafts" "Drafts" |> Tabs.withIcon Icon.edit |> Tabs.withCount 2
                    , Tabs.tab "archive" "Archive" |> Tabs.withIcon Icon.archive |> Tabs.disabledTab
                    ]
                ]
                model.iconTabs
            )
        , Doc.example
            { title = "Manual activation"
            , description = Just "Arrow Right and Left only move focus. Enter or Space selects the tab. Good when switching is expensive."
            , code = Just "Tabs.view TabsMsg [ Tabs.manual, Tabs.tabs tabs ] model.tabs"
            }
            (Layout.stack [ Layout.gap 0 ]
                [ Tabs.view ManualTabsMsg
                    [ Tabs.manual
                    , Tabs.ariaLabel "Manual activation"
                    , Tabs.tabs
                        [ Tabs.tab "a" "First"
                        , Tabs.tab "b" "Second"
                        , Tabs.tab "c" "Third"
                        ]
                    ]
                    model.manualTabs
                , Tabs.panels model.manualTabs
                    [ ( "a", \_ -> Text.paragraph "Selected: first." )
                    , ( "b", \_ -> Text.paragraph "Selected: second." )
                    , ( "c", \_ -> Text.paragraph "Selected: third." )
                    ]
                ]
            )
        , Doc.example
            { title = "Many tabs in a narrow space"
            , description = Just "The tab list scrolls sideways when there is no room. Focus on a tab outside the picture scrolls it into view."
            , code = Nothing
            }
            (Layout.container [ Layout.maxWidth 460, Layout.alignStart ]
                [ Tabs.view OverflowTabsMsg
                    [ Tabs.ariaLabel "Many tabs"
                    , Tabs.withoutPanels
                    , Tabs.tabs
                        (List.map
                            (\n -> Tabs.tab ("t" ++ String.fromInt n) ("Tab number " ++ String.fromInt n))
                            (List.range 1 10)
                        )
                    ]
                    model.overflowTabs
                ]
            )
        , Doc.props tabsProps
        ]


tabsProps : List { name : String, type_ : String, description : String }
tabsProps =
    [ { name = "tab", type_ = "String -> String -> Tab", description = "Key and text. The key identifies the tab and its panel." }
    , { name = "withIcon, withCount, withTitle", type_ = "Tab -> Tab", description = "An icon, a count and a tooltip (useful for saying why a tab is disabled)." }
    , { name = "disabledTab", type_ = "Tab -> Tab", description = "Visible but cannot be selected. The arrow keys skip it." }
    , { name = "tabs, ariaLabel", type_ = "List Tab, String", description = "The tabs, and the name of the tab list for screen readers." }
    , { name = "boxed, small, fill", type_ = "Attribute", description = "Boxed tabs, lower tabs, and tabs that share the width equally." }
    , { name = "manual", type_ = "Attribute", description = "The arrow keys only move focus. Enter or Space selects." }
    , { name = "withoutPanels", type_ = "Attribute", description = "The tabs choose something other than a panel below them (a route, a filter). They then do not point with aria-controls at a panel that is not there." }
    , { name = "init, active, setActive", type_ = "String -> String -> State, State -> String, String -> State -> State", description = "A unique id and the first active tab; read and set the active tab from the application." }
    , { name = "panel, panels", type_ = "State -> String -> (() -> Html msg) -> Html msg", description = "The content of a tab. The function is only called while the tab is active." }
    ]


tabsCode : String
tabsCode =
    """-- model:  tabs : Tabs.State          (Tabs.init "order-tabs" "overview")
-- update: TabsMsg m -> let ( tabs, cmd ) = Tabs.update m model.tabs in ...

Html.div []
    [ Tabs.view TabsMsg
        [ Tabs.ariaLabel "Order sections"
        , Tabs.tabs
            [ Tabs.tab "overview" "Overview"
            , Tabs.tab "history" "History" |> Tabs.withCount 12
            , Tabs.tab "files" "Files" |> Tabs.withIcon Icon.paperclip
            , Tabs.tab "billing" "Billing" |> Tabs.disabledTab
            ]
        ]
        model.tabs
    , Tabs.panels model.tabs
        [ ( "overview", \\_ -> overviewView model )
        , ( "history", \\_ -> historyView model )
        ]
    ]"""
