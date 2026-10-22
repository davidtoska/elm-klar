module Klar.Diff.Json exposing (Options, Step(..), diff, pathLabel)

{-| The difference between two JSON values, by path.

Objects are compared key by key and arrays position by position (or, for arrays of
objects, record by record by a key field that the application names). The answer is
a list of entries: every leaf that was added, removed or changed, with a readable
path such as `items[2].price`. The order is the same for the same two values: the
keys of an object are visited in alphabetical order, and an array in the order of
its positions.

Numbers are compared exactly (as the numbers a browser makes of them, which is
all JSON can say), strings character by character. A value that is not JSON at all
(a function or `undefined` that came through a port) or nested deeper than 64
levels is never reported as equal to anything: it shows up as changed, with a note
that it could not be compared.

-}

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, Value)
import Json.Encode as Encode
import Klar.Diff.Inline as Inline
import Klar.Diff.Keys as Keys
import Klar.Diff.Types exposing (Entry, Kind(..), Part, Shown(..))
import Set


{-| What to name the key of the records in arrays of objects, or nothing to compare
every array by position.
-}
type alias Options =
    { matchBy : Maybe String
    }


type Node
    = JObject (List ( String, Node ))
    | JArray (List Node)
    | JString String
    | JNumber Float
    | JBool Bool
    | JNull
    | JUnreadable
    | JTooDeep


{-| A step on the way from the root to a value.
-}
type Step
    = Key String
    | Index Int
    | Match String String


deepest : Int
deepest =
    64


{-| A value is cut after this many characters.
-}
longestValue : Int
longestValue =
    400


{-| Two strings are compared character by character up to this length.
-}
longestInline : Int
longestInline =
    2000


decoder : Int -> Decoder Node
decoder depth =
    let
        leaves =
            [ Decode.map JString Decode.string
            , Decode.map JNumber Decode.float
            , Decode.map JBool Decode.bool
            , Decode.null JNull
            ]
    in
    if depth <= 0 then
        Decode.oneOf (leaves ++ [ Decode.succeed JTooDeep ])

    else
        Decode.oneOf
            (leaves
                ++ [ Decode.map JArray (Decode.list (Decode.lazy (\_ -> decoder (depth - 1))))
                   , Decode.map (\members -> JObject (List.sortBy Tuple.first members))
                        (Decode.keyValuePairs (Decode.lazy (\_ -> decoder (depth - 1))))
                   , Decode.succeed JUnreadable
                   ]
            )


parse : Value -> Node
parse value =
    Decode.decodeValue (decoder deepest) value
        |> Result.withDefault JUnreadable



-- COMPARING


{-| The entries that turn the first value into the second. The values are equal
when the list is empty.
-}
diff : Options -> Value -> Value -> List Entry
diff options old new =
    compareNodes options [] (parse old) (parse new) { entries = [], budget = Inline.sharedBudget }
        |> .entries
        |> List.reverse
        |> withUniqueKeys


{-| Two different places can have the same path as text (an object that has a key
`"a.b"` and an object `a` with a key `b`), and the viewer needs a different key for
every entry. The label stays what it is.
-}
withUniqueKeys : List Entry -> List Entry
withUniqueKeys entries =
    List.map2 (\entry key -> { entry | key = key })
        entries
        (Keys.unique (\key number -> key ++ "~" ++ String.fromInt number) (List.map .key entries))


{-| What is found so far (the last entry first) and what is left of the work for
marking what changed inside the strings: all the strings of a diff share one budget,
so that the work has a limit whatever the number of strings is. A string that comes
after the budget is spent is shown as a whole.
-}
type alias Found =
    { entries : List Entry
    , budget : Int
    }


push : Entry -> Found -> Found
push entry found =
    { found | entries = entry :: found.entries }


