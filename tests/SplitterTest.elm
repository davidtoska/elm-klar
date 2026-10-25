module SplitterTest exposing (suite)

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar
import Klar.Locale as Locale
import Klar.Splitter as Splitter
import Support.Css as Css
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "Splitter: what is rendered and what the events do"
        [ structureTests
        , keyboardTests
        , pointerTests
        , sizesTests
        , foldTests
        ]



-- THE APPLICATION IN A NUTSHELL


type alias Model =
    { split : Splitter.State
    , attributes : List (Splitter.Attribute Splitter.Msg)
    , panes : List (Splitter.Pane Splitter.Msg)
    }


pane : String -> Splitter.Pane Splitter.Msg
pane name =
    Splitter.pane name (Html.p [ Attr.class "content" ] [ Html.text ("content of " ++ name) ])


twoPanes : Model
twoPanes =
    { split = Splitter.init "split" [ Splitter.percent 40, Splitter.percent 60 ]
    , attributes = []
    , panes = [ pane "Orders", pane "Details" ]
    }


threePanes : Model
threePanes =
    { split = Splitter.init "split" [ Splitter.percent 20, Splitter.percent 50, Splitter.percent 30 ]
    , attributes = []
    , panes = [ pane "Navigator", pane "Orders", pane "Details" ]
    }


view : Model -> Html Splitter.Msg
view model =
    Splitter.view identity model.attributes model.split model.panes


rendered : Model -> Query.Single Splitter.Msg
rendered model =
    Query.fromHtml (view model)


apply : Splitter.Msg -> Model -> Model
apply msg model =
    { model | split = Tuple.first (Splitter.update msg model.split) }


send : List Selector -> ( String, Encode.Value ) -> Model -> Result String Model
send selectors event model =
    (if List.isEmpty selectors then
        rendered model

     else
        rendered model |> Query.find selectors
    )
        |> Event.simulate event
        |> Event.toResult
        |> Result.map (\msg -> apply msg model)


percentages : Model -> List Int
percentages model =
    Splitter.sizes model.split |> List.map (Splitter.toPercent >> round)


separator : Int -> List Selector
separator index =
    [ Selector.id ("split-separator-" ++ String.fromInt index) ]


check : Result String Model -> List (Model -> Expectation) -> Expectation
check result checks =
    case result of
        Ok model ->
            Expect.all checks model

        Err reason ->
            Expect.fail reason


isOk : Result e a -> Bool
isOk result =
    case result of
        Ok _ ->
            True

        Err _ ->
            False


keyWith : List ( String, Bool ) -> String -> ( String, Encode.Value )
keyWith flags name =
    let
        on flag =
            List.any (\( other, value ) -> other == flag && value) flags
    in
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string name )
            , ( "ctrlKey", Encode.bool (on "ctrl") )
            , ( "metaKey", Encode.bool (on "meta") )
            , ( "shiftKey", Encode.bool (on "shift") )
            , ( "altKey", Encode.bool (on "alt") )
            ]
        )


key : String -> ( String, Encode.Value )
key =
    keyWith []


shifted : String -> ( String, Encode.Value )
shifted =
    keyWith [ ( "shift", True ) ]



-- STRUCTURE


