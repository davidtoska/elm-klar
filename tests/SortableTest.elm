module SortableTest exposing (suite)

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.Locale as Locale
import Klar.Sortable as Sortable
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


suite : Test
suite =
    describe "Sortable: what is rendered and what the events do"
        [ structureTests
        , keyboardTests
        , reorderTests
        , pointerTests
        , typedIdTests
        ]



-- THE APPLICATION IN A NUTSHELL


type alias Model =
    { sortable : Sortable.State String
    , items : List String
    , attributes : List Sortable.Attribute
    , fixedItems : List String
    }


start : List String -> Model
start items =
    { sortable = Sortable.init "list", items = items, attributes = [], fixedItems = [] }


five : Model
five =
    start [ "a", "b", "c", "d", "e" ]


withAttributes : List Sortable.Attribute -> Model -> Model
withAttributes attributes model =
    { model | attributes = attributes }


withFixed : List String -> Model -> Model
withFixed names model =
    { model | fixedItems = names }


view : Model -> Html Sortable.Msg
view model =
    Sortable.view Sortable.stringIds
        identity
        (Sortable.ariaLabel "Pick sequence" :: model.attributes)
        model.sortable
        (List.map
            (\name ->
                if List.member name model.fixedItems then
                    Sortable.item name ("Step " ++ name) (Html.text ("content " ++ name)) |> Sortable.fixed

                else
                    Sortable.item name ("Step " ++ name) (Html.span [ Attr.class "step" ] [ Html.text ("content " ++ name) ])
            )
            model.items
        )


rendered : Model -> Query.Single Sortable.Msg
rendered model =
    Query.fromHtml (view model)


apply : Sortable.Msg -> Model -> Model
apply msg model =
    let
        ( next, _ ) =
            Sortable.update msg model.sortable
    in
    { model
        | sortable = next
        , items = Sortable.reorder Sortable.stringIds identity model.sortable next model.items
    }


{-| The message that one event of one element of the rendered list produces. An
error says that there was no such element or that it does not listen to the event.
-}
messageOf : List Selector -> ( String, Encode.Value ) -> Model -> Result String Sortable.Msg
messageOf selectors event model =
    (if List.isEmpty selectors then
        -- no selector: the event goes to the box around the list
        rendered model

     else
        rendered model |> Query.find selectors
    )
        |> Event.simulate event
        |> Event.toResult


send : List Selector -> ( String, Encode.Value ) -> Model -> Result String Model
send selectors event model =
    messageOf selectors event model |> Result.map (\msg -> apply msg model)


drive : List ( List Selector, ( String, Encode.Value ) ) -> Model -> Result String Model
drive events model =
    List.foldl (\( selectors, event ) result -> Result.andThen (send selectors event) result) (Ok model) events


{-| Key presses on the handles: the name of the item and the key.
-}
afterKeys : List ( String, ( String, Encode.Value ) ) -> Model -> Result String Model
afterKeys presses =
    drive (List.map (\( name, event ) -> ( handleOf name, event )) presses)


{-| The checks on the model that came out, or the reason that there is none.
-}
check : Result String Model -> List (Model -> Expectation) -> Expectation
check result checks =
    case result of
        Ok model ->
            Expect.all checks model

        Err reason ->
            Expect.fail reason


handleOf : String -> List Selector
handleOf name =
    [ Selector.id ("list-handle-" ++ name) ]


itemOf : String -> List Selector
itemOf name =
    [ Selector.id ("list-item-" ++ name) ]


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
            , ( "shiftKey", Encode.bool False )
            , ( "altKey", Encode.bool (on "alt") )
            , ( "repeat", Encode.bool (on "repeat") )
            ]
        )


key : String -> ( String, Encode.Value )
key =
    keyWith []


space : ( String, Encode.Value )
space =
    key " "


order : Result String Model -> Result String (List String)
order =
    Result.map .items


liveRegion : Model -> Query.Single Sortable.Msg
liveRegion model =
    rendered model |> Query.find [ Selector.attribute (Attr.attribute "aria-live" "assertive") ]


says : String -> Model -> Expectation
says text model =
    liveRegion model |> Query.has [ Selector.text text ]


