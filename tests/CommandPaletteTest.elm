module CommandPaletteTest exposing (suite)

{-| Benchmark run 1, T06: the listbox of the palette holds only options (axe
`aria-required-children`), the status of a remote section is announced politely,
and an item can declare the words that call it.
-}

import Expect
import Html.Attributes
import Json.Encode as Encode
import Klar.CommandPalette as CommandPalette
import Klar.Overlay as Overlay
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Shortcut as Shortcut
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Time


type Msg
    = Retry
    | Go
    | Palette CommandPalette.Msg


goToOrder : CommandPalette.Item Msg
goToOrder =
    CommandPalette.item "Go to order ..." Go
        |> CommandPalette.withCommand "go to order"


newOrder : CommandPalette.Item Msg
newOrder =
    CommandPalette.item "New order" Go


opened : String -> CommandPalette.State
opened text =
    CommandPalette.init "palette"
        |> CommandPalette.open "opener"
        |> Tuple.first
        |> CommandPalette.setQuery text


view : String -> Remote (List (CommandPalette.Item Msg)) -> Query.Single Msg
view text hits =
    CommandPalette.view Palette
        [ CommandPalette.sections
            [ CommandPalette.section "Actions" [ newOrder, goToOrder ]
            , CommandPalette.remote "Orders" hits |> CommandPalette.onRetry Retry
            ]
        ]
        (opened text)
        |> (\overlay -> Overlay.host { attributes = [], page = [], overlays = [ overlay ] })
        |> Query.fromHtml


role : String -> Selector.Selector
role name =
    Selector.attribute (Html.Attributes.attribute "role" name)


