module Klar.ToggleGroup.Selection exposing (toggleMany, toggleOne)

{-| The two ways a click changes the selection of a toggle group. Not exposed;
`Klar.ToggleGroup` uses it, and the tests of the package read it. The ids are the
application's own and are compared with `==`, so they must be plain data (no
functions).
-}


{-| A group that holds at most one: clicking the chosen option clears the choice,
clicking another one chooses that instead.
-}
toggleOne : id -> Maybe id -> Maybe id
toggleOne id current =
    if current == Just id then
        Nothing

    else
        Just id


{-| A group that holds any number: clicking an option that is chosen takes it out,
clicking one that is not puts it in. The result lists the chosen options in the
order of the options (`optionIds`), whatever order the user clicked them in, so
the same choice is always the same list. An id in the selection that no option has
(the application changed the options) is kept, after the others, and an id never
comes twice. It reads each list once for each option, so it is meant for the
dozens of options that fit in a row of buttons.
-}
toggleMany : List id -> id -> List id -> List id
toggleMany optionIds id selected =
    let
        chosen =
            if List.member id selected then
                List.filter (\other -> other /= id) selected

            else
                id :: selected

        inOptionOrder =
            optionIds
                |> List.filter (\option -> List.member option chosen)

        others =
            chosen
                |> List.filter (\other -> not (List.member other optionIds))
    in
    unique (inOptionOrder ++ others)


unique : List id -> List id
unique ids =
    List.foldl
        (\id kept ->
            if List.member id kept then
                kept

            else
                id :: kept
        )
        []
        ids
        |> List.reverse
