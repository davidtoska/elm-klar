# Klar.JsonViewer

A collapsible tree for looking at JSON: an API response, a stored document, a request body.

Import: `import Klar.JsonViewer as JsonViewer` | Group: Data display

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute msg) -> State -> Json.Decode.Value -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- Opening and closing
isExpanded : String -> State -> Bool
expand : String -> State -> State
collapse : String -> State -> State
toggle : String -> State -> State
expandAll : State -> State
collapseAll : State -> State
expandedIds : Json.Decode.Value -> State -> List String
setExpandedIds : List String -> State -> State
path : List String -> String

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
toolbar : Attribute msg
rootLabel : String -> Attribute msg
ariaLabel : String -> Attribute msg
maxHeight : Int -> Attribute msg
maxDepth : Int -> Attribute msg
maxItems : Int -> Attribute msg
maxStringLength : Int -> Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

A collapsible tree for looking at JSON: an API response, a stored document,
a request body.

Use when: the application shows a JSON value, such as an API response or a stored document, that the user needs to explore.
Do not use when: a short snippet is enough (`codeBlock` of `Klar.Text`); or the value is still on its way, put the viewer inside `Klar.RemoteView`.
Quick path: `init`, `update`, `view`

    import Json.Decode as Decode
    import Klar.JsonViewer as JsonViewer

    -- in your model
    { response : Decode.Value
    , viewer : JsonViewer.State -- JsonViewer.init "response-viewer"
    }

    -- in update
    ViewerMsg viewerMsg ->
        let
            ( viewer, cmd ) =
                JsonViewer.update viewerMsg model.viewer
        in
        ( { model | viewer = viewer }, Cmd.map ViewerMsg cmd )

    -- in view
    JsonViewer.view ViewerMsg
        [ JsonViewer.toolbar, JsonViewer.rootLabel "response" ]
        model.viewer
        model.response

The value is a `Json.Decode.Value`, for example the result of decoding a
response with `Json.Decode.value`. The viewer decodes it into a small tree of
its own (object, array, string, number, boolean, null) on every render, so the
value can change freely between renders. Keys are blue and values have muted
colors. Long strings are cut, with the start of the whole text in a tooltip, and
an object or array with more than `maxItems` entries shows the first rows and a
"Show 100 more" row. Thin gray lines follow the indentation.

The state remembers which nodes the user opened or closed, as paths like
`/users/0/address` (the root is the empty path; `path` writes one for you). By
default the root and its children are open.

The viewer is an ARIA tree (`role="tree"`, `treeitem`, `group`, `aria-expanded`,
`aria-level`) with one tab stop. The arrow keys move between the rows: Down and Up
to the next and previous row, Right opens a node (or goes to its first child),
Left closes it (or goes to its parent), Home and End to the first and the last
row, and Enter or Space opens and closes a node or shows more rows. The row that
had the focus keeps it when the value changes, as long as it is still there.

There is no copy button: copying takes JavaScript, and the text of every row,
keys included, is selectable. For a short snippet that does not need exploring,
`codeBlock` of [Klar.Text](Klar.Text.md) is simpler.

