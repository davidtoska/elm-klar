# Klar.Splitter

Two or more panes side by side (or one above the other) that the user can make larger and smaller by moving the separators between them, with the mouse, a finger or the keyboard.

Import: `import Klar.Splitter as Splitter` | Group: Arranging

Types: `Msg`, `Pane`, `Share`, `State`, `Attribute`

## Signatures

```elm
-- View
type Pane msg  -- opaque: no constructors are exposed
view : (Msg -> msg) -> List Attribute -> State -> List (Pane msg) -> Html msg
pane : String -> Html msg -> Pane msg
minSize : Share -> Pane msg -> Pane msg
maxSize : Share -> Pane msg -> Pane msg
minPixels : Int -> Pane msg -> Pane msg
maxPixels : Int -> Pane msg -> Pane msg
collapsible : Pane msg -> Pane msg

-- State and messages
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> List Share -> State
update : Msg -> State -> ( State, Cmd Msg )
sizes : State -> List Share
setSizes : List Share -> State -> State
isDragging : State -> Bool

-- Shares
type Share  -- opaque: no constructors are exposed
percent : Float -> Share
toPercent : Share -> Float

-- Attributes
type Attribute  -- opaque: no constructors are exposed
stacked : Attribute
height : Int -> Attribute
fillRest : Attribute
locale : Locale.Locale -> Attribute
```

## Documentation

Two or more panes side by side (or one above the other) that the user can make
larger and smaller by moving the separators between them, with the mouse, a finger
or the keyboard.

Use when: the user should resize a master and its detail, a navigator beside a work area or an editor above a preview.
Do not use when: the layout is fixed, use `Klar.Layout`, or when sections only open and close, use `Klar.Accordion`.
Quick path: `init`, `update`, `view`, `sizes`

    import Klar.Splitter as Splitter

    -- model: split : Splitter.State
    -- init:  Splitter.init "orders-split" [ Splitter.percent 35, Splitter.percent 65 ]

    -- update
    SplitterMsg m ->
        let
            ( split, cmd ) =
                Splitter.update m model.split
        in
        ( { model | split = split }, Cmd.map SplitterMsg cmd )

    -- view
    Splitter.view SplitterMsg
        [ Splitter.height 420 ]
        model.split
        [ Splitter.pane "Orders" (viewOrderList model) |> Splitter.minPixels 240
        , Splitter.pane "Details" (viewOrderDetail model) |> Splitter.minPixels 320
        ]

Use it for a master and its detail, a navigator beside a work area, an editor above
a preview. Panes can hold another splitter. For a page with a fixed layout that the
user does not change, use [Klar.Layout](Klar.Layout.md); for sections that open and
close, [Klar.Accordion](Klar.Accordion.md).

The state keeps the sizes, as shares of the room the panes have together (the
width of the container without the separators), from 0 to 100 percent, always
adding up to 100. Shares, not pixels, are kept, so a layout follows the window when
it is resized. Read them with `sizes` and give them back with `setSizes` to save and
restore the layout of the user. The number of sizes should be the number of panes;
when it is not (a detail pane that comes and goes), the panes that have no size get
an equal share and the others keep their proportions. Panes are matched by place:
the first pane is the first size.

