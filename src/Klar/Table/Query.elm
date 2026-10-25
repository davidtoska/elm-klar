module Klar.Table.Query exposing (..)

{-| Versioned JSON serialization and tolerant decoding of table queries.
-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Klar.Table.Types exposing (ColumnId(..), Direction(..), Filter(..), Query)


{-| A query as JSON, to keep it where the application keeps its things (a saved
view, the address, a setting): `Encode.encode 0 (Table.encodeQuery q)`. The library
stores nothing itself. The object has a version, `"v": 1`, and the columns are
written by their name (`columnName`):

    {"v":1,"search":"acme","sort":[{"column":"total","descending":true}],
     "filters":[{"column":"status","oneOf":["open","late"]}],"page":1,"pageSize":25}

A filter is written as `contains` (text), `oneOf` (a list of texts) or `between`
(`[from, to]`, a missing bound is `null`).

-}
encodeQuery : Query -> Encode.Value
encodeQuery q =
    Encode.object
        [ ( "v", Encode.int 1 )
        , ( "search", Encode.string q.search )
        , ( "sort"
          , Encode.list
                (\( ColumnId id, direction ) ->
                    Encode.object
                        [ ( "column", Encode.string id )
                        , ( "descending", Encode.bool (direction == Descending) )
                        ]
                )
                q.sort
          )
        , ( "filters"
          , Encode.list
                (\( ColumnId id, filter ) ->
                    Encode.object
                        (( "column", Encode.string id )
                            :: (case filter of
                                    Contains words ->
                                        [ ( "contains", Encode.string words ) ]

                                    OneOf choices ->
                                        [ ( "oneOf", Encode.list Encode.string choices ) ]

                                    Between from to ->
                                        [ ( "between", Encode.list (Maybe.map Encode.float >> Maybe.withDefault Encode.null) [ from, to ] ) ]
                               )
                        )
                )
                q.filters
          )
        , ( "page", Encode.int q.page )
        , ( "pageSize", Encode.int q.pageSize )
        ]


{-| Reads what `encodeQuery` wrote. It is made for text that has been kept for a long
time or written by another version: a field that is missing takes the value of an
empty query (no search, no sort, no filters, page 1, 25 rows), a field it does not
know is ignored, a filter it does not know is left out (a restored view is better with
one filter less than not at all), and a version newer than 1 is refused, because
reading it as version 1 could be wrong. A page or page size below 1 becomes 1.

    Decode.decodeString Table.queryDecoder text

-}
queryDecoder : Decoder Query
queryDecoder =
    Decode.oneOf [ Decode.field "v" Decode.int, Decode.succeed 1 ]
        |> Decode.andThen
            (\version ->
                if version > 1 then
                    Decode.fail ("This query was written by a newer version (v" ++ String.fromInt version ++ ")")

                else
                    Decode.map5 Query
                        (optionalField "search" Decode.string "")
                        (optionalField "sort" (Decode.list sortDecoder |> Decode.map (List.filterMap identity)) [])
                        (optionalField "filters" (Decode.list filterDecoder |> Decode.map (List.filterMap identity)) [])
                        (optionalField "page" Decode.int 1 |> Decode.map (max 1))
                        (optionalField "pageSize" Decode.int 25 |> Decode.map (max 1))
            )


optionalField : String -> Decoder a -> a -> Decoder a
optionalField name decoder fallback =
    Decode.oneOf [ Decode.field name decoder, Decode.succeed fallback ]


sortDecoder : Decoder (Maybe ( ColumnId, Direction ))
sortDecoder =
    Decode.oneOf
        [ Decode.map2
            (\id descending ->
                Just
                    ( ColumnId id
                    , if descending then
                        Descending

                      else
                        Ascending
                    )
            )
            (Decode.field "column" Decode.string)
            (optionalField "descending" Decode.bool False)
        , Decode.succeed Nothing
        ]


filterDecoder : Decoder (Maybe ( ColumnId, Filter ))
filterDecoder =
    Decode.oneOf
        [ Decode.field "column" Decode.string
            |> Decode.andThen
                (\id ->
                    Decode.oneOf
                        [ Decode.field "contains" Decode.string |> Decode.map Contains
                        , Decode.field "oneOf" (Decode.list Decode.string) |> Decode.map OneOf
                        , Decode.field "between" (Decode.list (Decode.nullable Decode.float))
                            |> Decode.andThen
                                (\bounds ->
                                    case bounds of
                                        [ from, to ] ->
                                            Decode.succeed (Between from to)

                                        _ ->
                                            Decode.fail "a range has two bounds"
                                )
                        ]
                        |> Decode.map (\filter -> Just ( ColumnId id, filter ))
                )
        , Decode.succeed Nothing
        ]