The value is shown as Elm decodes it: a number goes through a `Float`, so an
integer beyond 2^53 is rounded and `1.10` is written `1.1`, and the browser puts
keys that look like integers first. For an inspector that must show the text the
server sent byte for byte, show that text with `codeBlock` instead.

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Json.Decode.Value -> Html msg
```

Shows a JSON value as a collapsible tree. The first argument wraps the
viewer's messages in one of yours. The state remembers what is open and which row
has the focus; the value can change freely between renders. A value that cannot
be shown at all gives a short message instead ("The value cannot be shown." in
English).

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

What the viewer remembers: which nodes the user opened or closed, and how
many extra rows of long objects and arrays were revealed. Make one with `init`,
keep it in your model and give it to `view` and `update`.

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

A state with the first two levels open: the root and its direct children.
The `String` is the DOM id of the viewer and the prefix of the ids of its
buttons, so it must be unique on the page.

    JsonViewer.init "response-viewer"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles opening and closing, the arrow keys, "expand all", "collapse all" and
"show more". Moving with the keys and "show more" return a command that puts the
focus on a row, so map the command with `Cmd.map`.

## Opening and closing

### `isExpanded`

```elm
isExpanded : String -> State -> Bool
```

Is the node at this path open? The root is `""`, a child of the root is
`"/name"` and an array item is `"/items/0"`. In a key, `~` is written `~0` and
`/` is written `~1`, as in JSON Pointer; `path` does that for you.

### `expand`

```elm
expand : String -> State -> State
```

Opens the node at this path and every node above it, so that it can be seen.
Nothing else changes.

    JsonViewer.expand (JsonViewer.path [ "items", "3", "error" ]) state

### `collapse`

```elm
collapse : String -> State -> State
```

Closes the node at this path. Nothing else changes.

### `toggle`

```elm
toggle : String -> State -> State
```

Opens the node at this path (see `isExpanded`) if it is closed and closes it
if it is open.

### `expandAll`

```elm
expandAll : State -> State
```

Opens every node. This is what the "Expand all" button of the `toolbar`
does.

### `collapseAll`

```elm
collapseAll : State -> State
```

Closes every node except the root. This is what the "Collapse all" button of
the `toolbar` does.

### `expandedIds`

```elm
expandedIds : Json.Decode.Value -> State -> List String
```

The paths of the open objects and arrays of this value, in document order:
what to keep when the application stores the view, and to give back with
`setExpandedIds`. The value is needed because a fresh state opens nodes by their
depth (the first two levels, after `init`; every level, after `expandAll`) rather
than by name. A node inside a closed one counts if it is open itself, as with
`isExpanded`.

    JsonViewer.setExpandedIds (JsonViewer.expandedIds value state) state -- the same view

### `setExpandedIds`

```elm
setExpandedIds : List String -> State -> State
```

Opens exactly these nodes and closes all others. Include the root (`""`) if
it should stay open; use `expand` to open a deep node with everything above it.

    JsonViewer.setExpandedIds [ "", "/items" ] state

### `path`

```elm
path : List String -> String
```

The path of a node, from the keys and array positions that lead to it, with
`~` and `/` in a key written as JSON Pointer wants them.

    JsonViewer.path [ "items", "3", "error" ] -- "/items/3/error"

    JsonViewer.path [ "a/b" ] -- "/a~1b"

    JsonViewer.path [] -- "", the root

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the viewer. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.

### `toolbar`

```elm
toolbar : Attribute msg
```

Shows "Expand all" and "Collapse all" buttons above the tree. There is no
toolbar by default.

### `rootLabel`

```elm
rootLabel : String -> Attribute msg
```

A name for the root node, shown as its key: `"response": { ... }`.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute msg
```

The accessible name of the tree, for example "API response". The default is
"JSON". Give one when the page has more than one viewer.

### `maxHeight`

```elm
maxHeight : Int -> Attribute msg
```

Scrolls inside the viewer when the tree gets taller than this many pixels.
By default the viewer grows with its content. The keyboard scrolls it by moving
from row to row: the row with the focus is always scrolled into view.

### `maxDepth`

```elm
maxDepth : Int -> Attribute msg
```

Objects and arrays nested deeper than this are shown as `{ ... }` or
`[ ... ]` and cannot be opened. The default is 12, and the value is kept between
1 and 100.

### `maxItems`

```elm
maxItems : Int -> Attribute msg
```

How many entries of one object or array are shown before a "Show N more"
row. The default is 100, and the value is kept between 5 and 5000.

### `maxStringLength`

```elm
maxStringLength : Int -> Attribute msg
```

Strings longer than this many characters are cut and end in "...", followed
by "Show all": a click on it, or Enter on the row, shows the whole string. The
tooltip has the start of the whole string (at most 4000 characters). The default
is 140, and the value is kept between 10 and 5000.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the toolbar buttons, the "Show N more"
row, the counts of keys and items, and the messages. The default is
`Locale.default`, which is English.