held : Model -> Maybe String
held model =
    Sortable.lifted Sortable.stringIds model.sortable


isOk : Result e a -> Bool
isOk result =
    case result of
        Ok _ ->
            True

        Err _ ->
            False



-- STRUCTURE


structureTests : Test
structureTests =
    describe "structure"
        [ test "a named list of list items, each with its own handle" <|
            \_ ->
                rendered five
                    |> Expect.all
                        [ Query.find [ Selector.tag "ol" ]
                            >> Query.has
                                [ Selector.attribute (Attr.attribute "role" "list")
                                , Selector.attribute (Attr.attribute "aria-label" "Pick sequence")
                                ]
                        , Query.findAll [ Selector.tag "li", Selector.attribute (Attr.attribute "role" "listitem") ] >> Query.count (Expect.equal 5)
                        , Query.findAll [ Selector.tag "button" ] >> Query.count (Expect.equal 5)
                        ]
        , test "the handle is a button named after the item, told apart as a sortable item, and described" <|
            \_ ->
                rendered five
                    |> Query.find (handleOf "c")
                    |> Query.has
                        [ Selector.tag "button"
                        , Selector.attribute (Attr.type_ "button")
                        , Selector.attribute (Attr.attribute "aria-label" "Step c")
                        , Selector.attribute (Attr.attribute "aria-roledescription" "sortable item")
                        , Selector.attribute (Attr.attribute "aria-describedby" "list-help")
                        , Selector.attribute (Attr.attribute "aria-pressed" "false")
                        ]
        , test "the description that the handle names is on the page" <|
            \_ ->
                rendered five
                    |> Query.find [ Selector.id "list-help" ]
                    |> Query.has [ Selector.text "Press Space or Enter to pick up. Then use the Up and Down arrow keys" ]
        , test "the content of an item is drawn as it is" <|
            \_ ->
                rendered five
                    |> Query.find (itemOf "d")
                    |> Query.has [ Selector.text "content d", Selector.class "step" ]
        , test "nothing uses the drag and drop of the browser, which Firefox only starts from JavaScript" <|
            \_ ->
                rendered five
                    |> Query.findAll [ Selector.attribute (Attr.draggable "true") ]
                    |> Query.count (Expect.equal 0)
        , test "a live region that interrupts belongs to the list" <|
            \_ ->
                liveRegion five
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-atomic" "true"), Selector.class "klar-sr-only" ]
        , test "a fixed item has no handle, only a lock and the words" <|
            \_ ->
                let
                    model =
                        withFixed [ "a" ] five
                in
                Expect.all
                    [ \m -> rendered m |> Query.findAll [ Selector.tag "button" ] |> Query.count (Expect.equal 4)
                    , \m -> rendered m |> Query.find (itemOf "a") |> Query.has [ Selector.text "Fixed position", Selector.class "klar-sortable__item--fixed" ]
                    , \m -> rendered m |> Query.find (itemOf "a") |> Query.findAll [ Selector.tag "button" ] |> Query.count (Expect.equal 0)
                    ]
                    model
        , test "a list that cannot be changed has handles that cannot be used" <|
            \_ ->
                let
                    model =
                        withAttributes [ Sortable.disabled True ] five
                in
                Expect.all
                    [ \m -> rendered m |> Query.findAll [ Selector.tag "button", Selector.disabled True ] |> Query.count (Expect.equal 5)
                    , \m -> rendered m |> Query.has [ Selector.class "klar-sortable--disabled" ]
                    , \m -> Expect.err (send (handleOf "a") space m)
                    , \m -> Expect.err (send (handleOf "a") (key "Enter") m)
                    , \m -> Expect.err (send (itemOf "a") (pointerDownOn "mouse" 0 "handle") m)
                    ]
                    model
        , test "no items: the text, no list, and the live region is still there" <|
            \_ ->
                Expect.all
                    [ \m -> rendered m |> Query.has [ Selector.text "No items" ]
                    , \m -> rendered m |> Query.findAll [ Selector.tag "ol" ] |> Query.count (Expect.equal 0)
                    , \m -> liveRegion m |> Query.has []
                    ]
                    (start [])
        , test "no items: a text of your own" <|
            \_ ->
                start []
                    |> withAttributes [ Sortable.emptyText "No steps yet" ]
                    |> rendered
                    |> Query.has [ Selector.text "No steps yet" ]
        , test "a horizontal list says so and names the Left and Right keys" <|
            \_ ->
                let
                    model =
                        withAttributes [ Sortable.horizontal ] five
                in
                Expect.all
                    [ \m -> rendered m |> Query.has [ Selector.class "klar-sortable--horizontal" ]
                    , \m -> rendered m |> Query.find [ Selector.id "list-help" ] |> Query.has [ Selector.text "Left and Right arrow keys" ]
                    ]
                    model
        , test "Norwegian Bokmål" <|
            \_ ->
                let
                    model =
                        withAttributes [ Sortable.locale Locale.nb ] five
                in
                Expect.all
                    [ \m -> rendered m |> Query.find (handleOf "a") |> Query.has [ Selector.attribute (Attr.attribute "aria-roledescription" "sorterbart element") ]
                    , \m -> rendered m |> Query.find [ Selector.id "list-help" ] |> Query.has [ Selector.text "Trykk mellomrom eller Enter for å løfte" ]
                    , \m -> check (afterKeys [ ( "b", space ) ] m) [ says "Step b er løftet, posisjon 2 av 5." ]
                    , \m -> check (afterKeys [ ( "b", space ), ( "b", key "ArrowDown" ) ] m) [ says "Flyttet til posisjon 3 av 5." ]
                    , \m -> check (afterKeys [ ( "b", space ), ( "b", key "ArrowDown" ), ( "b", space ) ] m) [ says "Step b er sluppet på posisjon 3 av 5." ]
                    , \m -> check (afterKeys [ ( "b", space ), ( "b", key "ArrowDown" ), ( "b", key "Escape" ) ] m) [ says "Avbrutt. Step b er tilbake på posisjon 2 av 5." ]
                    , \m -> check (afterKeys [ ( "a", space ), ( "a", key "ArrowUp" ) ] m) [ says "Posisjon 1 av 5. Kan ikke flyttes lenger." ]
                    ]
                    model
        , test "the same id twice draws the item once" <|
            \_ ->
                start [ "a", "b", "a", "c" ]
                    |> rendered
                    |> Query.findAll [ Selector.tag "li" ]
                    |> Query.count (Expect.equal 3)
        , test "ids with characters that are not safe in an id still give a DOM id each" <|
            \_ ->
                let
                    model =
                        start [ "a b", "a-b", "a/b" ]
                in
                Expect.all
                    [ \m -> rendered m |> Query.find [ Selector.id "list-item-a%20b" ] |> Query.has [ Selector.text "content a b" ]
                    , \m -> rendered m |> Query.find [ Selector.id "list-item-a-b" ] |> Query.has [ Selector.text "content a-b" ]
                    , \m -> rendered m |> Query.find [ Selector.id "list-item-a%2Fb" ] |> Query.has [ Selector.text "content a/b" ]
                    ]
                    model
        ]



