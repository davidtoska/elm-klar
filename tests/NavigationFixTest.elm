module NavigationFixTest exposing (suite)

{-| Regression tests for navigation and structure modules that used to behave
inconsistently: the strip and the panels of `Tabs`, the role of `Toolbar`, the ids
of `SideNav` sections, the mode of `Accordion`, the range of `Stepper.current`,
the heading of `PageHeader`, and the toggles and the brand of `AppShell`.
-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Accordion as Accordion
import Klar.AppShell as AppShell
import Klar.PageHeader as PageHeader
import Klar.SideNav as SideNav
import Klar.Stepper as Stepper
import Klar.Tabs as Tabs
import Klar.Toolbar as Toolbar
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "Navigation and structure fixes"
        [ tabsTests
        , toolbarTests
        , sideNavTests
        , accordionTests
        , stepperTests
        , pageHeaderTests
        , appShellTests
        ]



-- HELPERS


attr : String -> String -> Selector
attr name value =
    Selector.attribute (Attr.attribute name value)


{-| Draw the Html, find the one element the selectors name, and expect what the
check says about it.
-}
expectOn : List Selector -> (Query.Single msg -> Expectation) -> Html msg -> Expectation
expectOn selectors check html =
    html
        |> Query.fromHtml
        |> Query.find selectors
        |> check



-- TABS


orderTabs : List Tabs.Tab
orderTabs =
    [ Tabs.tab "overview" "Overview"
    , Tabs.tab "history" "History"
    , Tabs.tab "billing" "Billing" |> Tabs.disabledTab
    ]


panelEntries : List ( String, () -> Html msg )
panelEntries =
    [ ( "overview", \_ -> Html.text "Overview content" )
    , ( "history", \_ -> Html.text "History content" )
    , ( "billing", \_ -> Html.text "Billing content" )
    ]


strip : Tabs.State -> Html Tabs.Msg
strip state =
    Tabs.view identity [ Tabs.tabs orderTabs ] state


{-| What an application draws: the strip and its panels from one resolved state.
-}
page : Tabs.State -> Html Tabs.Msg
page state =
    let
        resolved =
            Tabs.resolve orderTabs state
    in
    Html.div []
        [ Tabs.view identity [ Tabs.tabs orderTabs ] resolved
        , Tabs.panels resolved panelEntries
        ]


{-| The active key is "billing", a tab that is disabled.
-}
disabledKey : Tabs.State
disabledKey =
    Tabs.init "t" "billing"


{-| The active key is "settings", which belongs to no tab.
-}
unknownKey : Tabs.State
unknownKey =
    Tabs.init "t" "settings"


tabsTests : Test
tabsTests =
    describe "Klar.Tabs: the strip and the panels agree"
        [ test "the strip selects the first enabled tab when the active key is disabled" <|
            \_ ->
                strip disabledKey
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ Selector.id "t-tab-overview" ] >> Query.has [ attr "aria-selected" "true" ]
                        , Query.find [ Selector.id "t-tab-history" ] >> Query.has [ attr "aria-selected" "false" ]
                        , Query.find [ Selector.id "t-tab-billing" ] >> Query.has [ attr "aria-selected" "false" ]
                        ]
        , test "the strip selects the first enabled tab when the active key is unknown" <|
            \_ ->
                strip unknownKey
                    |> expectOn [ Selector.id "t-tab-overview" ] (Query.has [ attr "aria-selected" "true" ])
        , test "resolve moves a disabled active key to the first enabled tab" <|
            \_ ->
                Tabs.resolve orderTabs disabledKey
                    |> Tabs.active
                    |> Expect.equal "overview"
        , test "resolve moves an unknown active key to the first enabled tab" <|
            \_ ->
                Tabs.resolve orderTabs unknownKey
                    |> Tabs.active
                    |> Expect.equal "overview"
        , test "resolve keeps an active key that belongs to an enabled tab" <|
            \_ ->
                Tabs.resolve orderTabs (Tabs.init "t" "history")
                    |> Tabs.active
                    |> Expect.equal "history"
        , test "resolve leaves an empty key when no tab is enabled" <|
            \_ ->
                Tabs.resolve [ Tabs.tab "a" "A" |> Tabs.disabledTab ] (Tabs.init "t" "a")
                    |> Tabs.active
                    |> Expect.equal ""
        , test "after resolve, panels builds only the panel of the tab that the strip selects" <|
            \_ ->
                page disabledKey
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.has [ Selector.text "Overview content" ]
                        , Query.hasNot [ Selector.text "Billing content" ]
                        , Query.hasNot [ Selector.text "History content" ]
                        ]
        , test "after resolve, an unknown key shows the panel of the first enabled tab" <|
            \_ ->
                page unknownKey
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Overview content" ]
        , test "after resolve, panel renders nothing for the disabled tab" <|
            \_ ->
                Html.div [] [ Tabs.panel (Tabs.resolve orderTabs disabledKey) "billing" (\_ -> Html.text "Billing content") ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.hasNot [ Selector.text "Billing content" ]
                        , Query.hasNot [ attr "role" "tabpanel" ]
                        ]
        , test "after resolve, panel renders the content of the first enabled tab" <|
            \_ ->
                Html.div [] [ Tabs.panel (Tabs.resolve orderTabs unknownKey) "overview" (\_ -> Html.text "Overview content") ]
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Overview content" ]
        , test "the selected tab and the panel point at each other" <|
            \_ ->
                page disabledKey
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find [ attr "aria-selected" "true" ]
                            >> Query.has [ Selector.id "t-tab-overview", attr "aria-controls" "t-panel-overview" ]
                        , Query.find [ attr "role" "tabpanel" ]
                            >> Query.has [ Selector.id "t-panel-overview", attr "aria-labelledby" "t-tab-overview" ]
                        ]
        , test "no panel is built when no tab is enabled" <|
            \_ ->
                let
                    resolved =
                        Tabs.resolve [ Tabs.tab "overview" "Overview" |> Tabs.disabledTab ] (Tabs.init "t" "overview")
                in
                Html.div [] [ Tabs.panels resolved panelEntries ]
                    |> Query.fromHtml
                    |> Query.hasNot [ attr "role" "tabpanel" ]
        ]



