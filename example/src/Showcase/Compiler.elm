port module Showcase.Compiler exposing (request, responses)

{-| The optional local compiler belongs to the showcase, never to Klar.
Every response carries the component and request id that initiated it.
-}

import Json.Encode as Encode


port request : Encode.Value -> Cmd msg


port responses : (Encode.Value -> msg) -> Sub msg
