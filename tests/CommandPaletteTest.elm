module CommandPaletteTest exposing (suite)

{-| Benchmark run 1, T06: the listbox of the palette holds only options (axe
`aria-required-children`), the status of a remote section is announced politely,
and an item can declare the words that call it.
-}

import Expect
import Html.Attributes
import Klar.CommandPalette as CommandPalette
import Klar.Overlay as Overlay
import Klar.Remote as Remote exposing (Remote(..))
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


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
        ]
