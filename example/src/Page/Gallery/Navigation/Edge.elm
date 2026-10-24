module Page.Gallery.Navigation.Edge exposing
    ( Model
    , Msg
    , init
    , section
    , update
    )

{-| The extremes: long names, a lot of data and a frame without a sidebar. Text
is cut with an ellipsis, lists scroll or fold, and nothing breaks the layout.
-}

import Html exposing (Html)
import Klar.Alert as Alert
import Klar.AppShell as AppShell
import Klar.Avatar as Avatar
import Klar.Badge as Badge
import Klar.Breadcrumbs as Breadcrumbs
import Klar.Button as Button
import Klar.Card as Card
import Klar.DescriptionList as DescriptionList
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.PageHeader as PageHeader
import Klar.SideNav as SideNav
import Klar.Stepper as Stepper
import Klar.Theme exposing (Size(..), Tone(..))
import Page.Gallery.Navigation.Demo as Demo
import Showcase.Doc as Doc



-- MODEL


type alias Model =
    { crumbs : Breadcrumbs.State
    , nav : SideNav.State String
    , lastAction : Maybe String
    }


init : Model
init =
    { crumbs = Breadcrumbs.init "nav-crumbs-long"
    , nav = SideNav.init "nav-long" |> SideNav.expandGroup Ids.string "g"
    , lastAction = Nothing
    }



-- UPDATE


type Msg
    = CrumbsMsg Breadcrumbs.Msg
    | NavMsg SideNav.Msg
    | Action String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CrumbsMsg inner ->
            Breadcrumbs.update inner model.crumbs
                |> Tuple.mapBoth (\state -> { model | crumbs = state }) (Cmd.map CrumbsMsg)

        NavMsg inner ->
            SideNav.update inner model.nav
                |> Tuple.mapBoth (\state -> { model | nav = state }) (Cmd.map NavMsg)

        Action name ->
            ( { model | lastAction = Just name }, Cmd.none )



-- VIEW


