module Klar.Link.Click exposing (plain)

{-| Which clicks on a link may be taken over by the application. Not exposed;
`Klar.Link` uses it, and the tests of the package read it.
-}

import Json.Decode as Decode exposing (Decoder)


{-| Succeeds for a click with the main button and no modifier key, and fails for
every other click: Ctrl or Cmd (a new tab), Shift (a new window), Alt (a
download) and a button other than the main one. A handler that is built on this
decoder leaves those clicks to the browser, so they still open the link where the
user asked. A field that the event does not have counts as "not pressed", which
is what a synthetic click in a test looks like.
-}
plain : Decoder ()
plain =
    Decode.map5 (\button ctrl meta shift alt -> button == 0 && not ctrl && not meta && not shift && not alt)
        (flag Decode.int 0 "button")
        (flag Decode.bool False "ctrlKey")
        (flag Decode.bool False "metaKey")
        (flag Decode.bool False "shiftKey")
        (flag Decode.bool False "altKey")
        |> Decode.andThen
            (\isPlain ->
                if isPlain then
                    Decode.succeed ()

                else
                    Decode.fail "not a plain click"
            )


flag : Decoder a -> a -> String -> Decoder a
flag decoder fallback name =
    Decode.oneOf [ Decode.field name decoder, Decode.succeed fallback ]
