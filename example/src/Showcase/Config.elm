module Showcase.Config exposing (Config, Control(..), Option, active, choice, empty, get, has, include, keep, number, only, remote, slot, text)

{-| Shared, typed playground configuration. Missing keys deliberately preserve the
original example, so the state gallery remains a useful baseline.
-}

import Dict exposing (Dict)
import Html exposing (Html)
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Layout as Layout
import Klar.Remote as Remote exposing (Remote)


type alias Config =
    { component : String
    , values : Dict String String
    }


type Control
    = Text
    | Number
    | Choice (List String)
    | Example


type alias Option =
    { name : String, type_ : String, description : String, control : Control }


empty : Config
empty =
    { component = "", values = Dict.empty }


active : Config -> String -> Bool
active config component =
    config.component == component


get : Config -> String -> String -> Maybe String
get config component key =
    if active config component then
        Dict.get key config.values

    else
        Nothing


has : Config -> String -> String -> Bool
has config component key =
    get config component key /= Nothing


keep : Config -> String -> String -> a -> List a
keep config component key original =
    if get config component key == Just "omit" then
        []

    else
        [ original ]


include : Config -> List String -> Bool
include config components =
    config.component == "" || List.isEmpty components || List.member config.component components


only : Config -> List String -> Html msg -> Html msg
only config components content =
    if include config components then
        content

    else
        Html.text ""


text : String -> String
text value =
    value


number : String -> Maybe Float
number =
    String.toFloat


choice : List ( String, a ) -> String -> Maybe a
choice choices value =
    choices |> List.filter (Tuple.first >> (==) value) |> List.head |> Maybe.map Tuple.second


remote : Config -> String -> String -> Remote a -> Remote a
remote config component key original =
    case get config component key of
        Just "Not asked" ->
            Remote.NotAsked

        Just "Loading" ->
            Remote.Loading

        Just "Failed" ->
            Remote.Failed (Remote.problem Remote.server |> Remote.withDetail "The demo request failed. Try again.")

        Just "Refreshing" ->
            Remote.refresh original

        Just "Stale" ->
            Remote.refresh original |> (\value -> Remote.settle value (Err (Remote.problem Remote.network)))

        _ ->
            original


slot : String -> Html msg
slot value =
    case value of
        "Badge" ->
            Badge.view [] "Configured content"

        "Button" ->
            Button.view [] "Composed action"

        "Stack" ->
            Layout.stack [ Layout.gap 2 ]
                [ Html.strong [] [ Html.text "Composed content" ]
                , Html.p [] [ Html.text "A heading and a description inside the component." ]
                ]

        "Empty" ->
            Html.text ""

        _ ->
            Html.text value
