module Klar.Select.Popup exposing
    ( Built
    , Cache
    , Env
    , Indicator(..)
    , Move(..)
    , Outcome(..)
    , Row(..)
    , RowConfig
    , Rows
    , Texts
    , act
    , activeDescendant
    , build
    , cachedRows
    , composing
    , findByValue
    , first
    , geometry
    , holdSearchFocus
    , indexOfValue
    , initial
    , isJust
    , last
    , listHeight
    , next
    , noticeRetry
    , onKeydown
    , onSearchKeys
    , onTriggerKeys
    , onWindowKeys
    , optionId
    , pageDown
    , pageSize
    , pageUp
    , prev
    , refresh
    , resolve
    , retryFor
    , rowAt
    , rowHeight
    , statusText
    , texts
    , viewChevron
    , viewClearButton
    , viewEmpty
    , viewFailure
    , viewFooter
    , viewLayer
    , viewMessage
    , viewNotice
    , viewPinned
    , viewRow
    , viewSearch
    , viewSkeleton
    )

{-| Shared machinery of the select family (`Klar.Select`, `Klar.MultiSelect`,
`Klar.Autocomplete`): turning options and a query into rows (filtering,
ranking, grouping, the "create" row), keyboard navigation over the rows,
built-in texts, and the views of rows, search box, footer and states.

Not for application code.

-}

import Array exposing (Array)
import Dict
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Button as Button
import Klar.Checkbox as Checkbox
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote
import Klar.Search as Search
import Klar.Select.Match as Match
import Klar.Select.Option exposing (Option)
import Klar.Settings exposing (Settings)
import Klar.Skeleton as Skeleton
import Klar.Spinner as Spinner
import Klar.VirtualList as VirtualList



-- TEXTS


type alias Texts =
    { placeholder : String
    , searchPlaceholder : String
    , searchLabel : String
    , noMatches : String
    , noMatchesFor : String -> String
    , noOptions : String
    , typeToSearch : String
    , loading : String
    , unavailable : String
    , unknownValue : String
    , clearSelection : String
    , clearQuery : String
    , create : String -> String
    , matches : Int -> Int -> String
    , options : Int -> String
    , results : Int -> String
    , selected : Int -> String
    , selectedOfMax : Int -> Int -> String
    , selectAll : String
    , selectAllFiltered : String
    , clearAll : String
    , more : Int -> String
    , moreLabel : Int -> String
    , removed : String -> String
    , removedValue : String
    , removedAll : String
    , noSuggestions : String
    , suggestions : Int -> String
    }


texts : Locale -> Texts
texts locale =
    let
        num =
            Format.int locale
    in
    Locale.pick locale
        { nb =
            { placeholder = "Velg ..."
            , searchPlaceholder = "Søk ..."
            , searchLabel = "Søk i alternativene"
            , noMatches = "Ingen treff"
            , noMatchesFor = \query -> "Ingen alternativer passer til «" ++ query ++ "»."
            , noOptions = "Ingen alternativer"
            , typeToSearch = "Skriv for å søke"
            , loading = "Laster ..."
            , unavailable = "Kunne ikke hentes"
            , unknownValue = "Ukjent verdi"
            , clearSelection = "Fjern valget"
            , clearQuery = "Tøm søket"
            , create = \text -> "Opprett «" ++ text ++ "»"
            , matches = \shown total -> num shown ++ " av " ++ num total ++ " treff"
            , options =
                \n ->
                    num n
                        ++ (if n == 1 then
                                " alternativ"

                            else
                                " alternativer"
                           )
            , results = \n -> num n ++ " treff"
            , selected = \n -> num n ++ " valgt"
            , selectedOfMax = \n limit -> num n ++ " av maks " ++ num limit ++ " valgt"
            , selectAll = "Velg alle"
            , selectAllFiltered = "Velg alle filtrerte"
            , clearAll = "Fjern alle"
            , more = \n -> "+" ++ num n
            , moreLabel = \n -> num n ++ " til er valgt"
            , removed = \name -> name ++ " fjernet"
            , removedValue = "Verdi fjernet"
            , removedAll = "Alle verdier fjernet"
            , noSuggestions = "Ingen forslag"
            , suggestions = \n -> num n ++ " forslag"
            }
        , en =
            { placeholder = "Select ..."
            , searchPlaceholder = "Search ..."
            , searchLabel = "Search the options"
            , noMatches = "No matches"
            , noMatchesFor = \query -> "No options match “" ++ query ++ "”."
            , noOptions = "No options"
            , typeToSearch = "Type to search"
            , loading = "Loading ..."
            , unavailable = "Could not be loaded"
            , unknownValue = "Unknown value"
            , clearSelection = "Clear selection"
            , clearQuery = "Clear search"
            , create = \text -> "Create “" ++ text ++ "”"
            , matches = \shown total -> num shown ++ " of " ++ num total ++ " matches"
            , options =
                \n ->
                    num n
                        ++ (if n == 1 then
                                " option"

                            else
                                " options"
                           )
            , results =
                \n ->
                    num n
                        ++ (if n == 1 then
                                " match"

                            else
                                " matches"
                           )
            , selected = \n -> num n ++ " selected"
            , selectedOfMax = \n limit -> num n ++ " of max " ++ num limit ++ " selected"
            , selectAll = "Select all"
            , selectAllFiltered = "Select all filtered"
            , clearAll = "Clear all"
            , more = \n -> "+" ++ num n
            , moreLabel = \n -> num n ++ " more selected"
            , removed = \name -> name ++ " removed"
            , removedValue = "Value removed"
            , removedAll = "All values removed"
            , noSuggestions = "No suggestions"
            , suggestions =
                \n ->
                    num n
                        ++ (if n == 1 then
                                " suggestion"

                            else
                                " suggestions"
                           )
            }
        }



