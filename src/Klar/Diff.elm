module Klar.Diff exposing
    ( view, viewStatic
    , Diff, lines, json, fields
    , TextOption, ignoreWhitespace, ignoreCase
    , JsonOption, matchBy
    , isEmpty, tooLarge, stats
    , Hunk, hunks, hunkKey, hunkBefore, hunkAfter
    , State, init, Msg, update, setSplit, isSplit, currentHunk, goToHunk
    , Attribute, ariaLabel, context, maxChanges, maxHeight, wrapLines, showUnchangedFields, locale
    )

{-| What changed between two versions of a text, of a JSON document or of a
record, shown so that a person can see it and decide.

Use when: a person must see what changed between two versions of a text, a JSON value or a record, such as in a review or an audit log.
Do not use when: several records are shown side by side, use `Klar.Compare`, or when there is only one JSON value, use `Klar.JsonViewer`.
Quick path: `lines`, `init`, `update`, `view`

    import Klar.Diff as Diff

    -- in your model
    { policyDiff : Diff.Diff
    , policyView : Diff.State -- Diff.init "policy-diff"
    }

    -- when the two versions are known (in `update`, not in `view`)
    { model | policyDiff = Diff.lines [ Diff.ignoreWhitespace ] oldText newText }

    -- in update
    PolicyDiffMsg diffMsg ->
        let
            ( state, cmd ) =
                Diff.update diffMsg model.policyView
        in
        ( { model | policyView = state }, Cmd.map PolicyDiffMsg cmd )

    -- in view
    Diff.view PolicyDiffMsg
        [ Diff.ariaLabel "Changes to the shipping policy" ]
        model.policyView
        model.policyDiff

There are three ways to make a [`Diff`](#Diff), and one way to show all of them.
`lines` compares two texts line by line (unified or side by side, with the
changed words marked inside a changed line), `json` compares two JSON values by
path (`items[2].price` changed from 12.5 to 14), and `fields` lists the fields of
a record that changed, with the text of each side, which is what an audit log needs.
Build the diff when the versions change and keep it in your model: comparing two
long texts is work, and showing a diff is not.

Use [Klar.Compare](Klar-Compare) when several records are shown side by side
and you want to see where they differ, and [Klar.JsonViewer](Klar-JsonViewer)
when there is only one JSON value.


# Showing a diff

@docs view, viewStatic


# Making a diff

@docs Diff, lines, json, fields


## Options of a text diff

@docs TextOption, ignoreWhitespace, ignoreCase


## Options of a JSON diff

@docs JsonOption, matchBy


# Reading a diff

@docs isEmpty, tooLarge, stats


## Changes one by one

@docs Hunk, hunks, hunkKey, hunkBefore, hunkAfter


# State

@docs State, init, Msg, update, setSplit, isSplit, currentHunk, goToHunk


# Attributes

@docs Attribute, ariaLabel, context, maxChanges, maxHeight, wrapLines, showUnchangedFields, locale

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode exposing (Value)
import Klar.Alert as Alert
import Klar.Button as Button
import Klar.DescriptionList as DescriptionList
import Klar.Diff.Inline as Inline
import Klar.Diff.Json as DiffJson
import Klar.Diff.Keys as Keys
import Klar.Diff.Lines as Lines
import Klar.Diff.Types exposing (Entry, Kind(..), Part, Shown(..))
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme exposing (Tone(..))



-- THE DIFF


{-| The difference between two versions of something: a text, a JSON value or a
record. The type is opaque; make one with `lines`, `json` or `fields`, show it with
`view`, and ask it questions with `isEmpty`, `stats` and `hunks`. It holds the
result of the comparison and nothing else, so it can be kept in your model and
compared with `==`.
-}
type Diff
    = Diff
        { content : Content
        , notes : Notes
        }


type Content
    = LinesContent Lines.Compared
    | SummaryContent Lines.Summary
    | EntriesContent Source (List Entry)


type Source
    = FromJson
    | FromFields


{-| What the viewer tells about how the comparison was made.
-}
type alias Notes =
    { ignoreWhitespace : Bool
    , ignoreCase : Bool
    , lineEndsDiffer : Bool
    }


{-| A setting of a text diff. Make one with `ignoreWhitespace` or `ignoreCase`
and pass a list to `lines`.
-}
type TextOption
    = TextOption (TextSettings -> TextSettings)


type alias TextSettings =
    { ignoreWhitespace : Bool
    , ignoreCase : Bool
    }


{-| Ignores differences in white space: indentation, trailing spaces, and a
space that became a tab or two spaces. Two lines that differ only in that are the
same line. Words that run together (`"a b"` and `"ab"`) are still different.
The viewer says that white space is ignored, so nobody mistakes the result for a
full comparison.
-}
ignoreWhitespace : TextOption
ignoreWhitespace =
    TextOption (\settings -> { settings | ignoreWhitespace = True })


{-| Ignores the difference between upper and lower case: `"Paid"` and `"PAID"`
are the same line. The viewer says that case is ignored.
-}
ignoreCase : TextOption
ignoreCase =
    TextOption (\settings -> { settings | ignoreCase = True })


{-| Compares two texts line by line, with the shortest set of changes.

    Diff.lines [] "Free shipping over $50\n" "Free shipping over $75\n"

`\r\n`, `\n` and `\r` all end a line, so a file with Windows line endings
compared with the same file with Unix line endings has no changes (the viewer
mentions that the line endings differ). A last line without a line end is told
apart from one with: adding the final newline of a file is a change, as `git`
sees it. An empty text has no lines.

Inside a changed line, the changed words are marked (a changed number is marked
digit by digit, and a letter is never cut from its accent).

**The work is limited**, so that a diff never freezes the page. The beginning and the
end that are the same in both texts are cut off first (two equal texts cost no more
than reading them). Finding the shortest set of changes in what is left may take
about a third of a second; when the two texts are so different that it would take
more (roughly more than two thousand changed lines, unless they are one block that
only one of the texts has), the diff becomes a summary (`tooLarge` is `True`): the
number of lines of each text, how many lines are the same at the start and at the
end, and how many lines of each text do not occur in the other. It says so. Marking
the changed words inside the changed lines has a budget of its own, about a third of
a second for the whole diff, and is left out for a block of more than a thousand
changed lines: the lines that come after the budget is spent are marked as whole
lines. All in all, beyond the time it takes to read the two texts, `lines` takes no
more than about two thirds of a second, whatever the texts are.

-}
lines : List TextOption -> String -> String -> Diff
lines options old new =
    let
        settings =
            List.foldl (\(TextOption change) current -> change current)
                { ignoreWhitespace = False, ignoreCase = False }
                options

        result =
            Lines.diff
                { ignoreWhitespace = settings.ignoreWhitespace
                , ignoreCase = settings.ignoreCase
                , maxWork = Lines.defaultMaxWork
                }
                old
                new
    in
    Diff
        { content =
            case result.outcome of
                Lines.Done compared ->
                    LinesContent compared

                Lines.TooLarge summary ->
                    SummaryContent summary
        , notes =
            { ignoreWhitespace = settings.ignoreWhitespace
            , ignoreCase = settings.ignoreCase
            , lineEndsDiffer = result.lineEndsDiffer
            }
        }


{-| A setting of a JSON diff. Make one with `matchBy` and pass a list to `json`.
-}
type JsonOption
    = JsonOption (JsonSettings -> JsonSettings)


type alias JsonSettings =
    { matchBy : Maybe String
    }


{-| Compares arrays of objects record by record instead of position by position:
the records of the two arrays that have the same value in this field (an `"id"`, a
`"sku"`) are compared with each other, wherever they stand, and the path says which
one (`lines[sku=A-100].qty`). Records that moved are not a change.

The field must hold a text or a number in every record of both arrays and be
different in every record of one array. For an array where that is not so, the
records are compared by position, as without this option.

-}
matchBy : String -> JsonOption
matchBy field =
    JsonOption (\settings -> { settings | matchBy = Just field })


{-| Compares two JSON values by path. Objects are compared key by key, arrays
position by position, and the answer lists every value that was added, removed
or changed, with a readable path such as `items[2].price`. The list is in a fixed
order (the keys of an object in alphabetical order), numbers are compared exactly
and strings character by character, and a string that changed shows what changed
inside it.

    Diff.json [ Diff.matchBy "sku" ] oldOrder newOrder

An added or removed object or array is one change, with its content in a line of
JSON (cut after about 400 characters, and it says so). Arrays are compared by
position unless `matchBy` says how to find the same record in both: an item that is
added at the start of an array shifts all the others. A value that is not JSON or is
nested more than 64 levels deep is always reported as changed, with a note that it
could not be compared.

-}
json : List JsonOption -> Value -> Value -> Diff
json options old new =
    let
        settings =
            List.foldl (\(JsonOption change) current -> change current) { matchBy = Nothing } options
    in
    Diff
        { content = EntriesContent FromJson (DiffJson.diff { matchBy = settings.matchBy } old new)
        , notes = { ignoreWhitespace = False, ignoreCase = False, lineEndsDiffer = False }
        }


{-| The fields of a record, with the text of each side, as they were and as they
are. A side that has no value is `Nothing` (a field that was added has no `before`,
one that was removed has no `after`); an empty text is a value.

    Diff.fields
        [ { label = "Status", before = Just "Open", after = Just "Shipped" }
        , { label = "Carrier", before = Nothing, after = Just "Nordic Freight" }
        , { label = "Customer", before = Just "Northwind", after = Just "Northwind" }
        ]

You choose the text of each side, so dates, amounts and names are written the way
your users read them. Fields that did not change stay in the diff and are hidden
by the viewer unless it is given `showUnchangedFields`. Fields that have no value
on either side are left out. The text is compared exactly, and a text that changed
shows what changed inside it.

-}
fields : List { label : String, before : Maybe String, after : Maybe String } -> Diff
fields records =
    let
        present =
            List.filter (\record -> record.before /= Nothing || record.after /= Nothing) records

        -- the same label twice is a mistake that can happen: both are shown, with different keys
        keys =
            Keys.unique (\key number -> key ++ " (" ++ String.fromInt number ++ ")") (List.map .label present)

        step ( key, record ) ( entries, budget ) =
            let
                ( entry, spent ) =
                    fieldEntry budget key record
            in
            ( entry :: entries, budget - spent )

        ( found, _ ) =
            List.foldl step ( [], Inline.sharedBudget ) (List.map2 Tuple.pair keys present)
    in
    Diff
        { content = EntriesContent FromFields (List.reverse found)
        , notes = { ignoreWhitespace = False, ignoreCase = False, lineEndsDiffer = False }
        }


{-| An entry of a field and the work that marking what changed inside the text took,
out of the budget that is left for all the fields of the diff.
-}
fieldEntry : Int -> String -> { label : String, before : Maybe String, after : Maybe String } -> ( Entry, Int )
fieldEntry budget key record =
    let
        plain text =
            Text { parts = [ { text = text, changed = False } ], truncated = False }
    in
    case ( record.before, record.after ) of
        ( Just before, Just after ) ->
            if before == after then
                ( { key = key, label = record.label, kind = Unchanged, before = Just (plain before), after = Just (plain after) }, 0 )

            else if String.length before > 2000 || String.length after > 2000 then
                ( { key = key, label = record.label, kind = Changed, before = Just (plain before), after = Just (plain after) }, 0 )

            else
                let
                    ( segments, spent ) =
                        Inline.diffWithin budget before after
                in
                ( { key = key
                  , label = record.label
                  , kind = Changed
                  , before = Just (Text { parts = sideParts (\removed _ -> removed) segments, truncated = False })
                  , after = Just (Text { parts = sideParts (\_ added -> added) segments, truncated = False })
                  }
                , spent
                )

        ( Just before, Nothing ) ->
            ( { key = key, label = record.label, kind = Removed, before = Just (plain before), after = Nothing }, 0 )

        ( Nothing, Just after ) ->
            ( { key = key, label = record.label, kind = Added, before = Nothing, after = Just (plain after) }, 0 )

        ( Nothing, Nothing ) ->
            ( { key = key, label = record.label, kind = Unchanged, before = Nothing, after = Nothing }, 0 )


{-| The parts of one side of an inline comparison. Text with nothing in common is
one unchanged part: the entry says that it changed.
-}
sideParts : (String -> String -> String) -> List Inline.Segment -> List Part
sideParts pick segments =
    case segments of
        [ Inline.Replace removed added ] ->
            [ { text = pick removed added, changed = False } ]

        _ ->
            segments
                |> List.map
                    (\segment ->
                        case segment of
                            Inline.Keep text ->
                                { text = text, changed = False }

                            Inline.Replace removed added ->
                                { text = pick removed added, changed = True }
                    )
                |> List.filter (\part -> part.text /= "")



-- READING A DIFF


{-| Are the two versions the same? A diff of two equal texts, of two equal JSON
values or of fields that all kept their value is empty, and the viewer says "No
changes". A diff that became a summary because it is too large is not empty.
-}
isEmpty : Diff -> Bool
isEmpty (Diff diff) =
    case diff.content of
        LinesContent compared ->
            not (List.any isChange compared.segments)

        SummaryContent _ ->
            False

        EntriesContent _ entries ->
            not (List.any (\entry -> entry.kind /= Unchanged) entries)


isChange : Lines.Segment -> Bool
isChange segment =
    case segment of
        Lines.Changed _ ->
            True

        Lines.Equal _ ->
            False


{-| Did the comparison give up? A text diff that would take too long becomes a
summary of the two texts (see `lines`); it has no changes to show, `hunks` is
empty, and the viewer says that it is too large. Offer the two texts for download,
or compare smaller parts.
-}
tooLarge : Diff -> Bool
tooLarge (Diff diff) =
    case diff.content of
        SummaryContent _ ->
            True

        _ ->
            False


{-| How much changed, for a summary such as "+12 -4 ~3". `added` counts lines (or
values, or fields) that only the new version has, `removed` those that only the old
one has, and `changed` those that exist in both and differ: in a text, a removed
line that was replaced by an added line is one changed line. Taken together they
count every change once.

For a diff that became a summary (see `tooLarge`) the counts are those of the
summary: lines that occur in only one of the texts, wherever they stand, and no
changed lines.

-}
stats : Diff -> { added : Int, removed : Int, changed : Int }
stats (Diff diff) =
    case diff.content of
        LinesContent compared ->
            List.foldl
                (\segment total ->
                    case segment of
                        Lines.Changed hunk ->
                            let
                                removed =
                                    List.length hunk.removed

                                added =
                                    List.length hunk.added

                                paired =
                                    min removed added
                            in
                            { added = total.added + added - paired
                            , removed = total.removed + removed - paired
                            , changed = total.changed + paired
                            }

                        Lines.Equal _ ->
                            total
                )
                { added = 0, removed = 0, changed = 0 }
                compared.segments

        SummaryContent summary ->
            { added = summary.onlyInNew, removed = summary.onlyInOld, changed = 0 }

        EntriesContent _ entries ->
            List.foldl
                (\entry total ->
                    case entry.kind of
                        Added ->
                            { total | added = total.added + 1 }

                        Removed ->
                            { total | removed = total.removed + 1 }

                        Changed ->
                            { total | changed = total.changed + 1 }

                        Unchanged ->
                            total
                )
                { added = 0, removed = 0, changed = 0 }
                entries


{-| One change of a diff: a group of lines that were removed and added together,
a JSON value that was added, removed or changed, or a field that changed. Get them
with `hunks`. The type is opaque, so that more can be asked of a hunk in a later
version, and a hunk can be compared with `==`.
-}
type Hunk
    = LineHunk Lines.Hunk
    | EntryHunk Entry


{-| The changes of a diff, in the order they are shown. A diff that is empty or
became a summary has none. Fields that did not change are not changes.
-}
hunks : Diff -> List Hunk
hunks (Diff diff) =
    case diff.content of
        LinesContent compared ->
            List.filterMap
                (\segment ->
                    case segment of
                        Lines.Changed hunk ->
                            Just (LineHunk hunk)

                        Lines.Equal _ ->
                            Nothing
                )
                compared.segments

        SummaryContent _ ->
            []

        EntriesContent _ entries ->
            entries
                |> List.filter (\entry -> entry.kind /= Unchanged)
                |> List.map EntryHunk


{-| A key for the hunk that is the same every time the same two versions are
compared with the same options, and different for every hunk of a diff: use it to
remember a decision about the hunk (accepted, rejected) in a `Dict` or a `Set`. For
a text it says where the hunk is (`"12:3/14:2"`: three lines from line 12 of the old
text became two lines from line 14 of the new text), for JSON it is the path, for
fields the label. A path or a label that comes twice gets `~2` or `(2)` after it, so
that the keys of a diff are always different. It is meant for programs, not for people, and it changes when
the texts change, so a decision about a hunk stays valid only for the diff it was
made for.
-}
hunkKey : Hunk -> String
hunkKey hunk =
    case hunk of
        LineHunk lineHunk ->
            Lines.hunkKey lineHunk

        EntryHunk entry ->
            entry.key


{-| The text of the hunk in the old version, or `Nothing` when the old version has
nothing there (lines or a value that were added). The lines of a text are joined
with `\n`, a JSON value is written as one line of JSON, and a field has the text you
gave. A text that was cut for the viewer (a long JSON value) is cut here too.
-}
hunkBefore : Hunk -> Maybe String
hunkBefore hunk =
    case hunk of
        LineHunk lineHunk ->
            linesText lineHunk.removed

        EntryHunk entry ->
            entry.before |> Maybe.andThen Klar.Diff.Types.shownText


{-| The text of the hunk in the new version, or `Nothing` when the new version has
nothing there (lines or a value that were removed). Written like `hunkBefore`.
-}
hunkAfter : Hunk -> Maybe String
hunkAfter hunk =
    case hunk of
        LineHunk lineHunk ->
            linesText lineHunk.added

        EntryHunk entry ->
            entry.after |> Maybe.andThen Klar.Diff.Types.shownText


linesText : List Lines.ChangedLine -> Maybe String
linesText changed =
    if List.isEmpty changed then
        Nothing

    else
        Just (String.join "\n" (List.map .text changed))



-- STATE


{-| What the viewer remembers: whether the side-by-side layout is chosen, which
runs of unchanged lines the user opened, how many changes are shown and which
change the user went to last. Make one with `init`, keep it in your model and give
it to `view` and `update`. It holds no functions and no diff, so a new diff can be
shown with the same state (the opened runs are remembered by where they start).
-}
type State
    = State
        { id : String
        , split : Bool
        , current : Maybe Int
        , folds : Dict String Int
        , shown : Int
        }


{-| A state with the unified layout, no run of unchanged lines opened and the first
changes shown. The `String` is the DOM id of the viewer and the prefix of the ids
of the elements inside it, so it must be unique on the page.

    Diff.init "policy-diff"

-}
init : String -> State
init id =
    State { id = id, split = False, current = Nothing, folds = Dict.empty, shown = 0 }


{-| Chooses the layout of a text diff: `True` shows the old and the new text side
by side (split), `False` one below the other (unified, the default). The user can
also choose it with the buttons in the toolbar. Other diffs have one layout.
-}
setSplit : Bool -> State -> State
setSplit value (State state) =
    State { state | split = value }


{-| Is the side-by-side layout chosen? Read it to remember the choice of the user.
-}
isSplit : State -> Bool
isSplit (State state) =
    state.split


{-| The change the user went to last (with `n` and `p`, or the buttons "Next" and
"Previous"), in this diff, or `Nothing` before the first step. Use it to show a panel
for the change the user is on, such as "Accept" and "Reject" for that hunk, with
`hunkKey` to remember the decision.

    Diff.currentHunk model.policyDiff model.policyView
        |> Maybe.map Diff.hunkKey

-}
currentHunk : Diff -> State -> Maybe Hunk
currentHunk diff (State state) =
    state.current
        |> Maybe.andThen (\index -> List.head (List.drop index (hunks diff)))


{-| Goes to the change with this `hunkKey`, as if the user had stepped to it: it
becomes the current change, it is drawn even when it is after the first changes that
are shown, and the command moves the keyboard focus to it (map it with `Cmd.map`).
A key that is not in this diff changes nothing. Use it for a list of the changes next
to the viewer, or to go back to the change the user decided on last.

    ( state, cmd ) =
        Diff.goToHunk model.policyDiff key model.policyView

-}
goToHunk : Diff -> String -> State -> ( State, Cmd Msg )
goToHunk diff key state =
    case
        hunks diff
            |> List.indexedMap Tuple.pair
            |> List.filter (\( _, hunk ) -> hunkKey hunk == key)
            |> List.head
    of
        Just ( index, _ ) ->
            update (Go index) state

        Nothing ->
            ( state, Cmd.none )


{-| The messages of the viewer. Wrap them in a message of your own, give them to
`update` and use the same wrapper in `view`.
-}
type Msg
    = Go Int
    | Reveal String Int
    | Hide String
    | ShowMore Int Int
    | SetSplit Bool
    | Noop


{-| Handles the buttons of the viewer: next and previous change, opening and
closing a run of unchanged lines, showing more changes and the layout. The
commands move the keyboard focus to the change the user went to, to the button of a
run of lines that was opened, or to the first change that appeared, so map them
with `Cmd.map`.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg ((State state) as current) =
    case msg of
        Go index ->
            ( State { state | current = Just index, shown = max state.shown (index + 1) }
            , Internal.focus (changeDomId state.id index) Noop
            )

        Reveal key count ->
            let
                before =
                    revealedBefore key state.folds
            in
            ( State { state | folds = Dict.insert key count state.folds }
              -- the focus goes to the first row that appeared: the button that was
              -- pressed is gone, and the button above (the fold that opened, far
              -- up in a long run) would scroll the page back. Only every `rowStep`th
              -- row has an id; a count kept from an earlier diff can stop in between,
              -- and then the next row with an id, or the fold itself, takes the focus,
              -- so that it never falls to the page
            , if before == 0 then
                Internal.focus (foldDomId state.id key) Noop

              else
                Internal.focusFirst
                    [ rowDomId state.id key before
                    , rowDomId state.id key ((before // rowStep + 1) * rowStep)
                    , foldDomId state.id key
                    ]
                    Noop
            )

        Hide key ->
            ( State { state | folds = Dict.remove key state.folds }
            , Internal.focus (foldDomId state.id key) Noop
            )

        ShowMore count first ->
            -- The button that was pressed goes away when everything is shown:
            -- the focus goes to the first change that appeared.
            ( State { state | shown = count, current = Just first }
            , Internal.focus (changeDomId state.id first) Noop
            )

        SetSplit value ->
            ( State { state | split = value }, Cmd.none )

        Noop ->
            ( current, Cmd.none )


changeDomId : String -> Int -> String
changeDomId id index =
    id ++ "-change-" ++ String.fromInt index


foldDomId : String -> String -> String
foldDomId id key =
    id ++ "-fold-" ++ key


{-| The id of a row of a run of lines that was opened or of a hunk that was cut: only
the rows where the next opening begins have one, and they are the rows `rowStep`,
`2 * rowStep` and so on.
-}
rowDomId : String -> String -> Int -> String
rowDomId id key index =
    id ++ "-row-" ++ key ++ "-" ++ String.fromInt index


{-| How many rows of a run of unchanged lines (key `f12`) or of a hunk (key `h12/14`) are
drawn before the key is opened more: none for a fold, a whole `rowStep` for a hunk.
-}
revealedBefore : String -> Dict String Int -> Int
revealedBefore key folds =
    Dict.get key folds
        |> Maybe.withDefault
            (if String.startsWith "h" key then
                rowStep

             else
                0
            )



-- ATTRIBUTES


{-| A setting of the viewer. Make them with the functions below and pass a list to
`view` or `viewStatic`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { ariaLabel : Maybe String
    , context : Int
    , maxChanges : Int
    , maxHeight : Maybe Int
    , wrap : Bool
    , unchangedFields : Bool
    , locale : Locale
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { ariaLabel = Nothing
        , context = 3
        , maxChanges = 200
        , maxHeight = Nothing
        , wrap = False
        , unchangedFields = False
        , locale = Locale.default
        }
        attributes


{-| The accessible name of the diff, such as "Changes to the shipping policy". It
names the area that scrolls, which screen readers announce as a region in `view` and
as a group in `viewStatic`; when nothing scrolls, it names the whole diff, as a group.
The default is "Changes".
-}
ariaLabel : String -> Attribute msg
ariaLabel text =
    Attribute (\config -> { config | ariaLabel = Just text })


{-| How many unchanged lines are shown around each change in a text diff; the rest
are folded into a row that says how many they are and opens when it is pressed.
The default is 3, and the value is kept between 0 and 20.
-}
context : Int -> Attribute msg
context count =
    Attribute (\config -> { config | context = clamp 0 20 count })


{-| How many changes are drawn before a row says "Showing 200 of 1,340 changes" and
offers to show more. The default is 200, and the value is kept between 10 and 5000.
It keeps a diff with thousands of changes fast. A block of more than 500 changed
lines is cut as well, after 500 lines, with a button that shows 500 more. `viewStatic`
has no buttons, so it draws at most 1,000 changes and 500 lines of a block, and says
how many it left out.
-}
maxChanges : Int -> Attribute msg
maxChanges count =
    Attribute (\config -> { config | maxChanges = clamp 10 5000 count })


{-| Scrolls inside the viewer when the diff is taller than this many pixels. By
default the viewer grows with its content. A diff of lines scrolls sideways inside
its own box in any case, never the page.
-}
maxHeight : Int -> Attribute msg
maxHeight pixels =
    Attribute (\config -> { config | maxHeight = Just pixels })


{-| Wraps long lines of a text diff instead of scrolling sideways. Good for
prose, such as a policy; code is easier to read when it keeps its lines. With nothing
to scroll sideways, the box of the lines is a tab stop only when it has a `maxHeight`.
-}
wrapLines : Attribute msg
wrapLines =
    Attribute (\config -> { config | wrap = True })


{-| Shows the fields that did not change as well, muted, in a diff made with
`fields`. By default only the fields that changed are shown. It has no effect on
other diffs.
-}
showUnchangedFields : Attribute msg
showUnchangedFields =
    Attribute (\config -> { config | unchangedFields = True })


{-| The language of the built-in text: the toolbar, the rows that fold unchanged
lines, the counts and the notes. The default is `Locale.default`, which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })



-- TEXT


type alias Texts =
    { defaultLabel : String
    , noChanges : String
    , whitespaceIgnored : String
    , caseIgnored : String
    , lineEndsDiffer : String
    , unified : String
    , split : String
    , layout : String
    , previousChange : String
    , nextChange : String
    , stepThrough : String
    , changeCount : Int -> String
    , changeOf : Int -> Int -> String
    , addedWord : String
    , removedWord : String
    , changedWord : String
    , unchangedWord : String
    , addedCount : Int -> String
    , removedCount : Int -> String
    , changedCount : Int -> String
    , unchangedLines : Int -> String
    , hideUnchanged : Int -> String
    , showMoreUnchanged : Int -> Int -> String
    , changedLinesShown : Int -> Int -> String
    , showMoreChanged : Int -> Int -> String
    , showing : Int -> Int -> String
    , showMore : Int -> String
    , showAll : Int -> String
    , tooLarge : String
    , summaryOld : String
    , summaryNew : String
    , summaryStart : String
    , summaryEnd : String
    , summaryOnlyOld : String
    , summaryOnlyNew : String
    , summaryNote : String
    , lineCount : Int -> String
    , missingNewline : String
    , emptyValue : String
    , shortened : String
    , notJson : String
    , tooDeep : String
    , oldLine : String
    , newLine : String
    , oldChange : String
    , newChange : String
    , oldText : String
    , newText : String
    , changeColumn : String
    , textColumn : String
    , changedFrom : String
    , changedTo : String
    }


texts : Locale -> Texts
texts loc =
    let
        pick nb en =
            Locale.pick loc { nb = nb, en = en }

        number =
            Format.int loc

        count n forms =
            number n ++ " " ++ Format.plural loc n forms
    in
    { defaultLabel = pick "Endringer" "Changes"
    , noChanges = pick "Ingen endringer" "No changes"
    , whitespaceIgnored = pick "Forskjeller i mellomrom ignoreres" "Differences in white space are ignored"
    , caseIgnored = pick "Store og små bokstaver regnes som like" "Upper and lower case count as the same"
    , lineEndsDiffer = pick "Linjeskiftene er ulike (Windows og Unix) og sammenlignes ikke" "The line endings differ (Windows and Unix) and are not compared"
    , unified = pick "Under hverandre" "Unified"
    , split = pick "Side ved side" "Split"
    , layout = pick "Visning" "Layout"
    , previousChange = pick "Forrige endring" "Previous change"
    , nextChange = pick "Neste endring" "Next change"
    , stepThrough = pick "Gå gjennom endringene" "Go through the changes"
    , changeCount = \n -> count n { one = pick "endring" "change", other = pick "endringer" "changes" }
    , changeOf = \i n -> pick ("Endring " ++ number i ++ " av " ++ number n) ("Change " ++ number i ++ " of " ++ number n)
    , addedWord = pick "Lagt til" "Added"
    , removedWord = pick "Fjernet" "Removed"
    , changedWord = pick "Endret" "Changed"
    , unchangedWord = pick "Uendret" "Unchanged"
    , addedCount = \n -> number n ++ " " ++ pick "lagt til" "added"
    , removedCount = \n -> number n ++ " " ++ pick "fjernet" "removed"
    , changedCount = \n -> number n ++ " " ++ pick "endret" "changed"
    , unchangedLines = \n -> count n { one = pick "uendret linje" "unchanged line", other = pick "uendrede linjer" "unchanged lines" }
    , hideUnchanged = \n -> pick "Skjul " "Hide " ++ count n { one = pick "uendret linje" "unchanged line", other = pick "uendrede linjer" "unchanged lines" }
    , showMoreUnchanged = \more left -> pick ("Vis " ++ number more ++ " flere uendrede linjer (" ++ number left ++ " igjen)") ("Show " ++ number more ++ " more unchanged lines (" ++ number left ++ " left)")
    , changedLinesShown = \shown total -> pick ("Viser " ++ number shown ++ " av " ++ number total ++ " endrede linjer") ("Showing " ++ number shown ++ " of " ++ number total ++ " changed lines")
    , showMoreChanged = \more left -> pick ("Vis " ++ number more ++ " flere linjer (" ++ number left ++ " igjen)") ("Show " ++ number more ++ " more lines (" ++ number left ++ " left)")
    , showing = \shown total -> pick ("Viser " ++ number shown ++ " av " ++ number total ++ " endringer") ("Showing " ++ number shown ++ " of " ++ number total ++ " changes")
    , showMore = \n -> pick ("Vis " ++ number n ++ " flere") ("Show " ++ number n ++ " more")
    , showAll = \n -> pick ("Vis alle " ++ number n) ("Show all " ++ number n)
    , tooLarge = pick "For stor til å sammenligne linje for linje: viser et sammendrag" "Too large to compare line by line: showing a summary"
    , summaryOld = pick "Gammel tekst" "Old text"
    , summaryNew = pick "Ny tekst" "New text"
    , summaryStart = pick "Like linjer i begynnelsen" "The same at the start"
    , summaryEnd = pick "Like linjer på slutten" "The same at the end"
    , summaryOnlyOld = pick "Bare i den gamle teksten" "Only in the old text"
    , summaryOnlyNew = pick "Bare i den nye teksten" "Only in the new text"
    , summaryNote = pick "Linjene telles etter innholdet, uansett hvor de står: linjer som bare er flyttet regnes ikke som forskjellige." "Lines are counted by their text, wherever they stand: lines that only moved do not count as different."
    , lineCount = \n -> count n { one = pick "linje" "line", other = pick "linjer" "lines" }
    , missingNewline = pick "Ingen linjeskift på slutten av filen" "No newline at end of file"
    , emptyValue = pick "(tom)" "(empty)"
    , shortened = pick "forkortet" "shortened"
    , notJson = pick "(ikke JSON-data)" "(not JSON data)"
    , tooDeep = pick "(for dypt nøstet til å sammenligne)" "(nested too deeply to compare)"
    , oldLine = pick "Gammel linje" "Old line"
    , newLine = pick "Ny linje" "New line"
    , oldChange = pick "Gammel endring" "Old change"
    , newChange = pick "Ny endring" "New change"
    , oldText = pick "Gammel tekst" "Old text"
    , newText = pick "Ny tekst" "New text"
    , changeColumn = pick "Endring" "Change"
    , textColumn = pick "Tekst" "Text"
    , changedFrom = pick "endret fra" "changed from"
    , changedTo = pick "til" "to"
    }



-- VIEW


{-| What the parts of the view need to know.
-}
type alias Ctx msg =
    { toMsg : Maybe (Msg -> msg)
    , state : State
    , config : Config
    , t : Texts
    , changeCount : Int
    , interactive : Bool
    }


{-| The viewer: a toolbar (the counts, the layout of a text diff, buttons to the
previous and the next change), and under it the diff in a box that scrolls
sideways when the lines are long. The first argument wraps the viewer's messages in
one of yours.

A text diff shows the unchanged lines around each change, folds the rest into a
row ("12 unchanged lines") that opens when it is pressed, and marks the changed
words inside a changed line. The diff of two equal versions says "No changes"; a
diff that became a summary says that it is too large and gives the numbers. A diff
with many changes draws the first ones and says "Showing 200 of 1,340 changes" with
buttons to show more (see `maxChanges`). One block of more than 500 changed lines is
cut as well: "Showing 500 of 20,000 changed lines", with a button for 500 more.

**Keyboard.** The box that scrolls is a tab stop with a name (`ariaLabel`), so the
arrow keys, Page Down and Home scroll it (a list of JSON or field changes is a tab stop
only with `maxHeight`; without it the whole viewer has the name). The buttons "Previous
change" and "Next change" move the focus to a change, and the box scrolls to it; while the
focus is in the box, `n` and `p` do the same without leaving it. The rows that fold
unchanged lines are buttons; when one opens more lines the focus goes to the first line
that appeared, so that the page does not jump.

**Right to left.** The columns of a diff are the line numbers, the signs and the text, from
the left, whatever the direction of the page, as in every diff tool; each line of text is
shown in its own direction. The toolbar follows the direction of the page.

**Screen readers.** A text diff is a table with the columns line number, new line
number, kind of change and text; added and removed lines say "Added" and "Removed" in
text, not only with a color and a `+` or `-`, and the first row of each change says
"Change 3 of 12". Changed words inside a line are `ins` and `del` elements, which
screen readers announce as insertions and deletions. JSON and field changes are a list
whose items read like sentences ("price: changed from 12.5 to 14").

The viewer needs an id from `init` for the focus. For a list of many diffs, where
a state for each would be a nuisance, use `viewStatic`.

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Diff -> Html msg
view toMsg attributes state diff =
    render (Just toMsg) (configure attributes) state diff


{-| The viewer without state, for a diff in a list of many (an audit log, the history
of a record): the changes only, in the unified layout, with no toolbar, no buttons, no
id. It draws at most 1,000 changes and at most 500 lines of one block of changed lines,
and says how many it left out. The unchanged lines around the changes of a text diff are
folded, into rows that say how many they are but do not open.

    Diff.viewStatic [ Diff.locale model.locale ] entry.diff

A diff of lines scrolls sideways inside a box that is a tab stop and a group named by
`ariaLabel`, not a landmark, so that an audit log of fifty entries does not add fifty
regions to the page (give each entry its own `ariaLabel`). With `wrapLines` nothing
scrolls sideways and the box is no tab stop. The others do not need one and are plain
lists.

-}
viewStatic : List (Attribute msg) -> Diff -> Html msg
viewStatic attributes diff =
    render Nothing (configure attributes) (init "") diff


render : Maybe (Msg -> msg) -> Config -> State -> Diff -> Html msg
render toMsg config state ((Diff diff) as whole) =
    let
        t =
            texts config.locale

        ctx =
            { toMsg = toMsg
            , state = state
            , config = config
            , t = t
            , changeCount = List.length (hunks whole)
            , interactive = interactive
            }

        (State s) =
            state

        label =
            Maybe.withDefault t.defaultLabel config.ariaLabel

        interactive =
            case toMsg of
                Just _ ->
                    True

                Nothing ->
                    False

        frame body =
            Html.div
                ([ Internal.cls
                    [ "klar-diff"
                    , if interactive && s.split && isLines diff.content then
                        "klar-diff--split"

                      else
                        ""
                    , if config.wrap then
                        "klar-diff--wrap"

                      else
                        ""
                    ]
                 ]
                    ++ (if interactive then
                            [ Attr.id s.id ]

                        else
                            []
                       )
                    ++ (if hasRegion then
                            []

                        else
                            [ Attr.attribute "role" "group", Attr.attribute "aria-label" label ]
                       )
                )
                body

        -- the name is on the box that scrolls when there is one that is a tab stop; a
        -- viewer without one gets the name on the whole, and never on both
        hasRegion =
            case diff.content of
                SummaryContent _ ->
                    False

                LinesContent _ ->
                    not (isEmpty whole) && linesScroll config

                EntriesContent _ _ ->
                    interactive
                        && config.maxHeight
                        /= Nothing
                        && not (isEmpty whole && not config.unchangedFields)
    in
    case diff.content of
        SummaryContent summary ->
            frame [ viewToolbar ctx whole, viewSummary ctx summary ]

        LinesContent compared ->
            if isEmpty whole then
                frame [ viewToolbar ctx whole, viewEmpty ctx diff.notes ]

            else
                frame
                    [ viewToolbar ctx whole
                    , viewNotes ctx diff.notes
                    , viewLines ctx label compared
                    , viewFooter ctx
                    ]

        EntriesContent source entries ->
            let
                nothingChanged =
                    isEmpty whole
            in
            frame
                [ viewToolbar ctx whole
                , if nothingChanged then
                    viewEmpty ctx diff.notes

                  else
                    Html.text ""
                , if nothingChanged && not config.unchangedFields then
                    Html.text ""

                  else
                    viewEntries ctx label source entries
                , viewFooter ctx
                ]


{-| Whether the table of lines can scroll, and so must be a tab stop: sideways unless
the lines are wrapped, and up and down with a `maxHeight`.
-}
linesScroll : Config -> Bool
linesScroll config =
    not config.wrap || config.maxHeight /= Nothing


isLines : Content -> Bool
isLines content =
    case content of
        LinesContent _ ->
            True

        _ ->
            False


{-| What the toolbar shows depends on the diff, and a static view has none.
-}
viewToolbar : Ctx msg -> Diff -> Html msg
viewToolbar ctx ((Diff diff) as whole) =
    case ctx.toMsg of
        Nothing ->
            Html.text ""

        Just toMsg ->
            let
                (State state) =
                    ctx.state

                t =
                    ctx.t

                totals =
                    stats whole

                stat tone count word =
                    if count == 0 then
                        Html.text ""

                    else
                        Html.span [ Internal.cls [ "klar-diff__stat", "klar-diff__stat--" ++ tone ] ]
                            [ Html.span [ ariaHidden ] [ Html.text (statMark tone ++ Format.int ctx.config.locale count) ]
                            , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (word count) ]
                            ]

                current =
                    state.current
                        |> Maybe.andThen
                            (\index ->
                                if index < ctx.changeCount then
                                    Just index

                                else
                                    Nothing
                            )

                previous =
                    case current of
                        Just index ->
                            if index > 0 then
                                Just (index - 1)

                            else
                                Nothing

                        Nothing ->
                            Nothing

                next =
                    case current of
                        Just index ->
                            if index + 1 < ctx.changeCount then
                                Just (index + 1)

                            else
                                Nothing

                        Nothing ->
                            if ctx.changeCount > 0 then
                                Just 0

                            else
                                Nothing

                step label icon target =
                    Button.view
                        [ Button.small
                        , Button.ghost
                        , Button.icon icon
                        , Button.disabled (target == Nothing)
                        , case target of
                            Just index ->
                                Button.onClick (toMsg (Go index))

                            Nothing ->
                                Button.htmlAttrs []
                        ]
                        label

                layoutButton label isSplitChoice =
                    Button.view
                        [ Button.small
                        , Button.ghost
                        , Button.pressed (state.split == isSplitChoice)
                        , Button.onClick (toMsg (SetSplit isSplitChoice))
                        ]
                        label

                hasChanges =
                    ctx.changeCount > 0
            in
            Html.div [ Internal.cls [ "klar-diff__toolbar" ] ]
                [ Html.div [ Internal.cls [ "klar-diff__stats" ] ]
                    [ stat "added" totals.added t.addedCount
                    , stat "removed" totals.removed t.removedCount
                    , stat "changed" totals.changed t.changedCount
                    ]
                , Html.div [ Internal.cls [ "klar-diff__tools" ] ]
                    [ if isLines diff.content && not (tooLarge whole) then
                        Html.div
                            [ Internal.cls [ "klar-diff__layout" ]
                            , Attr.attribute "role" "group"
                            , Attr.attribute "aria-label" t.layout
                            ]
                            [ layoutButton t.unified False, layoutButton t.split True ]

                      else
                        Html.text ""
                    , if hasChanges then
                        Html.div [ Internal.cls [ "klar-diff__nav" ], Attr.attribute "role" "group", Attr.attribute "aria-label" t.stepThrough ]
                            [ Html.span [ Internal.cls [ "klar-diff__counter", "klar-tabular" ] ]
                                [ Html.text
                                    (case current of
                                        Just index ->
                                            t.changeOf (index + 1) ctx.changeCount

                                        Nothing ->
                                            t.changeCount ctx.changeCount
                                    )
                                ]
                            , step t.previousChange Icon.chevronUp previous
                            , step t.nextChange Icon.chevronDown next
                            ]

                      else
                        Html.text ""
                    ]
                ]


statMark : String -> String
statMark tone =
    case tone of
        "added" ->
            "+"

        "removed" ->
            "−"

        _ ->
            "~"


ariaHidden : Html.Attribute msg
ariaHidden =
    Attr.attribute "aria-hidden" "true"


{-| "Differences in white space are ignored" and the like, so that a result that was
computed with an option is never taken for a full comparison.
-}
viewNotes : Ctx msg -> Notes -> Html msg
viewNotes ctx notes =
    let
        t =
            ctx.t

        items =
            List.filterMap identity
                [ if notes.ignoreWhitespace then
                    Just t.whitespaceIgnored

                  else
                    Nothing
                , if notes.ignoreCase then
                    Just t.caseIgnored

                  else
                    Nothing
                , if notes.lineEndsDiffer then
                    Just t.lineEndsDiffer

                  else
                    Nothing
                ]
    in
    if List.isEmpty items then
        Html.text ""

    else
        Html.ul [ Internal.cls [ "klar-diff__notes" ] ]
            (List.map (\item -> Html.li [ Internal.cls [ "klar-diff__note" ] ] [ Html.text item ]) items)


viewEmpty : Ctx msg -> Notes -> Html msg
viewEmpty ctx notes =
    Html.div [ Internal.cls [ "klar-diff__empty" ], Attr.attribute "role" "status" ]
        [ Html.p [ Internal.cls [ "klar-diff__empty-text" ] ] [ Html.text ctx.t.noChanges ]
        , viewNotes ctx notes
        ]


viewSummary : Ctx msg -> Lines.Summary -> Html msg
viewSummary ctx summary =
    let
        t =
            ctx.t

        row label n =
            DescriptionList.text label (t.lineCount n)
    in
    Html.div [ Internal.cls [ "klar-diff__summary" ] ]
        [ Alert.viewWith [ Alert.tone Warning, Alert.compact, Alert.locale ctx.config.locale ]
            [ Html.text t.tooLarge ]
        , DescriptionList.view [ DescriptionList.columns 2, DescriptionList.labelBeside, DescriptionList.bordered, DescriptionList.compact, DescriptionList.locale ctx.config.locale ]
            [ row t.summaryOld summary.oldLines
            , row t.summaryNew summary.newLines
            , row t.summaryStart summary.sameAtStart
            , row t.summaryEnd summary.sameAtEnd
            , row t.summaryOnlyOld summary.onlyInOld
            , row t.summaryOnlyNew summary.onlyInNew
            ]
        , Html.p [ Internal.cls [ "klar-diff__summary-note" ] ] [ Html.text t.summaryNote ]
        ]



-- THE SCROLL AREA


{-| The box that scrolls: sideways for long lines, and up and down when there is a
`maxHeight`. It is a tab stop with a name when it can scroll (a table of lines
always can, a list of changes only with a `maxHeight`), so the arrow keys scroll it.
In the viewer `n` and `p` go to the next and the previous change while the focus is
inside, whether it is a tab stop or not.
-}
scrollArea : Ctx msg -> String -> Bool -> List (Html msg) -> Html msg
scrollArea ctx label tabStop content =
    let
        (State state) =
            ctx.state

        current =
            state.current
                |> Maybe.andThen
                    (\index ->
                        if index < ctx.changeCount then
                            Just index

                        else
                            Nothing
                    )

        keys =
            case ctx.toMsg of
                Just toMsg ->
                    List.filterMap identity
                        [ case current of
                            Just index ->
                                if index + 1 < ctx.changeCount then
                                    Just ( "n", toMsg (Go (index + 1)) )

                                else
                                    Nothing

                            Nothing ->
                                if ctx.changeCount > 0 then
                                    Just ( "n", toMsg (Go 0) )

                                else
                                    Nothing
                        , case current of
                            Just index ->
                                if index > 0 then
                                    Just ( "p", toMsg (Go (index - 1)) )

                                else
                                    Nothing

                            Nothing ->
                                Nothing
                        ]

                Nothing ->
                    []
    in
    Html.div
        ([ Internal.cls [ "klar-diff__scroll" ]
         , case ctx.config.maxHeight of
            Just pixels ->
                Internal.styleVars [ ( "max-height", Internal.px pixels ) ]

            Nothing ->
                Internal.noAttr
         ]
            ++ (if tabStop then
                    [ Attr.tabindex 0

                    -- the viewer is a landmark of the page; a static diff is one of many in
                    -- a list (an audit log), and fifty landmarks would flood the list of them
                    , Attr.attribute "role"
                        (if ctx.interactive then
                            "region"

                         else
                            "group"
                        )
                    , Attr.attribute "aria-label" label
                    ]
                        ++ (if ctx.interactive then
                                [ Attr.id (state.id ++ "-scroll") ]

                            else
                                []
                           )

                else
                    []
               )
            ++ [ Internal.attrIf (not (List.isEmpty keys)) (Internal.onKeys keys) ]
        )
        content



-- TEXT DIFF


type RowKind
    = ContextRow
    | AddedRow
    | RemovedRow


type Block
    = ContextBlock { oldStart : Int, newStart : Int, count : Int }
    | FoldBlock { key : String, oldStart : Int, newStart : Int, hidden : Int, revealed : Int }
    | HunkBlock Lines.Hunk


{-| A run of unchanged lines is opened this many lines at a time, and a hunk draws
this many rows before the rest is hidden behind a button.
-}
rowStep : Int
rowStep =
    500


{-| A static view draws at most this many changes, and says how many it left out.
-}
mostStaticChanges : Int
mostStaticChanges =
    1000


viewLines : Ctx msg -> String -> Lines.Compared -> Html msg
viewLines ctx label compared =
    let
        (State state) =
            ctx.state

        interactive =
            ctx.interactive

        split =
            interactive && state.split

        limit =
            visibleChanges ctx

        blockList =
            blocks ctx.config.context state.folds limit compared.segments

        digits =
            String.length (String.fromInt (max (Array.length compared.old) (Array.length compared.new)))

        t =
            ctx.t

        head =
            if split then
                [ t.oldLine, t.oldChange, t.oldText, t.newLine, t.newChange, t.newText ]

            else
                [ t.oldLine, t.newLine, t.changeColumn, t.textColumn ]
    in
    scrollArea ctx
        label
        (linesScroll ctx.config)
        [ Keyed.node "table"
            [ Internal.cls
                [ "klar-diff__table"
                , if split then
                    "klar-diff__table--split"

                  else
                    "klar-diff__table--unified"
                ]
            , Internal.styleVars [ ( "--_digits", String.fromInt digits ) ]
            ]
            (( "head"
             , Html.thead [ Internal.cls [ "klar-diff__head" ] ]
                [ Html.tr []
                    (List.map
                        (\name ->
                            Html.th [ Attr.scope "col" ] [ Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text name ] ]
                        )
                        head
                    )
                ]
             )
                :: List.map (viewBlock ctx split compared) blockList
            )
        ]


{-| How many changes are drawn: the limit and what the user asked for, or as many as
a static view draws.
-}
visibleChanges : Ctx msg -> Int
visibleChanges ctx =
    let
        (State state) =
            ctx.state
    in
    case ctx.toMsg of
        Just _ ->
            min ctx.changeCount (max ctx.config.maxChanges state.shown)

        Nothing ->
            min ctx.changeCount mostStaticChanges


{-| The blocks that are drawn: the changes up to the limit with some unchanged
lines around each, and the rest of the unchanged lines folded away.
-}
blocks : Int -> Dict String Int -> Int -> List Lines.Segment -> List Block
blocks around folds limit segments =
    let
        go remaining drawn built =
            case remaining of
                [] ->
                    List.reverse built

                (Lines.Equal run) :: rest ->
                    let
                        hasBefore =
                            drawn > 0

                        hasAfter =
                            not (List.isEmpty rest) && drawn < limit

                        atEnd =
                            List.isEmpty rest
                    in
                    go rest drawn (List.reverse (equalBlocks around folds run hasBefore hasAfter atEnd) ++ built)

                (Lines.Changed hunk) :: rest ->
                    if drawn >= limit then
                        List.reverse built

                    else
                        go rest (drawn + 1) (HunkBlock hunk :: built)
    in
    go segments 0 []


equalBlocks : Int -> Dict String Int -> { oldStart : Int, newStart : Int, count : Int } -> Bool -> Bool -> Bool -> List Block
equalBlocks around folds run hasBefore hasAfter atEnd =
    let
        contextBlock start count =
            if count <= 0 then
                []

            else
                [ ContextBlock { oldStart = run.oldStart + start, newStart = run.newStart + start, count = count } ]

        fold start hidden =
            if hidden <= 0 then
                []

            else
                let
                    key =
                        "f" ++ String.fromInt (run.oldStart + start + 1)
                in
                [ FoldBlock
                    { key = key
                    , oldStart = run.oldStart + start
                    , newStart = run.newStart + start
                    , hidden = hidden
                    , revealed = clamp 0 hidden (Dict.get key folds |> Maybe.withDefault 0)
                    }
                ]
    in
    if hasBefore && hasAfter then
        if run.count - 2 * around <= 1 then
            contextBlock 0 run.count

        else
            contextBlock 0 around ++ fold around (run.count - 2 * around) ++ contextBlock (run.count - around) around

    else if hasBefore then
        -- after the last change that is drawn: the run is folded only when it is
        -- the end of the text; otherwise more changes follow that are not drawn
        if atEnd then
            if run.count - around <= 1 then
                contextBlock 0 run.count

            else
                contextBlock 0 around ++ fold around (run.count - around)

        else
            contextBlock 0 (min around run.count)

    else if hasAfter then
        if run.count - around <= 1 then
            contextBlock 0 run.count

        else
            fold 0 (run.count - around) ++ contextBlock (run.count - around) around

    else
        []


viewBlock : Ctx msg -> Bool -> Lines.Compared -> Block -> ( String, Html msg )
viewBlock ctx split compared block =
    case block of
        ContextBlock run ->
            ( "context-" ++ String.fromInt run.oldStart
            , Html.tbody [ Internal.cls [ "klar-diff__context" ] ] (contextRows ctx split compared Nothing run.oldStart run.newStart 0 run.count)
            )

        FoldBlock fold ->
            ( "fold-" ++ fold.key, viewFold ctx split compared fold )

        HunkBlock hunk ->
            let
                (State state) =
                    ctx.state

                isCurrent =
                    state.current == Just hunk.index

                key =
                    hunkRowsKey hunk

                -- a hunk of thousands of lines is cut, and says so
                allowed =
                    if ctx.interactive then
                        revealedBefore key state.folds

                    else
                        rowStep

                total =
                    if split then
                        max (List.length hunk.removed) (List.length hunk.added)

                    else
                        List.length hunk.removed + List.length hunk.added
            in
            ( "hunk-" ++ String.fromInt hunk.index
            , Html.tbody
                [ Internal.cls
                    [ "klar-diff__hunk"
                    , if isCurrent then
                        "klar-diff__hunk--current"

                      else
                        ""
                    ]
                ]
                ((if split then
                    splitHunkRows ctx key allowed hunk

                  else
                    unifiedHunkRows ctx key allowed hunk
                 )
                    ++ (if total > allowed then
                            [ viewMoreRows ctx split key allowed total ]

                        else
                            []
                       )
                )
            )


{-| The key of the rows of a hunk that are shown, in the state of the viewer: where the
hunk starts, so that it is remembered for the same diff and forgotten for another.
-}
hunkRowsKey : Lines.Hunk -> String
hunkRowsKey hunk =
    "h" ++ String.fromInt (hunk.oldStart + 1) ++ "/" ++ String.fromInt (hunk.newStart + 1)


{-| The row that tells that the rest of a hunk is not drawn, with the button that draws
more of it (a static view cannot).
-}
viewMoreRows : Ctx msg -> Bool -> String -> Int -> Int -> Html msg
viewMoreRows ctx split key shown total =
    let
        t =
            ctx.t

        left =
            total - shown

        step =
            min left rowStep
    in
    Html.tr [ Internal.cls [ "klar-diff__fold-row" ] ]
        [ Html.td [ Internal.cls [ "klar-diff__fold-cell", "klar-diff__fold-cell--more" ], Attr.colspan (columnCount split) ]
            (Html.span [ Internal.cls [ "klar-diff__fold-note", "klar-tabular" ] ] [ Html.text (t.changedLinesShown shown total) ]
                :: (case ctx.toMsg of
                        Just toMsg ->
                            [ Html.button
                                [ Internal.cls [ "klar-diff__fold-button" ]
                                , Attr.type_ "button"
                                , Events.onClick (toMsg (Reveal key (shown + step)))
                                ]
                                [ Html.text (t.showMoreChanged step left) ]
                            ]

                        Nothing ->
                            []
                   )
            )
        ]


columnCount : Bool -> Int
columnCount split =
    if split then
        6

    else
        4


{-| The rows of unchanged lines `from` to `from + count` of a run that starts at the
given lines.
-}
contextRows : Ctx msg -> Bool -> Lines.Compared -> Maybe String -> Int -> Int -> Int -> Int -> List (Html msg)
contextRows ctx split compared opened oldStart newStart from count =
    List.range from (from + count - 1)
        |> List.map
            (\offset ->
                let
                    newIndex =
                        newStart + offset

                    oldNumber =
                        oldStart + offset + 1

                    newNumber =
                        newIndex + 1

                    text =
                        Array.get newIndex compared.new |> Maybe.withDefault ""

                    missing =
                        compared.newMissingNewline && newNumber == Array.length compared.new
                in
                if split then
                    let
                        -- with ignoreWhitespace or ignoreCase an unchanged line can still be
                        -- written differently: the old column shows the old text
                        oldText =
                            Array.get (oldNumber - 1) compared.old |> Maybe.withDefault text

                        oldMissing =
                            compared.oldMissingNewline && oldNumber == Array.length compared.old
                    in
                    Html.tr (Internal.cls [ "klar-diff__row" ] :: openedRowAttributes ctx opened offset)
                        (sideCells ctx ContextRow (Just oldNumber) [ { text = oldText, changed = False } ] oldMissing Nothing False
                            ++ sideCells ctx ContextRow (Just newNumber) [ { text = text, changed = False } ] missing Nothing (oldText == text && oldMissing == missing)
                        )

                else
                    Html.tr (Internal.cls [ "klar-diff__row" ] :: openedRowAttributes ctx opened offset)
                        [ numberCell [] ContextRow (Just oldNumber)
                        , numberCell [] ContextRow (Just newNumber)
                        , markCell [] ctx ContextRow Nothing
                        , codeCell [] ctx ContextRow [ { text = text, changed = False } ] missing
                        ]
            )


{-| The id that the focus goes to when a run of lines or a hunk is opened further: the
row where the next rows begin, and only such a row, has one.
-}
openedRowAttributes : Ctx msg -> Maybe String -> Int -> List (Html.Attribute msg)
openedRowAttributes ctx opened index =
    case opened of
        Just key ->
            if ctx.interactive && index > 0 && modBy rowStep index == 0 then
                let
                    (State state) =
                        ctx.state
                in
                [ Attr.id (rowDomId state.id key index), Attr.tabindex -1 ]

            else
                []

        Nothing ->
            []


viewFold : Ctx msg -> Bool -> Lines.Compared -> { key : String, oldStart : Int, newStart : Int, hidden : Int, revealed : Int } -> Html msg
viewFold ctx split compared fold =
    let
        t =
            ctx.t

        (State state) =
            ctx.state

        span =
            columnCount split

        domId =
            foldDomId state.id fold.key

        foldRow content =
            Html.tr [ Internal.cls [ "klar-diff__fold-row" ] ]
                [ Html.td [ Internal.cls [ "klar-diff__fold-cell" ], Attr.colspan span ] [ content ] ]

        label count =
            Html.span [ Internal.cls [ "klar-diff__fold-label" ] ]
                [ Html.span [ Internal.cls [ "klar-diff__fold-icon" ], ariaHidden ] [ Icon.sized Icon.ExtraSmall Icon.chevronRight ]
                , Html.text (t.unchangedLines count)
                ]

        toggle expanded message text =
            case ctx.toMsg of
                Just toMsg ->
                    Html.button
                        [ Internal.cls [ "klar-diff__fold-button" ]
                        , Attr.type_ "button"
                        , Attr.id domId
                        , Attr.attribute "aria-expanded"
                            (if expanded then
                                "true"

                             else
                                "false"
                            )
                        , Events.onClick (toMsg message)
                        ]
                        [ text ]

                Nothing ->
                    Html.span [ Internal.cls [ "klar-diff__fold-button", "klar-diff__fold-button--static" ] ] [ text ]
    in
    if fold.revealed == 0 then
        Html.tbody [ Internal.cls [ "klar-diff__fold" ] ]
            [ foldRow (toggle False (Reveal fold.key (min fold.hidden rowStep)) (label fold.hidden)) ]

    else
        let
            left =
                fold.hidden - fold.revealed
        in
        Html.tbody [ Internal.cls [ "klar-diff__fold", "klar-diff__fold--open" ] ]
            (foldRow
                (toggle True
                    (Hide fold.key)
                    (Html.span [ Internal.cls [ "klar-diff__fold-label" ] ]
                        [ Html.span [ Internal.cls [ "klar-diff__fold-icon" ], ariaHidden ] [ Icon.sized Icon.ExtraSmall Icon.chevronDown ]
                        , Html.text (t.hideUnchanged fold.hidden)
                        ]
                    )
                )
                :: contextRows ctx split compared (Just fold.key) fold.oldStart fold.newStart 0 fold.revealed
                ++ (if left > 0 then
                        [ foldRow
                            (case ctx.toMsg of
                                Just toMsg ->
                                    Html.button
                                        [ Internal.cls [ "klar-diff__fold-button" ]
                                        , Attr.type_ "button"
                                        , Events.onClick (toMsg (Reveal fold.key (fold.revealed + min left rowStep)))
                                        ]
                                        [ Html.text (t.showMoreUnchanged (min left rowStep) left) ]

                                Nothing ->
                                    Html.text ""
                            )
                        ]

                    else
                        []
                   )
            )



-- ROWS


{-| The class that colors a cell by the kind of line it belongs to.
-}
kindClass : RowKind -> String
kindClass kind =
    case kind of
        ContextRow ->
            "klar-diff__cell--context"

        AddedRow ->
            "klar-diff__cell--added"

        RemovedRow ->
            "klar-diff__cell--removed"


numberCell : List (Html.Attribute msg) -> RowKind -> Maybe Int -> Html msg
numberCell extra kind number =
    Html.td
        (Internal.cls [ "klar-diff__num", "klar-tabular", kindClass kind ] :: extra)
        [ Html.text (number |> Maybe.map String.fromInt |> Maybe.withDefault "") ]


{-| The cell that says what kind of change the row is, in a sign for the eye and in
words for a screen reader. The first row of a change is where the focus goes when
the user steps to the change, so it has an id and says "Change 3 of 12".
-}
markCell : List (Html.Attribute msg) -> Ctx msg -> RowKind -> Maybe ( String, String ) -> Html msg
markCell extra ctx kind focus =
    let
        t =
            ctx.t

        ( sign, word ) =
            case kind of
                ContextRow ->
                    ( "", "" )

                AddedRow ->
                    ( "+", t.addedWord )

                RemovedRow ->
                    ( "−", t.removedWord )
    in
    Html.td
        (Internal.cls [ "klar-diff__mark", kindClass kind ]
            :: (case focus of
                    Just ( domId, _ ) ->
                        [ Attr.id domId, Attr.tabindex -1 ]

                    Nothing ->
                        []
               )
            ++ extra
        )
        [ case focus of
            Just ( _, announcement ) ->
                Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (announcement ++ ": ") ]

            Nothing ->
                Html.text ""
        , Html.span [ ariaHidden ] [ Html.text sign ]
        , if word == "" then
            Html.text ""

          else
            Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text word ]
        ]


codeCell : List (Html.Attribute msg) -> Ctx msg -> RowKind -> List Part -> Bool -> Html msg
codeCell extra ctx kind parts missingNewline =
    Html.td
        (Internal.cls [ "klar-diff__code", kindClass kind ] :: extra)
        [ Html.span [ Internal.cls [ "klar-diff__text" ] ] (viewParts kind parts)
        , if missingNewline then
            Html.span [ Internal.cls [ "klar-diff__noeol" ] ] [ Html.text ctx.t.missingNewline ]

          else
            Html.text ""
        ]


{-| The side of a row that has no line: three empty cells. They stay in the table for
screen readers, so every row has the six columns of the heading.
-}
fillerCells : List (Html msg)
fillerCells =
    List.repeat 3 (Html.td [ Internal.cls [ "klar-diff__filler" ] ] [])


{-| The text of a line: what changed inside it is an `ins` or a `del`, and the white
space at the end of a changed line is marked, because nobody can see it otherwise.
-}
viewParts : RowKind -> List Part -> List (Html msg)
viewParts kind parts =
    viewPartsWith kind (kind /= ContextRow) parts


viewPartsWith : RowKind -> Bool -> List Part -> List (Html msg)
viewPartsWith kind markTrailing parts =
    let
        ( body, trailing ) =
            if markTrailing then
                splitTrailing parts

            else
                ( parts, "" )

        piece part =
            if part.text == "" then
                Html.text ""

            else if part.changed then
                case kind of
                    AddedRow ->
                        Html.ins [ Internal.cls [ "klar-diff__ins" ] ] [ Html.text part.text ]

                    RemovedRow ->
                        Html.del [ Internal.cls [ "klar-diff__del" ] ] [ Html.text part.text ]

                    ContextRow ->
                        Html.text part.text

            else
                Html.text part.text
    in
    List.map piece body
        ++ (if trailing == "" then
                []

            else
                [ Html.span [ Internal.cls [ "klar-diff__trailing" ] ] [ Html.text trailing ] ]
           )


splitTrailing : List Part -> ( List Part, String )
splitTrailing parts =
    case List.reverse parts of
        [] ->
            ( [], "" )

        last :: before ->
            let
                trimmed =
                    String.trimRight last.text
            in
            ( List.reverse ({ last | text = trimmed } :: before)
            , String.dropLeft (String.length trimmed) last.text
            )


{-| The id of the first row of a change and what it says, when the viewer can be
steered; a static view has neither.
-}
focusTarget : Ctx msg -> Int -> Maybe ( String, String )
focusTarget ctx index =
    let
        (State state) =
            ctx.state
    in
    if ctx.interactive then
        Just ( changeDomId state.id index, ctx.t.changeOf (index + 1) ctx.changeCount )

    else
        Nothing


unifiedHunkRows : Ctx msg -> String -> Int -> Lines.Hunk -> List (Html msg)
unifiedHunkRows ctx key allowed hunk =
    let
        target =
            focusTarget ctx hunk.index

        row index kind oldNumber newNumber line focus =
            Html.tr (Internal.cls [ "klar-diff__row" ] :: openedRowAttributes ctx (Just key) index)
                [ numberCell [] kind oldNumber
                , numberCell [] kind newNumber
                , markCell [] ctx kind focus
                , codeCell [] ctx kind line.parts line.missingNewline
                ]

        removed =
            List.take allowed hunk.removed

        added =
            List.take (allowed - List.length removed) hunk.added
    in
    List.indexedMap
        (\i line ->
            row i
                RemovedRow
                (Just line.number)
                Nothing
                line
                (if i == 0 then
                    target

                 else
                    Nothing
                )
        )
        removed
        ++ List.indexedMap
            (\i line ->
                row (List.length removed + i)
                    AddedRow
                    Nothing
                    (Just line.number)
                    line
                    (if i == 0 && List.isEmpty removed then
                        target

                     else
                        Nothing
                    )
            )
            added


splitHunkRows : Ctx msg -> String -> Int -> Lines.Hunk -> List (Html msg)
splitHunkRows ctx key allowed hunk =
    let
        target =
            focusTarget ctx hunk.index

        removed =
            Array.fromList (List.take allowed hunk.removed)

        added =
            Array.fromList (List.take allowed hunk.added)

        count =
            max (Array.length removed) (Array.length added)

        side kind line focus =
            case line of
                Just found ->
                    sideCells ctx kind (Just found.number) found.parts found.missingNewline focus False

                Nothing ->
                    fillerCells
    in
    List.range 0 (count - 1)
        |> List.map
            (\j ->
                let
                    left =
                        Array.get j removed

                    right =
                        Array.get j added

                    leftFocus =
                        if j == 0 && left /= Nothing then
                            target

                        else
                            Nothing

                    rightFocus =
                        if j == 0 && left == Nothing then
                            target

                        else
                            Nothing
                in
                Html.tr (Internal.cls [ "klar-diff__row" ] :: openedRowAttributes ctx (Just key) j)
                    (side RemovedRow left leftFocus ++ side AddedRow right rightFocus)
            )


{-| The three cells of one side of a row in the side-by-side layout. When the
other side has the same text (an unchanged line) this side is hidden from screen
readers, so the line is read once.
-}
sideCells : Ctx msg -> RowKind -> Maybe Int -> List Part -> Bool -> Maybe ( String, String ) -> Bool -> List (Html msg)
sideCells ctx kind number parts missingNewline focus duplicate =
    if duplicate then
        -- the same text as the other side: a screen reader hears it once, and the cells
        -- stay in the table so that every row has the columns of the heading
        [ numberCell [] kind number
        , markCell [] ctx kind focus
        , Html.td [ Internal.cls [ "klar-diff__code", kindClass kind ] ]
            [ Html.span [ Internal.cls [ "klar-diff__text" ], ariaHidden ] (viewParts kind parts)
            , if missingNewline then
                Html.span [ Internal.cls [ "klar-diff__noeol" ], ariaHidden ] [ Html.text ctx.t.missingNewline ]

              else
                Html.text ""
            ]
        ]

    else
        [ numberCell [] kind number
        , markCell [] ctx kind focus
        , codeCell [] ctx kind parts missingNewline
        ]



-- JSON AND FIELDS


viewEntries : Ctx msg -> String -> Source -> List Entry -> Html msg
viewEntries ctx label source entries =
    let
        limit =
            visibleChanges ctx

        numbered =
            numberChanges entries

        shown =
            List.filter
                (\( index, entry ) ->
                    case index of
                        Just i ->
                            i < limit

                        Nothing ->
                            ctx.config.unchangedFields && entry.kind == Unchanged
                )
                numbered

        scrolls =
            ctx.interactive && ctx.config.maxHeight /= Nothing
    in
    scrollArea ctx
        label
        scrolls
        [ Keyed.ul
            [ Internal.cls
                [ "klar-diff__entries"
                , case source of
                    FromJson ->
                        "klar-diff__entries--json"

                    FromFields ->
                        "klar-diff__entries--fields"
                ]
            ]
            (List.map (\( index, entry ) -> ( entry.key, viewEntry ctx source index entry )) shown)
        ]


{-| The changed entries get their number among the changes, from 0; an entry that
did not change has none.
-}
numberChanges : List Entry -> List ( Maybe Int, Entry )
numberChanges entries =
    List.foldl
        (\entry ( next, built ) ->
            case entry.kind of
                Unchanged ->
                    ( next, ( Nothing, entry ) :: built )

                _ ->
                    ( next + 1, ( Just next, entry ) :: built )
        )
        ( 0, [] )
        entries
        |> Tuple.second
        |> List.reverse


viewEntry : Ctx msg -> Source -> Maybe Int -> Entry -> Html msg
viewEntry ctx source index entry =
    let
        t =
            ctx.t

        (State state) =
            ctx.state

        srOnly text =
            Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text text ]

        value side shown =
            case shown of
                Just found ->
                    viewShown ctx side found

                Nothing ->
                    Html.text ""

        ( sign, kindName, body ) =
            case entry.kind of
                Added ->
                    ( "+", "added", [ srOnly (t.addedWord ++ ": "), value (Just AddedRow) entry.after ] )

                Removed ->
                    ( "−", "removed", [ srOnly (t.removedWord ++ ": "), value (Just RemovedRow) entry.before ] )

                Changed ->
                    ( "~"
                    , "changed"
                    , [ srOnly (t.changedFrom ++ " ")
                      , value (Just RemovedRow) entry.before
                      , Html.span [ Internal.cls [ "klar-diff__arrow" ], ariaHidden ] [ Html.text "→" ]
                      , srOnly (" " ++ t.changedTo ++ " ")
                      , value (Just AddedRow) entry.after
                      ]
                    )

                Unchanged ->
                    ( "", "unchanged", [ srOnly (t.unchangedWord ++ ": "), value Nothing entry.after ] )

        current =
            index /= Nothing && index == state.current

        focusAttributes =
            case ( index, ctx.interactive ) of
                ( Just i, True ) ->
                    [ Attr.id (changeDomId state.id i), Attr.tabindex -1 ]

                _ ->
                    []
    in
    Html.li
        (Internal.cls
            [ "klar-diff__entry"
            , "klar-diff__entry--" ++ kindName
            , if current then
                "klar-diff__entry--current"

              else
                ""
            ]
            :: focusAttributes
        )
        [ case ( index, ctx.interactive ) of
            ( Just i, True ) ->
                srOnly (t.changeOf (i + 1) ctx.changeCount ++ ": ")

            _ ->
                Html.text ""
        , Html.span [ Internal.cls [ "klar-diff__entry-mark" ], ariaHidden ] [ Html.text sign ]
        , Html.span
            [ Internal.cls
                [ "klar-diff__entry-label"
                , case source of
                    FromJson ->
                        "klar-diff__entry-label--path"

                    FromFields ->
                        ""
                ]
            ]
            [ Html.text entry.label ]
        , srOnly ": "
        , Html.span [ Internal.cls [ "klar-diff__entry-values" ] ] body
        ]


{-| A value of an entry. A value that was added is an `ins` and one that was
removed a `del`; in a changed entry the parts that changed inside the value are.
-}
viewShown : Ctx msg -> Maybe RowKind -> Shown -> Html msg
viewShown ctx side shown =
    case shown of
        Text { parts, truncated } ->
            let
                whole =
                    String.concat (List.map .text parts)

                wrap content =
                    case side of
                        Just AddedRow ->
                            if List.any .changed parts then
                                content

                            else
                                [ Html.ins [ Internal.cls [ "klar-diff__ins", "klar-diff__ins--whole" ] ] content ]

                        Just RemovedRow ->
                            if List.any .changed parts then
                                content

                            else
                                [ Html.del [ Internal.cls [ "klar-diff__del", "klar-diff__del--whole" ] ] content ]

                        _ ->
                            content
            in
            if whole == "" then
                Html.span [ Internal.cls [ "klar-diff__value", "klar-diff__value--empty" ] ] [ Html.text ctx.t.emptyValue ]

            else
                Html.span [ Internal.cls [ "klar-diff__value" ] ]
                    (wrap (viewPartsWith (Maybe.withDefault ContextRow side) False parts)
                        ++ (if truncated then
                                [ Html.span [ Internal.cls [ "klar-diff__cut" ] ]
                                    [ Html.span [ ariaHidden ] [ Html.text "… " ]
                                    , Html.text ("(" ++ ctx.t.shortened ++ ")")
                                    ]
                                ]

                            else
                                []
                           )
                    )

        NotJson ->
            Html.span [ Internal.cls [ "klar-diff__value", "klar-diff__value--note" ] ] [ Html.text ctx.t.notJson ]

        TooDeep ->
            Html.span [ Internal.cls [ "klar-diff__value", "klar-diff__value--note" ] ] [ Html.text ctx.t.tooDeep ]



-- MORE CHANGES


viewFooter : Ctx msg -> Html msg
viewFooter ctx =
    case ctx.toMsg of
        Nothing ->
            -- a static view cannot show more: it says how many changes it left out
            if visibleChanges ctx < ctx.changeCount then
                Html.div [ Internal.cls [ "klar-diff__footer" ] ]
                    [ Html.span [ Internal.cls [ "klar-diff__footer-text", "klar-tabular" ] ]
                        [ Html.text (ctx.t.showing (visibleChanges ctx) ctx.changeCount) ]
                    ]

            else
                Html.text ""

        Just toMsg ->
            let
                visible =
                    visibleChanges ctx

                total =
                    ctx.changeCount

                t =
                    ctx.t

                step =
                    min (total - visible) ctx.config.maxChanges
            in
            if visible >= total then
                Html.text ""

            else
                Html.div [ Internal.cls [ "klar-diff__footer" ] ]
                    [ Html.span [ Internal.cls [ "klar-diff__footer-text", "klar-tabular" ] ] [ Html.text (t.showing visible total) ]
                    , Button.view
                        [ Button.small
                        , Button.ghost
                        , Button.onClick (toMsg (ShowMore (visible + step) visible))
                        ]
                        (t.showMore step)
                    , if total - visible <= 1000 && total - visible > step then
                        Button.view
                            [ Button.small
                            , Button.ghost
                            , Button.onClick (toMsg (ShowMore total visible))
                            ]
                            (t.showAll total)

                      else
                        Html.text ""
                    ]
