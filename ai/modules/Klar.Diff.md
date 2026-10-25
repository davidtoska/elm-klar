# Klar.Diff

What changed between two versions of a text, of a JSON document or of a record, shown so that a person can see it and decide.

Import: `import Klar.Diff as Diff` | Group: Text and change

Types: `Msg`, `Diff`, `Hunk`, `State`, `Attribute`, `JsonOption`, `TextOption`

## Signatures

```elm
-- Showing a diff
view : (Msg -> msg) -> List (Attribute msg) -> State -> Diff -> Html msg
viewStatic : List (Attribute msg) -> Diff -> Html msg

-- Making a diff
type Diff  -- opaque: no constructors are exposed
lines : List TextOption -> String -> String -> Diff
json : List JsonOption -> Json.Decode.Value -> Json.Decode.Value -> Diff
fields : List { label : String, before : Maybe String, after : Maybe String } -> Diff

-- Options of a text diff
type TextOption  -- opaque: no constructors are exposed
ignoreWhitespace : TextOption
ignoreCase : TextOption

-- Options of a JSON diff
type JsonOption  -- opaque: no constructors are exposed
matchBy : String -> JsonOption

-- Reading a diff
isEmpty : Diff -> Bool
tooLarge : Diff -> Bool
stats : Diff -> { added : Int, removed : Int, changed : Int }

-- Changes one by one
type Hunk  -- opaque: no constructors are exposed
hunks : Diff -> List Hunk
hunkKey : Hunk -> String
hunkBefore : Hunk -> Maybe String
hunkAfter : Hunk -> Maybe String

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
setSplit : Bool -> State -> State
isSplit : State -> Bool
currentHunk : Diff -> State -> Maybe Hunk
goToHunk : Diff -> String -> State -> ( State, Cmd Msg )

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
ariaLabel : String -> Attribute msg
context : Int -> Attribute msg
maxChanges : Int -> Attribute msg
maxHeight : Int -> Attribute msg
wrapLines : Attribute msg
showUnchangedFields : Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

What changed between two versions of a text, of a JSON document or of a
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

There are three ways to make a [`Diff`](#diff), and one way to show all of them.
`lines` compares two texts line by line (unified or side by side, with the
changed words marked inside a changed line), `json` compares two JSON values by
path (`items[2].price` changed from 12.5 to 14), and `fields` lists the fields of
a record that changed, with the text of each side, which is what an audit log needs.
Build the diff when the versions change and keep it in your model: comparing two
long texts is work, and showing a diff is not.

Use [Klar.Compare](Klar.Compare.md) when several records are shown side by side
and you want to see where they differ, and [Klar.JsonViewer](Klar.JsonViewer.md)
when there is only one JSON value.

## Showing a diff

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Diff -> Html msg
```