structureTests : Test
structureTests =
    describe "structure"
        [ test "panes and separators in turn, with ids that the separators name" <|
            \_ ->
                rendered twoPanes
                    |> Expect.all
                        [ Query.find [ Selector.id "split-pane-0" ]
                            >> Query.has [ Selector.attribute (Attr.attribute "role" "group"), Selector.attribute (Attr.attribute "aria-label" "Orders"), Selector.text "content of Orders" ]
                        , Query.find [ Selector.id "split-pane-1" ]
                            >> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Details"), Selector.text "content of Details" ]
                        , Query.findAll [ Selector.attribute (Attr.attribute "role" "separator") ] >> Query.count (Expect.equal 1)
                        ]
        , test "a separator is a focusable separator with its value, its range and the panes it controls" <|
            \_ ->
                rendered twoPanes
                    |> Query.find (separator 0)
                    |> Query.has
                        [ Selector.attribute (Attr.attribute "role" "separator")
                        , Selector.attribute (Attr.tabindex 0)
                        , Selector.attribute (Attr.attribute "aria-orientation" "vertical")
                        , Selector.attribute (Attr.attribute "aria-label" "Resize Orders")
                        , Selector.attribute (Attr.attribute "aria-controls" "split-pane-0 split-pane-1")
                        , Selector.attribute (Attr.attribute "aria-valuenow" "40")
                        , Selector.attribute (Attr.attribute "aria-valuemin" "0")
                        , Selector.attribute (Attr.attribute "aria-valuemax" "100")
                        , Selector.attribute (Attr.attribute "aria-valuetext" "40 percent")
                        ]
        , test "the panes that a separator controls are on the page" <|
            \_ ->
                Expect.all
                    [ \m -> rendered m |> Query.find [ Selector.id "split-pane-0" ] |> Query.has []
                    , \m -> rendered m |> Query.find [ Selector.id "split-pane-1" ] |> Query.has []
                    , \m -> rendered m |> Query.has [ Selector.id "split", Selector.class "klar-splitter" ]
                    ]
                    twoPanes
        , test "stacked panes have horizontal separators" <|
            \_ ->
                let
                    model =
                        { twoPanes | attributes = [ Splitter.stacked, Splitter.height 300 ] }
                in
                Expect.all
                    [ \m -> rendered m |> Query.find (separator 0) |> Query.has [ Selector.attribute (Attr.attribute "aria-orientation" "horizontal") ]
                    , \m -> rendered m |> Query.has [ Selector.class "klar-splitter--stacked" ]
                    , \m -> rendered m |> Query.has [ Selector.attribute (Attr.attribute "style" "--klar-split-h:300px") ]
                    ]
                    model
        , test "three panes have two separators, each named after the pane before it" <|
            \_ ->
                Expect.all
                    [ \m -> rendered m |> Query.findAll [ Selector.attribute (Attr.attribute "role" "separator") ] |> Query.count (Expect.equal 2)
                    , \m -> rendered m |> Query.find (separator 0) |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Resize Navigator"), Selector.attribute (Attr.attribute "aria-valuenow" "20") ]
                    , \m -> rendered m |> Query.find (separator 1) |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Resize Orders"), Selector.attribute (Attr.attribute "aria-valuenow" "50"), Selector.attribute (Attr.attribute "aria-controls" "split-pane-1 split-pane-2") ]
                    ]
                    threePanes
        , test "one pane has no separator, no panes draw nothing but the box" <|
            \_ ->
                Expect.all
                    [ \m -> rendered { m | panes = [ pane "Only" ] } |> Query.findAll [ Selector.attribute (Attr.attribute "role" "separator") ] |> Query.count (Expect.equal 0)
                    , \m -> rendered { m | panes = [] } |> Query.findAll [ Selector.class "klar-splitter__pane" ] |> Query.count (Expect.equal 0)
                    ]
                    twoPanes
        , test "the sizes are the sizes of the panes, as a share of the room" <|
            \_ ->
                rendered twoPanes
                    |> Expect.all
                        [ Query.find [ Selector.id "split-pane-0" ] >> Query.has [ Selector.attribute (Attr.attribute "style" "--klar-grow:40") ]
                        , Query.find [ Selector.id "split-pane-1" ] >> Query.has [ Selector.attribute (Attr.attribute "style" "--klar-grow:60") ]
                        ]
        , test "pixel limits go to the stylesheet too, so that the layout keeps them while the window changes" <|
            \_ ->
                let
                    model =
                        { twoPanes
                            | panes =
                                [ pane "Orders" |> Splitter.minPixels 240 |> Splitter.maxPixels 600
                                , pane "Details"
                                ]
                        }
                in
                rendered model
                    |> Query.find [ Selector.id "split-pane-0" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "style" "--klar-grow:40;--klar-min:240px;--klar-max:600px") ]
        , test "pixel minimums that do not fit the container scroll it, so that the last pane is not cut off" <|
            \_ ->
                let
                    rule selector =
                        Css.rules
                            |> String.split (selector ++ "{")
                            |> List.drop 1
                            |> List.head
                            |> Maybe.andThen (String.split "}" >> List.head)
                            |> Maybe.withDefault ""
                in
                Expect.all
                    [ \_ -> Expect.equal True (String.contains "overflow-x: auto" (rule ".klar-splitter"))
                    , \_ -> Expect.equal True (String.contains "overflow-y: auto" (rule ".klar-splitter--stacked"))
                    ]
                    ()
        , test "a size outside the limits is drawn inside them" <|
            \_ ->
                let
                    model =
                        { twoPanes
                            | split = Splitter.init "split" [ Splitter.percent 5, Splitter.percent 95 ]
                            , panes = [ pane "Orders" |> Splitter.minSize (Splitter.percent 30), pane "Details" ]
                        }
                in
                rendered model
                    |> Query.find (separator 0)
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-valuenow" "30") ]
        , test "the range of a pane that can fold starts at the sliver that Home gives it, not at 0" <|
            \_ ->
                let
                    model =
                        { twoPanes | panes = [ pane "Orders" |> Splitter.collapsible, pane "Details" ] }
                in
                Expect.all
                    [ \m -> rendered m |> Query.find (separator 0) |> Query.has [ Selector.attribute (Attr.attribute "aria-valuemin" "2") ]
                    , \m ->
                        send (separator 0) (key "Home") m
                            |> Result.map percentages
                            |> Expect.equal (Ok [ 2, 98 ])
                    ]
                    model
        , test "the smallest size is the larger of a share and pixels, and a smallest size above the largest wins" <|
            \_ ->
                let
                    model =
                        { twoPanes
                            | panes =
                                [ pane "Orders" |> Splitter.minSize (Splitter.percent 30) |> Splitter.maxSize (Splitter.percent 20)
                                , pane "Details"
                                ]
                        }
                in
                Expect.all
                    [ \m -> rendered m |> Query.find (separator 0) |> Query.has [ Selector.attribute (Attr.attribute "aria-valuenow" "30") ]
                    , \m ->
                        send (separator 0) (key "End") m
                            |> Result.map percentages
                            |> Expect.equal (Ok [ 30, 70 ])
                    ]
                    model
        , test "a pane that is folded away says so, and is hidden" <|
            \_ ->
                let
                    model =
                        { twoPanes
                            | split = Splitter.init "split" [ Splitter.percent 0, Splitter.percent 100 ]
                            , panes = [ pane "Orders" |> Splitter.collapsible, pane "Details" ]
                        }
                in
                Expect.all
                    [ \m -> rendered m |> Query.find [ Selector.id "split-pane-0" ] |> Query.has [ Selector.class "klar-splitter__pane--folded" ]
                    , \m -> rendered m |> Query.find (separator 0) |> Query.has [ Selector.attribute (Attr.attribute "aria-valuenow" "0"), Selector.attribute (Attr.attribute "aria-valuetext" "Folded away") ]
                    ]
                    model
        , test "Norwegian Bokmål" <|
            \_ ->
                { twoPanes | attributes = [ Splitter.locale Locale.nb ] }
                    |> rendered
                    |> Query.find (separator 0)
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Endre størrelse på Orders"), Selector.attribute (Attr.attribute "aria-valuetext" "40 prosent") ]
        , test "nothing is announced by the splitter itself" <|
            \_ ->
                rendered twoPanes
                    |> Query.findAll [ Selector.attribute (Attr.attribute "aria-live" "assertive") ]
                    |> Query.count (Expect.equal 0)
        , test "nothing uses the drag and drop of the browser" <|
            \_ ->
                rendered twoPanes
                    |> Query.findAll [ Selector.attribute (Attr.draggable "true") ]
                    |> Query.count (Expect.equal 0)
        ]