-- ROWS


{-| What the rows are built from. `filterLocally` is `False` when the server
already did the searching (the options are shown as they come).
-}
type alias Env id =
    { options : List (Option id)
    , filterLocally : Bool
    , creatable : Bool
    }


{-| One fixed-height row of the list. Items and the create row carry their
1-based position among the selectable rows (`aria-posinset`).
-}
type Row id
    = Heading String
    | Item Int (Option id)
    | Create Int String


type alias Rows id =
    { rows : Array (Row id)
    , matched : List (Option id)
    , matchCount : Int
    , total : Int
    , optionRows : Int
    , grouped : Bool
    }


{-| The rows, and the search index they were filtered with (keep it in the
state and pass it back while the options stay the same).
-}
type alias Built id =
    { rows : Rows id
    , index : Maybe (Match.Index id)
    }


{-| Filter (or not), rank, group, and add the create row. The search index is
built only when there is something to search for.
-}
build : Maybe (Match.Index id) -> Env id -> String -> Built id
build cachedIndex env query =
    let
        trimmed =
            String.trim query

        filtering =
            env.filterLocally && trimmed /= ""

        searchIndex =
            if filtering then
                case cachedIndex of
                    Just existing ->
                        Just existing

                    Nothing ->
                        Just (Match.index env.options)

            else
                cachedIndex

        ( ranked, hasExactMatch ) =
            case ( filtering, searchIndex ) of
                ( True, Just entries ) ->
                    let
                        matching =
                            Match.rank trimmed entries

                        normalized =
                            Match.normalize trimmed
                    in
                    ( List.map .option matching
                    , env.creatable && List.any (\e -> String.trim e.label == normalized) matching
                    )

                _ ->
                    ( env.options
                    , env.creatable && trimmed /= "" && List.any (Match.isExactMatch trimmed) env.options
                    )

        createText =
            if env.creatable && trimmed /= "" && not hasExactMatch then
                Just trimmed

            else
                Nothing

        sections =
            groupSections ranked

        grouped =
            List.any (\( group, _ ) -> group /= Nothing) sections

        firstOrdinal =
            if createText == Nothing then
                1

            else
                2

        ( itemRowsReversed, orderedReversed, _ ) =
            List.foldl
                (\( group, items ) ( rowsAcc, orderedAcc, ordinal ) ->
                    List.foldl
                        (\opt ( r, o, n ) -> ( Item n opt :: r, opt :: o, n + 1 ))
                        ( case group of
                            Just name ->
                                Heading name :: rowsAcc

                            Nothing ->
                                rowsAcc
                        , orderedAcc
                        , ordinal
                        )
                        items
                )
                ( [], [], firstOrdinal )
                sections

        matchCount =
            List.length ranked

        createRows =
            case createText of
                Just text ->
                    [ Create 1 text ]

                Nothing ->
                    []
    in
    { rows =
        { rows = Array.fromList (createRows ++ List.reverse itemRowsReversed)
        , matched =
            if grouped then
                List.reverse orderedReversed

            else
                ranked
        , matchCount = matchCount
        , total = List.length env.options
        , optionRows = matchCount + List.length createRows
        , grouped = grouped
        }
    , index = searchIndex
    }


{-| What a component keeps in its state so that filtering happens once per
keystroke (not on every hover, scroll or arrow key), and the search index once
per list of options.
-}
type alias Cache id =
    { env : Env id
    , index : Maybe (Match.Index id)
    , query : String
    , rows : Rows id
    }


{-| Build the rows for a query and remember them (reusing the search index
while the options are the same list).
-}
refresh : Maybe (Cache id) -> Env id -> String -> Cache id
refresh cache env query =
    let
        built =
            build (Maybe.andThen (reusableIndex env) cache) env query
    in
    { env = env, index = built.index, query = query, rows = built.rows }


{-| The rows for the current options and query: from the cache when it is up
to date, otherwise built now.
-}
cachedRows : Maybe (Cache id) -> Env id -> String -> Rows id
cachedRows cache env query =
    case cache of
        Just existing ->
            if existing.query == query && existing.env == env then
                existing.rows

            else
                (build (reusableIndex env existing) env query).rows

        Nothing ->
            (build Nothing env query).rows


reusableIndex : Env id -> Cache id -> Maybe (Match.Index id)
reusableIndex env cache =
    if cache.env.options == env.options then
        cache.index

    else
        Nothing


