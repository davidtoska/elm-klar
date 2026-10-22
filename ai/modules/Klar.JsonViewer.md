# Klar.JsonViewer

A collapsible tree for looking at JSON: an API response, a stored document, a request body.

Import: `import Klar.JsonViewer as JsonViewer` | Group: Data display

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List Attribute -> State -> Json.Decode.Value -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- Opening and closing
isExpanded : String -> State -> Bool
toggle : String -> State -> State
expandAll : State -> State
collapseAll : State -> State
setExpanded : List String -> State -> State

-- Attributes
type Attribute  -- opaque: no constructors are exposed
toolbar : Attribute
rootLabel : String -> Attribute
ariaLabel : String -> Attribute
maxHeight : Int -> Attribute
maxDepth : Int -> Attribute
maxItems : Int -> Attribute
maxStringLength : Int -> Attribute
locale : Locale.Locale -> Attribute
```

## Documentation

A collapsible tree for looking at JSON: an API response, a stored document,
a request body.

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
`/users/0/address` (the root is the empty path). By default the root and its
children are open. Every toggle is a real button with `aria-expanded`, so the
keyboard works with `Tab` and `Enter`. The tree is a nested list of buttons, not
an ARIA tree, so the arrow keys do not move between nodes.

There is no copy button: copying takes JavaScript, and the text is selectable.
For a short snippet that does not need exploring, `codeBlock` of
[Klar.Text](Klar.Text.md) is simpler.

## View

### `view`

```elm
view : (Msg -> msg) -> List Attribute -> State -> Json.Decode.Value -> Html msg
```

Shows a JSON value as a collapsible tree. The first argument wraps the
viewer's messages in one of yours. The state remembers what is open; the value
can change freely between renders. A value that cannot be shown at all gives a
short message instead ("The value cannot be shown." in English).

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

Handles opening and closing, "expand all", "collapse all" and "show more".
After "show more" it returns a command that puts the focus back on a button, so
map the command with `Cmd.map`.

## Opening and closing

### `isExpanded`

```elm
isExpanded : String -> State -> Bool
```

Is the node at this path open? The root is `""`, a child of the root is
`"/name"` and an array item is `"/items/0"`. In a key, `~` is written `~0` and
`/` is written `~1`, as in JSON Pointer.

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

### `setExpanded`

```elm
setExpanded : List String -> State -> State
```

Opens exactly these nodes and closes all others. Include the root (`""`) if
it should stay open.

    JsonViewer.setExpanded [ "", "/items" ] state

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of the viewer. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.

### `toolbar`

```elm
toolbar : Attribute
```

Shows "Expand all" and "Collapse all" buttons above the tree. There is no
toolbar by default.

### `rootLabel`

```elm
rootLabel : String -> Attribute
```

A name for the root node, shown as its key: `"response": { ... }`.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute
```

The accessible name of the tree, for example "API response". Give one when
nothing near the viewer names it. In a viewer with a `maxHeight` the name goes to
the scroll area as well, which then is a `region`.

### `maxHeight`

```elm
maxHeight : Int -> Attribute
```

Scrolls inside the viewer when the tree gets taller than this many pixels.
By default the viewer grows with its content.

A scrolling viewer can take the keyboard focus (`tabindex="0"`), so that
keyboard users can scroll it with the arrow keys. With an `ariaLabel` the scroll
area is also a `region` with that name.

### `maxDepth`

```elm
maxDepth : Int -> Attribute
```

Objects and arrays nested deeper than this are shown as `{ ... }` or
`[ ... ]` and cannot be opened. The default is 12, and the value is kept between
1 and 100.

### `maxItems`

```elm
maxItems : Int -> Attribute
```

How many entries of one object or array are shown before a "Show N more"
row. The default is 100, and the value is kept between 5 and 5000.

### `maxStringLength`

```elm
maxStringLength : Int -> Attribute
```

Strings longer than this many characters are cut and end in "...". The
tooltip has the start of the whole string (at most 4000 characters). The default
is 140, and the value is kept between 10 and 5000.

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

The language of the built-in text: the toolbar buttons, the "Show N more"
row, the counts of keys and items, and the messages. The default is
`Locale.default`, which is English.