-- THE KEYBOARD


keyboardTests : Test
keyboardTests =
    describe "keyboard"
        [ test "Space picks the item up: pressed, lifted, announced" <|
            \_ ->
                check (afterKeys [ ( "b", space ) ] five)
                    [ \m -> rendered m |> Query.find (handleOf "b") |> Query.has [ Selector.attribute (Attr.attribute "aria-pressed" "true") ]
                    , \m -> rendered m |> Query.find (itemOf "b") |> Query.has [ Selector.class "klar-sortable__item--lifted" ]
                    , says "Step b picked up, position 2 of 5."
                    , \m -> Expect.equal (Just "b") (held m)
                    ]
        , test "Enter picks up too" <|
            \_ ->
                check (afterKeys [ ( "c", key "Enter" ) ] five) [ \m -> Expect.equal (Just "c") (held m) ]
        , test "the arrow keys move the target one place, and a line shows where the item would land" <|
            \_ ->
                check (afterKeys [ ( "b", space ), ( "b", key "ArrowDown" ), ( "b", key "ArrowDown" ) ] five)
                    [ says "Moved to position 4 of 5."
                    , \m -> rendered m |> Query.find (itemOf "d") |> Query.has [ Selector.class "klar-sortable__item--drop-after" ]
                    , \m -> rendered m |> Query.findAll [ Selector.class "klar-sortable__item--drop-before" ] |> Query.count (Expect.equal 0)
                    , \m -> Expect.equal [ "a", "b", "c", "d", "e" ] m.items
                    ]
        , test "moving up draws the line before" <|
            \_ ->
                check (afterKeys [ ( "d", space ), ( "d", key "ArrowUp" ) ] five)
                    [ \m -> rendered m |> Query.find (itemOf "c") |> Query.has [ Selector.class "klar-sortable__item--drop-before" ] ]
        , test "while the item is held the list is not rearranged (the handle that has the focus stays put)" <|
            \_ ->
                check (afterKeys [ ( "b", space ), ( "b", key "ArrowDown" ) ] five)
                    [ \m -> Expect.equal [ "a", "b", "c", "d", "e" ] m.items
                    , \m -> rendered m |> Query.findAll [ Selector.tag "li" ] |> Query.count (Expect.equal 5)
                    ]
        , test "Space drops it, and the list is in the new order" <|
            \_ ->
                afterKeys [ ( "b", space ), ( "b", key "ArrowDown" ), ( "b", key "ArrowDown" ), ( "b", space ) ] five
                    |> order
                    |> Expect.equal (Ok [ "a", "c", "d", "b", "e" ])
        , test "Enter drops it too" <|
            \_ ->
                afterKeys [ ( "d", space ), ( "d", key "ArrowUp" ), ( "d", key "Enter" ) ] five
                    |> order
                    |> Expect.equal (Ok [ "a", "b", "d", "c", "e" ])
        , test "after the drop it is announced and nothing is held" <|
            \_ ->
                check (afterKeys [ ( "a", space ), ( "a", key "End" ), ( "a", space ) ] five)
                    [ says "Step a dropped at position 5 of 5."
                    , \m -> Expect.equal Nothing (held m)
                    , \m -> rendered m |> Query.findAll [ Selector.class "klar-sortable__item--lifted" ] |> Query.count (Expect.equal 0)
                    ]
        , test "Home and End jump to the ends" <|
            \_ ->
                Expect.equal
                    [ Ok [ "c", "a", "b", "d", "e" ], Ok [ "a", "b", "d", "e", "c" ] ]
                    [ afterKeys [ ( "c", space ), ( "c", key "Home" ), ( "c", space ) ] five |> order
                    , afterKeys [ ( "c", space ), ( "c", key "End" ), ( "c", space ) ] five |> order
                    ]
        , test "dropping an item where it was does not move anything" <|
            \_ ->
                check (afterKeys [ ( "c", space ), ( "c", key "ArrowDown" ), ( "c", key "ArrowUp" ), ( "c", space ) ] five)
                    [ \m -> Expect.equal [ "a", "b", "c", "d", "e" ] m.items
                    , says "Step c dropped at position 3 of 5."
                    ]
        , test "Escape puts everything back and says so" <|
            \_ ->
                check (afterKeys [ ( "b", space ), ( "b", key "ArrowDown" ), ( "b", key "Escape" ) ] five)
                    [ \m -> Expect.equal [ "a", "b", "c", "d", "e" ] m.items
                    , says "Cancelled. Step b is back at position 2 of 5."
                    , \m -> rendered m |> Query.find (handleOf "b") |> Query.has [ Selector.attribute (Attr.attribute "aria-pressed" "false") ]
                    ]
        , test "leaving the handle cancels the move" <|
            \_ ->
                afterKeys [ ( "b", space ), ( "b", key "ArrowDown" ) ] five
                    |> Result.andThen (drive [ ( handleOf "b", Event.custom "blur" (Encode.object []) ) ])
                    |> check
                    |> (\run -> run [ \m -> Expect.equal Nothing (held m), says "Cancelled. Step b is back at position 2 of 5." ])
        , test "the item stops at the ends and says that it cannot move further" <|
            \_ ->
                check (afterKeys [ ( "a", space ), ( "a", key "ArrowUp" ) ] five)
                    [ says "Position 1 of 5. It cannot move further."
                    , \m -> rendered m |> Query.findAll [ Selector.class "klar-sortable__item--drop-before" ] |> Query.count (Expect.equal 0)
                    ]
        , test "a fixed item cannot be passed, and nothing beyond it can be reached" <|
            \_ ->
                let
                    model =
                        withFixed [ "c" ] five
                in
                Expect.equal
                    [ Ok [ "b", "a", "c", "d", "e" ]
                    , Ok [ "a", "b", "c", "e", "d" ]
                    , Ok [ "a", "b", "c", "d", "e" ]
                    ]
                    [ afterKeys [ ( "a", space ), ( "a", key "End" ), ( "a", space ) ] model |> order
                    , afterKeys [ ( "d", space ), ( "d", key "End" ), ( "d", space ) ] model |> order
                    , afterKeys [ ( "d", space ), ( "d", key "Home" ), ( "d", space ) ] model |> order
                    ]
        , test "a fixed item has no handle to press keys on" <|
            \_ ->
                Expect.err (send (handleOf "c") space (withFixed [ "c" ] five))
        , test "in a horizontal list the Left and Right keys move, Up and Down do not" <|
            \_ ->
                let
                    model =
                        withAttributes [ Sortable.horizontal ] five
                in
                Expect.equal
                    ( [ Ok [ "a", "c", "b", "d", "e" ], Ok [ "b", "a", "c", "d", "e" ] ]
                    , [ False, False ]
                    )
                    ( [ afterKeys [ ( "b", space ), ( "b", key "ArrowRight" ), ( "b", space ) ] model |> order
                      , afterKeys [ ( "b", space ), ( "b", key "ArrowLeft" ), ( "b", space ) ] model |> order
                      ]
                    , [ afterKeys [ ( "b", space ), ( "b", key "ArrowDown" ) ] model |> isOk
                      , afterKeys [ ( "b", space ), ( "b", key "ArrowUp" ) ] model |> isOk
                      ]
                    )
        , test "keys with Ctrl, Alt or Meta are left to the browser" <|
            \_ ->
                Expect.equal
                    [ False, False, False ]
                    (List.map
                        (\flags -> isOk (send (handleOf "a") (keyWith flags " ") five))
                        [ [ ( "ctrl", True ) ], [ ( "alt", True ) ], [ ( "meta", True ) ] ]
                    )
        , test "a key held down does not pick up and drop over and over" <|
            \_ ->
                let
                    repeated =
                        keyWith [ ( "repeat", True ) ] " "
                in
                Expect.equal
                    [ Ok Nothing, Ok (Just "a") ]
                    [ drive [ ( handleOf "a", repeated ) ] five |> Result.map held
                    , afterKeys [ ( "a", space ) ] five |> Result.andThen (drive [ ( handleOf "a", repeated ) ]) |> Result.map held
                    ]
        , test "the arrow keys of a handle that holds nothing are left to the browser" <|
            \_ ->
                Expect.equal [ False, False, False ]
                    (List.map (\name -> isOk (send (handleOf "a") (key name) five)) [ "Escape", "ArrowDown", "Home" ])
        , test "picking up a second item replaces the first" <|
            \_ ->
                check (afterKeys [ ( "b", space ), ( "d", space ) ] five)
                    [ \m -> Expect.equal (Just "d") (held m) ]
        ]



