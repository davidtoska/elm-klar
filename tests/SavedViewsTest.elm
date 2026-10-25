module SavedViewsTest exposing (suite)

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Decode as Decode
import Json.Encode as Encode
import Klar.Remote as Remote
import Klar.Rule as Rule
import Klar.SavedViews as SavedViews
import Klar.Table as Table
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)
import Time


state : SavedViews.State
state =
    SavedViews.init "views"
        |> SavedViews.setViews
            [ SavedViews.savedView "Open" Rule.emptyGroup |> SavedViews.asShared
            , SavedViews.savedView "Late" Rule.emptyGroup
            ]


query : Table.Query
query =
    { search = "ada", sort = [], filters = [], page = 4, pageSize = 50 }


fullQuery : Table.Query
fullQuery =
    { search = "ada"
    , sort = [ ( Table.columnId "total", Table.Descending ), ( Table.columnId "name", Table.Ascending ) ]
    , filters =
        [ ( Table.columnId "status", Table.OneOf [ "open", "late" ] )
        , ( Table.columnId "customer", Table.Contains "acme" )
        , ( Table.columnId "total", Table.Between (Just 10) Nothing )
        ]
    , page = 4
    , pageSize = 50
    }


suite : Test
suite =
    describe "Klar.SavedViews"
        [ test "apply makes the named view active and bumps the revision" <|
            \_ ->
                let
                    applied =
                        SavedViews.apply "Late" state
                in
                Expect.equal
                    ( Maybe.map .name (SavedViews.active applied), SavedViews.revision applied )
                    ( Just "Late", SavedViews.revision state + 1 )
        , test "apply with an unknown name changes nothing" <|
            \_ ->
                Expect.equal (SavedViews.revision (SavedViews.apply "Nope" state)) (SavedViews.revision state)
        , test "startSave opens the list" <|
            \_ ->
                Expect.equal (Tuple.first (SavedViews.startSave state) |> SavedViews.isOpen) True
        , test "a view can be shared and the flag survives setViews" <|
            \_ ->
                Expect.equal (SavedViews.views state |> List.map .isShared) [ True, False ]
        , test "a query is held from the first page" <|
            \_ ->
                Expect.equal
                    (SavedViews.savedView "A" Rule.emptyGroup |> SavedViews.withQuery query |> .query |> Maybe.map .page)
                    (Just 1)
        , describe "keeping a view and a query as JSON"
            [ test "a view with a full query comes back as it was" <|
                \_ ->
                    let
                        saved =
                            SavedViews.savedView "Late" Rule.emptyGroup
                                |> SavedViews.withNote "Older than a week"
                                |> SavedViews.asDefault
                                |> SavedViews.asShared
                                |> SavedViews.withQuery fullQuery
                    in
                    Encode.encode 0 (SavedViews.encode saved)
                        |> Decode.decodeString SavedViews.decoder
                        |> Result.map (\back -> { back | query = Maybe.map (\q -> { q | page = 1 }) back.query })
                        |> Expect.equal (Ok { saved | query = Just { fullQuery | page = 1 } })
            , test "a query keeps its page and size when it is encoded on its own" <|
                \_ ->
                    Encode.encode 0 (Table.encodeQuery fullQuery)
                        |> Decode.decodeString Table.queryDecoder
                        |> Expect.equal (Ok fullQuery)
            , test "the text says the version and names the columns" <|
                \_ ->
                    Encode.encode 0 (Table.encodeQuery fullQuery)
                        |> Expect.all
                            [ String.contains "\"v\":1" >> Expect.equal True
                            , String.contains "\"column\":\"total\"" >> Expect.equal True
                            ]
            , test "fields that are missing take the value of an empty query" <|
                \_ ->
                    Decode.decodeString Table.queryDecoder "{}"
                        |> Expect.equal (Ok { search = "", sort = [], filters = [], page = 1, pageSize = 25 })
            , test "fields it does not know are ignored" <|
                \_ ->
                    Decode.decodeString Table.queryDecoder "{\"v\":1,\"search\":\"x\",\"colour\":\"red\",\"future\":{\"a\":[1]}}"
                        |> Result.map .search
                        |> Expect.equal (Ok "x")
            , test "a filter it does not know is left out, the others stay" <|
                \_ ->
                    Decode.decodeString Table.queryDecoder "{\"filters\":[{\"column\":\"a\",\"soundsLike\":\"x\"},{\"column\":\"b\",\"contains\":\"y\"}]}"
                        |> Result.map .filters
                        |> Expect.equal (Ok [ ( Table.columnId "b", Table.Contains "y" ) ])
            , test "a version from the future is refused" <|
                \_ ->
                    Decode.decodeString Table.queryDecoder "{\"v\":2}"
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            , test "a page below 1 becomes 1" <|
                \_ ->
                    Decode.decodeString Table.queryDecoder "{\"page\":-3,\"pageSize\":0}"
                        |> Result.map (\q -> ( q.page, q.pageSize ))
                        |> Expect.equal (Ok ( 1, 1 ))
            , test "a view needs a name and a rule, and may lack the rest" <|
                \_ ->
                    Expect.all
                        [ \_ -> Decode.decodeString SavedViews.decoder "{\"name\":\"A\",\"rule\":{\"type\":\"group\",\"combinator\":\"all\",\"children\":[]}}" |> Result.map .name |> Expect.equal (Ok "A")
                        , \_ -> Decode.decodeString SavedViews.decoder "{\"name\":\" \",\"rule\":{\"type\":\"group\",\"combinator\":\"all\",\"children\":[]}}" |> Result.toMaybe |> Expect.equal Nothing
                        , \_ -> Decode.decodeString SavedViews.decoder "{\"name\":\"A\"}" |> Result.toMaybe |> Expect.equal Nothing
                        ]
                        ()
            , test "a query that is there but cannot be read fails the view" <|
                \_ ->
                    Decode.decodeString SavedViews.decoder "{\"name\":\"A\",\"rule\":{\"type\":\"group\",\"combinator\":\"all\",\"children\":[]},\"query\":{\"v\":9}}"
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            ]
        , behaviourTests
        ]