-- TOOLBAR


tinyBar : List Toolbar.Attribute -> Html msg
tinyBar attributes =
    Toolbar.view attributes [ Html.text "x" ]


toolbarTests : Test
toolbarTests =
    describe "Klar.Toolbar: a group, not a toolbar"
        [ test "the bar is a named group" <|
            \_ ->
                tinyBar [ Toolbar.ariaLabel "Orders" ]
                    |> Query.fromHtml
                    |> Query.has [ attr "role" "group", attr "aria-label" "Orders" ]
        , test "the bar does not claim the toolbar role" <|
            \_ ->
                tinyBar [ Toolbar.ariaLabel "Orders" ]
                    |> Query.fromHtml
                    |> Query.hasNot [ attr "role" "toolbar" ]
        , test "the bar has no orientation, which a group does not support" <|
            \_ ->
                tinyBar []
                    |> Query.fromHtml
                    |> Query.hasNot [ attr "aria-orientation" "horizontal" ]
        , test "the bar is a group also without a name" <|
            \_ ->
                tinyBar []
                    |> Query.fromHtml
                    |> Query.has [ attr "role" "group" ]
        , test "a labelled group inside the bar is still a group with its name" <|
            \_ ->
                Toolbar.view [] [ Toolbar.groupLabelled "Layout" [ Html.text "x" ] ]
                    |> Query.fromHtml
                    |> Query.find [ attr "aria-label" "Layout" ]
                    |> Query.has [ attr "role" "group" ]
        ]



-- SIDENAV


link : String -> SideNav.Entry String msg
link key =
    SideNav.item SideNav.stringKeys { key = key, label = key, href = "#/" ++ key }


{-| Two sections with the same caption, and a third that holds one more with that
caption.
-}
sameCaptions : List (SideNav.Entry String msg)
sameCaptions =
    [ SideNav.section "Workspace" [ link "orders" ]
    , SideNav.section "Workspace" [ link "customers" ]
    , SideNav.section "Admin"
        [ SideNav.section "Workspace" [ link "users" ] ]
    ]


sideNav : List (SideNav.Entry String SideNav.Msg) -> SideNav.State String -> Html SideNav.Msg
sideNav entries state =
    SideNav.view identity [ SideNav.entries entries ] state