-- REORDER


reorderTests : Test
reorderTests =
    let
        -- the message that drops "b" one place down, and the states around it
        dropOne : Result String ( Sortable.State String, Sortable.State String )
        dropOne =
            afterKeys [ ( "b", space ), ( "b", key "ArrowDown" ) ] five
                |> Result.andThen
                    (\model ->
                        messageOf (handleOf "b") space model
                            |> Result.map (\msg -> ( model.sortable, Tuple.first (Sortable.update msg model.sortable) ))
                    )

        reorderWith list =
            dropOne |> Result.map (\( before, after ) -> Sortable.reorder Sortable.stringIds identity before after list)
    in
    describe "reorder"
        [ test "an update that dropped nothing leaves the list alone" <|
            \_ ->
                messageOf (handleOf "a") space five
                    |> Result.map (\msg -> Tuple.first (Sortable.update msg five.sortable))
                    |> Result.map (\after -> Sortable.reorder Sortable.stringIds identity five.sortable after [ "a", "b", "c" ])
                    |> Expect.equal (Ok [ "a", "b", "c" ])
        , test "the move is applied to the list the application has now, found by id" <|
            \_ ->
                Expect.equal
                    [ Ok [ "x", "c", "b", "y" ], Ok [ "x", "y" ], Ok [] ]
                    [ reorderWith [ "x", "b", "c", "y" ], reorderWith [ "x", "y" ], reorderWith [] ]
        , test "the same id twice in the list moves the first" <|
            \_ ->
                reorderWith [ "b", "x", "b" ]
                    |> Result.map List.sort
                    |> Expect.equal (Ok [ "b", "b", "x" ])
        , test "also for a list of records, by the id function" <|
            \_ ->
                dropOne
                    |> Result.map
                        (\( before, after ) ->
                            Sortable.reorder Sortable.stringIds .name before after [ { name = "a" }, { name = "b" }, { name = "c" } ]
                                |> List.map .name
                        )
                    |> Expect.equal (Ok [ "a", "c", "b" ])
        ]