{-| Options grouped by `group`, groups in order of first appearance, options
without a group first.
-}
groupSections : List (Option id) -> List ( Maybe String, List (Option id) )
groupSections options =
    if List.any (\opt -> opt.group /= Nothing) options then
        let
            keyOf opt =
                Maybe.withDefault "" opt.group

            ( orderReversed, groups ) =
                List.foldl
                    (\opt ( seen, dict ) ->
                        let
                            key =
                                keyOf opt
                        in
                        case Dict.get key dict of
                            Just items ->
                                ( seen, Dict.insert key (opt :: items) dict )

                            Nothing ->
                                ( key :: seen, Dict.insert key [ opt ] dict )
                    )
                    ( [], Dict.empty )
                    options

            order =
                List.reverse orderReversed

            keys =
                if List.member "" order then
                    "" :: List.filter (\key -> key /= "") order

                else
                    order
        in
        List.map
            (\key ->
                ( if key == "" then
                    Nothing

                  else
                    Just key
                , Dict.get key groups |> Maybe.withDefault [] |> List.reverse
                )
            )
            keys

    else
        [ ( Nothing, options ) ]


rowAt : Int -> Rows id -> Maybe (Row id)
rowAt index rows =
    Array.get index rows.rows


{-| Whether a `Maybe` has a value, without comparing values (application
messages may hold functions, which `==` cannot compare).
-}
isJust : Maybe a -> Bool
isJust maybe =
    case maybe of
        Just _ ->
            True

        Nothing ->
            False


findByValue : id -> List (Option id) -> Maybe (Option id)
findByValue value options =
    case options of
        [] ->
            Nothing

        opt :: rest ->
            if opt.value == value then
                Just opt

            else
                findByValue value rest


indexOfValue : id -> Rows id -> Maybe Int
indexOfValue value rows =
    findIndex
        (\row ->
            case row of
                Item _ opt ->
                    opt.value == value

                _ ->
                    False
        )
        0
        rows.rows


findIndex : (Row id -> Bool) -> Int -> Array (Row id) -> Maybe Int
findIndex predicate index rows =
    case Array.get index rows of
        Nothing ->
            Nothing

        Just row ->
            if predicate row then
                Just index

            else
                findIndex predicate (index + 1) rows



-- NAVIGATION


selectable : Row id -> Bool
selectable row =
    case row of
        Heading _ ->
            False

        Item _ opt ->
            not opt.disabled

        Create _ _ ->
            True


{-| The first selectable row at `index` or beyond in direction `step`.
-}
seek : Int -> Int -> Array (Row id) -> Maybe Int
seek step index rows =
    case Array.get index rows of
        Nothing ->
            Nothing

        Just row ->
            if selectable row then
                Just index

            else
                seek step (index + step) rows


{-| The row highlighted when nothing has been highlighted yet: the best
match, or the create row when nothing matches.
-}
initial : Rows id -> Maybe Int
initial rows =
    case
        findIndex
            (\row ->
                case row of
                    Item _ opt ->
                        not opt.disabled

                    _ ->
                        False
            )
            0
            rows.rows
    of
        Just index ->
            Just index

        Nothing ->
            seek 1 0 rows.rows


{-| The highlighted row, made valid for the current rows.
-}
resolve : Maybe Int -> Rows id -> Maybe Int
resolve highlighted rows =
    case highlighted of
        Nothing ->
            initial rows

        Just index ->
            let
                count =
                    Array.length rows.rows

                clamped =
                    clamp 0 (count - 1) index
            in
            if count == 0 then
                Nothing

            else
                case seek -1 clamped rows.rows of
                    Just found ->
                        Just found

                    Nothing ->
                        seek 1 clamped rows.rows


next : Rows id -> Int -> Int
next rows index =
    seek 1 (index + 1) rows.rows |> Maybe.withDefault index


prev : Rows id -> Int -> Int
prev rows index =
    seek -1 (index - 1) rows.rows |> Maybe.withDefault index


first : Rows id -> Maybe Int
first rows =
    seek 1 0 rows.rows


last : Rows id -> Maybe Int
last rows =
    seek -1 (Array.length rows.rows - 1) rows.rows


pageDown : Int -> Rows id -> Int -> Int
pageDown size rows index =
    let
        target =
            min (Array.length rows.rows - 1) (index + size)
    in
    case seek 1 target rows.rows of
        Just found ->
            found

        Nothing ->
            seek -1 target rows.rows |> Maybe.withDefault index


pageUp : Int -> Rows id -> Int -> Int
pageUp size rows index =
    let
        target =
            max 0 (index - size)
    in
    case seek -1 target rows.rows of
        Just found ->
            found

        Nothing ->
            seek 1 target rows.rows |> Maybe.withDefault index


{-| A navigation key on an open list.
-}
type Move
    = MoveNext
    | MovePrevious
    | MovePageDown
    | MovePageUp
    | MoveFirst
    | MoveLast
    | MoveChoose


{-| What a `Move` comes to: highlight another row, or choose the highlighted
one.
-}
type Outcome id
    = Highlight Int
    | Choose (Row id)