sideNavTests : Test
sideNavTests =
    describe "Klar.SideNav: section headings have unique ids"
        [ test "sections with the same caption get different heading ids" <|
            \_ ->
                sideNav sameCaptions (SideNav.init "main-nav")
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "h2" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 4)
                        , Query.index 0 >> Query.has [ Selector.id "main-nav-section-0", Selector.text "Workspace" ]
                        , Query.index 1 >> Query.has [ Selector.id "main-nav-section-1", Selector.text "Workspace" ]
                        , Query.index 2 >> Query.has [ Selector.id "main-nav-section-2", Selector.text "Admin" ]
                        , Query.index 3 >> Query.has [ Selector.id "main-nav-section-2-0", Selector.text "Workspace" ]
                        ]
        , test "every id is on one element only" <|
            \_ ->
                let
                    drawn =
                        sideNav sameCaptions (SideNav.init "main-nav") |> Query.fromHtml
                in
                [ "main-nav-section-0", "main-nav-section-1", "main-nav-section-2", "main-nav-section-2-0" ]
                    |> List.map
                        (\id _ ->
                            drawn
                                |> Query.findAll [ Selector.id id ]
                                |> Query.count (Expect.equal 1)
                        )
                    |> (\checks -> Expect.all checks ())
        , test "each list is named by its own heading" <|
            \_ ->
                let
                    drawn =
                        sideNav sameCaptions (SideNav.init "main-nav") |> Query.fromHtml

                    namedBy id _ =
                        drawn
                            |> Query.findAll [ attr "aria-labelledby" id ]
                            |> Query.count (Expect.equal 1)
                in
                Expect.all
                    (List.map namedBy [ "main-nav-section-0", "main-nav-section-1", "main-nav-section-2", "main-nav-section-2-0" ])
                    ()
        , test "sections inside a group are numbered by their place under the group" <|
            \_ ->
                let
                    entries =
                        [ SideNav.section "Top" [ link "home" ]
                        , SideNav.group SideNav.stringKeys
                            { key = "reports", label = "Reports" }
                            [ SideNav.section "Same" [ link "monthly" ]
                            , SideNav.section "Same" [ link "yearly" ]
                            ]
                        ]
                in
                sideNav entries (SideNav.init "main-nav" |> SideNav.expandGroup SideNav.stringKeys "reports")
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "h2" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 3)
                        , Query.index 0 >> Query.has [ Selector.id "main-nav-section-0" ]
                        , Query.index 1 >> Query.has [ Selector.id "main-nav-section-1-0" ]
                        , Query.index 2 >> Query.has [ Selector.id "main-nav-section-1-1" ]
                        ]
        , test "a section without a caption has no heading and no name" <|
            \_ ->
                sideNav [ SideNav.section "" [ link "orders" ] ] (SideNav.init "main-nav")
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.hasNot [ Selector.tag "h2" ]
                        , Query.hasNot [ Selector.attribute (Attr.attribute "aria-labelledby" "main-nav-section-0") ]
                        ]
        ]



-- ACCORDION


accordionSections : List (Accordion.Section msg)
accordionSections =
    [ Accordion.section "a" "Alpha" [ Html.text "alpha" ]
    , Accordion.section "b" "Beta" [ Html.text "beta" ]
    , Accordion.section "c" "Gamma" [ Html.text "gamma" ]
    ]


{-| Click the header of the section, and give the message that it sends to
`Accordion.update`.
-}
clickHeader : List (Accordion.Attribute Accordion.Msg) -> String -> Accordion.State -> Result String Accordion.State
clickHeader attributes key state =
    Accordion.view identity (Accordion.sections accordionSections :: attributes) state
        |> Query.fromHtml
        |> Query.find [ Selector.id ("acc-header-" ++ key) ]
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\msg -> Tuple.first (Accordion.update msg state))


openAfter : (Accordion.State -> Accordion.State) -> Accordion.State -> List String
openAfter change state =
    change state |> Accordion.openKeys


single : Accordion.State
single =
    Accordion.init "acc"


several : Accordion.State
several =
    Accordion.init "acc" |> Accordion.setMultiple True


