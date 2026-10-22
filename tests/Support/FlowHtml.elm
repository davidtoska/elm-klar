module Support.FlowHtml exposing
    ( attr
    , count
    , has
    , hasNot
    , inside
    , none
    , sends
    )

{-| Small helpers for the render tests of the pages-and-flow modules.
-}

import Expect exposing (Expectation)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


{-| The root element has all these.
-}
has : List Selector -> Html msg -> Expectation
has selectors html =
    html |> Query.fromHtml |> Query.has selectors


{-| The root element lacks at least one of these.
-}
hasNot : List Selector -> Html msg -> Expectation
hasNot selectors html =
    html |> Query.fromHtml |> Query.hasNot selectors


{-| The one element inside the root that matches `find` has all these.
-}
inside : List Selector -> List Selector -> Html msg -> Expectation
inside find selectors html =
    html |> Query.fromHtml |> Query.find find |> Query.has selectors


{-| No element in the HTML matches.
-}
none : List Selector -> Html msg -> Expectation
none find html =
    html |> Query.fromHtml |> Query.findAll find |> Query.count (Expect.equal 0)


{-| Exactly this many elements match.
-}
count : Int -> List Selector -> Html msg -> Expectation
count n find html =
    html |> Query.fromHtml |> Query.findAll find |> Query.count (Expect.equal n)


attr : String -> String -> Selector
attr name value =
    Selector.attribute (Attr.attribute name value)


{-| The message that the one element matching `find` sends for an event, or why
it sends none.
-}
sends : List Selector -> ( String, Encode.Value ) -> Html msg -> Result String msg
sends find event html =
    html
        |> Query.fromHtml
        |> Query.find find
        |> Event.simulate event
        |> Event.toResult