-- DRIVEN THROUGH THE MARKUP


drawn : SavedViews.State -> Html SavedViews.Msg
drawn current =
    SavedViews.view identity [ SavedViews.currentRule Rule.emptyGroup ] current


{-| Send the event to the element and let the component handle the message.
-}
on : ( String, Encode.Value ) -> List Selector -> Result String SavedViews.State -> Result String SavedViews.State
on event selectors =
    Result.andThen
        (\current ->
            drawn current
                |> Query.fromHtml
                |> Query.find selectors
                |> Event.simulate event
                |> Event.toResult
                |> Result.map (\msg -> Tuple.first (SavedViews.update msg current))
        )


button : String -> List Selector
button name =
    [ Selector.tag "button", Selector.attribute (Attr.attribute "aria-label" name) ]


opened : Result String SavedViews.State
opened =
    on Event.click [ Selector.id "views-trigger" ] (Ok state)


expectOk : (SavedViews.State -> Expectation) -> Result String SavedViews.State -> Expectation
expectOk check result =
    case result of
        Ok current ->
            check current

        Err why ->
            Expect.fail why


type Outer
    = Views SavedViews.Msg
    | Retry


{-| The list opened, drawn with the state of the request for the views.
-}
openWith : Remote.Remote (List SavedViews.SavedView) -> SavedViews.State -> Query.Single Outer
openWith source current =
    let
        draw =
            SavedViews.view Views [ SavedViews.currentRule Rule.emptyGroup, SavedViews.remote source, SavedViews.onRetry Retry ]

        isOpen =
            draw current
                |> Query.fromHtml
                |> Query.find [ Selector.id "views-trigger" ]
                |> Event.simulate Event.click
                |> Event.toResult
                |> Result.map
                    (\msg ->
                        case msg of
                            Views inner ->
                                Tuple.first (SavedViews.update inner current)

                            Retry ->
                                current
                    )
                |> Result.withDefault current
    in
    Query.fromHtml (draw isOpen)


