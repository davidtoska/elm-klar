module Klar.Diff.Types exposing (Entry, Kind(..), Part, Shown(..), shownText)

{-| The pieces that the diffs of lines, of JSON and of fields have in common.

An entry is one change in a JSON value or one field of a record. The text of its
values is cut into parts, so that the characters that changed inside a value can
be marked.

-}


{-| A piece of the text of a line or a value, and whether it changed.
-}
type alias Part =
    { text : String
    , changed : Bool
    }


{-| What happened to a value.
-}
type Kind
    = Added
    | Removed
    | Changed
    | Unchanged


{-| One change in a JSON value or one field of a record, with the text of its
value before and after, when there is one.
-}
type alias Entry =
    { key : String
    , label : String
    , kind : Kind
    , before : Maybe Shown
    , after : Maybe Shown
    }


{-| How a value is shown. A value can be cut when it is long (`truncated`), and a
value of a JSON document may be something that is not JSON at all, or too deeply
nested to compare.
-}
type Shown
    = Text { parts : List Part, truncated : Bool }
    | NotJson
    | TooDeep


{-| The text of a shown value, for a program to read, or `Nothing` when there is
no text to give.
-}
shownText : Shown -> Maybe String
shownText shown =
    case shown of
        Text { parts } ->
            Just (String.concat (List.map .text parts))

        NotJson ->
            Nothing

        TooDeep ->
            Nothing