-- THE POINTER


pointerDownOn : String -> Int -> String -> ( String, Encode.Value )
pointerDownOn kind button target =
    Event.custom "pointerdown"
        (Encode.object
            [ ( "pointerType", Encode.string kind )
            , ( "button", Encode.int button )
            , ( "isPrimary", Encode.bool True )
            , ( "pageX", Encode.float 20 )
            , ( "pageY", Encode.float 30 )
            , ( "clientX", Encode.float 20 )
            , ( "clientY", Encode.float 30 )
            , ( "target", targets target )
            ]
        )


{-| What the press hit, as the chain of elements from there up to the item: the icon
of the handle, the text of the content, a button or a link in the content, or the
item itself.
-}
targets : String -> Encode.Value
targets what =
    let
        element tag name parent =
            Encode.object
                [ ( "tagName", Encode.string tag )
                , ( "className", Encode.string name )
                , ( "parentElement", parent )
                ]

        item =
            element "LI" "klar-sortable__item" Encode.null

        content =
            element "DIV" "klar-sortable__content" item
    in
    case what of
        "handle" ->
            element "SPAN" "klar-icon" (element "BUTTON" "klar-sortable__handle" item)

        "text" ->
            element "SPAN" "step" content

        "button" ->
            element "BUTTON" "klar-button" content

        "link" ->
            element "SPAN" "" (element "A" "" content)

        _ ->
            item


