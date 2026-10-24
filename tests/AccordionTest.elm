module AccordionTest exposing (suite)

{-| `Klar.Accordion`: the mode of the state (expand, toggle and a click on a header
agree), keys of the application's own type, the keyboard between the headers, the
markup of open and closed sections, and the bodies kept hidden until found.
-}

import Expect
import Html
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Accordion as Accordion
import Klar.Ids as Ids exposing (Ids)
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Part
    = Alpha
    | Beta
    | Gamma


partIds : Ids Part
partIds =
    Ids.list
        (\part ->
            case part of
                Alpha ->
                    "a"

                Beta ->
                    "b"

                Gamma ->
                    "c"
        )
        [ Alpha, Beta, Gamma ]


sections : List (Accordion.Section Part msg)
sections =
    [ Accordion.section partIds Alpha "Alpha" [ Html.text "alpha" ]
    , Accordion.section partIds Beta "Beta" [ Html.text "beta" ]
    , Accordion.section partIds Gamma "Gamma" [ Html.text "gamma" ]
    ]


render : Accordion.State Part -> List (Accordion.Section Part (Accordion.Msg Part)) -> Query.Single (Accordion.Msg Part)
render state given =
    Accordion.view identity [] state given |> Query.fromHtml


{-| Click the header of the section, and give the message that it sends to
`Accordion.update`.
-}
clickHeader : String -> Accordion.State Part -> Result String (Accordion.State Part)
clickHeader domKey state =
    render state sections
        |> Query.find [ Selector.id ("acc-header-" ++ domKey) ]
        |> Event.simulate Event.click
        |> Event.toResult
        |> Result.map (\msg -> Tuple.first (Accordion.update msg state))


{-| The message that a key press on the header of the section sends.
-}
keyMsg : String -> String -> List (Accordion.Section Part (Accordion.Msg Part)) -> Result String (Accordion.Msg Part)
keyMsg key domKey given =
    render single given
        |> Query.find [ Selector.id ("acc-header-" ++ domKey) ]
        |> Event.simulate (Event.custom "keydown" (keyEvent key))
        |> Event.toResult


keyEvent : String -> Encode.Value
keyEvent key =
    Encode.object
        [ ( "key", Encode.string key )
        , ( "ctrlKey", Encode.bool False )
        , ( "metaKey", Encode.bool False )
        , ( "altKey", Encode.bool False )
        , ( "shiftKey", Encode.bool False )
        , ( "repeat", Encode.bool False )
        , ( "isComposing", Encode.bool False )
        , ( "keyCode", Encode.int 0 )
        ]


single : Accordion.State Part
single =
    Accordion.init "acc"


several : Accordion.State Part
several =
    Accordion.init "acc" |> Accordion.setMultiple True


suite : Test
suite =
    describe "Klar.Accordion"
        [ modeTests
        , markupTests
        , keyboardTests
        ]


