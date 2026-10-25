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
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options



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


section : Config.Config -> Locale -> Model -> Html Msg
section playground locale model =
    let
        deepTrail =
            List.map
                (\level ->
                    Breadcrumbs.link
                        { label = "Level " ++ String.fromInt level ++ " of the organization"
                        , href = Demo.href ("level/" ++ String.fromInt level)
                        }
                )
                (List.range 1 24)
                ++ [ Breadcrumbs.text "Current location" ]

        manySteps =
            List.map (\number -> Stepper.step ("Step number " ++ String.fromInt number)) (List.range 1 12)
    in
    Doc.configuredSection playground
        [ "AppShell", "SideNav" ]
        "Edge cases"
        "Long names, large amounts of data and a frame without a sidebar. Long text is cut with an ellipsis (menus, breadcrumbs and steps show the whole text as a tooltip), lists scroll or fold, and nothing breaks the layout."
        [ Doc.configuredExample playground
            [ "AppShell" ]
            { title = "Frame without a sidebar, with a banner and long names"
            , description =
                Just
                    (Demo.actionText model.lastAction
                        ++ ". Without AppShell.sidebar there is neither a side menu nor a menu button. The banner sits above the top bar, the names are cut, and the search field has a text of its own and no key caps (searchShortcut [])."
                    )
            , code = Just shellPlainCode
            }
            (AppShell.view
                (Options.klarAppShell playground
                    (List.concat
                        [ Config.keep playground "AppShell" "id" (AppShell.id "nav-demo-shell-plain")
                        , Config.keep playground "AppShell" "locale" (AppShell.locale locale)
                        , Config.keep playground "AppShell" "height" (AppShell.height 300)
                        , Config.keep playground "AppShell" "contentPadding" (AppShell.contentPadding 4)
                        , Config.keep playground
                            "AppShell"
                            "banner"
                            (AppShell.banner
                                (Options.alertView playground
                                    (Options.klarAlert playground (List.concat [ Config.keep playground "Alert" "banner" Alert.banner, Config.keep playground "Alert" "compact" Alert.compact, Config.keep playground "Alert" "tone" (Alert.tone Warning), Config.keep playground "Alert" "locale" (Alert.locale locale) ]))
                                    "Read-only mode: you are looking at the data of yesterday."
                                )
                            )
                        , Config.keep playground
                            "AppShell"
                            "brand"
                            (AppShell.brand
                                (AppShell.brandLink
                                    { name = "Acme Logistics Worldwide Freight and Distribution Services"
                                    , href = Demo.href ""
                                    , logo = Nothing
                                    }
                                )
                            )
                        , Config.keep playground "AppShell" "onSearch" (AppShell.onSearch (Action "Search"))
                        , Config.keep playground "AppShell" "searchPlaceholder" (AppShell.searchPlaceholder "Search shipments ...")
                        , Config.keep playground "AppShell" "searchShortcut" (AppShell.searchShortcut [])
                        , Config.keep playground
                            "AppShell"
                            "actions"
                            (AppShell.actions
                                [ Button.iconOnly (Options.klarButton playground (List.concat [ Config.keep playground "Button" "ghost" Button.ghost, Config.keep playground "Button" "onClick" (Button.onClick (Action "Notifications")) ])) Icon.bell "Notifications" ]
                            )
                        , Config.keep playground "AppShell" "userName" (AppShell.userName "Ada Augusta Lovelace-Montgomery-Featherstone")
                        , Config.keep playground "AppShell" "userRole" (AppShell.userRole "Head of operations, northern distribution center, Rotterdam")
                        , Config.keep playground "AppShell" "userAvatar" (AppShell.userAvatar (Avatar.view (Options.klarAvatar playground (List.concat [ Config.keep playground "Avatar" "decorative" Avatar.decorative ])) "Ada Augusta Lovelace-Montgomery-Featherstone"))
                        ]
                    )
                )
                [ PageHeader.view
                    (Options.klarPageHeader playground
                        (List.concat
                            [ Config.keep playground "PageHeader" "headingLevel" (PageHeader.headingLevel 3)
                            , Config.keep playground "PageHeader" "title" (PageHeader.title "No side menu here")
                            , Config.keep playground "PageHeader" "subtitle" (PageHeader.subtitle "Only the top bar and the content.")
                            ]
                        )
                    )
                ]
            )
        , Doc.example
            { title = "Deep trail"
            , description = Just "25 levels, at most four visible. The list of hidden levels scrolls on its own."
            , code = Nothing
            }
            (Breadcrumbs.view CrumbsMsg
                (Options.klarBreadcrumbs playground (List.concat [ Config.keep playground "Breadcrumbs" "items" (Breadcrumbs.items deepTrail), Config.keep playground "Breadcrumbs" "maxItems" (Breadcrumbs.maxItems 4), Config.keep playground "Breadcrumbs" "locale" (Breadcrumbs.locale locale) ]))
                model.crumbs
            )
        , Doc.configuredExample playground
            [ "SideNav" ]
            { title = "Long menu names"
            , description = Just "The names are cut and show the whole text as a tooltip (hover over them). Numbers above 99 are shown as 99+."
            , code = Nothing
            }
            (Layout.container (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "maxWidth" (Layout.maxWidth 280), Config.keep playground "Layout" "alignStart" Layout.alignStart ]))
                [ Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "flush" Card.flush ]))
                    [ Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "padding" (Layout.padding 2), Config.keep playground "Layout" "gap" (Layout.gap 0) ]))
                        [ SideNav.view NavMsg
                            (Options.klarSideNav playground
                                (List.concat
                                    [ Config.keep playground "SideNav" "entries" (SideNav.entries (longMenu playground))
                                    , Config.keep playground "SideNav" "current" (SideNav.current "b")
                                    , Config.keep playground "SideNav" "locale" (SideNav.locale locale)
                                    , Config.keep playground "SideNav" "ariaLabel" (SideNav.ariaLabel "Menu with long names")
                                    ]
                                )
                            )
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
            (Layout.container (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "maxWidth" (Layout.maxWidth 560), Config.keep playground "Layout" "alignStart" Layout.alignStart ]))
                [ Stepper.view (Options.klarStepper playground (List.concat [ Config.keep playground "Stepper" "current" (Stepper.current 4), Config.keep playground "Stepper" "locale" (Stepper.locale locale) ])) manySteps ]
            )
        , Doc.example
            { title = "Long values in the description list"
            , description = Just "Values without spaces are broken over several lines instead of being cut off. A blank value is shown as a dash."
            , code = Nothing
            }
            (Layout.container (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "maxWidth" (Layout.maxWidth 560), Config.keep playground "Layout" "alignStart" Layout.alignStart ]))
                [ DescriptionList.view (Options.klarDescriptionList playground (List.concat [ Config.keep playground "DescriptionList" "columns" (DescriptionList.columns 2), Config.keep playground "DescriptionList" "locale" (DescriptionList.locale locale) ]))
                    [ DescriptionList.text "Identifier" "a1b2c3d4-e5f6-7890-abcd-ef1234567890-a1b2c3d4-e5f6-7890-abcd-ef1234567890"
                    , DescriptionList.text "Email" "a.very.long.email.address.that.does.not.fit@example-organization-with-a-long-name.com"
                    , DescriptionList.text "Empty" "   "
                    ]
                ]
            )
        ]


longMenu : Config.Config -> List (SideNav.Entry String msg)
longMenu playground =
    [ SideNav.section "Very long names"
        [ SideNav.item Ids.string { key = "a", label = "A menu entry with an incredibly long name that never fits", href = Demo.href "a" }
            |> SideNav.withIcon Icon.fileText
            |> SideNav.withCount 1482
        , SideNav.item Ids.string { key = "b", label = "Short", href = Demo.href "b" }
            |> SideNav.withIcon Icon.tag
            |> SideNav.withBadge (Options.badgeView playground (Options.klarBadge playground (List.concat [ Config.keep playground "Badge" "tone" (Badge.tone Warning), Config.keep playground "Badge" "size" (Badge.size Small) ])) "Overdue")
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
