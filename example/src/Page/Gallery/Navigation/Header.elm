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


{-| The views of an order, the keys of the tab strips: a misspelled tab is a compile
error, and the page matches the active one with a `case`.
-}
type Section
    = Overview
    | Activity
    | Documents
    | History
    | Files
    | Admin
    | Notes


type Folder
    = Inbox
    | Sent
    | Drafts
    | Archive


type Choice
    = First
    | Second
    | Third


type alias Model =
    { -- page header
      headerMenu : Menu.State
    , headerTabs : Tabs.State Section
    , lastAction : Maybe String

    -- breadcrumbs
    , crumbs : Breadcrumbs.State
    , crumbsDeep : Breadcrumbs.State

    -- tabs
    , lineTabs : Tabs.State Section
    , boxedTabs : Tabs.State Section
    , iconTabs : Tabs.State Folder
    , manualTabs : Tabs.State Choice
    , overflowTabs : Tabs.State Int
    , verticalTabs : Tabs.State Section
    }


init : Model
init =
    { headerMenu = Menu.init "nav-header-menu"
    , headerTabs = Tabs.init "nav-header-tabs" Overview
    , lastAction = Nothing
    , crumbs = Breadcrumbs.init "nav-crumbs"
    , crumbsDeep = Breadcrumbs.init "nav-crumbs-deep"
    , lineTabs = Tabs.init "nav-line-tabs" Overview
    , boxedTabs = Tabs.init "nav-boxed-tabs" History
    , iconTabs = Tabs.init "nav-icon-tabs" Inbox
    , manualTabs = Tabs.init "nav-manual-tabs" First
    , overflowTabs = Tabs.init "nav-overflow-tabs" 1
    , verticalTabs = Tabs.init "nav-vertical-tabs" Overview
    }



-- UPDATE