-- THE KEYBOARD


keyboardTests : Test
keyboardTests =
    describe "keyboard"
        [ test "Right moves the separator one percent, Left back" <|
            \_ ->
                Expect.equal [ Ok [ 41, 59 ], Ok [ 39, 61 ] ]
                    [ send (separator 0) (key "ArrowRight") twoPanes |> Result.map percentages
                    , send (separator 0) (key "ArrowLeft") twoPanes |> Result.map percentages
                    ]
        , test "with Shift ten percent" <|
            \_ ->
                Expect.equal [ Ok [ 50, 50 ], Ok [ 30, 70 ] ]
                    [ send (separator 0) (shifted "ArrowRight") twoPanes |> Result.map percentages
                    , send (separator 0) (shifted "ArrowLeft") twoPanes |> Result.map percentages
                    ]
        , test "stacked panes use Up and Down" <|
            \_ ->
                let
                    model =
                        { twoPanes | attributes = [ Splitter.stacked ] }
                in
                Expect.equal
                    ( [ Ok [ 41, 59 ], Ok [ 39, 61 ] ], [ False, False ] )
                    ( [ send (separator 0) (key "ArrowDown") model |> Result.map percentages
                      , send (separator 0) (key "ArrowUp") model |> Result.map percentages
                      ]
                    , [ isOk (send (separator 0) (key "ArrowRight") model), isOk (send (separator 0) (key "ArrowLeft") model) ]
                    )
        , test "side by side panes do not use Up and Down" <|
            \_ ->
                Expect.equal [ False, False ]
                    [ isOk (send (separator 0) (key "ArrowDown") twoPanes), isOk (send (separator 0) (key "ArrowUp") twoPanes) ]
        , test "Home and End give the pane before the separator its smallest and largest size" <|
            \_ ->
                let
                    model =
                        { twoPanes | panes = [ pane "Orders" |> Splitter.minSize (Splitter.percent 20) |> Splitter.maxSize (Splitter.percent 70), pane "Details" ] }
                in
                Expect.equal [ Ok [ 20, 80 ], Ok [ 70, 30 ] ]
                    [ send (separator 0) (key "Home") model |> Result.map percentages
                    , send (separator 0) (key "End") model |> Result.map percentages
                    ]
        , test "a step stops at the limits" <|
            \_ ->
                let
                    model =
                        { twoPanes | panes = [ pane "Orders", pane "Details" |> Splitter.minSize (Splitter.percent 55) ] }
                in
                send (separator 0) (shifted "ArrowRight") model
                    |> Result.map percentages
                    |> Expect.equal (Ok [ 45, 55 ])
        , test "the value of the separator follows the keys" <|
            \_ ->
                check (send (separator 0) (key "ArrowRight") twoPanes)
                    [ \m -> rendered m |> Query.find (separator 0) |> Query.has [ Selector.attribute (Attr.attribute "aria-valuenow" "41"), Selector.attribute (Attr.attribute "aria-valuetext" "41 percent") ]
                    ]
        , test "keys with Ctrl, Alt or Meta are left to the browser" <|
            \_ ->
                Expect.equal [ False, False, False ]
                    (List.map (\flag -> isOk (send (separator 0) (keyWith [ ( flag, True ) ] "ArrowRight") twoPanes)) [ "ctrl", "alt", "meta" ])
        , test "Enter folds a pane that can fold, and opens it again" <|
            \_ ->
                let
                    model =
                        { twoPanes | panes = [ pane "Orders" |> Splitter.collapsible, pane "Details" ] }
                in
                Expect.equal [ Ok [ 0, 100 ], Ok [ 40, 60 ] ]
                    [ send (separator 0) (key "Enter") model |> Result.map percentages
                    , send (separator 0) (key "Enter") model
                        |> Result.andThen (send (separator 0) (key "Enter"))
                        |> Result.map percentages
                    ]
        , test "Enter does nothing where no pane can fold" <|
            \_ ->
                Expect.equal False (isOk (send (separator 0) (key "Enter") twoPanes))
        , test "a double click does the same as Enter, where a pane can fold" <|
            \_ ->
                let
                    model =
                        { twoPanes | panes = [ pane "Orders", pane "Details" |> Splitter.collapsible ] }

                    doubleClick =
                        Event.custom "dblclick" (Encode.object [])
                in
                Expect.equal ( Ok [ 100, 0 ], False )
                    ( send (separator 0) doubleClick model |> Result.map percentages
                    , isOk (send (separator 0) doubleClick twoPanes)
                    )
        , test "Escape does nothing while no separator is dragged" <|
            \_ ->
                Expect.equal False (isOk (send (separator 0) (key "Escape") twoPanes))
        ]