accordionTests : Test
accordionTests =
    describe "Klar.Accordion: open and toggle follow the mode like a click on a header"
        [ test "in the default mode open closes the other sections" <|
            \_ ->
                single
                    |> Accordion.open "a"
                    |> Accordion.open "b"
                    |> Accordion.openKeys
                    |> Expect.equal [ "b" ]
        , test "in the default mode toggle opens one section and closes the others" <|
            \_ ->
                single
                    |> Accordion.toggle "a"
                    |> Accordion.toggle "b"
                    |> Accordion.openKeys
                    |> Expect.equal [ "b" ]
        , test "toggle closes an open section" <|
            \_ ->
                single
                    |> Accordion.toggle "a"
                    |> Accordion.toggle "a"
                    |> Accordion.openKeys
                    |> Expect.equal []
        , test "in the default mode open leaves only that section open, also if it was open with others" <|
            \_ ->
                single
                    |> Accordion.openMany [ "a", "b" ]
                    |> Accordion.open "a"
                    |> Accordion.openKeys
                    |> Expect.equal [ "a" ]
        , test "after setMultiple True open keeps the other sections open" <|
            \_ ->
                several
                    |> Accordion.open "a"
                    |> Accordion.open "b"
                    |> Accordion.openKeys
                    |> Expect.equal [ "a", "b" ]
        , test "after setMultiple True toggle keeps the other sections open" <|
            \_ ->
                several
                    |> Accordion.toggle "a"
                    |> Accordion.toggle "b"
                    |> Accordion.toggle "a"
                    |> Accordion.openKeys
                    |> Expect.equal [ "b" ]
        , test "opening a section that is open does not repeat it" <|
            \_ ->
                several
                    |> Accordion.open "a"
                    |> Accordion.open "a"
                    |> Accordion.openKeys
                    |> Expect.equal [ "a" ]
        , test "setMultiple False brings back the default mode" <|
            \_ ->
                several
                    |> Accordion.open "a"
                    |> Accordion.setMultiple False
                    |> Accordion.open "b"
                    |> Accordion.openKeys
                    |> Expect.equal [ "b" ]
        , test "setMultiple keeps the open sections" <|
            \_ ->
                single
                    |> Accordion.open "a"
                    |> Accordion.setMultiple True
                    |> Accordion.openKeys
                    |> Expect.equal [ "a" ]
        , test "openMany sets exactly these sections, whatever the mode" <|
            \_ ->
                Expect.all
                    [ \_ -> single |> Accordion.openMany [ "a", "c" ] |> Accordion.openKeys |> Expect.equal [ "a", "c" ]
                    , \_ -> several |> Accordion.open "b" |> Accordion.openMany [ "a", "c" ] |> Accordion.openKeys |> Expect.equal [ "a", "c" ]
                    ]
                    ()
        , test "a click on a header does what toggle does in the default mode" <|
            \_ ->
                Expect.equal
                    (clickHeader [] "b" (single |> Accordion.open "a") |> Result.map Accordion.openKeys)
                    (Ok (single |> Accordion.open "a" |> Accordion.toggle "b" |> Accordion.openKeys))
        , test "a click on a header does what toggle does after setMultiple True" <|
            \_ ->
                Expect.equal
                    (clickHeader [] "b" (several |> Accordion.open "a") |> Result.map Accordion.openKeys)
                    (Ok (several |> Accordion.open "a" |> Accordion.toggle "b" |> Accordion.openKeys))
        , test "a click on an open header closes it, in both modes" <|
            \_ ->
                Expect.all
                    [ \_ -> clickHeader [] "a" (single |> Accordion.open "a") |> Result.map Accordion.openKeys |> Expect.equal (Ok [])
                    , \_ -> clickHeader [] "a" (several |> Accordion.open "a") |> Result.map Accordion.openKeys |> Expect.equal (Ok [])
                    ]
                    ()
        , test "the multiple attribute still lets clicks keep other sections open" <|
            \_ ->
                clickHeader [ Accordion.multiple ] "b" (single |> Accordion.open "a")
                    |> Result.map Accordion.openKeys
                    |> Expect.equal (Ok [ "a", "b" ])
        , test "without the attribute a click follows a state that allows several" <|
            \_ ->
                clickHeader [] "c" (several |> Accordion.open "a" |> Accordion.open "b")
                    |> Result.map Accordion.openKeys
                    |> Expect.equal (Ok [ "a", "b", "c" ])
        ]



-- STEPPER


threeSteps : List Stepper.Step
threeSteps =
    [ Stepper.step "One", Stepper.step "Two", Stepper.step "Three" ]


{-| The steps of the list as `li` elements, first to last.
-}
stepAt : Int -> Html msg -> Query.Single msg
stepAt index html =
    html
        |> Query.fromHtml
        |> Query.findAll [ Selector.tag "li" ]
        |> Query.index index