{-| The effect of a navigation key on the rows as they are right now. A key
that arrives before the list has had its next frame sends the `Move` itself
(not a ready-made target), and the component works the outcome out in `update`,
from the latest state: keys that arrive together still add up, and Enter never
chooses a row that the text typed a moment ago has filtered away.
-}
act : Int -> Rows id -> Maybe Int -> Move -> Maybe (Outcome id)
act visibleRows rows highlighted move =
    case resolve highlighted rows of
        Nothing ->
            Nothing

        Just current ->
            case move of
                MoveNext ->
                    Just (Highlight (next rows current))

                MovePrevious ->
                    Just (Highlight (prev rows current))

                MovePageDown ->
                    Just (Highlight (pageDown (pageSize visibleRows) rows current))

                MovePageUp ->
                    Just (Highlight (pageUp (pageSize visibleRows) rows current))

                MoveFirst ->
                    Just (Highlight (Maybe.withDefault current (first rows)))

                MoveLast ->
                    Just (Highlight (Maybe.withDefault current (last rows)))

                MoveChoose ->
                    rowAt current rows |> Maybe.map Choose



-- GEOMETRY


{-| Height of every row in pixels; the same as the `--klar-option-h` token.
-}
rowHeight : Int
rowHeight =
    32


listHeight : Int -> Int
listHeight visibleRows =
    max 1 visibleRows * rowHeight


{-| Rows a PageUp/PageDown moves.
-}
pageSize : Int -> Int
pageSize visibleRows =
    max 1 (visibleRows - 1)


geometry : Int -> Rows id -> VirtualList.Geometry
geometry visibleRows rows =
    { rowHeight = rowHeight
    , height = listHeight visibleRows
    , count = Array.length rows.rows
    , inset =
        if rows.grouped then
            rowHeight

        else
            0
    }


optionId : String -> Int -> String
optionId base index =
    base ++ "-opt-" ++ String.fromInt index


{-| The id for `aria-activedescendant`: the highlighted row, but only while that
row is on the page. The list draws only the rows around the scroll position, so
after the user scrolled away with the wheel the highlighted row is gone, and an
id that is not on the page names nothing.
-}
activeDescendant : String -> VirtualList.Geometry -> VirtualList.State -> Maybe Int -> Maybe String
activeDescendant base rowsGeometry list highlighted =
    case highlighted of
        Just index ->
            if VirtualList.isDrawn rowsGeometry index list then
                Just (optionId base index)

            else
                Nothing

        Nothing ->
            Nothing


statusText : Texts -> Bool -> String -> Rows id -> String
statusText t filterLocally query rows =
    if not filterLocally then
        t.results rows.matchCount

    else if String.isEmpty (String.trim query) then
        t.options rows.total

    else
        t.matches rows.matchCount rows.total



-- KEYBOARD


keyName : Internal.KeyEvent -> String
keyName event =
    String.concat
        [ if event.ctrl then
            "Ctrl+"

          else
            ""
        , if event.meta then
            "Meta+"

          else
            ""
        , if event.alt then
            "Alt+"

          else
            ""
        , if event.shift && String.length event.key /= 1 then
            "Shift+"

          else
            ""
        , event.key
        ]


lookup : String -> List ( String, a ) -> Maybe a
lookup key bindings =
    case bindings of
        [] ->
            Nothing

        ( name, value ) :: rest ->
            if name == key then
                Just value

            else
                lookup key rest


{-| Whether the key is held down (an automatic repeat). Holding Backspace to
delete the search text must not go on to remove every chosen value, so
Backspace bindings only react to a fresh press.
-}
isRepeatedBackspace : Internal.KeyEvent -> Decoder Bool
isRepeatedBackspace event =
    if event.key == "Backspace" then
        Decode.oneOf [ Decode.field "repeat" Decode.bool, Decode.succeed False ]

    else
        Decode.succeed False


{-| Is the key part of an input method composition (Japanese, Chinese, Korean
...)? Then Enter commits the composed text and the arrows pick a candidate: they
are not keys for the list. Browsers say so with `isComposing`, and with the key
code 229 for the key that ends a composition in some of them. It is the same
guard as in `Klar.Picking.View`.
-}
composing : Decoder Bool
composing =
    Decode.map2 (||)
        (Decode.oneOf [ Decode.field "isComposing" Decode.bool, Decode.succeed False ])
        (Decode.oneOf [ Decode.field "keyCode" Decode.int |> Decode.map (\code -> code == 229), Decode.succeed False ])


{-| A key press the list may act on: the key, whether it is a held-down
Backspace, and whether the element it was pressed in has no text.
-}
type alias Press =
    { event : Internal.KeyEvent
    , repeatedBackspace : Bool
    , empty : Bool
    }


{-| Every key handler of the select family reads its keys through this decoder.
It fails while an input method composes, so no binding ever acts on the Enter
that confirms a composition or on the arrows that choose a candidate.
-}
press : Decoder Press
press =
    composing
        |> Decode.andThen
            (\isComposing ->
                if isComposing then
                    Decode.fail "an input method is composing"

                else
                    Internal.keyEvent
                        |> Decode.andThen
                            (\event ->
                                Decode.map2 (Press event)
                                    (isRepeatedBackspace event)
                                    (Decode.oneOf
                                        [ Decode.at [ "target", "value" ] Decode.string |> Decode.map String.isEmpty
                                        , Decode.succeed True
                                        ]
                                    )
                            )
            )


pressName : Press -> String
pressName pressed =
    if pressed.repeatedBackspace then
        "Repeat+" ++ keyName pressed.event

    else
        keyName pressed.event