type Msg
    = HeaderMenuMsg Menu.Msg
    | HeaderTabsMsg (Tabs.Msg Section)
    | CrumbsMsg Breadcrumbs.Msg
    | CrumbsDeepMsg Breadcrumbs.Msg
    | LineTabsMsg (Tabs.Msg Section)
    | BoxedTabsMsg (Tabs.Msg Section)
    | IconTabsMsg (Tabs.Msg Folder)
    | ManualTabsMsg (Tabs.Msg Choice)
    | OverflowTabsMsg (Tabs.Msg Int)
    | VerticalTabsMsg (Tabs.Msg Section)
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

        VerticalTabsMsg inner ->
            Tabs.update inner model.verticalTabs
                |> Tuple.mapBoth (\state -> { model | verticalTabs = state }) (Cmd.map VerticalTabsMsg)

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
                    (Breadcrumbs.viewStatic
                        [ Breadcrumbs.items
                            [ Breadcrumbs.link { label = "Home", href = Demo.href "" } |> Breadcrumbs.withIcon Icon.home
                            , Breadcrumbs.link { label = "Orders", href = Demo.href "orders" }
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
                        , Tabs.locale locale
                        , Tabs.tabs
                            [ Tabs.tab Overview "Overview"
                            , Tabs.tab Activity "Activity" |> Tabs.withCount 48
                            , Tabs.tab Documents "Documents" |> Tabs.withCount 3
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
            [ Tabs.ariaLabel "Order"
            , Tabs.tabs [ Tabs.tab Overview "Overview", Tabs.tab Activity "Activity" |> Tabs.withCount 48 ]
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
crumbTrail : List (Breadcrumbs.Crumb Msg)
crumbTrail =
    [ Breadcrumbs.link { label = "Home", href = Demo.href "" } |> Breadcrumbs.withIcon Icon.home
    , Breadcrumbs.link { label = "Europe", href = Demo.href "europe" }
    , Breadcrumbs.link { label = "Netherlands", href = Demo.href "netherlands" }
    , Breadcrumbs.link { label = "Rotterdam", href = Demo.href "rotterdam" }
    , Breadcrumbs.link { label = "Warehouse 3", href = Demo.href "warehouse-3" }
    , Breadcrumbs.text "Aisle 3B"
    ]


breadcrumbsSection : Locale -> Model -> Html Msg
breadcrumbsSection locale model =
    Doc.section "Breadcrumbs"
        "The path to the current page, with a chevron between the levels. The last level is the current page (aria-current) and is not a link. When the trail has at least two levels more than maxItems, the levels in the middle fold into a \"more\" button that opens a list of them (Escape closes it and returns to the button, Arrow Up and Down move between the links, Tab moves on); one level more is shown whole, since a button for one level saves no room. Long names are cut with an ellipsis and show the whole name as a tooltip."
        [ Doc.example
            { title = "Short trail without state"
            , description = Just "A trail with a fixed depth of two or three levels needs no state: viewStatic."
            , code = Just breadcrumbsStaticCode
            }
            (Breadcrumbs.viewStatic
                [ Breadcrumbs.items
                    [ Breadcrumbs.link { label = "Home", href = Demo.href "" } |> Breadcrumbs.withIcon Icon.home
                    , Breadcrumbs.link { label = "Orders", href = Demo.href "orders" }
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
                    [ Breadcrumbs.viewStatic
                        [ Breadcrumbs.items
                            [ Breadcrumbs.link { label = "Home", href = Demo.href "" }
                            , Breadcrumbs.link { label = "A very long name of an intermediate level that has to be cut down", href = Demo.href "long" }
                            , Breadcrumbs.text "And an equally long title of the page itself that does not fit either"
                            ]
                        , Breadcrumbs.locale locale
                        ]
                    ]
                ]
            )
        , Doc.example
            { title = "A drill-down without addresses"
            , description = Just (Demo.actionText model.lastAction ++ ". Crumbs made with Breadcrumbs.button send a message instead of following a link: the levels of a report that is opened step by step inside one page.")
            , code = Just "Breadcrumbs.viewStatic\n    [ Breadcrumbs.items\n        [ Breadcrumbs.button \"All years\" (DrillUpTo AllYears)\n        , Breadcrumbs.button \"2026\" (DrillUpTo (Year 2026))\n        , Breadcrumbs.text \"March\"\n        ]\n    ]"
            }
            (Breadcrumbs.viewStatic
                [ Breadcrumbs.ariaLabel "Report levels"
                , Breadcrumbs.items
                    [ Breadcrumbs.button "All years" (Action "Show all years")
                    , Breadcrumbs.button "2026" (Action "Show 2026")
                    , Breadcrumbs.text "March"
                    ]
                , Breadcrumbs.locale locale
                ]
            )
        ]


breadcrumbsStaticCode : String
breadcrumbsStaticCode =
    """Breadcrumbs.viewStatic
    [ Breadcrumbs.items
        [ Breadcrumbs.link { label = "Home", href = "#/" }
        , Breadcrumbs.link { label = "Orders", href = "#/orders" }
        , Breadcrumbs.text "Order 10482"
        ]
    ]"""



-- TABS


tabsSection : Locale -> Model -> Html Msg
tabsSection locale model =
    Doc.section "Tabs"
        "Tabs switch between views of the same thing. The tabs are values of your own type, and the component has a state of its own (the active tab), so the application reads Tabs.active and compares before and after an update. The strip draws the panel of the active tab itself (withPanel), so the two always agree, and a panel is only built while its tab is active. Keyboard: Arrow Left and Right (Up and Down when vertical) move to the previous and next tab and select it, wrapping around at the ends (Home and End jump to the first and last). Only the active tab is in the Tab order, so Tab goes straight from the tab list into the panel. With manual the arrows only move focus, and Enter or Space selects."
        [ Doc.example
            { title = "Line with panels"
            , description = Just "The default look. A panel is only built for the active tab. The last tab is disabled and explains why in a tooltip."
            , code = Just tabsCode
            }
            (Tabs.view LineTabsMsg
                [ Tabs.ariaLabel "Order sections"
                , Tabs.locale locale
                , Tabs.tabs
                    [ Tabs.tab Overview "Overview"
                        |> Tabs.withPanel
                            (\_ ->
                                DescriptionList.view [ DescriptionList.columns 2, DescriptionList.locale locale ]
                                    [ DescriptionList.text "Customer" "Northwind Traders"
                                    , DescriptionList.text "Order number" "10482"
                                    ]
                            )
                    , Tabs.tab History "History"
                        |> Tabs.withCount 12
                        |> Tabs.withPanel (\_ -> Text.paragraph "The history would be here: 12 events in the last 90 days.")
                    , Tabs.tab Files "Files"
                        |> Tabs.withIcon Icon.paperclip
                        |> Tabs.withPanel (\_ -> Text.paragraph "The files would be here.")
                    , Tabs.tab Admin "Administration"
                        |> Tabs.disabledTab
                        |> Tabs.withTitle "Requires administrator access"
                    ]
                ]
                model.lineTabs
            )
        , Doc.example
            { title = "Boxed tabs"
            , description = Just "The tabs are joined to the panel below them. Counts are shown whole, grouped the way the language writes numbers."
            , code = Just "Tabs.view TabsMsg [ Tabs.boxed, Tabs.tabs tabs ] model.tabs"
            }
            (Tabs.view BoxedTabsMsg
                [ Tabs.boxed
                , Tabs.ariaLabel "Order details"
                , Tabs.locale locale
                , Tabs.tabs
                    [ Tabs.tab Overview "Overview" |> Tabs.withPanel (\_ -> Text.paragraph "Overview in a boxed panel.")
                    , Tabs.tab History "History" |> Tabs.withCount 12 |> Tabs.withPanel (\_ -> Text.paragraph "History in a boxed panel.")
                    , Tabs.tab Notes "Notes" |> Tabs.withCount 12040 |> Tabs.withPanel (\_ -> Text.paragraph "Notes in a boxed panel.")
                    ]
                ]
                model.boxedTabs
            )
        , Doc.example
            { title = "Vertical tabs"
            , description = Just "The tabs stacked beside their panel, for settings pages and detail panes. Arrow Up and Down move between them, and the list says aria-orientation vertical."
            , code = Just "Tabs.view TabsMsg [ Tabs.vertical, Tabs.tabs tabs ] model.tabs"
            }
            (Tabs.view VerticalTabsMsg
                [ Tabs.vertical
                , Tabs.ariaLabel "Order settings"
                , Tabs.tabs
                    [ Tabs.tab Overview "General" |> Tabs.withPanel (\_ -> Text.paragraph "The name, the customer and the warehouse of the order.")
                    , Tabs.tab Documents "Documents" |> Tabs.withPanel (\_ -> Text.paragraph "Invoices, delivery notes and customs papers.")
                    , Tabs.tab Notes "Notifications" |> Tabs.withPanel (\_ -> Text.paragraph "Who hears about changes to the order.")
                    ]
                ]
                model.verticalTabs
            )
        , Doc.example
            { title = "Icons, counts and small tabs"
            , description = Just "Small tabs that share the width equally (fill), without panels: they choose something else, so they do not point at a panel that is not there."
            , code = Just "Tabs.tab Inbox \"Inbox\" |> Tabs.withIcon Icon.inbox |> Tabs.withCount 7"
            }
            (Tabs.view IconTabsMsg
                [ Tabs.small
                , Tabs.fill
                , Tabs.ariaLabel "Messages"
                , Tabs.tabs
                    [ Tabs.tab Inbox "Inbox" |> Tabs.withIcon Icon.inbox |> Tabs.withCount 7
                    , Tabs.tab Sent "Sent" |> Tabs.withIcon Icon.send
                    , Tabs.tab Drafts "Drafts" |> Tabs.withIcon Icon.edit |> Tabs.withCount 2
                    , Tabs.tab Archive "Archive" |> Tabs.withIcon Icon.archive |> Tabs.disabledTab
                    ]
                ]
                model.iconTabs
            )
        , Doc.example
            { title = "Manual activation"
            , description = Just "Arrow Right and Left only move focus. Enter or Space selects the tab. Good when switching is expensive."
            , code = Just "Tabs.view TabsMsg [ Tabs.manual, Tabs.tabs tabs ] model.tabs"
            }
            (Tabs.view ManualTabsMsg
                [ Tabs.manual
                , Tabs.ariaLabel "Manual activation"
                , Tabs.tabs
                    [ Tabs.tab First "First" |> Tabs.withPanel (\_ -> Text.paragraph "Selected: first.")
                    , Tabs.tab Second "Second" |> Tabs.withPanel (\_ -> Text.paragraph "Selected: second.")
                    , Tabs.tab Third "Third" |> Tabs.withPanel (\_ -> Text.paragraph "Selected: third.")
                    ]
                ]
                model.manualTabs
            )
        , Doc.example
            { title = "Many tabs in a narrow space"
            , description = Just "The tab list scrolls sideways when there is no room. Focus on a tab outside the picture scrolls it into view."
            , code = Nothing
            }
            (Layout.container [ Layout.maxWidth 460, Layout.alignStart ]
                [ Tabs.view OverflowTabsMsg
                    [ Tabs.ariaLabel "Many tabs"
                    , Tabs.tabs
                        (List.map
                            (\n -> Tabs.tab n ("Tab number " ++ String.fromInt n))
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
    [ { name = "tab", type_ = "key -> String -> Tab key msg", description = "A value of your own type and the text. The key identifies the tab, compared with ==." }
    , { name = "withPanel", type_ = "(() -> Html msg) -> Tab key msg -> Tab key msg", description = "The content under the strip while the tab is active. The function is only called then. Without panels the strip claims none (route tabs)." }
    , { name = "withIcon, withCount, withTitle", type_ = "Tab key msg -> Tab key msg", description = "An icon, a count (grouped by the locale) and a tooltip (useful for saying why a tab is disabled)." }
    , { name = "disabledTab", type_ = "Tab key msg -> Tab key msg", description = "Visible but cannot be selected. The arrow keys skip it." }
    , { name = "tabs, ariaLabel, locale", type_ = "List (Tab key msg), String, Locale", description = "The tabs, the name of the tab list for screen readers, and the language of the counts." }
    , { name = "boxed, small, fill, vertical", type_ = "Attribute key msg", description = "Boxed tabs, lower tabs, tabs that share the width equally, and tabs stacked beside their panel." }
    , { name = "manual", type_ = "Attribute key msg", description = "The arrow keys only move focus. Enter or Space selects." }
    , { name = "init, active, setActive", type_ = "String -> key -> State key, State key -> key, key -> State key -> State key", description = "A unique id and the first active tab; read and set the active tab from the application." }
    ]


tabsCode : String
tabsCode =
    """-- model:  tabs : Tabs.State Section     (Tabs.init "order-tabs" Overview)
-- update: TabsMsg m -> let ( tabs, cmd ) = Tabs.update m model.tabs in ...

Tabs.view TabsMsg
    [ Tabs.ariaLabel "Order sections"
    , Tabs.tabs
        [ Tabs.tab Overview "Overview" |> Tabs.withPanel (\\_ -> overviewView model)
        , Tabs.tab History "History" |> Tabs.withCount 12 |> Tabs.withPanel (\\_ -> historyView model)
        , Tabs.tab Files "Files" |> Tabs.withIcon Icon.paperclip |> Tabs.withPanel (\\_ -> filesView model)
        , Tabs.tab Billing "Billing" |> Tabs.disabledTab
        ]
    ]
    model.tabs"""
