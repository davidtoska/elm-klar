module ToastKeyTest exposing (suite)

{-| A toast with a key can be taken away from `update` (a stale failure toast when a retry
succeeded), and a new toast with the same key replaces the old one.
-}

import Expect
import Klar.Theme exposing (Tone(..))
import Klar.Toast as Toast
import Test exposing (Test, describe, test)


type alias Stack =
    Toast.State ()


pushed : List (Toast.Attribute ()) -> Stack -> Stack
pushed attributes stack =
    Toast.push attributes stack |> Tuple.first


suite : Test
suite =
    describe "Klar.Toast keys"
        [ test "dismiss removes the toast with that key and no other" <|
            \_ ->
                Toast.init "toasts"
                    |> pushed [ Toast.tone Danger, Toast.key "save", Toast.message "Could not save" ]
                    |> pushed [ Toast.tone Success, Toast.message "Note added" ]
                    |> Toast.dismiss "save"
                    |> Toast.count
                    |> Expect.equal 1
        , test "dismiss with a key nobody has changes nothing" <|
            \_ ->
                Toast.init "toasts"
                    |> pushed [ Toast.key "save" ]
                    |> Toast.dismiss "other"
                    |> Toast.count
                    |> Expect.equal 1
        , test "a new toast with the same key replaces the old one" <|
            \_ ->
                Toast.init "toasts"
                    |> pushed [ Toast.key "save", Toast.message "first" ]
                    |> pushed [ Toast.key "save", Toast.message "second" ]
                    |> Toast.count
                    |> Expect.equal 1
        , test "toasts without a key stack" <|
            \_ ->
                Toast.init "toasts"
                    |> pushed [ Toast.message "a" ]
                    |> pushed [ Toast.message "a" ]
                    |> Toast.count
                    |> Expect.equal 2
        , test "dismissing a visible toast lets a waiting one in, and a keyed waiting toast can be dismissed" <|
            \_ ->
                let
                    crowded =
                        Toast.init "toasts"
                            |> Toast.setMaxVisible 1
                            |> pushed [ Toast.key "a" ]
                            |> pushed [ Toast.key "b" ]
                            |> pushed [ Toast.key "c" ]
                in
                crowded
                    |> Toast.dismiss "b"
                    |> Toast.dismiss "a"
                    |> Expect.all
                        [ Toast.count >> Expect.equal 1
                        , Toast.queued >> Expect.equal 0
                        ]
        ]