{-| Compares two values and puts the entries on the front of `found` (so the
result is in reverse order).
-}
compareNodes : Options -> List Step -> Node -> Node -> Found -> Found
compareNodes options path old new found =
    case ( old, new ) of
        ( JObject oldMembers, JObject newMembers ) ->
            compareMembers options path oldMembers newMembers found

        ( JArray oldItems, JArray newItems ) ->
            case options.matchBy |> Maybe.andThen (\field -> matchedItems field oldItems newItems) of
                Just ( field, pairs ) ->
                    compareMatched options path field pairs found

                Nothing ->
                    comparePositions options path 0 oldItems newItems found

        ( JString a, JString b ) ->
            if a == b then
                found

            else
                changedStrings path a b found

        ( JNumber a, JNumber b ) ->
            if sameNumber a b then
                found

            else
                push (changed path old new) found

        ( JBool a, JBool b ) ->
            if a == b then
                found

            else
                push (changed path old new) found

        ( JNull, JNull ) ->
            found

        _ ->
            -- another kind of value, or one that cannot be compared
            push (changed path old new) found


{-| NaN cannot come out of JSON text, but a value from a port can have it.
-}
sameNumber : Float -> Float -> Bool
sameNumber a b =
    a == b || (isNaN a && isNaN b)


compareMembers : Options -> List Step -> List ( String, Node ) -> List ( String, Node ) -> Found -> Found
compareMembers options path oldMembers newMembers found =
    case ( oldMembers, newMembers ) of
        ( [], [] ) ->
            found

        ( ( oldKey, oldValue ) :: oldRest, [] ) ->
            compareMembers options path oldRest [] (push (removed (Key oldKey :: path) oldValue) found)

        ( [], ( newKey, newValue ) :: newRest ) ->
            compareMembers options path [] newRest (push (added (Key newKey :: path) newValue) found)

        ( ( oldKey, oldValue ) :: oldRest, ( newKey, newValue ) :: newRest ) ->
            case compare oldKey newKey of
                EQ ->
                    compareMembers options path oldRest newRest (compareNodes options (Key oldKey :: path) oldValue newValue found)

                LT ->
                    compareMembers options path oldRest newMembers (push (removed (Key oldKey :: path) oldValue) found)

                GT ->
                    compareMembers options path oldMembers newRest (push (added (Key newKey :: path) newValue) found)


comparePositions : Options -> List Step -> Int -> List Node -> List Node -> Found -> Found
comparePositions options path index oldItems newItems found =
    case ( oldItems, newItems ) of
        ( [], [] ) ->
            found

        ( oldItem :: oldRest, [] ) ->
            comparePositions options path (index + 1) oldRest [] (push (removed (Index index :: path) oldItem) found)

        ( [], newItem :: newRest ) ->
            comparePositions options path (index + 1) [] newRest (push (added (Index index :: path) newItem) found)

        ( oldItem :: oldRest, newItem :: newRest ) ->
            comparePositions options path (index + 1) oldRest newRest (compareNodes options (Index index :: path) oldItem newItem found)



-- ARRAYS OF RECORDS


type Matched
    = Both Node Node
    | OnlyOld Node
    | OnlyNew Node


{-| The records of two arrays paired by the value of a key field, in the order
of the new array and then the records that only the old one has. `Nothing` when
the arrays cannot be matched this way: an item that is not an object or has no
text or number in the field, or two items with the same key in one array. They
are then compared by position.
-}
matchedItems : String -> List Node -> List Node -> Maybe ( String, List ( String, Matched ) )
matchedItems field oldItems newItems =
    let
        keyed items =
            items
                |> List.map (\item -> Maybe.map (\key -> ( key, item )) (keyOf field item))
                |> List.foldr (Maybe.map2 (::)) (Just [])
                |> Maybe.andThen
                    (\pairs ->
                        if Set.size (Set.fromList (List.map Tuple.first pairs)) == List.length pairs then
                            Just pairs

                        else
                            Nothing
                    )
    in
    Maybe.map2
        (\oldKeyed newKeyed ->
            let
                oldByKey =
                    Dict.fromList oldKeyed

                newKeys =
                    Set.fromList (List.map Tuple.first newKeyed)

                fromNew =
                    List.map
                        (\( key, item ) ->
                            case Dict.get key oldByKey of
                                Just oldItem ->
                                    ( key, Both oldItem item )

                                Nothing ->
                                    ( key, OnlyNew item )
                        )
                        newKeyed

                fromOld =
                    oldKeyed
                        |> List.filter (\( key, _ ) -> not (Set.member key newKeys))
                        |> List.map (\( key, item ) -> ( key, OnlyOld item ))
            in
            ( field, fromNew ++ fromOld )
        )
        (keyed oldItems)
        (keyed newItems)


