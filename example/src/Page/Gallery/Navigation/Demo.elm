module Page.Gallery.Navigation.Demo exposing
    ( Page
    , actionText
    , href
    , menu
    , pageFor
    )

{-| The pretend application behind the previews of the navigation page: "Acme
Logistics", with a handful of pages and a menu. Nothing here is a component.
-}

import Klar.Badge as Badge
import Klar.Icon as Icon
import Klar.SideNav as SideNav
import Klar.Theme exposing (Size(..), Tone(..))


{-| The address of a link in a preview. The showcase treats only `#/...` as a
route and ignores every other fragment, so a click on one of these links leaves
the user on this page.
-}
href : String -> String
href slug =
    "#demo/" ++ slug


{-| The line that tells what the user did last in a preview.
-}
actionText : Maybe String -> String
actionText action =
    case action of
        Just name ->
            "Last action: " ++ name

        Nothing ->
            "No action yet"



-- PAGES


type alias Page =
    { key : String
    , title : String
    , subtitle : String
    , parents : List String
    }


pages : List Page
pages =
    [ { key = "overview", title = "Overview", subtitle = "The state of the whole operation today.", parents = [] }
    , { key = "orders", title = "Orders", subtitle = "All orders, with their status and due date.", parents = [] }
    , { key = "customers", title = "Customers", subtitle = "Customers, contacts and delivery addresses.", parents = [] }
    , { key = "reports-monthly", title = "Monthly report", subtitle = "Volumes and key figures for the chosen month.", parents = [ "Reports" ] }
    , { key = "reports-activity", title = "Activity", subtitle = "Who did what, and when.", parents = [ "Reports" ] }
    , { key = "reports-budget", title = "Budget", subtitle = "Budget against actual costs.", parents = [ "Reports", "Finance" ] }
    , { key = "reports-revenue", title = "Revenue", subtitle = "Invoiced amounts so far this year.", parents = [ "Reports", "Finance" ] }
    , { key = "reports-exports", title = "Exports", subtitle = "Download reports as spreadsheets.", parents = [ "Reports" ] }
    , { key = "settings", title = "Settings", subtitle = "Settings for the company and for you.", parents = [] }
    , { key = "help", title = "Help", subtitle = "Guides and contact information.", parents = [] }
    ]


pageFor : String -> Page
pageFor key =
    pages
        |> List.filter (\page -> page.key == key)
        |> List.head
        |> Maybe.withDefault { key = key, title = key, subtitle = "", parents = [] }



-- MENU


{-| The menu of the pretend application, in three sections, with a group inside
a group.
-}
menu : List (SideNav.Entry String msg)
menu =
    [ SideNav.section "Workspace"
        [ SideNav.item SideNav.stringKeys { key = "overview", label = "Overview", href = href "overview" }
            |> SideNav.withIcon Icon.home
        , SideNav.item SideNav.stringKeys { key = "orders", label = "Orders", href = href "orders" }
            |> SideNav.withIcon Icon.clipboardCheck
            |> SideNav.withCount 12
        , SideNav.item SideNav.stringKeys { key = "customers", label = "Customers", href = href "customers" }
            |> SideNav.withIcon Icon.users
            |> SideNav.withBadge (Badge.view [ Badge.tone Warning, Badge.size Small ] "New")
        ]
    , SideNav.section "Analysis"
        [ SideNav.group SideNav.stringKeys
            { key = "reports", label = "Reports" }
            [ SideNav.item SideNav.stringKeys { key = "reports-monthly", label = "Monthly report", href = href "reports/monthly" }
            , SideNav.item SideNav.stringKeys { key = "reports-activity", label = "Activity", href = href "reports/activity" }
            , SideNav.group SideNav.stringKeys
                { key = "reports-finance", label = "Finance" }
                [ SideNav.item SideNav.stringKeys { key = "reports-budget", label = "Budget", href = href "reports/budget" }
                , SideNav.item SideNav.stringKeys { key = "reports-revenue", label = "Revenue", href = href "reports/revenue" }
                ]
            , SideNav.item SideNav.stringKeys { key = "reports-exports", label = "Exports", href = href "reports/exports" }
            ]
            |> SideNav.withIcon Icon.barChart
        ]
    , SideNav.section "System"
        [ SideNav.item SideNav.stringKeys { key = "settings", label = "Settings", href = href "settings" }
            |> SideNav.withIcon Icon.settings
        , SideNav.item SideNav.stringKeys { key = "billing", label = "Billing", href = href "billing" }
            |> SideNav.withIcon Icon.fileText
            |> SideNav.disabledItem
        , SideNav.item SideNav.stringKeys { key = "help", label = "Help", href = href "help" }
            |> SideNav.withIcon Icon.help
        ]
    ]