{-| One keydown handler with two kinds of bindings: `handled` keys prevent the
browser default and stop propagation (so a surrounding dialog does not also
react to Escape or the arrows), `passive` keys only send the message (Tab).
-}
onKeydown : { handled : List ( String, msg ), passive : List ( String, msg ) } -> Html.Attribute msg
onKeydown bindings =
    onSearchKeys { handled = bindings.handled, whenEmpty = [], passive = bindings.passive }


{-| The keys of a search box: `onKeydown`, plus `whenEmpty` bindings that act
(and prevent the default) only while the box has no text. Home and End are such
keys: in an empty box they go to the first and the last row, and in a box with
text they move the caret, as in every text field.
-}
onSearchKeys :
    { handled : List ( String, msg ), whenEmpty : List ( String, msg ), passive : List ( String, msg ) }
    -> Html.Attribute msg
onSearchKeys bindings =
    Events.custom "keydown"
        (press
            |> Decode.andThen
                (\pressed ->
                    let
                        name =
                            pressName pressed

                        handled =
                            case lookup name bindings.handled of
                                Just msg ->
                                    Just msg

                                Nothing ->
                                    if pressed.empty then
                                        lookup name bindings.whenEmpty

                                    else
                                        Nothing
                    in
                    case handled of
                        Just msg ->
                            Decode.succeed { message = msg, preventDefault = True, stopPropagation = True }

                        Nothing ->
                            case lookup name bindings.passive of
                                Just msg ->
                                    Decode.succeed { message = msg, preventDefault = False, stopPropagation = False }

                                Nothing ->
                                    Decode.fail "unhandled key"
                )
        )


{-| Keys on a closed trigger: the bindings, plus (optionally) any printable
character, which opens the list and starts the search with that character.
-}
onTriggerKeys : List ( String, msg ) -> Maybe (String -> msg) -> Html.Attribute msg
onTriggerKeys bindings typed =
    Events.custom "keydown"
        (press
            |> Decode.andThen
                (\pressed ->
                    let
                        event =
                            pressed.event
                    in
                    case lookup (pressName pressed) bindings of
                        Just msg ->
                            Decode.succeed { message = msg, preventDefault = True, stopPropagation = True }

                        Nothing ->
                            case typed of
                                Just toMsg ->
                                    if String.length event.key == 1 && event.key /= " " && not event.ctrl && not event.meta && not event.alt then
                                        Decode.succeed { message = toMsg event.key, preventDefault = True, stopPropagation = True }

                                    else
                                        Decode.fail "unhandled key"

                                Nothing ->
                                    Decode.fail "unhandled key"
                )
        )


{-| Keys on the trigger of a list that has just opened, before focus has
reached its search box (Elm moves it a frame later). What is typed in that
moment still belongs to the search, so it is not lost: characters (a space
too) and Backspace edit the text, the arrow, Home, End and Page keys and Enter
act on the list, Escape closes it, and Tab goes on.
-}
onWindowKeys :
    { typed : String -> msg
    , backspace : msg
    , move : Move -> msg
    , close : msg
    , leave : msg
    }
    -> Html.Attribute msg
onWindowKeys bindings =
    Events.custom "keydown"
        (press
            |> Decode.andThen
                (\pressed ->
                    let
                        event =
                            pressed.event

                        repeated =
                            pressed.repeatedBackspace

                        handled msg =
                            Decode.succeed { message = msg, preventDefault = True, stopPropagation = True }
                    in
                    if event.ctrl || event.meta || event.alt then
                        Decode.fail "modifier"

                    else
                        case event.key of
                            "Tab" ->
                                Decode.succeed { message = bindings.leave, preventDefault = False, stopPropagation = False }

                            "Escape" ->
                                handled bindings.close

                            "Enter" ->
                                handled (bindings.move MoveChoose)

                            "ArrowDown" ->
                                handled (bindings.move MoveNext)

                            "ArrowUp" ->
                                handled (bindings.move MovePrevious)

                            "PageDown" ->
                                handled (bindings.move MovePageDown)

                            "PageUp" ->
                                handled (bindings.move MovePageUp)

                            "Home" ->
                                handled (bindings.move MoveFirst)

                            "End" ->
                                handled (bindings.move MoveLast)

                            "Backspace" ->
                                -- a held key is the search box's business, not this
                                -- one-frame window's
                                if repeated then
                                    Decode.fail "repeat"

                                else
                                    handled bindings.backspace

                            _ ->
                                if String.length event.key == 1 then
                                    handled (bindings.typed event.key)

                                else
                                    Decode.fail "unhandled key"
                )
        )



-- VIEW: ROWS


type Indicator
    = CheckMark
    | CheckBox
    | NoIndicator


type alias RowConfig id msg =
    { idBase : String
    , query : String
    , highlighted : Maybe Int
    , setSize : Int
    , indicator : Indicator
    , isSelected : Option id -> Bool
    , isBlocked : Option id -> Bool
    , selectedFollowsHighlight : Bool
    , onPick : Option id -> msg
    , onCreate : String -> msg
    , onHover : Int -> msg
    , noop : msg
    , texts : Texts
    }


viewRow : RowConfig id msg -> Int -> Row id -> Html msg
viewRow config index row =
    case row of
        Heading name ->
            viewHeading name

        Item ordinal opt ->
            viewItem config index ordinal opt

        Create ordinal text ->
            viewCreate config index ordinal text