section : Locale -> Model -> Html Msg
section locale model =
    let
        deepTrail =
            List.map
                (\level ->
                    Breadcrumbs.link
                        ("Level " ++ String.fromInt level ++ " of the organization")
                        (Demo.href ("level/" ++ String.fromInt level))
                )
                (List.range 1 24)
                ++ [ Breadcrumbs.text "Current location" ]

        manySteps =
            List.map (\number -> Stepper.step ("Step number " ++ String.fromInt number)) (List.range 1 12)
    in
    Doc.section "Edge cases"
        "Long names, large amounts of data and a frame without a sidebar. Long text is cut with an ellipsis (menus, breadcrumbs and steps show the whole text as a tooltip), lists scroll or fold, and nothing breaks the layout."
        [ Doc.example
            { title = "Frame without a sidebar, with a banner and long names"
            , description =
                Just
                    (Demo.actionText model.lastAction
                        ++ ". Without AppShell.sidebar there is neither a side menu nor a menu button. The banner sits above the top bar, the names are cut, and the search field has a text of its own and no key caps (searchShortcut [])."
                    )
            , code = Just shellPlainCode
            }
            (AppShell.view
                [ AppShell.id "nav-demo-shell-plain"
                , AppShell.locale locale
                , AppShell.height 300
                , AppShell.contentPadding 4
                , AppShell.banner
                    (Alert.view
                        [ Alert.banner, Alert.compact, Alert.tone Warning, Alert.locale locale ]
                        "Read-only mode: you are looking at the data of yesterday."
                    )
                , AppShell.brand
                    (AppShell.brandLink
                        { name = "Acme Logistics Worldwide Freight and Distribution Services"
                        , href = Demo.href ""
                        , logo = Nothing
                        }
                    )
                , AppShell.onSearch (Action "Search")
                , AppShell.searchPlaceholder "Search shipments ..."
                , AppShell.searchShortcut []
                , AppShell.actions
                    [ Button.iconOnly [ Button.ghost, Button.onClick (Action "Notifications") ] Icon.bell "Notifications" ]
                , AppShell.userName "Ada Augusta Lovelace-Montgomery-Featherstone"
                , AppShell.userRole "Head of operations, northern distribution center, Rotterdam"
                , AppShell.userAvatar (Avatar.view [ Avatar.decorative ] "Ada Augusta Lovelace-Montgomery-Featherstone")
                ]
                [ PageHeader.view
                    [ PageHeader.headingLevel 3
                    , PageHeader.title "No side menu here"
                    , PageHeader.subtitle "Only the top bar and the content."
                    ]
                ]
            )
        , Doc.example
            { title = "Deep trail"
            , description = Just "25 levels, at most four visible. The list of hidden levels scrolls on its own."
            , code = Nothing
            }
            (Breadcrumbs.view CrumbsMsg
                [ Breadcrumbs.items deepTrail, Breadcrumbs.maxItems 4, Breadcrumbs.locale locale ]
                model.crumbs
            )
        , Doc.example
            { title = "Long menu names"
            , description = Just "The names are cut and show the whole text as a tooltip (hover over them). Numbers above 99 are shown as 99+."
            , code = Nothing
            }
            (Layout.container [ Layout.maxWidth 280, Layout.alignStart ]
                [ Card.view [ Card.flush ]
                    [ Layout.stack [ Layout.padding 2, Layout.gap 0 ]
                        [ SideNav.view NavMsg
                            [ SideNav.entries longMenu
                            , SideNav.current "b"
                            , SideNav.locale locale
                            , SideNav.ariaLabel "Menu with long names"
                            ]
                            model.nav
                        ]
                    ]
                ]
            )
        , Doc.example
            { title = "Many steps"
            , description = Just "Twelve steps in a narrow space: the steps scroll sideways."
            , code = Nothing
            }
            (Layout.container [ Layout.maxWidth 560, Layout.alignStart ]
                [ Stepper.view [ Stepper.current 4, Stepper.locale locale ] manySteps ]
            )
        , Doc.example
            { title = "Long values in the description list"
            , description = Just "Values without spaces are broken over several lines instead of being cut off. A blank value is shown as a dash."
            , code = Nothing
            }
            (Layout.container [ Layout.maxWidth 560, Layout.alignStart ]
                [ DescriptionList.view [ DescriptionList.columns 2, DescriptionList.locale locale ]
                    [ DescriptionList.text "Identifier" "a1b2c3d4-e5f6-7890-abcd-ef1234567890-a1b2c3d4-e5f6-7890-abcd-ef1234567890"
                    , DescriptionList.text "Email" "a.very.long.email.address.that.does.not.fit@example-organization-with-a-long-name.com"
                    , DescriptionList.text "Empty" "   "
                    ]
                ]
            )
        ]


longMenu : List (SideNav.Entry String msg)
longMenu =
    [ SideNav.section "Very long names"
        [ SideNav.item Ids.string { key = "a", label = "A menu entry with an incredibly long name that never fits", href = Demo.href "a" }
            |> SideNav.withIcon Icon.fileText
            |> SideNav.withCount 1482
        , SideNav.item Ids.string { key = "b", label = "Short", href = Demo.href "b" }
            |> SideNav.withIcon Icon.tag
            |> SideNav.withBadge (Badge.view [ Badge.tone Warning, Badge.size Small ] "Overdue")
        , SideNav.group Ids.string
            { key = "g", label = "A group with a rather long name too" }
            [ SideNav.item Ids.string { key = "g1", label = "A sub-entry with a name as long as the rest", href = Demo.href "g1" } ]
            |> SideNav.withIcon Icon.folder
        ]
    ]


shellPlainCode : String
shellPlainCode =
    """AppShell.view
    [ AppShell.banner (Alert.view [ Alert.banner, Alert.compact ] "Read-only mode")
    , AppShell.brand
        (AppShell.brandLink
            { name = "Acme Logistics Worldwide Freight and Distribution Services"
            , href = "#/"
            , logo = Nothing
            }
        )
    , AppShell.onSearch OpenSearch
    , AppShell.searchPlaceholder "Search shipments ..."
    , AppShell.searchShortcut [] -- no key caps
    , AppShell.userName "Ada Augusta Lovelace-Montgomery-Featherstone"
    , AppShell.userRole "Head of operations, northern distribution center, Rotterdam"
    , AppShell.userAvatar (Avatar.view [ Avatar.decorative ] "Ada Augusta Lovelace-Montgomery-Featherstone")
    ]
    [ pageContent ]"""
