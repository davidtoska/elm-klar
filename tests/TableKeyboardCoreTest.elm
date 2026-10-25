module TableKeyboardCoreTest exposing (suite)

import Expect
import Json.Decode as Decode
import Klar.Table.Keyboard as Keyboard
import Test exposing (Test, test)


suite : Test
suite =
    test "row actions ignore a nested button but accept the row background" <|
        \_ ->
            List.map (Decode.decodeString (Keyboard.ignoreControls "row") >> Result.toMaybe)
                [ "{\"target\":{\"tagName\":\"SPAN\",\"parentElement\":{\"tagName\":\"BUTTON\"}}}"
                , "{\"target\":{\"tagName\":\"TR\"}}"
                ]
                |> Expect.equal [ Nothing, Just "row" ]