{-| The pinned copy of a heading row (see `VirtualList.viewGrouped`).
-}
viewPinned : Row id -> Maybe (Html msg)
viewPinned row =
    case row of
        Heading name ->
            Just (viewHeading name)

        _ ->
            Nothing


viewHeading : String -> Html msg
viewHeading name =
    Html.div [ Internal.cls [ "klar-select__group" ], Attr.attribute "role" "presentation", Attr.title name ]
        [ Html.span [ Internal.cls [ "klar-select__group-label" ] ] [ Html.text name ] ]


hoverHandler : RowConfig id msg -> Int -> Html.Attribute msg
hoverHandler config index =
    Events.on "mousemove"
        (if config.highlighted == Just index then
            Decode.fail "already highlighted"

         else
            Decode.succeed (config.onHover index)
        )


viewItem : RowConfig id msg -> Int -> Int -> Option id -> Html msg
viewItem config index ordinal opt =
    let
        isHighlighted =
            config.highlighted == Just index

        isSelected =
            config.isSelected opt

        blocked =
            not isSelected && config.isBlocked opt

        inactive =
            opt.disabled || blocked

        ariaSelected =
            if config.selectedFollowsHighlight then
                isHighlighted

            else
                isSelected

        tooltip =
            case opt.description of
                Just description ->
                    opt.label ++ " – " ++ description

                Nothing ->
                    opt.label

        -- the description is highlighted only when it is why the option matched
        descriptionQuery =
            if opt.description == Nothing || Match.labelMatches (Match.prepare config.query) opt then
                ""

            else
                config.query
    in
    Html.div
        [ Internal.cls
            [ "klar-select__option"
            , if isHighlighted then
                "klar-select__option--highlighted"

              else
                ""
            , if isSelected then
                "klar-select__option--selected"

              else
                ""
            , if inactive then
                "klar-select__option--disabled"

              else
                ""
            ]
        , Attr.id (optionId config.idBase index)
        , Attr.attribute "role" "option"
        , Attr.attribute "aria-selected"
            (if ariaSelected then
                "true"

             else
                "false"
            )
        , Internal.attrIf inactive (Attr.attribute "aria-disabled" "true")
        , Attr.attribute "aria-posinset" (String.fromInt ordinal)
        , Attr.attribute "aria-setsize" (String.fromInt config.setSize)
        , Attr.title tooltip
        , Internal.onMouseDownPrevent config.noop

        -- a row that cannot be chosen cannot be highlighted either (the
        -- highlight would land on the row above it)
        , if inactive then
            Internal.noAttr

          else
            hoverHandler config index
        , if inactive then
            Internal.onClickPrevent config.noop

          else
            Internal.onClickPrevent (config.onPick opt)
        ]
        [ viewIndicator config.indicator isSelected inactive
        , Internal.markDot opt.tone opt.color
        , Internal.viewMaybe (\icon -> Html.span [ Internal.cls [ "klar-select__option-icon" ] ] [ Icon.view icon ]) opt.icon
        , Html.span [ Internal.cls [ "klar-select__option-label" ] ] (Search.highlight config.query opt.label)
        , Internal.viewMaybe
            (\description ->
                Html.span [ Internal.cls [ "klar-select__option-description" ] ] (Search.highlight descriptionQuery description)
            )
            opt.description
        , Internal.viewMaybe
            (\meta -> Html.span [ Internal.cls [ "klar-select__option-meta", "klar-tabular" ] ] [ Html.text meta ])
            opt.meta

        -- The heading rows are not part of the listbox (a virtual list cannot
        -- wrap its options in a role="group"), so each option says its group.
        , Internal.viewMaybe (\group -> Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (", " ++ group) ]) opt.group
        ]


viewIndicator : Indicator -> Bool -> Bool -> Html msg
viewIndicator indicator isSelected inactive =
    case indicator of
        CheckMark ->
            Html.span [ Internal.cls [ "klar-select__check" ] ]
                [ Internal.viewIf isSelected (Icon.view Icon.check) ]

        CheckBox ->
            Html.span [ Internal.cls [ "klar-select__checkbox" ], Attr.attribute "aria-hidden" "true" ]
                [ Checkbox.view [ Checkbox.checked isSelected, Checkbox.disabled inactive ] ]

        NoIndicator ->
            Html.text ""


viewCreate : RowConfig id msg -> Int -> Int -> String -> Html msg
viewCreate config index ordinal text =
    let
        isHighlighted =
            config.highlighted == Just index
    in
    Html.div
        [ Internal.cls
            [ "klar-select__option"
            , "klar-select__option--create"
            , if isHighlighted then
                "klar-select__option--highlighted"

              else
                ""
            ]
        , Attr.id (optionId config.idBase index)
        , Attr.attribute "role" "option"
        , Attr.attribute "aria-selected"
            (if config.selectedFollowsHighlight && isHighlighted then
                "true"

             else
                "false"
            )
        , Attr.attribute "aria-posinset" (String.fromInt ordinal)
        , Attr.attribute "aria-setsize" (String.fromInt config.setSize)
        , Attr.title (config.texts.create text)
        , Internal.onMouseDownPrevent config.noop
        , hoverHandler config index
        , Internal.onClickPrevent (config.onCreate text)
        ]
        [ Html.span [ Internal.cls [ "klar-select__check", "klar-select__create-icon" ] ] [ Icon.view Icon.plus ]
        , Html.span [ Internal.cls [ "klar-select__option-label" ] ] [ Html.text (config.texts.create text) ]
        ]