stepperTests : Test
stepperTests =
    describe "Klar.Stepper: current stays inside the list"
        [ test "an index past the end makes the last step the current one" <|
            \_ ->
                Stepper.view [ Stepper.current 9 ] threeSteps
                    |> expectAllSteps
                        [ Selector.class "klar-stepper__step--complete"
                        , Selector.class "klar-stepper__step--complete"
                        , Selector.class "klar-stepper__step--current"
                        ]
        , test "an index before the start makes the first step the current one" <|
            \_ ->
                Stepper.view [ Stepper.current -4 ] threeSteps
                    |> expectAllSteps
                        [ Selector.class "klar-stepper__step--current"
                        , Selector.class "klar-stepper__step--upcoming"
                        , Selector.class "klar-stepper__step--upcoming"
                        ]
        , test "an index inside the list is used as it is" <|
            \_ ->
                Stepper.view [ Stepper.current 1 ] threeSteps
                    |> expectAllSteps
                        [ Selector.class "klar-stepper__step--complete"
                        , Selector.class "klar-stepper__step--current"
                        , Selector.class "klar-stepper__step--upcoming"
                        ]
        , test "the clamped current step is the one marked as current for assistive technology" <|
            \_ ->
                Stepper.view [ Stepper.current 9 ] threeSteps
                    |> Query.fromHtml
                    |> Query.findAll [ attr "aria-current" "step" ]
                    |> Expect.all
                        [ Query.count (Expect.equal 1)
                        , Query.first >> Query.has [ Selector.containing [ Selector.text "Three" ] ]
                        ]
        , test "the line before the clamped current step is marked as passed" <|
            \_ ->
                Stepper.view [ Stepper.current 9 ] threeSteps
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.class "klar-stepper__step--passed" ]
                    |> Query.count (Expect.equal 2)
        , test "view and progress agree about an index past the end" <|
            \_ ->
                Expect.all
                    [ \_ -> Stepper.progress [ Stepper.current 9 ] threeSteps |> Query.fromHtml |> Query.has [ Selector.text "Step 3 of 3" ]
                    , \_ -> stepAt 2 (Stepper.view [ Stepper.current 9 ] threeSteps) |> Query.has [ Selector.class "klar-stepper__step--current" ]
                    ]
                    ()
        , test "view and progress agree about an index before the start" <|
            \_ ->
                Expect.all
                    [ \_ -> Stepper.progress [ Stepper.current -1 ] threeSteps |> Query.fromHtml |> Query.has [ Selector.text "Step 1 of 3" ]
                    , \_ -> stepAt 0 (Stepper.view [ Stepper.current -1 ] threeSteps) |> Query.has [ Selector.class "klar-stepper__step--current" ]
                    ]
                    ()
        , test "a list without steps draws nothing and does not fail" <|
            \_ ->
                Stepper.view [ Stepper.current 3 ] []
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "li" ]
                    |> Query.count (Expect.equal 0)
        ]


{-| The three steps carry these selectors, first to last.
-}
expectAllSteps : List Selector -> Html msg -> Expectation
expectAllSteps selectors html =
    selectors
        |> List.indexedMap (\index selector _ -> stepAt index html |> Query.has [ selector ])
        |> (\checks -> Expect.all checks ())



-- PAGEHEADER


pageHeaderTests : Test
pageHeaderTests =
    describe "Klar.PageHeader: no title, no heading"
        [ test "a header without a title has no h1" <|
            \_ ->
                PageHeader.view []
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.tag "h1" ]
        , test "a blank title has no h1" <|
            \_ ->
                PageHeader.view [ PageHeader.title "   " ]
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.tag "h1" ]
        , test "a title is the h1" <|
            \_ ->
                PageHeader.view [ PageHeader.title "Order 10482" ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "h1" ]
                    |> Query.has [ Selector.text "Order 10482" ]
        , test "the badges are still drawn when there is no title" <|
            \_ ->
                PageHeader.view [ PageHeader.badges [ Html.text "Shipped" ] ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.hasNot [ Selector.tag "h1" ]
                        , Query.has [ Selector.text "Shipped" ]
                        ]
        , test "nothing is left of the title row when there is neither title nor badges" <|
            \_ ->
                PageHeader.view [ PageHeader.subtitle "Placed on 12 March" ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.findAll [ Selector.class "klar-page-header__title-row" ] >> Query.count (Expect.equal 0)
                        , Query.has [ Selector.text "Placed on 12 March" ]
                        ]
        , test "a title and badges share the title row" <|
            \_ ->
                PageHeader.view [ PageHeader.title "Order 10482", PageHeader.badges [ Html.text "Shipped" ] ]
                    |> Query.fromHtml
                    |> Query.find [ Selector.class "klar-page-header__title-row" ]
                    |> Query.has [ Selector.tag "h1", Selector.text "Shipped" ]
        ]