-- THE POINTER


pointerDown : String -> Int -> ( String, Encode.Value )
pointerDown kind button =
    Event.custom "pointerdown"
        (Encode.object
            [ ( "pointerType", Encode.string kind )
            , ( "button", Encode.int button )
            , ( "isPrimary", Encode.bool True )
            , ( "pageX", Encode.float 400 )
            , ( "pageY", Encode.float 100 )
            ]
        )


mouseMove : Float -> Int -> ( String, Encode.Value )
mouseMove x buttons =
    Event.custom "mousemove"
        (Encode.object [ ( "pageX", Encode.float x ), ( "pageY", Encode.float 100 ), ( "buttons", Encode.int buttons ) ])


pointerTests : Test
pointerTests =
    let
        press kind =
            send (separator 0) (pointerDown kind 0) twoPanes

        pressAndMove =
            press "mouse" |> Result.andThen (send [] (mouseMove 450 1))
    in
    describe "pointer"
        [ test "a press with the mouse starts a drag, but nothing covers the window before the pointer moves" <|
            \_ ->
                check (press "mouse")
                    [ \m -> Expect.equal True (Splitter.isDragging m.split)
                    , \m -> rendered m |> Query.has [ Selector.class "klar-splitter--dragging" ]
                    , \m -> rendered m |> Query.findAll [ Selector.class "klar-splitter__layer" ] |> Query.count (Expect.equal 0)
                    , \m -> rendered m |> Query.find (separator 0) |> Query.has [ Selector.class "klar-splitter__separator--active" ]
                    ]
        , test "once the pointer moves, a layer over the window gives one cursor and keeps the mouse from the page below" <|
            \_ ->
                check pressAndMove
                    [ \m -> rendered m |> Query.findAll [ Selector.class "klar-splitter__layer" ] |> Query.count (Expect.equal 1)
                    , \m -> Expect.equal True (Splitter.isDragging m.split)
                    ]
        , test "only the main button presses" <|
            \_ ->
                Expect.equal False (isOk (send (separator 0) (pointerDown "mouse" 2) twoPanes))
        , test "a finger is followed through the box, and no layer is put over the window" <|
            \_ ->
                let
                    touchMove =
                        Event.custom "pointermove" (Encode.object [ ( "pageX", Encode.float 450 ), ( "pageY", Encode.float 100 ), ( "buttons", Encode.int 1 ) ])
                in
                check (press "touch")
                    [ \m -> Expect.equal True (Splitter.isDragging m.split)
                    , \m -> Expect.equal True (isOk (send [] touchMove m))
                    , \m -> Expect.equal False (isOk (send [] (mouseMove 450 1) m))
                    , \m -> rendered m |> Query.findAll [ Selector.class "klar-splitter__layer" ] |> Query.count (Expect.equal 0)
                    ]
        , test "a finger that the browser takes over ends the drag and puts the sizes back" <|
            \_ ->
                press "touch"
                    |> Result.andThen (send [] (Event.custom "pointermove" (Encode.object [ ( "pageX", Encode.float 450 ), ( "pageY", Encode.float 100 ), ( "buttons", Encode.int 1 ) ])))
                    |> Result.andThen (send [] (Event.custom "pointercancel" (Encode.object [])))
                    |> Result.map (\m -> ( Splitter.isDragging m.split, percentages m ))
                    |> Expect.equal (Ok ( False, [ 40, 60 ] ))
        , test "the mouse is followed while the button is down, and the drag ends on release" <|
            \_ ->
                press "mouse"
                    |> Result.andThen (send [] (Event.custom "mouseup" (Encode.object [])))
                    |> Result.map (\m -> Splitter.isDragging m.split)
                    |> Expect.equal (Ok False)
        , test "a mouse button that was let go unseen ends the drag" <|
            \_ ->
                press "mouse"
                    |> Result.andThen (send [] (mouseMove 450 0))
                    |> Result.map (\m -> Splitter.isDragging m.split)
                    |> Expect.equal (Ok False)
        , test "Escape cancels a drag" <|
            \_ ->
                pressAndMove
                    |> Result.andThen (send (separator 0) (key "Escape"))
                    |> Result.map (\m -> Splitter.isDragging m.split)
                    |> Expect.equal (Ok False)
        , test "the keys of the separator wait while a drag goes on" <|
            \_ ->
                press "mouse"
                    |> Result.andThen (send (separator 0) (key "ArrowRight"))
                    |> Expect.err
        , test "the click that ends a drag stops at the splitter; the click of a plain press goes on (so a double click works)" <|
            \_ ->
                let
                    stopsClick model =
                        rendered model
                            |> Event.simulate (Event.custom "click" (Encode.object []))
                            |> Event.toResult
                            |> isOk
                in
                Expect.equal [ Ok False, Ok True, Ok False ]
                    [ press "mouse" |> Result.map stopsClick
                    , pressAndMove |> Result.map stopsClick
                    , Ok (stopsClick twoPanes)
                    ]
        , test "the mouse going down on a separator does not select text or start a native drag" <|
            \_ ->
                Expect.equal [ True, False ]
                    [ isOk (send (separator 0) (Event.custom "mousedown" (Encode.object [ ( "button", Encode.int 0 ) ])) twoPanes)
                    , isOk (send (separator 0) (Event.custom "mousedown" (Encode.object [ ( "button", Encode.int 2 ) ])) twoPanes)
                    ]
        ]