keyOf : String -> Node -> Maybe String
keyOf field node =
    case node of
        JObject members ->
            members
                |> List.filter (\( name, _ ) -> name == field)
                |> List.head
                |> Maybe.andThen
                    (\( _, value ) ->
                        case value of
                            JString text ->
                                Just text

                            JNumber number ->
                                Just (String.fromFloat number)

                            _ ->
                                Nothing
                    )

        _ ->
            Nothing


compareMatched : Options -> List Step -> String -> List ( String, Matched ) -> Found -> Found
compareMatched options path field pairs found =
    List.foldl
        (\( key, matched ) soFar ->
            let
                here =
                    Match field key :: path
            in
            case matched of
                Both oldItem newItem ->
                    compareNodes options here oldItem newItem soFar

                OnlyOld oldItem ->
                    push (removed here oldItem) soFar

                OnlyNew newItem ->
                    push (added here newItem) soFar
        )
        found
        pairs



-- ENTRIES


added : List Step -> Node -> Entry
added path node =
    { key = pathLabel (List.reverse path)
    , label = pathLabel (List.reverse path)
    , kind = Added
    , before = Nothing
    , after = Just (shown node)
    }


removed : List Step -> Node -> Entry
removed path node =
    { key = pathLabel (List.reverse path)
    , label = pathLabel (List.reverse path)
    , kind = Removed
    , before = Just (shown node)
    , after = Nothing
    }


changed : List Step -> Node -> Node -> Entry
changed path old new =
    { key = pathLabel (List.reverse path)
    , label = pathLabel (List.reverse path)
    , kind = Changed
    , before = Just (shown old)
    , after = Just (shown new)
    }


changedStrings : List Step -> String -> String -> Found -> Found
changedStrings path old new found =
    let
        oldText =
            encodeString old

        newText =
            encodeString new

        label =
            pathLabel (List.reverse path)
    in
    if String.length oldText > longestInline || String.length newText > longestInline then
        push { key = label, label = label, kind = Changed, before = Just (shown (JString old)), after = Just (shown (JString new)) } found

    else
        let
            ( segments, spent ) =
                Inline.diffWithin found.budget oldText newText
        in
        push
            { key = label
            , label = label
            , kind = Changed
            , before = Just (Text { parts = side (\removedText _ -> removedText) segments, truncated = False })
            , after = Just (Text { parts = side (\_ addedText -> addedText) segments, truncated = False })
            }
            { found | budget = found.budget - spent }


{-| The parts of one side of an inline comparison. Text with nothing in common is
one unchanged part: the entry says that it changed.
-}
side : (String -> String -> String) -> List Inline.Segment -> List Part
side pick segments =
    case segments of
        [ Inline.Replace removedText addedText ] ->
            [ { text = pick removedText addedText, changed = False } ]

        _ ->
            segments
                |> List.map
                    (\segment ->
                        case segment of
                            Inline.Keep text ->
                                { text = text, changed = False }

                            Inline.Replace removedText addedText ->
                                { text = pick removedText addedText, changed = True }
                    )
                |> List.filter (\part -> part.text /= "")


shown : Node -> Shown
shown node =
    case node of
        JUnreadable ->
            NotJson

        JTooDeep ->
            TooDeep

        _ ->
            let
                ( text, truncated ) =
                    compact longestValue node
            in
            Text { parts = [ { text = text, changed = False } ], truncated = truncated }



-- TEXT


encodeString : String -> String
encodeString text =
    Encode.encode 0 (Encode.string text)


{-| The value as one line of JSON text with the keys in order, cut after about
that many characters.

    compact 400 node -- ( "{\"id\": 7, \"tags\": [\"a\", \"b\"]}", False )

-}
compact : Int -> Node -> ( String, Bool )
compact budget node =
    let
        ( pieces, left ) =
            write node budget []

        text =
            String.concat (List.reverse pieces)
    in
    if left < 0 then
        ( cut budget text, True )

    else
        ( text, False )


