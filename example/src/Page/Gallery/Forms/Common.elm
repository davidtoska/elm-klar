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
import Showcase.Config as Config
import Showcase.Options as Options


{-| Examples side by side, as many columns as fit.
-}
grid : Config.Config -> Int -> List (Html msg) -> Html msg
grid playground minWidth children =
    Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "minColumn" (Layout.minColumn minWidth), Config.keep playground "Layout" "gap" (Layout.gap 5), Config.keep playground "Layout" "alignStart" Layout.alignStart ])) children


stack : Config.Config -> List (Html msg) -> Html msg
stack playground children =
    Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4) ])) children


{-| A column of limited width at the left edge of the example (not centred
like a page container), to show how long texts behave in a narrow place.
-}
narrow : Config.Config -> Int -> List (Html msg) -> Html msg
narrow playground width children =
    Layout.container (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "maxWidth" (Layout.maxWidth width), Config.keep playground "Layout" "alignStart" Layout.alignStart ])) children


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
resultTable : Config.Config -> List String -> List ( String, String ) -> Html msg
resultTable playground headers rows =
    Layout.grid (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "columns" (Layout.columns 2), Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "maxWidth" (Layout.maxWidth 420) ]))
        (List.map Text.overline headers
            ++ List.concatMap (\( left, right ) -> [ Text.mono left, Text.strong right ]) rows
        )