-- SIZES


sizesTests : Test
sizesTests =
    describe "sizes"
        [ test "percent is a number from 0 to 100" <|
            \_ ->
                Expect.equal [ 0, 0, 100, 35.5 ]
                    (List.map (Splitter.percent >> Splitter.toPercent) [ -20, 0 / 0, 400, 35.5 ])
        , test "sizes that do not add up to 100 are scaled to" <|
            \_ ->
                Splitter.init "x" [ Splitter.percent 30, Splitter.percent 30 ]
                    |> Splitter.sizes
                    |> List.map Splitter.toPercent
                    |> Expect.equal [ 50, 50 ]
        , test "setSizes restores a saved layout" <|
            \_ ->
                twoPanes.split
                    |> Splitter.setSizes [ Splitter.percent 25, Splitter.percent 75 ]
                    |> Splitter.sizes
                    |> List.map Splitter.toPercent
                    |> Expect.equal [ 25, 75 ]
        , test "sizes the user set come back in sizes" <|
            \_ ->
                send (separator 0) (shifted "ArrowRight") twoPanes
                    |> Result.map (\m -> List.map Splitter.toPercent (Splitter.sizes m.split))
                    |> Result.map (List.map round)
                    |> Expect.equal (Ok [ 50, 50 ])
        , test "more panes than sizes: the new pane gets an equal share" <|
            \_ ->
                { twoPanes | panes = [ pane "A", pane "B", pane "C" ] }
                    |> rendered
                    |> Query.find [ Selector.id "split-pane-2" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "style" "--klar-grow:33.33333333333333") ]
        , test "no sizes at all: an equal share" <|
            \_ ->
                { twoPanes | split = Splitter.init "split" [] }
                    |> rendered
                    |> Query.find [ Selector.id "split-pane-0" ]
                    |> Query.has [ Selector.attribute (Attr.attribute "style" "--klar-grow:50") ]
        ]