mouseMove : Float -> Float -> Int -> ( String, Encode.Value )
mouseMove x y buttons =
    Event.custom "mousemove"
        (Encode.object
            [ ( "pageX", Encode.float x )
            , ( "pageY", Encode.float y )
            , ( "clientX", Encode.float x )
            , ( "clientY", Encode.float y )
            , ( "buttons", Encode.int buttons )
            ]
        )


mouseDownOn : Int -> String -> ( String, Encode.Value )
mouseDownOn button target =
    Event.custom "mousedown"
        (Encode.object [ ( "button", Encode.int button ), ( "target", targets target ) ])


pressOnB : ( List Selector, ( String, Encode.Value ) )
pressOnB =
    ( itemOf "b", pointerDownOn "mouse" 0 "handle" )


pointerTests : Test
pointerTests =
    describe "pointer"
        [ test "a press on the handle starts a session, but nothing is lifted before the pointer moves" <|
            \_ ->
                check (drive [ pressOnB ] five)
                    [ \m -> Expect.equal Nothing (held m)
                    , \m -> rendered m |> Query.findAll [ Selector.class "klar-sortable__ghost" ] |> Query.count (Expect.equal 0)
                    , \m -> rendered m |> Query.findAll [ Selector.class "klar-sortable__layer" ] |> Query.count (Expect.equal 0)
                    ]
        , test "moving the mouse a few pixels lifts the item: its label follows the pointer, and the window has one cursor" <|
            \_ ->
                check (drive [ pressOnB, ( [], mouseMove 60 90 1 ) ] five)
                    [ \m -> Expect.equal (Just "b") (held m)
                    , \m -> rendered m |> Query.find [ Selector.class "klar-sortable__ghost" ] |> Query.has [ Selector.text "Step b", Selector.attribute (Attr.attribute "aria-hidden" "true") ]
                    , \m -> rendered m |> Query.findAll [ Selector.class "klar-sortable__layer" ] |> Query.count (Expect.equal 1)
                    , \m -> rendered m |> Query.has [ Selector.class "klar-sortable--dragging" ]
                    , \m -> rendered m |> Query.find (itemOf "b") |> Query.has [ Selector.class "klar-sortable__item--lifted" ]
                    , says "Step b picked up, position 2 of 5."
                    ]
        , test "a small movement is still a click" <|
            \_ ->
                check (drive [ pressOnB, ( [], mouseMove 21 31 1 ) ] five)
                    [ \m -> Expect.equal Nothing (held m) ]
        , test "letting go of a click ends the session and moves nothing" <|
            \_ ->
                check (drive [ pressOnB, ( [], Event.custom "mouseup" (Encode.object []) ) ] five)
                    [ \m -> Expect.equal [ "a", "b", "c", "d", "e" ] m.items
                    , \m -> rendered m |> Query.findAll [ Selector.class "klar-sortable__layer" ] |> Query.count (Expect.equal 0)
                    ]
        , test "a mouse button that was let go unseen cancels the drag" <|
            \_ ->
                check (drive [ pressOnB, ( [], mouseMove 60 90 1 ), ( [], mouseMove 70 90 0 ) ] five)
                    [ \m -> Expect.equal Nothing (held m)
                    , says "Cancelled. Step b is back at position 2 of 5."
                    ]
        , test "Escape on the handle cancels a drag with the pointer" <|
            \_ ->
                check (drive [ pressOnB, ( [], mouseMove 60 90 1 ), ( handleOf "b", key "Escape" ) ] five)
                    [ \m -> Expect.equal Nothing (held m) ]
        , test "the arrow keys do not move an item that the pointer holds" <|
            \_ ->
                drive [ pressOnB, ( [], mouseMove 60 90 1 ), ( handleOf "b", key "ArrowDown" ) ] five
                    |> Expect.err
        , test "the click that ends a drag stops at the list; the click of a plain press goes on" <|
            \_ ->
                let
                    stopsClick model =
                        rendered model
                            |> Event.simulate (Event.custom "click" (Encode.object []))
                            |> Event.toResult
                            |> isOk
                in
                Expect.equal
                    [ Ok False, Ok True, Ok False ]
                    [ drive [ pressOnB ] five |> Result.map stopsClick
                    , drive [ pressOnB, ( [], mouseMove 60 90 1 ) ] five |> Result.map stopsClick
                    , Ok (stopsClick five)
                    ]
        , test "only the main button presses" <|
            \_ ->
                Expect.err (send (itemOf "b") (pointerDownOn "mouse" 2 "handle") five)
        , test "only the handle presses, unless the whole item is the handle" <|
            \_ ->
                let
                    whole =
                        withAttributes [ Sortable.wholeItem ] five
                in
                Expect.equal
                    [ False, False, True, True, True ]
                    [ isOk (send (itemOf "b") (pointerDownOn "mouse" 0 "text") five)
                    , isOk (send (itemOf "b") (pointerDownOn "mouse" 0 "item") five)
                    , isOk (send (itemOf "b") (pointerDownOn "mouse" 0 "handle") five)
                    , isOk (send (itemOf "b") (pointerDownOn "mouse" 0 "text") whole)
                    , isOk (send (itemOf "b") (pointerDownOn "mouse" 0 "item") whole)
                    ]
        , test "a press on a button or a link inside the item belongs to that button or link" <|
            \_ ->
                let
                    whole =
                        withAttributes [ Sortable.wholeItem ] five
                in
                Expect.equal [ False, False ]
                    [ isOk (send (itemOf "b") (pointerDownOn "mouse" 0 "button") whole)
                    , isOk (send (itemOf "b") (pointerDownOn "mouse" 0 "link") whole)
                    ]
        , test "a finger takes hold of the handle only, so that the rest of the item scrolls the page" <|
            \_ ->
                let
                    whole =
                        withAttributes [ Sortable.wholeItem ] five
                in
                Expect.equal [ True, False ]
                    [ isOk (send (itemOf "b") (pointerDownOn "touch" 0 "handle") whole)
                    , isOk (send (itemOf "b") (pointerDownOn "touch" 0 "text") whole)
                    ]
        , test "a finger is followed on the item itself, not on a layer over the window" <|
            \_ ->
                let
                    touchMove =
                        Event.custom "pointermove"
                            (Encode.object
                                [ ( "pageX", Encode.float 20 )
                                , ( "pageY", Encode.float 100 )
                                , ( "clientX", Encode.float 20 )
                                , ( "clientY", Encode.float 100 )
                                , ( "buttons", Encode.int 1 )
                                ]
                            )
                in
                check (drive [ ( itemOf "b", pointerDownOn "touch" 0 "handle" ), ( [], touchMove ) ] five)
                    [ \m -> Expect.equal (Just "b") (held m)
                    , \m -> rendered m |> Query.findAll [ Selector.class "klar-sortable__layer" ] |> Query.count (Expect.equal 0)
                    , \m -> rendered m |> Query.has [ Selector.class "klar-sortable__ghost--touch" ]
                    ]
        , test "a finger that the browser takes over (to scroll) ends the drag" <|
            \_ ->
                check
                    (drive
                        [ ( itemOf "b", pointerDownOn "touch" 0 "handle" )
                        , ( [], Event.custom "pointercancel" (Encode.object []) )
                        ]
                        five
                    )
                    [ \m -> rendered m |> Query.findAll [ Selector.class "klar-sortable__ghost" ] |> Query.count (Expect.equal 0)
                    , \m -> Expect.equal Nothing (held m)
                    ]
        , test "the mouse going down on the handle does not select text or start a native drag" <|
            \_ ->
                Expect.equal [ True, False, False ]
                    [ isOk (send (itemOf "b") (mouseDownOn 0 "handle") five)
                    , isOk (send (itemOf "b") (mouseDownOn 0 "text") five)
                    , isOk (send (itemOf "b") (mouseDownOn 2 "handle") five)
                    ]
        , test "a press on a fixed item does nothing" <|
            \_ ->
                Expect.err (send (itemOf "b") (pointerDownOn "mouse" 0 "handle") (withFixed [ "b" ] five))
        ]



