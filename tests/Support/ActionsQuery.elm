module Support.ActionsQuery exposing (absent, count, isPresent)

{-| Questions about rendered HTML that `Test.Html.Query` cannot ask directly.

`Query.has` and `Query.hasNot` look at the element that the query is on, not at
what is inside it. These look inside.

-}

import Expect exposing (Expectation)
import Test.Html.Query as Query
import Test.Html.Selector exposing (Selector)
import Test.Runner


{-| Nothing inside the element matches.
-}
absent : List Selector -> Query.Single msg -> Expectation
absent selectors =
    Query.findAll selectors >> Query.count (Expect.equal 0)


{-| Something inside the element matches.
-}
isPresent : List Selector -> Query.Single msg -> Bool
isPresent selectors single =
    count selectors single > 0


{-| How many elements inside match. It asks `Query.count` until it says yes, so it
reads up to 40.
-}
count : List Selector -> Query.Single msg -> Int
count selectors single =
    let
        found =
            Query.findAll selectors single
    in
    List.range 0 40
        |> List.filter (\n -> Test.Runner.getFailureReason (Query.count (Expect.equal n) found) == Nothing)
        |> List.head
        |> Maybe.withDefault -1