Each pane has a name, which names its separator for screen readers ("Resize
Orders"). A pane can have a smallest and a largest size, in percent of the room or in
pixels, and can be `collapsible`. The panes scroll inside themselves when their
content is larger than they are; a pane that has nothing in it that can take the focus
is scrolled with the keyboard in current Chrome and Firefox, which make a scrolling
box focusable, but not in every browser, so give such a pane a button or a link if it
matters. The container needs a height (give the parent one, or use `height`).

Keyboard: a separator is a tab stop. `Left` and `Right` move it by 1 percent (`Up`
and `Down` when the panes are `stacked`), with `Shift` by 10 percent, `Home` and
`End` give the pane before it its smallest and its largest size. `Enter` (and a
double click) folds a `collapsible` pane away and opens it again. `Escape` cancels a
drag. The separator has the role `separator` with its value in percent, so a screen
reader says "Resize Orders, separator, 40 percent" and nothing else: no
announcements of ours.

Pointer: press a separator and drag; the panes follow at once. The separator never
goes beyond what the two panes beside it allow, and the others keep their size. A
mouse that is let go outside the window ends the drag when it comes back. The
component uses pointer events (and not the HTML5 drag and drop), so a finger or a
pen works too. It needs no subscription: once the mouse has moved, a transparent
layer over the window receives the events and gives the window one cursor and no
text selection.

Limits: a limit in pixels is checked against the container as it was when the user
last pressed or focused a separator; between then and the next time, the stylesheet
keeps the panes from being drawn smaller than their `minPixels` (and larger than
their `maxPixels`), but the sizes that `sizes` gives are the last ones that the
user's own movement set. Only the two panes beside a separator change when it
moves, and the content of every pane is drawn all the time, also in a pane that is
folded away. Right-to-left languages are not mirrored yet.

## View

### `Pane`

```elm
type Pane msg  -- opaque: no constructors are exposed
```

One pane: a name and what to draw. Refine it with `minSize`, `maxSize`,
`minPixels`, `maxPixels` and `collapsible`.

### `view`

```elm
view : (Msg -> msg) -> List Attribute -> State -> List (Pane msg) -> Html msg
```

The splitter. It takes the constructor that wraps the messages, the attributes,
the state and the panes, in order. One pane is drawn on its own; no panes give an
empty splitter.

    Splitter.view SplitterMsg
        [ Splitter.height 420 ]
        model.split
        [ Splitter.pane "Orders" ordersView
        , Splitter.pane "Details" detailView |> Splitter.collapsible
        ]

### `pane`

```elm
pane : String -> Html msg -> Pane msg
```

A pane. The name is what screen readers call it and what names the separator
after it ("Resize Orders"), so it is required. The `Html` is drawn inside the pane,
which scrolls when the content is larger than it.

    Splitter.pane "Orders" (viewOrderList model)

### `minSize`

```elm
minSize : Share -> Pane msg -> Pane msg
```

The smallest share of the room the pane may have. The default is no smallest
size. With `minPixels` as well, the larger of the two counts. A smallest size that is
above the largest (`maxSize`, `maxPixels`) wins: the largest is raised to it, so a
pane can never be asked for something that cannot be.

### `maxSize`

```elm
maxSize : Share -> Pane msg -> Pane msg
```

The largest share of the room the pane may have. The default is no largest
size. With `maxPixels` as well, the smaller of the two counts. When it is below the
smallest size, the smallest size wins.

### `minPixels`

```elm
minPixels : Int -> Pane msg -> Pane msg
```

The smallest width (the smallest height in a `stacked` splitter) of the pane in
pixels. A number below 0 counts as 0.

### `maxPixels`

```elm
maxPixels : Int -> Pane msg -> Pane msg
```

The largest width (height when `stacked`) of the pane in pixels. A number below
0 counts as 0.

### `collapsible`

```elm
collapsible : Pane msg -> Pane msg
```

The pane can be folded away. `Enter` on the separator next to it, or a double
click, folds it (its room goes to the pane on the other side of the separator) and
opens it again. A folded pane has no room at all and is hidden from the keyboard and
from screen readers; its size is 0 in `sizes`, so a saved layout comes back folded.
A pane that is open keeps at least 2 percent of the room, so that it can not be
dragged shut by accident. A pane that is not `collapsible` never has no room, except
when it is given none.

## State and messages

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The sizes of the panes and what the user is doing with a separator right now.
Make one with `init`, keep it in your model, pass every `Msg` through `update`, and
read the sizes with `sizes`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

A message of the splitter. Wrap it in a constructor of your own message type
(`SplitterMsg`), pass that to `view`, and hand the messages you get back to
`update`.

### `init`

```elm
init : String -> List Share -> State
```

A splitter with these sizes, one for each pane. The sizes are shares of the room
and are scaled to add up to 100 percent, whatever they add up to now: 30 and 30
become 50 and 50. A size that is 0 gives a pane that is folded away (if it is
`collapsible`) or has no room. The `String` is a DOM id prefix and must be unique on
the page: the container, the panes and the separators get ids that start with it.

    Splitter.init "orders-split" [ Splitter.percent 35, Splitter.percent 65 ]

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Follows the user: a separator that is pressed, dragged, moved with the keys or
folded away. The command measures the container when a drag begins or a separator
gets the focus, and moves the focus to the separator that is pressed, so map it
with `Cmd.map` like any other child. To react to the new sizes, compare `sizes`
before and after.

### `sizes`

```elm
sizes : State -> List Share
```

The sizes of the panes now, in percent, adding up to 100. Compare them before and
after an `update` to save them when the user has moved a separator. While a
separator is dragged they change with every movement; `isDragging` tells when it is
done. A list that is shorter or longer than the number of panes is only brought in
line when the user moves a separator.

### `setSizes`

```elm
setSizes : List Share -> State -> State
```

Sets the sizes of all the panes, for example to restore a saved layout, or
`[ percent 0, percent 100 ]` to fold the first pane away. They are scaled to add up
to 100 percent, like those of `init`.

### `isDragging`

```elm
isDragging : State -> Bool
```

Is a separator being dragged with the mouse, a finger or a pen right now?

## Shares

### `Share`

```elm
type Share  -- opaque: no constructors are exposed
```

A share of the room that the panes have together, from 0 to 100 percent. Make
one with `percent`.

### `percent`

```elm
percent : Float -> Share
```

A share in percent. A number below 0 counts as 0, above 100 as 100, and what is
not a number as 0.

    Splitter.percent 35

### `toPercent`

```elm
toPercent : Share -> Float
```

The share in percent, from 0 to 100.

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of the splitter. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `stacked`

```elm
stacked : Attribute
```

The panes lie one above the other, with horizontal separators, instead of side
by side. The keyboard then moves a separator with `Up` and `Down`. The default is
side by side.

### `height`

```elm
height : Int -> Attribute
```

The height of the splitter in pixels. Without it the splitter is as high as its
parent, which must then have a height of its own; a splitter inside a pane of
another splitter does not need one. A `stacked` splitter needs a height to be able
to divide anything.

### `fillRest`

```elm
fillRest : Attribute
```

Makes the splitter as high as the room that is left in its parent, instead of
as high as the parent (which must have a height of its own) or a number of pixels.
Use it in a `Layout.stack [ Layout.fillRest ]`, so that a navigator beside a work
area fills the window under the page header with no pixel height; see
`Layout.fillRest`. It overrides `height`.

    Layout.stack [ Layout.fillRest ]
        [ PageHeader.view [ PageHeader.title "Stock" ]
        , Splitter.view SplitterMsg [ Splitter.fillRest ] model.split panes
        ]

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

The language of the built-in text: "Resize" in the name of a separator and the
value ("40 percent"). The default is `Locale.default`, which is English. See
[Klar.Locale](Klar.Locale.md).