suite : Test
suite =
    describe "CommandPalette"
        [ describe "the listbox holds only options and their groups"
            (List.map
                (\( name, hits ) ->
                    test name <|
                        \_ ->
                            view "order" hits
                                |> Query.find [ role "listbox" ]
                                |> Expect.all
                                    [ Query.hasNot [ role "alert" ]
                                    , Query.hasNot [ Selector.tag "button" ]
                                    , Query.hasNot [ Selector.class "klar-skeleton" ]
                                    , Query.has [ role "option" ]
                                    ]
                )
                [ ( "loading", Loading )
                , ( "failed", Failed (Remote.problem Remote.server) )
                , ( "no results", Loaded [] )
                ]
            )
        , test "with no item at all there is no listbox, only the notice" <|
            \_ ->
                CommandPalette.view Palette
                    [ CommandPalette.sections [ CommandPalette.remote "Orders" (Failed (Remote.problem Remote.server)) |> CommandPalette.onRetry Retry ] ]
                    (opened "zzz")
                    |> (\overlay -> Overlay.host { attributes = [], page = [], overlays = [ overlay ] })
                    |> Query.fromHtml
                    |> Expect.all
                        [ Query.hasNot [ role "listbox" ]
                        , Query.has [ Selector.text "Try again" ]
                        ]
        , test "a failure is announced in the polite status, not as an alert" <|
            \_ ->
                view "order" (Failed (Remote.problem Remote.server))
                    |> Expect.all
                        [ Query.hasNot [ role "alert" ]
                        , Query.find [ role "status" ] >> Query.has [ Selector.text "Something went wrong on our side" ]
                        ]
        , describe "command words"
            [ test "the item stays while its words are followed by an argument" <|
                \_ ->
                    view "go to order 1001" (Loaded [])
                        |> Query.findAll [ role "option" ]
                        |> Query.count (Expect.equal 1)
            , test "an item without command words disappears when nothing matches" <|
                \_ ->
                    view "new order 1001" (Loaded [])
                        |> Query.hasNot [ role "option" ]
            , test "argument is what follows the words, as typed" <|
                \_ ->
                    CommandPalette.argument [ goToOrder ] (opened "Go to Order  A-1001 ")
                        |> Expect.equal "A-1001"
            , test "argument is the whole query when no command starts it" <|
                \_ ->
                    CommandPalette.argument [ goToOrder ] (opened "1001 go to order")
                        |> Expect.equal "1001 go to order"
            , test "argument of the words alone is empty" <|
                \_ ->
                    CommandPalette.argument [ goToOrder ] (opened "go to order")
                        |> Expect.equal ""
            , test "the longest command wins" <|
                \_ ->
                    CommandPalette.argument
                        [ goToOrder, CommandPalette.item "Go" Go |> CommandPalette.withCommand "go" ]
                        (opened "go to order 7")
                        |> Expect.equal "7"
            , test "a command must end at a word: 'go to orders' is not 'go to order' + 's'" <|
                \_ ->
                    CommandPalette.argument [ goToOrder ] (opened "go to orders")
                        |> Expect.equal "go to orders"
            ]
        , describe "the query waits for a pause in the typing"
            [ test "a typed text is not the query at once" <|
                \_ ->
                    typed "ada" (opened "")
                        |> Expect.equal (Ok "")
            , test "an emptied box is the query at once" <|
                \_ ->
                    typed "" (opened "ada")
                        |> Expect.equal (Ok "")
            , test "setQuery is the query at once, trimmed" <|
                \_ ->
                    CommandPalette.query (opened " ada ")
                        |> Expect.equal "ada"
            , test "closing empties the query, so a late answer is dropped" <|
                \_ ->
                    CommandPalette.close (opened "ada")
                        |> Tuple.first
                        |> CommandPalette.query
                        |> Expect.equal ""
            , test "the sections that the palette filters do not wait" <|
                \_ ->
                    let
                        state =
                            opened ""

                        afterTyping =
                            draw [ CommandPalette.sections [ CommandPalette.section "Actions" [ newOrder, goToOrder ] ] ] state
                                |> Query.find [ Selector.id "palette-input" ]
                                |> Event.simulate (Event.input "new")
                                |> Event.toResult
                    in
                    case afterTyping of
                        Ok (Palette inner) ->
                            draw [ CommandPalette.sections [ CommandPalette.section "Actions" [ newOrder, goToOrder ] ] ]
                                (Tuple.first (CommandPalette.update inner state))
                                |> Query.findAll [ role "option" ]
                                |> Query.count (Expect.equal 1)

                        _ ->
                            Expect.fail "the search box did not answer"
            ]
        , describe "remote sections in every state"
            [ test "old data says so in the heading of its group, not inside the listbox" <|
                \_ ->
                    view "order" (Remote.refreshWith (Loaded [ goToOrder ]) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0))
                        |> Expect.all
                            [ Query.find [ role "listbox" ] >> Query.hasNot [ Selector.class "klar-palette__notice" ]
                            , Query.find [ Selector.id "palette-group-s1" ] >> Query.has [ Selector.text "Old data" ]
                            , Query.find [ role "status" ] >> Query.has [ Selector.text "Old data" ]
                            ]
            , test "data that is being refreshed is drawn busy" <|
                \_ ->
                    view "order" (Remote.refresh (Loaded [ goToOrder ]))
                        |> Query.find [ Selector.class "klar-refreshing" ]
                        |> Query.has [ Selector.attribute (Html.Attributes.attribute "aria-busy" "true") ]
            , test "an empty remote section says the palette's emptyText" <|
                \_ ->
                    draw
                        [ CommandPalette.sections [ CommandPalette.remote "Orders" (Loaded []) ]
                        , CommandPalette.emptyText "Nothing here"
                        ]
                        (opened "zzz")
                        |> Query.has [ Selector.text "Nothing here" ]
            , test "withEmptyText wins over the palette's emptyText" <|
                \_ ->
                    draw
                        [ CommandPalette.sections [ CommandPalette.remote "Orders" (Loaded []) |> CommandPalette.withEmptyText "No orders found" ]
                        , CommandPalette.emptyText "Nothing here"
                        ]
                        (opened "zzz")
                        |> Query.has [ Selector.text "No orders found" ]
            ]
        , describe "items"
            [ test "withKeywords called twice keeps both sets of words" <|
                \_ ->
                    let
                        item =
                            CommandPalette.item "New order" Go
                                |> CommandPalette.withKeywords [ "create" ]
                                |> CommandPalette.withKeywords [ "register" ]

                        options text =
                            draw [ CommandPalette.sections [ CommandPalette.section "Actions" [ item ] ] ] (opened text)
                                |> Query.findAll [ role "option" ]
                    in
                    Expect.all
                        [ \_ -> options "create" |> Query.count (Expect.equal 1)
                        , \_ -> options "register" |> Query.count (Expect.equal 1)
                        ]
                        ()
            , test "the shortcut of an item is drawn by Kbd, with a spoken phrase" <|
                \_ ->
                    draw
                        [ CommandPalette.sections
                            [ CommandPalette.section "Actions"
                                [ newOrder |> CommandPalette.withShortcut (Shortcut.mod (Shortcut.char 'k')) ]
                            ]
                        ]
                        (opened "")
                        |> Query.find [ Selector.class "klar-palette__keys" ]
                        |> Query.has [ Selector.text "Control plus K" ]
            ]
        , describe "a disabled item"
            (let
                exportItem =
                    CommandPalette.item "Export the selection" Go
                        |> CommandPalette.withDisabled "Select some rows first"

                drawn =
                    draw [ CommandPalette.sections [ CommandPalette.section "Actions" [ exportItem, newOrder ] ] ] (opened "")
             in
             [ test "is shown with its reason and marked unavailable" <|
                \_ ->
                    drawn
                        |> Query.find [ Selector.id "palette-option-0" ]
                        |> Expect.all
                            [ Query.has [ Selector.attribute (Html.Attributes.attribute "aria-disabled" "true") ]
                            , Query.has [ Selector.text "Select some rows first" ]
                            ]
             , test "is never highlighted: the first item that can run is" <|
                \_ ->
                    drawn
                        |> Query.find [ Selector.id "palette-input" ]
                        |> Query.has [ Selector.attribute (Html.Attributes.attribute "aria-activedescendant" "palette-option-1") ]
             , test "a click on it runs nothing" <|
                \_ ->
                    drawn
                        |> Query.find [ Selector.id "palette-option-0" ]
                        |> Event.simulate Event.click
                        |> Event.toResult
                        |> Expect.err
             , test "the arrow keys skip it" <|
                \_ ->
                    case
                        drawn
                            |> Query.find [ Selector.class "klar-palette__panel" ]
                            |> Event.simulate (keyDown "ArrowDown")
                            |> Event.toResult
                    of
                        Ok (Palette inner) ->
                            draw [ CommandPalette.sections [ CommandPalette.section "Actions" [ exportItem, newOrder ] ] ]
                                (Tuple.first (CommandPalette.update inner (opened "")))
                                |> Query.find [ Selector.id "palette-input" ]
                                |> Query.has [ Selector.attribute (Html.Attributes.attribute "aria-activedescendant" "palette-option-1") ]

                        _ ->
                            Expect.fail "the palette did not answer the arrow"
             ]
            )
        , describe "ranking and the keys"
            [ test "a match on the label ranks above a match on a keyword" <|
                \_ ->
                    draw
                        [ CommandPalette.sections
                            [ CommandPalette.section "Actions"
                                [ CommandPalette.item "New order" Go |> CommandPalette.withKeywords [ "invoice" ]
                                , CommandPalette.item "Invoices" Go
                                ]
                            ]
                        ]
                        (opened "invoice")
                        |> Query.find [ Selector.id "palette-option-0" ]
                        |> Query.hasNot [ Selector.text "New order" ]
            , test "the recent items show only while the query is empty" <|
                \_ ->
                    let
                        withRecent text =
                            draw [ CommandPalette.recent [ newOrder ], CommandPalette.sections [ CommandPalette.section "Actions" [ goToOrder ] ] ] (opened text)
                    in
                    Expect.all
                        [ \_ -> withRecent "" |> Query.has [ Selector.text "Recent" ]
                        , \_ -> withRecent "go" |> Query.hasNot [ Selector.text "Recent" ]
                        ]
                        ()
            , test "ArrowUp on the first item wraps around to the last" <|
                \_ ->
                    let
                        attributes =
                            [ CommandPalette.sections [ CommandPalette.section "Actions" [ newOrder, goToOrder ] ] ]
                    in
                    case
                        draw attributes (opened "")
                            |> Query.find [ Selector.class "klar-palette__panel" ]
                            |> Event.simulate (keyDown "ArrowUp")
                            |> Event.toResult
                    of
                        Ok (Palette inner) ->
                            draw attributes (Tuple.first (CommandPalette.update inner (opened "")))
                                |> Query.find [ Selector.id "palette-input" ]
                                |> Query.has [ Selector.attribute (Html.Attributes.attribute "aria-activedescendant" "palette-option-1") ]

                        _ ->
                            Expect.fail "the palette did not answer the arrow"
            ]
        , describe "focus stays in the search box"
            [ test "a press on the frame of the palette keeps focus where it is" <|
                \_ ->
                    view "" NotAsked
                        |> Query.find [ Selector.class "klar-palette__panel" ]
                        |> Event.simulate (mouseDownOn "DIV")
                        |> Event.expectPreventDefault
            , test "a press in the search box places the caret as usual" <|
                \_ ->
                    view "" NotAsked
                        |> Query.find [ Selector.class "klar-palette__panel" ]
                        |> Event.simulate (mouseDownOn "INPUT")
                        |> Event.toResult
                        |> Expect.err
            , test "the palette brings focus back when the focused element goes away" <|
                \_ ->
                    view "" NotAsked
                        |> Query.find [ Selector.class "klar-palette__panel" ]
                        |> Query.has [ Selector.class "klar-modal__guard" ]
            , test "the footer is for the eye only" <|
                \_ ->
                    view "" NotAsked
                        |> Query.find [ Selector.class "klar-palette__footer" ]
                        |> Query.has [ Selector.attribute (Html.Attributes.attribute "aria-hidden" "true") ]
            ]
        ]