modeTests : Test
modeTests =
    describe "expand and toggle follow the mode like a click on a header"
        [ test "in the default mode expand closes the other sections" <|
            \_ ->
                single
                    |> Accordion.expand Alpha
                    |> Accordion.expand Beta
                    |> Accordion.expandedIds
                    |> Expect.equal [ Beta ]
        , test "in the default mode toggle opens one section and closes the others" <|
            \_ ->
                single
                    |> Accordion.toggle Alpha
                    |> Accordion.toggle Beta
                    |> Accordion.expandedIds
                    |> Expect.equal [ Beta ]
        , test "toggle closes an open section" <|
            \_ ->
                single
                    |> Accordion.toggle Alpha
                    |> Accordion.toggle Alpha
                    |> Accordion.expandedIds
                    |> Expect.equal []
        , test "in the default mode expand leaves only that section open, also if it was open with others" <|
            \_ ->
                single
                    |> Accordion.setExpandedIds [ Alpha, Beta ]
                    |> Accordion.expand Alpha
                    |> Accordion.expandedIds
                    |> Expect.equal [ Alpha ]
        , test "after setMultiple True expand keeps the other sections open" <|
            \_ ->
                several
                    |> Accordion.expand Alpha
                    |> Accordion.expand Beta
                    |> Accordion.expandedIds
                    |> Expect.equal [ Alpha, Beta ]
        , test "after setMultiple True toggle keeps the other sections open" <|
            \_ ->
                several
                    |> Accordion.toggle Alpha
                    |> Accordion.toggle Beta
                    |> Accordion.toggle Alpha
                    |> Accordion.expandedIds
                    |> Expect.equal [ Beta ]
        , test "expanding a section that is open does not repeat it" <|
            \_ ->
                several
                    |> Accordion.expand Alpha
                    |> Accordion.expand Alpha
                    |> Accordion.expandedIds
                    |> Expect.equal [ Alpha ]
        , test "setMultiple False brings back the default mode" <|
            \_ ->
                several
                    |> Accordion.expand Alpha
                    |> Accordion.setMultiple False
                    |> Accordion.expand Beta
                    |> Accordion.expandedIds
                    |> Expect.equal [ Beta ]
        , test "setMultiple keeps the open sections" <|
            \_ ->
                single
                    |> Accordion.expand Alpha
                    |> Accordion.setMultiple True
                    |> Accordion.expandedIds
                    |> Expect.equal [ Alpha ]
        , test "setExpandedIds sets exactly these sections, whatever the mode" <|
            \_ ->
                Expect.all
                    [ \_ -> single |> Accordion.setExpandedIds [ Alpha, Gamma ] |> Accordion.expandedIds |> Expect.equal [ Alpha, Gamma ]
                    , \_ -> several |> Accordion.expand Beta |> Accordion.setExpandedIds [ Alpha, Gamma ] |> Accordion.expandedIds |> Expect.equal [ Alpha, Gamma ]
                    ]
                    ()
        , test "isExpanded compares the keys with ==" <|
            \_ ->
                single
                    |> Accordion.expand Beta
                    |> Expect.all
                        [ Accordion.isExpanded Beta >> Expect.equal True
                        , Accordion.isExpanded Alpha >> Expect.equal False
                        ]
        , test "collapse closes one section, collapseAll every section" <|
            \_ ->
                several
                    |> Accordion.setExpandedIds [ Alpha, Beta, Gamma ]
                    |> Expect.all
                        [ Accordion.collapse Beta >> Accordion.expandedIds >> Expect.equal [ Alpha, Gamma ]
                        , Accordion.collapseAll >> Accordion.expandedIds >> Expect.equal []
                        ]
        , test "expandAll opens every section but the disabled ones, keeping the open ones first" <|
            \_ ->
                single
                    |> Accordion.expand Gamma
                    |> Accordion.expandAll
                        [ Accordion.section partIds Alpha "Alpha" []
                        , Accordion.section partIds Beta "Beta" [] |> Accordion.disabledSection
                        , Accordion.section partIds Gamma "Gamma" []
                        ]
                    |> Accordion.expandedIds
                    |> Expect.equal [ Gamma, Alpha ]
        , test "a click on a header does what toggle does in the default mode" <|
            \_ ->
                Expect.equal
                    (clickHeader "b" (single |> Accordion.expand Alpha) |> Result.map Accordion.expandedIds)
                    (Ok (single |> Accordion.expand Alpha |> Accordion.toggle Beta |> Accordion.expandedIds))
        , test "a click on a header does what toggle does after setMultiple True" <|
            \_ ->
                Expect.equal
                    (clickHeader "b" (several |> Accordion.expand Alpha) |> Result.map Accordion.expandedIds)
                    (Ok (several |> Accordion.expand Alpha |> Accordion.toggle Beta |> Accordion.expandedIds))
        , test "a click on an open header closes it, in both modes" <|
            \_ ->
                Expect.all
                    [ \_ -> clickHeader "a" (single |> Accordion.expand Alpha) |> Result.map Accordion.expandedIds |> Expect.equal (Ok [])
                    , \_ -> clickHeader "a" (several |> Accordion.expand Alpha) |> Result.map Accordion.expandedIds |> Expect.equal (Ok [])
                    ]
                    ()
        , test "the browser finding text in a closed section opens it" <|
            \_ ->
                render single sections
                    |> Query.find [ Selector.id "acc-body-b" ]
                    |> Event.simulate (Event.custom "beforematch" Encode.null)
                    |> Event.toResult
                    |> Result.map (\msg -> Accordion.update msg single |> Tuple.first |> Accordion.expandedIds)
                    |> Expect.equal (Ok [ Beta ])
        ]


