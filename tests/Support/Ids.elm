module Support.Ids exposing (strings)

{-| The row ids of the table tests: the ids are plain text, kept as they are.
-}

import Klar.Table as Table


strings : Table.RowIds String
strings =
    Table.stringIds
