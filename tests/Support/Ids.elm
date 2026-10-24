module Support.Ids exposing (strings)

{-| The row ids of the table tests: the ids are plain text, kept as they are.
-}

import Klar.Ids as Ids exposing (Ids)
import Klar.Table as Table


strings : Ids String
strings =
    Ids.string