-- VIEW: PARTS


{-| Placeholder rows while the options load.
-}
viewSkeleton : Int -> Html msg
viewSkeleton count =
    Html.div [ Internal.cls [ "klar-select__skeleton" ], Attr.attribute "aria-hidden" "true" ]
        (List.range 0 (max 1 count - 1)
            |> List.map
                (\i ->
                    Html.div [ Internal.cls [ "klar-select__skeleton-row" ] ]
                        [ Skeleton.line (Maybe.withDefault 60 (List.head (List.drop (modBy 5 i) [ 72, 48, 84, 60, 40 ]))) ]
                )
        )


viewEmpty : Icon -> String -> Maybe String -> Html msg
viewEmpty icon title description =
    Html.div [ Internal.cls [ "klar-select__state" ] ]
        [ EmptyState.view
            (List.filterMap identity
                [ Just EmptyState.compact
                , Just (EmptyState.icon icon)
                , Just (EmptyState.title title)
                , Maybe.map EmptyState.description description
                ]
            )
        ]


{-| The message that retries a failed load, when a "Try again" button is on
screen: the load failed with a problem that is worth retrying
(`Remote.isRetryable`) and the application said what retrying means (`onRetry`).
Everything that depends on the button asks this once, and only a `Just` allows
it: Enter may retry, and Tab may go on to the button. For a problem that is not
worth retrying (no access, not found ...) there is no button, so nothing is
retried and Tab simply leaves.
-}
retryFor : Remote.Problem -> Maybe msg -> Maybe msg
retryFor problem onRetry =
    if Remote.isRetryable problem then
        onRetry

    else
        Nothing


{-| Options that failed to load: a compact `ErrorState`, with "try again" when
there is something to retry (see `retryFor`). A mouse click on it does not take
focus from the search box, and any click (also Enter on the focused button)
sends `refocus`, so focus goes back to the search box when the button is
replaced by loading rows. Tab on the button sends `leave`; without a button
there is nothing to hold focus here, so Tab is not handled.

With `focusable = False` the button is for the mouse only (`tabindex="-1"`):
for a popup whose focus never leaves the field it belongs to, where Enter in the
field retries and Tab leaves the field.

-}
viewFailure :
    { locale : Locale
    , onRetry : Maybe msg
    , focusable : Bool
    , refocus : msg
    , leave : msg
    , noop : msg
    }
    -> Remote.Problem
    -> Html msg
viewFailure config problem =
    let
        retry =
            retryFor problem config.onRetry
    in
    Html.div
        [ Internal.cls [ "klar-select__state" ]
        , Internal.onMouseDownPrevent config.noop
        , Events.onClick config.refocus
        , Internal.attrIf (config.focusable && isJust retry) (onKeydown { handled = [], passive = [ ( "Tab", config.leave ) ] })
        ]
        (if config.focusable then
            [ ErrorState.view
                (List.filterMap identity
                    [ Just ErrorState.compact
                    , Just (ErrorState.locale config.locale)
                    , Maybe.map ErrorState.onRetry retry
                    ]
                )
                problem
            ]

         else
            [ ErrorState.view [ ErrorState.compact, ErrorState.locale config.locale ] problem
            , Internal.viewMaybe
                (\msg ->
                    Html.div [ Internal.cls [ "klar-select__retry" ] ]
                        [ Button.view
                            [ Button.small
                            , Button.icon Icon.refresh
                            , Button.onClick msg
                            , Button.htmlAttrs [ Attr.tabindex -1 ]
                            ]
                            (Locale.pick config.locale { en = "Try again", nb = "Prøv igjen" })
                        ]
                )
                retry
            ]
        )


{-| The message that retries the last refresh, when the "Old data" notice above
the list shows its "Try again" button: the refresh failed with a problem worth
retrying, and there is an `onRetry`. Like `retryFor`, everything that depends on
the button asks this.
-}
noticeRetry : Freshness -> Maybe msg -> Maybe msg
noticeRetry freshness onRetry =
    case freshness of
        Freshness.Stale value ->
            retryFor value.problem onRetry

        _ ->
            Nothing


{-| The "Old data from 14:05" notice above the list of an open popup (nothing
for fresh data). Its "Try again" button is the one element of the popup besides
the search box that Tab reaches, so: a click on it (also Enter on the focused
button) sends `refocus`, and focus goes back to the search box before the button
turns into a spinner or goes away; and Tab on the button sends `leave` when
nothing after it in the popup takes focus, so the popup closes behind the focus
that moves on, instead of taking the focus with it.
-}
viewNotice :
    { locale : Locale
    , settings : Settings
    , onRetry : Maybe msg
    , refocus : msg
    , leave : Maybe msg
    }
    -> Freshness
    -> Html msg
viewNotice config freshness =
    let
        retry =
            noticeRetry freshness config.onRetry
    in
    Html.div
        [ Internal.cls [ "klar-select__notice" ]
        , Internal.attrIf (isJust retry) (Events.onClick config.refocus)
        , case ( retry, config.leave ) of
            ( Just _, Just leave ) ->
                onKeydown { handled = [], passive = [ ( "Tab", leave ) ] }

            _ ->
                Internal.noAttr
        ]
        [ Freshness.notice
            { locale = config.locale, settings = config.settings, onRetry = config.onRetry, inline = False }
            freshness
        ]