remoteTests : Test
remoteTests =
    let
        empty =
            SavedViews.init "views"
    in
    describe "the request for the views"
        [ test "while the views load the list says so, not that there are none" <|
            \_ ->
                openWith Remote.Loading empty
                    |> Expect.all
                        [ Query.has [ Selector.text "Loading saved views …" ]
                        , Query.hasNot [ Selector.text "No saved views yet. Save the current filter to find it again." ]
                        ]
        , test "a failure says what went wrong and offers a retry" <|
            \_ ->
                openWith (Remote.Failed (Remote.problem Remote.server)) empty
                    |> Query.find [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ]
                    |> Event.simulate Event.click
                    |> Event.expect Retry
        , test "while the retry loads, the button stays, busy" <|
            \_ ->
                openWith Remote.Loading empty
                    |> Query.find [ Selector.tag "button", Selector.containing [ Selector.text "Try again" ] ]
                    |> Query.has [ Selector.attribute (Attr.attribute "aria-busy" "true") ]
        , test "views kept after a failed refresh are marked old" <|
            \_ ->
                openWith (Remote.refreshWith (Remote.Loaded []) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0)) state
                    |> Expect.all
                        [ Query.has [ Selector.text "Old data" ]
                        , Query.findAll [ Selector.class "klar-savedviews__apply" ] >> Query.count (Expect.equal 2)
                        ]
        , test "without remote the views count as loaded" <|
            \_ ->
                drawn empty
                    |> Query.fromHtml
                    |> Query.hasNot [ Selector.text "Loading saved views …" ]
        ]


changeTests : Test
changeTests =
    let
        open =
            SavedViews.savedView "Open" Rule.emptyGroup |> SavedViews.withKey "k1"

        late =
            SavedViews.savedView "Late" Rule.emptyGroup |> SavedViews.withKey "k2"

        fresh =
            SavedViews.savedView "New" Rule.emptyGroup
    in
    describe "changes for a backend that keeps each view"
        [ test "a view the user saved is created" <|
            \_ -> Expect.equal (SavedViews.changes [ open ] [ open, fresh ]) [ SavedViews.Created fresh ]
        , test "a renamed view keeps its key and is updated" <|
            \_ ->
                Expect.equal (SavedViews.changes [ open, late ] [ open, { late | name = "Later" } ])
                    [ SavedViews.Updated { late | name = "Later" } ]
        , test "a deleted view is deleted by its key" <|
            \_ -> Expect.equal (SavedViews.changes [ open, late ] [ late ]) [ SavedViews.Deleted "k1" ]
        , test "the same list gives nothing" <|
            \_ -> Expect.equal (SavedViews.changes [ open, late, fresh ] [ open, late, fresh ]) []
        , test "a new default updates both views" <|
            \_ ->
                Expect.equal
                    (SavedViews.changes [ SavedViews.asDefault open, late ] [ open, SavedViews.asDefault late ])
                    [ SavedViews.Updated open, SavedViews.Updated (SavedViews.asDefault late) ]
        , test "a locked view can be made the default but not renamed or deleted" <|
            \_ ->
                Ok (SavedViews.setViews [ SavedViews.asLocked open, late ] (SavedViews.init "views"))
                    |> on Event.click [ Selector.id "views-trigger" ]
                    |> expectOk
                        (\shown ->
                            drawn shown
                                |> Query.fromHtml
                                |> Expect.all
                                    [ Query.findAll (button "Rename: Open") >> Query.count (Expect.equal 0)
                                    , Query.findAll (button "Delete: Open") >> Query.count (Expect.equal 0)
                                    , Query.findAll (button "Default view: Open") >> Query.count (Expect.equal 1)
                                    , Query.findAll (button "Rename: Late") >> Query.count (Expect.equal 1)
                                    , Query.has [ Selector.text "Locked: cannot be renamed or deleted" ]
                                    ]
                        )
        , test "the lock is kept in the JSON" <|
            \_ ->
                Encode.encode 0 (SavedViews.encode (SavedViews.asLocked open))
                    |> Decode.decodeString SavedViews.decoder
                    |> Result.map .isLocked
                    |> Expect.equal (Ok True)
        , test "the key is kept in the JSON" <|
            \_ ->
                Encode.encode 0 (SavedViews.encode open)
                    |> Decode.decodeString SavedViews.decoder
                    |> Result.map .key
                    |> Expect.equal (Ok (Just "k1"))
        , test "a rename through the list keeps the key" <|
            \_ ->
                Ok (SavedViews.setViews [ open, late ] (SavedViews.init "views"))
                    |> on Event.click [ Selector.id "views-trigger" ]
                    |> on Event.click (button "Rename: Late")
                    |> on (Event.input "Later") [ Selector.id "views-rename" ]
                    |> on Event.click [ Selector.tag "button", Selector.class "klar-button--primary" ]
                    |> expectOk (\renamed -> Expect.equal (List.map .key (SavedViews.views renamed)) [ Just "k1", Just "k2" ])
        ]