-- APPSHELL


{-| A shell with a sidebar and both toggles. The messages are not looked at.
-}
shell : List (AppShell.Attribute ()) -> Html ()
shell attributes =
    AppShell.view
        ([ AppShell.sidebar (Html.text "menu")
         , AppShell.onToggleSidebar ()
         , AppShell.onToggleDrawer ()
         ]
            ++ attributes
        )
        [ Html.text "page" ]


wideToggle : List Selector
wideToggle =
    [ Selector.class "klar-app-shell__toggle--wide" ]


narrowToggle : List Selector
narrowToggle =
    [ Selector.class "klar-app-shell__toggle--narrow" ]


appShellTests : Test
appShellTests =
    describe "Klar.AppShell"
        [ test "the sidebar toggle says that the sidebar is expanded" <|
            \_ ->
                shell []
                    |> expectOn wideToggle (Query.has [ attr "aria-expanded" "true" ])
        , test "the sidebar toggle says that the sidebar is collapsed" <|
            \_ ->
                shell [ AppShell.sidebarCollapsed True ]
                    |> expectOn wideToggle (Query.has [ attr "aria-expanded" "false" ])
        , test "the sidebar toggle points at the sidebar, which is there" <|
            \_ ->
                shell []
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find wideToggle >> Query.has [ attr "aria-controls" "klar-app-shell-sidebar" ]
                        , Query.find [ Selector.id "klar-app-shell-sidebar" ] >> Query.has [ Selector.text "menu" ]
                        ]
        , test "the sidebar toggle points at the sidebar of a shell with its own id" <|
            \_ ->
                shell [ AppShell.id "app" ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find wideToggle >> Query.has [ attr "aria-controls" "app-sidebar" ]
                        , Query.find [ Selector.id "app-sidebar" ] >> Query.has [ Selector.text "menu" ]
                        ]
        , test "the menu button says that the drawer is closed" <|
            \_ ->
                shell []
                    |> expectOn narrowToggle (Query.has [ attr "aria-expanded" "false" ])
        , test "the menu button says that the drawer is open" <|
            \_ ->
                shell [ AppShell.drawerOpen True ]
                    |> expectOn narrowToggle (Query.has [ attr "aria-expanded" "true" ])
        , test "the toggles do not follow each other's state" <|
            \_ ->
                shell [ AppShell.drawerOpen True, AppShell.sidebarCollapsed True ]
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.find wideToggle >> Query.has [ attr "aria-expanded" "false" ]
                        , Query.find narrowToggle >> Query.has [ attr "aria-expanded" "true" ]
                        ]
        , test "a brand with a logo is marked, so that the name can give way to the logo" <|
            \_ ->
                AppShell.brandLink { name = "Acme Operations", href = "#/", logo = Just (Html.text "A") }
                    |> Query.fromHtml
                    |> Query.has [ Selector.class "klar-app-shell__brand-link--logo" ]
        , test "a brand without a logo is not marked, so that its name stays" <|
            \_ ->
                AppShell.brandLink { name = "Acme Operations", href = "#/", logo = Nothing }
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.hasNot [ Selector.class "klar-app-shell__brand-link--logo" ]
                        , Query.has [ Selector.class "klar-app-shell__brand-link", Selector.text "Acme Operations" ]
                        ]
        , test "the brand name is in the link in both cases" <|
            \_ ->
                [ Just (Html.text "A"), Nothing ]
                    |> List.map
                        (\logo _ ->
                            AppShell.brandLink { name = "Acme Operations", href = "#/", logo = logo }
                                |> Query.fromHtml
                                |> Query.find [ Selector.class "klar-app-shell__brand-name" ]
                                |> Query.has [ Selector.text "Acme Operations" ]
                        )
                    |> (\checks -> Expect.all checks ())
        ]