markupTests : Test
markupTests =
    describe "the markup"
        [ test "an open header is expanded and controls its body" <|
            \_ ->
                render (single |> Accordion.expand Alpha) sections
                    |> Query.find [ Selector.id "acc-header-a" ]
                    |> Query.has
                        [ Selector.attribute (Attr.attribute "aria-expanded" "true")
                        , Selector.attribute (Attr.attribute "aria-controls" "acc-body-a")
                        ]
        , test "the body of a closed section stays in the page, hidden until found" <|
            \_ ->
                render single sections
                    |> Query.find [ Selector.id "acc-body-b" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "hidden" "until-found"), Selector.text "beta" ]
        , test "a closed header still controls its hidden body" <|
            \_ ->
                render single sections
                    |> Query.find [ Selector.id "acc-header-b" ]
                    |> Query.has
                        [ Selector.attribute (Attr.attribute "aria-expanded" "false")
                        , Selector.attribute (Attr.attribute "aria-controls" "acc-body-b")
                        ]
        , test "an open body is not hidden" <|
            \_ ->
                render (single |> Accordion.expand Alpha) sections
                    |> Query.find [ Selector.id "acc-body-a" ]
                    |> Query.hasNot [ Selector.attribute (Attr.attribute "hidden" "until-found") ]
        , test "a closed lazy section has no body and controls nothing" <|
            \_ ->
                render single [ Accordion.lazySection partIds Alpha "Alpha" (\_ -> [ Html.text "alpha" ]) ]
                    |> Expect.all
                        [ Query.findAll [ Selector.id "acc-body-a" ] >> Query.count (Expect.equal 0)
                        , Query.find [ Selector.id "acc-header-a" ] >> Query.hasNot [ Selector.attribute (Attr.attribute "aria-controls" "acc-body-a") ]
                        ]
        , test "an open lazy section draws its content" <|
            \_ ->
                render (single |> Accordion.expand Alpha) [ Accordion.lazySection partIds Alpha "Alpha" (\_ -> [ Html.text "alpha" ]) ]
                    |> Query.find [ Selector.id "acc-body-a" ]
                    |> Query.has [ Selector.text "alpha" ]
        , test "a disabled section is a disabled button and has no body, also when its key is open" <|
            \_ ->
                render (single |> Accordion.expand Alpha) [ Accordion.section partIds Alpha "Alpha" [ Html.text "alpha" ] |> Accordion.disabledSection ]
                    |> Expect.all
                        [ Query.find [ Selector.id "acc-header-a" ] >> Query.has [ Selector.attribute (Attr.disabled True), Selector.attribute (Attr.attribute "aria-expanded" "false") ]
                        , Query.findAll [ Selector.id "acc-body-a" ] >> Query.count (Expect.equal 0)
                        ]
        , test "with six sections or fewer the bodies are regions named by their headers" <|
            \_ ->
                render (single |> Accordion.expand Alpha) sections
                    |> Query.find [ Selector.id "acc-body-a" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "role" "region"), Selector.attribute (Attr.attribute "aria-labelledby" "acc-header-a") ]
        , test "with seven sections the bodies are no regions" <|
            \_ ->
                List.range 1 7
                    |> List.map (\n -> Accordion.section Ids.string (String.fromInt n) ("Section " ++ String.fromInt n) [])
                    |> Accordion.view identity [] (Accordion.init "acc" |> Accordion.expand "1")
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.attribute (Attr.attribute "role" "region") ]
                    |> Query.count (Expect.equal 0)
        , test "the heading level is kept between 1 and 6" <|
            \_ ->
                Accordion.view identity [ Accordion.headingLevel 9 ] single sections
                    |> Query.fromHtml
                    |> Query.findAll [ Selector.tag "h6" ]
                    |> Query.count (Expect.equal 3)
        , test "the default heading level is 3" <|
            \_ ->
                render single sections
                    |> Query.findAll [ Selector.tag "h3" ]
                    |> Query.count (Expect.equal 3)
        ]


keyboardTests : Test
keyboardTests =
    let
        withBetaDisabled =
            [ Accordion.section partIds Alpha "Alpha" []
            , Accordion.section partIds Beta "Beta" [] |> Accordion.disabledSection
            , Accordion.section partIds Gamma "Gamma" []
            ]
    in
    describe "the arrow keys move between the enabled headers"
        [ test "ArrowDown on the last header wraps to the first" <|
            \_ ->
                keyMsg "ArrowDown" "c" sections
                    |> Expect.equal (keyMsg "Home" "b" sections)
        , test "ArrowUp on the first header wraps to the last" <|
            \_ ->
                keyMsg "ArrowUp" "a" sections
                    |> Expect.equal (keyMsg "End" "b" sections)
        , test "ArrowDown moves to the next header" <|
            \_ ->
                keyMsg "ArrowDown" "a" sections
                    |> Expect.equal (keyMsg "ArrowUp" "c" sections)
        , test "the arrow keys skip a disabled header" <|
            \_ ->
                keyMsg "ArrowDown" "a" withBetaDisabled
                    |> Expect.equal (keyMsg "End" "a" withBetaDisabled)
        , test "a disabled header has no keys" <|
            \_ ->
                keyMsg "ArrowDown" "b" withBetaDisabled
                    |> Expect.err
        , test "a key that is not bound does nothing" <|
            \_ ->
                keyMsg "x" "a" sections
                    |> Expect.err
        ]
