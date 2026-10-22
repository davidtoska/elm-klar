module SavedViewsTest exposing (suite)

import Expect
import Klar.Rule as Rule
import Klar.SavedViews as SavedViews
import Klar.Table as Table
import Test exposing (Test, describe, test)


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
        ]