-- FOLDING FROM THE APPLICATION


percents : Splitter.State -> List Int
percents state =
    Splitter.sizes state |> List.map (Splitter.toPercent >> round)


thirtySeventy : Splitter.State
thirtySeventy =
    Splitter.init "split" [ Splitter.percent 30, Splitter.percent 70 ]


foldTests : Test
foldTests =
    describe "fold, unfold and isFolded"
        [ test "fold gives the room of the pane to the next one" <|
            \_ -> thirtySeventy |> Splitter.fold 0 |> percents |> Expect.equal [ 0, 100 ]
        , test "fold of the last pane gives its room to the one before" <|
            \_ -> thirtySeventy |> Splitter.fold 1 |> percents |> Expect.equal [ 100, 0 ]
        , test "unfold gives back the room the pane had" <|
            \_ ->
                Expect.all
                    [ \_ -> thirtySeventy |> Splitter.fold 0 |> Splitter.unfold 0 |> percents |> Expect.equal [ 30, 70 ]
                    , \_ -> thirtySeventy |> Splitter.fold 1 |> Splitter.unfold 1 |> percents |> Expect.equal [ 30, 70 ]
                    ]
                    ()
        , test "isFolded follows" <|
            \_ ->
                Expect.equal [ False, True, False ]
                    [ Splitter.isFolded 1 thirtySeventy
                    , Splitter.isFolded 1 (Splitter.fold 1 thirtySeventy)
                    , Splitter.isFolded 1 (thirtySeventy |> Splitter.fold 1 |> Splitter.unfold 1)
                    ]
        , test "a place that is not there is not folded, and folding it changes nothing" <|
            \_ ->
                Expect.all
                    [ \_ -> Splitter.isFolded 5 thirtySeventy |> Expect.equal False
                    , \_ -> Splitter.isFolded -1 thirtySeventy |> Expect.equal False
                    , \_ -> thirtySeventy |> Splitter.fold 5 |> percents |> Expect.equal [ 30, 70 ]
                    , \_ -> thirtySeventy |> Splitter.fold -1 |> percents |> Expect.equal [ 30, 70 ]
                    ]
                    ()
        , test "unfold of a pane that has room changes nothing" <|
            \_ -> thirtySeventy |> Splitter.unfold 0 |> percents |> Expect.equal [ 30, 70 ]
        , test "a pane restored folded gets a fifth back" <|
            \_ ->
                thirtySeventy
                    |> Splitter.setSizes [ Splitter.percent 0, Splitter.percent 100 ]
                    |> Splitter.unfold 0
                    |> percents
                    |> Expect.equal [ 20, 80 ]
        , test "the middle pane of three folds into the next one and comes back from it" <|
            \_ ->
                Splitter.init "split" [ Splitter.percent 20, Splitter.percent 30, Splitter.percent 50 ]
                    |> Expect.all
                        [ Splitter.fold 1 >> percents >> Expect.equal [ 20, 0, 80 ]
                        , Splitter.fold 1 >> Splitter.unfold 1 >> percents >> Expect.equal [ 20, 30, 50 ]
                        ]
        , test "a folded collapsible pane is drawn folded" <|
            \_ ->
                { twoPanes | split = Splitter.fold 1 twoPanes.split, panes = [ pane "A", pane "B" |> Splitter.collapsible ] }
                    |> rendered
                    |> Query.find [ Selector.id "split-pane-1" ]
                    |> Query.has [ Selector.class "klar-splitter__pane--folded" ]
        , test "a pane the application folds is drawn folded even when it is not collapsible, so isFolded tells the truth" <|
            \_ ->
                { twoPanes | split = Splitter.fold 1 twoPanes.split, panes = [ pane "A", pane "B" |> Splitter.minSize (Splitter.percent 30) ] }
                    |> Expect.all
                        [ \model -> Splitter.isFolded 1 model.split |> Expect.equal True
                        , rendered
                            >> Query.find [ Selector.id "split-pane-1" ]
                            >> Query.has [ Selector.class "klar-splitter__pane--folded" ]
                        ]
        , test "Enter on the separator opens a pane the application folded, collapsible or not" <|
            \_ ->
                { twoPanes | split = Splitter.fold 1 twoPanes.split }
                    |> send (separator 0) (key "Enter")
                    |> Result.map percentages
                    |> Expect.equal (Ok [ 40, 60 ])
        , test "the middle pane of three opens from the pane that took its room, from either separator" <|
            \_ ->
                { threePanes | split = Splitter.fold 1 threePanes.split, panes = [ pane "Navigator", pane "Orders" |> Splitter.collapsible, pane "Details" ] }
                    |> Expect.all
                        [ \model -> percentages model |> Expect.equal [ 20, 0, 80 ]
                        , send (separator 0) (key "Enter") >> Result.map percentages >> Expect.equal (Ok [ 20, 50, 30 ])
                        , send (separator 1) (key "Enter") >> Result.map percentages >> Expect.equal (Ok [ 20, 50, 30 ])
                        ]
        , test "unfold after a restored fold is brought inside the smallest size of the pane when it is drawn" <|
            \_ ->
                { twoPanes
                    | split =
                        twoPanes.split
                            |> Splitter.setSizes [ Splitter.percent 100, Splitter.percent 0 ]
                            |> Splitter.unfold 1
                    , panes = [ pane "A", pane "B" |> Splitter.collapsible |> Splitter.minSize (Splitter.percent 30) ]
                }
                    |> rendered
                    |> Query.find (separator 0)
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-valuenow" "70") ]
        , test "separatorId is the id of the separator" <|
            \_ ->
                twoPanes
                    |> rendered
                    |> Query.find [ Selector.id (Splitter.separatorId 0 twoPanes.split) ]
                    |> Query.has [ Selector.attribute (Attr.attribute "role" "separator") ]
        ]