{-| A single muted line inside a popup ("No suggestions"), announced politely.
-}
viewMessage : String -> Html msg
viewMessage text =
    Html.div
        [ Internal.cls [ "klar-select__message" ]
        , Attr.attribute "role" "status"
        , Attr.attribute "aria-live" "polite"
        ]
        [ Html.text text ]


{-| The status line under the list: counts on the left (announced politely to
screen readers), optional actions on the right.
-}
viewFooter : String -> List (Html msg) -> Html msg
viewFooter status actions =
    Html.div [ Internal.cls [ "klar-select__footer" ] ]
        [ Html.span
            [ Internal.cls [ "klar-select__status", "klar-tabular", "klar-truncate" ]
            , Attr.attribute "role" "status"
            , Attr.attribute "aria-live" "polite"
            ]
            [ Html.text status ]
        , if List.isEmpty actions then
            Html.text ""

          else
            Html.div [ Internal.cls [ "klar-select__actions" ] ] actions
        ]


{-| The search box at the top of the popup.
-}
viewSearch :
    { id : String
    , listboxId : Maybe String
    , query : String
    , placeholder : String
    , label : String
    , activeDescendant : Maybe String
    , onInput : String -> msg
    , onFocus : msg
    , keys : Html.Attribute msg
    , loading : Bool
    , loadingLabel : String
    , clearLabel : String
    , noop : msg
    }
    -> Html msg
viewSearch config =
    Html.div [ Internal.cls [ "klar-select__search" ] ]
        [ Html.span [ Internal.cls [ "klar-select__search-icon" ] ] [ Icon.view Icon.search ]
        , Html.input
            [ Internal.cls [ "klar-select__search-input" ]
            , Attr.id config.id
            , Attr.type_ "text"
            , Attr.value config.query
            , Attr.placeholder config.placeholder
            , Attr.attribute "role" "combobox"
            , Attr.attribute "aria-expanded" "true"
            , Internal.attrMaybe (Attr.attribute "aria-controls") config.listboxId
            , Attr.attribute "aria-autocomplete" "list"
            , Attr.attribute "aria-label" config.label
            , Internal.attrMaybe (Attr.attribute "aria-activedescendant") config.activeDescendant
            , Attr.attribute "autocomplete" "off"
            , Attr.spellcheck False
            , Events.onInput config.onInput
            , Events.onFocus config.onFocus
            , config.keys
            ]
            []
        , -- Always in the page, so that its live region is there before the
          -- text "Loading" is (an idle slot is out of sight and takes no room).
          Html.span
            [ Internal.cls
                [ if config.loading then
                    "klar-select__search-spinner"

                  else
                    "klar-sr-only"
                ]
            ]
            [ Spinner.view [ Spinner.label config.loadingLabel, Spinner.loading config.loading ] ]
        , if config.loading then
            Html.text ""

          else if config.query /= "" then
            Html.button
                [ Internal.cls [ "klar-input__clear" ]
                , Attr.type_ "button"
                , Attr.tabindex -1
                , Attr.attribute "aria-label" config.clearLabel
                , Attr.title config.clearLabel
                , Internal.onMouseDownPrevent config.noop
                , Events.onClick (config.onInput "")
                ]
                [ Icon.view Icon.close ]

          else
            Html.text ""
        ]


viewChevron : Html msg
viewChevron =
    Html.span [ Internal.cls [ "klar-select__chevron" ], Attr.attribute "aria-hidden" "true" ] [ Icon.view Icon.chevronDown ]


{-| The small × inside a trigger. Its click does not reach the trigger.
-}
viewClearButton : String -> msg -> Html msg
viewClearButton label msg =
    Html.button
        [ Internal.cls [ "klar-input__clear", "klar-select__clear" ]
        , Attr.type_ "button"
        , Attr.tabindex -1
        , Attr.attribute "aria-label" label
        , Attr.title label
        , Internal.onClickStop msg
        ]
        [ Icon.view Icon.close ]


{-| A mouse press anywhere in the popup except on its search box keeps keyboard
focus in the search box. Without it, pressing on the footer, an empty state or
the gap between rows moved focus to the page: Escape and the arrow keys then
did nothing until the user clicked the field again.
-}
holdSearchFocus : msg -> Html.Attribute msg
holdSearchFocus msg =
    Events.preventDefaultOn "mousedown"
        (Decode.at [ "target", "tagName" ] Decode.string
            |> Decode.andThen
                (\tag ->
                    if tag == "INPUT" then
                        Decode.fail "the search box takes the press itself"

                    else
                        Decode.succeed ( msg, True )
                )
        )


{-| The transparent click-away layer around a popup. A click outside the popup
lands here (`close`); Escape anywhere inside sends `close` too and does not
reach a surrounding dialog.
-}
viewLayer : msg -> Html msg -> Html msg
viewLayer close popup =
    Html.div
        [ Internal.cls [ "klar-layer" ]
        , Events.onClick close
        , onKeydown { handled = [ ( "Escape", close ) ], passive = [] }
        ]
        [ popup ]