The viewer: a toolbar (the counts, the layout of a text diff, buttons to the
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

### `viewStatic`

```elm
viewStatic : List (Attribute msg) -> Diff -> Html msg
```

The viewer without state, for a diff in a list of many (an audit log, the history
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

## Making a diff

### `Diff`

```elm
type Diff  -- opaque: no constructors are exposed
```

The difference between two versions of something: a text, a JSON value or a
record. The type is opaque; make one with `lines`, `json` or `fields`, show it with
`view`, and ask it questions with `isEmpty`, `stats` and `hunks`. It holds the
result of the comparison and nothing else, so it can be kept in your model and
compared with `==`.

### `lines`

```elm
lines : List TextOption -> String -> String -> Diff
```

Compares two texts line by line, with the shortest set of changes.

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

### `json`

```elm
json : List JsonOption -> Json.Decode.Value -> Json.Decode.Value -> Diff
```

Compares two JSON values by path. Objects are compared key by key, arrays
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

### `fields`

```elm
fields : List { label : String, before : Maybe String, after : Maybe String } -> Diff
```

The fields of a record, with the text of each side, as they were and as they
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

### Options of a text diff

### `TextOption`

```elm
type TextOption  -- opaque: no constructors are exposed
```

A setting of a text diff. Make one with `ignoreWhitespace` or `ignoreCase`
and pass a list to `lines`.

### `ignoreWhitespace`

```elm
ignoreWhitespace : TextOption
```

Ignores differences in white space: indentation, trailing spaces, and a
space that became a tab or two spaces. Two lines that differ only in that are the
same line. Words that run together (`"a b"` and `"ab"`) are still different.
The viewer says that white space is ignored, so nobody mistakes the result for a
full comparison.

### `ignoreCase`

```elm
ignoreCase : TextOption
```

Ignores the difference between upper and lower case: `"Paid"` and `"PAID"`
are the same line. The viewer says that case is ignored.

### Options of a JSON diff

### `JsonOption`

```elm
type JsonOption  -- opaque: no constructors are exposed
```

A setting of a JSON diff. Make one with `matchBy` and pass a list to `json`.

### `matchBy`

```elm
matchBy : String -> JsonOption
```

Compares arrays of objects record by record instead of position by position:
the records of the two arrays that have the same value in this field (an `"id"`, a
`"sku"`) are compared with each other, wherever they stand, and the path says which
one (`lines[sku=A-100].qty`). Records that moved are not a change.

The field must hold a text or a number in every record of both arrays and be
different in every record of one array. For an array where that is not so, the
records are compared by position, as without this option.

## Reading a diff

### `isEmpty`

```elm
isEmpty : Diff -> Bool
```

Are the two versions the same? A diff of two equal texts, of two equal JSON
values or of fields that all kept their value is empty, and the viewer says "No
changes". A diff that became a summary because it is too large is not empty.

### `tooLarge`

```elm
tooLarge : Diff -> Bool
```

Did the comparison give up? A text diff that would take too long becomes a
summary of the two texts (see `lines`); it has no changes to show, `hunks` is
empty, and the viewer says that it is too large. Offer the two texts for download,
or compare smaller parts.

### `stats`

```elm
stats : Diff -> { added : Int, removed : Int, changed : Int }
```

How much changed, for a summary such as "+12 -4 ~3". `added` counts lines (or
values, or fields) that only the new version has, `removed` those that only the old
one has, and `changed` those that exist in both and differ: in a text, a removed
line that was replaced by an added line is one changed line. Taken together they
count every change once.

For a diff that became a summary (see `tooLarge`) the counts are those of the
summary: lines that occur in only one of the texts, wherever they stand, and no
changed lines.

### Changes one by one

### `Hunk`

```elm
type Hunk  -- opaque: no constructors are exposed
```

One change of a diff: a group of lines that were removed and added together,
a JSON value that was added, removed or changed, or a field that changed. Get them
with `hunks`. The type is opaque, so that more can be asked of a hunk in a later
version, and a hunk can be compared with `==`.

### `hunks`

```elm
hunks : Diff -> List Hunk
```

The changes of a diff, in the order they are shown. A diff that is empty or
became a summary has none. Fields that did not change are not changes.

### `hunkKey`

```elm
hunkKey : Hunk -> String
```

A key for the hunk that is the same every time the same two versions are
compared with the same options, and different for every hunk of a diff: use it to
remember a decision about the hunk (accepted, rejected) in a `Dict` or a `Set`. For
a text it says where the hunk is (`"12:3/14:2"`: three lines from line 12 of the old
text became two lines from line 14 of the new text), for JSON it is the path, for
fields the label. A path or a label that comes twice gets `~2` or `(2)` after it, so
that the keys of a diff are always different. It is meant for programs, not for people, and it changes when
the texts change, so a decision about a hunk stays valid only for the diff it was
made for.

### `hunkBefore`

```elm
hunkBefore : Hunk -> Maybe String
```

The text of the hunk in the old version, or `Nothing` when the old version has
nothing there (lines or a value that were added). The lines of a text are joined
with `\n`, a JSON value is written as one line of JSON, and a field has the text you
gave. A text that was cut for the viewer (a long JSON value) is cut here too.

### `hunkAfter`

```elm
hunkAfter : Hunk -> Maybe String
```

The text of the hunk in the new version, or `Nothing` when the new version has
nothing there (lines or a value that were removed). Written like `hunkBefore`.

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

What the viewer remembers: whether the side-by-side layout is chosen, which
runs of unchanged lines the user opened, how many changes are shown and which
change the user went to last. Make one with `init`, keep it in your model and give
it to `view` and `update`. It holds no functions and no diff, so a new diff can be
shown with the same state (the opened runs are remembered by where they start).

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of the viewer. Wrap them in a message of your own, give them to
`update` and use the same wrapper in `view`.

### `init`

```elm
init : String -> State
```

A state with the unified layout, no run of unchanged lines opened and the first
changes shown. The `String` is the DOM id of the viewer and the prefix of the ids
of the elements inside it, so it must be unique on the page.

    Diff.init "policy-diff"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles the buttons of the viewer: next and previous change, opening and
closing a run of unchanged lines, showing more changes and the layout. The
commands move the keyboard focus to the change the user went to, to the button of a
run of lines that was opened, or to the first change that appeared, so map them
with `Cmd.map`.

### `setSplit`

```elm
setSplit : Bool -> State -> State
```

Chooses the layout of a text diff: `True` shows the old and the new text side
by side (split), `False` one below the other (unified, the default). The user can
also choose it with the buttons in the toolbar. Other diffs have one layout.

### `isSplit`

```elm
isSplit : State -> Bool
```

Is the side-by-side layout chosen? Read it to remember the choice of the user.

### `currentHunk`

```elm
currentHunk : Diff -> State -> Maybe Hunk
```

The change the user went to last (with `n` and `p`, or the buttons "Next" and
"Previous"), in this diff, or `Nothing` before the first step. Use it to show a panel
for the change the user is on, such as "Accept" and "Reject" for that hunk, with
`hunkKey` to remember the decision.

    Diff.currentHunk model.policyDiff model.policyView
        |> Maybe.map Diff.hunkKey

### `goToHunk`

```elm
goToHunk : Diff -> String -> State -> ( State, Cmd Msg )
```

Goes to the change with this `hunkKey`, as if the user had stepped to it: it
becomes the current change, it is drawn even when it is after the first changes that
are shown, and the command moves the keyboard focus to it (map it with `Cmd.map`).
A key that is not in this diff changes nothing. Use it for a list of the changes next
to the viewer, or to go back to the change the user decided on last.

    ( state, cmd ) =
        Diff.goToHunk model.policyDiff key model.policyView

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the viewer. Make them with the functions below and pass a list to
`view` or `viewStatic`; later attributes win over earlier ones.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

The accessible name of the diff, such as "Changes to the shipping policy". It
names the area that scrolls, which screen readers announce as a region in `view` and
as a group in `viewStatic`; when nothing scrolls, it names the whole diff, as a group.
The default is "Changes".

### `context`

```elm
context : Int -> Attribute msg
```

How many unchanged lines are shown around each change in a text diff; the rest
are folded into a row that says how many they are and opens when it is pressed.
The default is 3, and the value is kept between 0 and 20.

### `maxChanges`

```elm
maxChanges : Int -> Attribute msg
```

How many changes are drawn before a row says "Showing 200 of 1,340 changes" and
offers to show more. The default is 200, and the value is kept between 10 and 5000.
It keeps a diff with thousands of changes fast. A block of more than 500 changed
lines is cut as well, after 500 lines, with a button that shows 500 more. `viewStatic`
has no buttons, so it draws at most 1,000 changes and 500 lines of a block, and says
how many it left out.

### `maxHeight`

```elm
maxHeight : Int -> Attribute msg
```

Scrolls inside the viewer when the diff is taller than this many pixels. By
default the viewer grows with its content. A diff of lines scrolls sideways inside
its own box in any case, never the page.

### `wrapLines`

```elm
wrapLines : Attribute msg
```

Wraps long lines of a text diff instead of scrolling sideways. Good for
prose, such as a policy; code is easier to read when it keeps its lines. With nothing
to scroll sideways, the box of the lines is a tab stop only when it has a `maxHeight`.

### `showUnchangedFields`

```elm
showUnchangedFields : Attribute msg
```

Shows the fields that did not change as well, muted, in a diff made with
`fields`. By default only the fields that changed are shown. It has no effect on
other diffs.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the toolbar, the rows that fold unchanged
lines, the counts and the notes. The default is `Locale.default`, which is English.
