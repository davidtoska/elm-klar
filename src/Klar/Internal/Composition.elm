module Klar.Internal.Composition exposing (unlessComposing)

{-| The Enter or Escape that ends an IME composition (Japanese, Chinese, Korean
input) belongs to the input method, not to the field: it picks the characters. A
key handler that saves, cancels or formats on Enter or Escape must not act on it.
-}

import Json.Decode as Decode exposing (Decoder)


{-| Fails while the key event is part of a composition (`isComposing`, or the
`keyCode` 229 that some browsers send instead), and is the given decoder
otherwise. A browser that sends neither is never composing.
-}
unlessComposing : Decoder a -> Decoder a
unlessComposing decoder =
    Decode.map2 (||)
        (Decode.oneOf [ Decode.field "isComposing" Decode.bool, Decode.succeed False ])
        (Decode.oneOf [ Decode.field "keyCode" Decode.int |> Decode.map ((==) 229), Decode.succeed False ])
        |> Decode.andThen
            (\composing ->
                if composing then
                    Decode.fail "composing"

                else
                    decoder
            )