-- TYPED IDS


type StepId
    = StepId Int


stepIds : Sortable.Ids StepId
stepIds =
    Sortable.itemIds
        { toKey = \(StepId n) -> "step-" ++ String.fromInt n
        , fromKey = \text -> String.toInt (String.dropLeft 5 text) |> Maybe.map StepId
        }


typedIdTests : Test
typedIdTests =
    let
        liftedAfterSpaceOn : Sortable.Ids StepId -> String -> Result String (Maybe StepId)
        liftedAfterSpaceOn ids handle =
            let
                state =
                    Sortable.init "steps"
            in
            Sortable.view Sortable.stringIds
                identity
                []
                state
                [ Sortable.item "step-7" "Seven" (Html.text "seven"), Sortable.item "step-8" "Eight" (Html.text "eight"), Sortable.item "odd" "Odd" (Html.text "odd") ]
                |> Query.fromHtml
                |> Query.find [ Selector.id ("steps-handle-" ++ handle) ]
                |> Event.simulate space
                |> Event.toResult
                |> Result.map (\msg -> Sortable.update msg (Sortable.init "steps") |> Tuple.first |> Sortable.lifted ids)
    in
    describe "ids of the application's own type"
        [ test "what is held comes back as the application's own id" <|
            \_ ->
                -- the state is typed by the ids of the view that made the message
                liftedAfterSpaceOn stepIds "step-8"
                    |> Expect.equal (Ok (Just (StepId 8)))
        , test "a key the application cannot read gives no id" <|
            \_ ->
                liftedAfterSpaceOn stepIds "odd"
                    |> Expect.equal (Ok Nothing)
        ]
