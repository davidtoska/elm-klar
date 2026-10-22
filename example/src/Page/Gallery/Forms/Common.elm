module Page.Gallery.Forms.Common exposing
    ( grid
    , narrow
    , readout
    , resultTable
    , showNumber
    , stack
    , yesNo
    )

{-| Small helpers shared by the sections of the forms page.
-}

import Html exposing (Html)
import Klar.Form.Layout as FormLayout
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Remote as Remote
import Klar.Text as Text


{-| Examples side by side, as many columns as fit.
-}
grid : Int -> List (Html msg) -> Html msg
grid minWidth children =
    Layout.grid [ Layout.minColumn minWidth, Layout.gap 5, Layout.alignStart ] children


stack : List (Html msg) -> Html msg
stack children =
    Layout.stack [ Layout.gap 4 ] children


{-| A column of limited width at the left edge of the example (not centred
like a page container), to show how long texts behave in a narrow place.
-}
narrow : Int -> List (Html msg) -> Html msg
narrow width children =
    Layout.container [ Layout.maxWidth width, Layout.alignStart ] children


{-| A small line that shows what the application knows.
-}
readout : String -> Html msg
readout text =
    Text.caption text


showNumber : Maybe Float -> String
showNumber maybe =
    case maybe of
        Just number ->
            String.fromFloat number

        Nothing ->
            "none"


yesNo : Bool -> String
yesNo flag =
    if flag then
        "yes"

    else
        "no"


{-| Two columns: what goes in, and what comes out.
-}
resultTable : List String -> List ( String, String ) -> Html msg
resultTable headers rows =
    Layout.grid [ Layout.columns 2, Layout.gap 2, Layout.maxWidth 420 ]
        (List.map Text.overline headers
            ++ List.concatMap (\( left, right ) -> [ Text.mono left, Text.strong right ]) rows
        )
