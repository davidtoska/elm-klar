module SavedViewsTest exposing (suite)

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Decode as Decode
import Json.Encode as Encode
import Klar.Rule as Rule
import Klar.SavedViews as SavedViews
import Klar.Table as Table
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


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


behaviourTests : Test
behaviourTests =
    describe "what the user does"
        [ test "apply and setActive find a name ignoring case and spaces" <|
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