{-| Adds the text of a node to the front of the pieces (in reverse) and counts
down the characters that are left. It stops going deeper when none are.
-}
write : Node -> Int -> List String -> ( List String, Int )
write node left pieces =
    if left < 0 then
        ( pieces, left )

    else
        case node of
            JString text ->
                leaf (encodeString text) left pieces

            JNumber number ->
                leaf (String.fromFloat number) left pieces

            JBool True ->
                leaf "true" left pieces

            JBool False ->
                leaf "false" left pieces

            JNull ->
                leaf "null" left pieces

            JUnreadable ->
                leaf "?" left pieces

            JTooDeep ->
                leaf "..." left pieces

            JArray [] ->
                leaf "[]" left pieces

            JArray items ->
                writeList "[" "]" (\item l p -> write item l p) items left pieces

            JObject [] ->
                leaf "{}" left pieces

            JObject members ->
                writeList "{"
                    "}"
                    (\( name, value ) l p ->
                        let
                            ( withName, afterName ) =
                                leaf (encodeString name ++ ": ") l p
                        in
                        write value afterName withName
                    )
                    members
                    left
                    pieces


leaf : String -> Int -> List String -> ( List String, Int )
leaf text left pieces =
    ( text :: pieces, left - String.length text )


writeList : String -> String -> (a -> Int -> List String -> ( List String, Int )) -> List a -> Int -> List String -> ( List String, Int )
writeList open close writeOne items left pieces =
    let
        ( opened, afterOpen ) =
            leaf open left pieces

        step item ( index, ( soFar, remaining ) ) =
            if remaining < 0 then
                ( index + 1, ( soFar, remaining ) )

            else
                let
                    ( separated, afterSeparator ) =
                        if index == 0 then
                            ( soFar, remaining )

                        else
                            leaf ", " remaining soFar
                in
                ( index + 1, writeOne item afterSeparator separated )

        ( _, ( written, afterItems ) ) =
            List.foldl step ( 0, ( opened, afterOpen ) ) items
    in
    leaf close afterItems written


{-| The first `count` characters of a text, without cutting a character that is
written as two UTF-16 units in the middle.
-}
cut : Int -> String -> String
cut count text =
    let
        left =
            String.left count text
    in
    if endsWithHighSurrogate left then
        String.dropRight 1 left

    else
        left


endsWithHighSurrogate : String -> Bool
endsWithHighSurrogate text =
    case String.right 1 text |> String.toList of
        [ char ] ->
            let
                code =
                    Char.toCode char
            in
            code >= 0xD800 && code <= 0xDBFF

        _ ->
            False



-- PATHS


{-| A readable path: `items[2].price`, `customer.address.city`, `["ship to"].name`.
A key that is not a plain name is written in brackets as a JSON string, an array
matched by a key field as `[sku=A-100]`, and the root itself as `$`.

    pathLabel [ Key "items", Index 2, Key "price" ] -- "items[2].price"

-}
pathLabel : List Step -> String
pathLabel steps =
    case steps of
        [] ->
            "$"

        _ ->
            steps
                |> List.indexedMap
                    (\position step ->
                        case step of
                            Key name ->
                                if isPlainName name then
                                    if position == 0 then
                                        name

                                    else
                                        "." ++ name

                                else
                                    "[" ++ encodeString name ++ "]"

                            Index index ->
                                "[" ++ String.fromInt index ++ "]"

                            Match field value ->
                                "[" ++ field ++ "=" ++ value ++ "]"
                    )
                |> String.concat


isPlainName : String -> Bool
isPlainName name =
    case String.toList name of
        [] ->
            False

        first :: rest ->
            isNameStart first && List.all isNameChar rest


isNameStart : Char -> Bool
isNameStart char =
    Char.isAlpha char || char == '_' || char == '$' || Char.toCode char > 127


isNameChar : Char -> Bool
isNameChar char =
    isNameStart char || Char.isDigit char || char == '-'