draw : List (CommandPalette.Attribute Msg) -> CommandPalette.State -> Query.Single Msg
draw attributes state =
    CommandPalette.view Palette attributes state
        |> (\overlay -> Overlay.host { attributes = [], page = [], overlays = [ overlay ] })
        |> Query.fromHtml


{-| The query after the user typed this text into the search box.
-}
typed : String -> CommandPalette.State -> Result String String
typed text state =
    draw [] state
        |> Query.find [ Selector.id "palette-input" ]
        |> Event.simulate (Event.input text)
        |> Event.toResult
        |> Result.andThen
            (\msg ->
                case msg of
                    Palette inner ->
                        Ok (CommandPalette.query (Tuple.first (CommandPalette.update inner state)))

                    _ ->
                        Err "not a message of the palette"
            )


keyDown : String -> ( String, Encode.Value )
keyDown key =
    Event.custom "keydown"
        (Encode.object
            [ ( "key", Encode.string key )
            , ( "ctrlKey", Encode.bool False )
            , ( "metaKey", Encode.bool False )
            , ( "shiftKey", Encode.bool False )
            , ( "altKey", Encode.bool False )
            ]
        )


mouseDownOn : String -> ( String, Encode.Value )
mouseDownOn tag =
    Event.custom "mousedown" (Encode.object [ ( "target", Encode.object [ ( "tagName", Encode.string tag ) ] ) ])