behaviourTests : Test
behaviourTests =
    describe "what the user does"
        [ remoteTests
        , changeTests
        , test "apply and setActive find a name ignoring case and spaces" <|
            \_ ->
                Expect.equal
                    ( SavedViews.apply " late " state |> SavedViews.active |> Maybe.map .name
                    , SavedViews.setActive (Just "OPEN") state |> SavedViews.active |> Maybe.map .name
                    )
                    ( Just "Late", Just "Open" )
        , test "setViews keeps a rename that is being typed" <|
            \_ ->
                opened
                    |> on Event.click (button "Rename: Late")
                    |> on (Event.input "Later") [ Selector.id "views-rename" ]
                    |> expectOk
                        (\renaming ->
                            drawn (SavedViews.setViews (SavedViews.views renaming) renaming)
                                |> Query.fromHtml
                                |> Query.find [ Selector.id "views-rename" ]
                                |> Query.has [ Selector.attribute (Attr.value "Later") ]
                        )
        , test "setViews closes a rename of a view that is gone" <|
            \_ ->
                opened
                    |> on Event.click (button "Rename: Late")
                    |> expectOk
                        (\renaming ->
                            drawn (SavedViews.setViews (List.take 1 (SavedViews.views renaming)) renaming)
                                |> Query.fromHtml
                                |> Query.findAll [ Selector.id "views-rename" ]
                                |> Query.count (Expect.equal 0)
                        )
        , test "a rename can change the note" <|
            \_ ->
                opened
                    |> on Event.click (button "Rename: Late")
                    |> on (Event.input "Older than a week") [ Selector.id "views-note" ]
                    |> on Event.click [ Selector.tag "button", Selector.class "klar-button--primary" ]
                    |> expectOk
                        (\renamed ->
                            SavedViews.views renamed
                                |> List.map .note
                                |> Expect.equal [ Nothing, Just "Older than a week" ]
                        )
        , test "the question of a deletion describes its buttons" <|
            \_ ->
                opened
                    |> on Event.click (button "Delete: Late")
                    |> expectOk
                        (\deleting ->
                            drawn deleting
                                |> Query.fromHtml
                                |> Expect.all
                                    [ Query.find [ Selector.id "views-confirm" ]
                                        >> Query.has [ Selector.attribute (Attr.attribute "aria-describedby" "views-question") ]
                                    , Query.find [ Selector.id "views-question" ] >> Query.has [ Selector.text "Delete “Late”?" ]
                                    ]
                        )
        , test "the default toggle keeps its name and says its state with aria-pressed" <|
            \_ ->
                opened
                    |> on Event.click (button "Default view: Open")
                    |> expectOk
                        (\toggled ->
                            drawn toggled
                                |> Query.fromHtml
                                |> Query.find (button "Default view: Open")
                                |> Query.has [ Selector.attribute (Attr.attribute "aria-pressed" "true") ]
                        )
        ]
