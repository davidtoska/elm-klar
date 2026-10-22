# Klar.Accordion

Sections that open and close: the details of a record, groups of settings, advanced filters.

Import: `import Klar.Accordion as Accordion` | Group: Structure

Types: `Msg`, `State`, `Section`, `Attribute`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- Sections
type Section msg  -- opaque: no constructors are exposed
section : String -> String -> List (Html msg) -> Section msg
lazySection : String -> String -> (() -> List (Html msg)) -> Section msg
withSubtitle : String -> Section msg -> Section msg
withIcon : Icon.Icon -> Section msg -> Section msg
withCount : Int -> Section msg -> Section msg
withBadge : Html msg -> Section msg -> Section msg
disabledSection : Section msg -> Section msg

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
sections : List (Section msg) -> Attribute msg
multiple : Attribute msg
bordered : Attribute msg
flush : Attribute msg
small : Attribute msg
headingLevel : Int -> Attribute msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
setMultiple : Bool -> State -> State
isOpen : String -> State -> Bool
openKeys : State -> List String
open : String -> State -> State
openMany : List String -> State -> State
close : String -> State -> State
closeAll : State -> State
toggle : String -> State -> State
update : Msg -> State -> ( State, Cmd Msg )
```

## Documentation

Sections that open and close: the details of a record, groups of settings,
advanced filters.

Use when: sections of content should open and close in place, such as the details of a record or groups of settings.
Do not use when: the sections are views the user switches between (use `Klar.Tabs`).
Quick path: `init`, `update`, `view`, `isOpen`, `open`, `closeAll`

    import Klar.Accordion as Accordion

    -- model: accordion : Accordion.State
    -- init:  Accordion.init "order-sections"

    -- update
    AccordionMsg m ->
        let
            ( accordion, cmd ) =
                Accordion.update m model.accordion
        in
        ( { model | accordion = accordion }, Cmd.map AccordionMsg cmd )

    -- view
    Accordion.view AccordionMsg
        [ Accordion.sections
            [ Accordion.section "shipping" "Shipping address" [ shippingView model ]
            , Accordion.section "items" "Line items" [ itemsView model ]
                |> Accordion.withCount 4
            , Accordion.lazySection "log" "Activity log" (\_ -> [ logView model ])
            , Accordion.section "billing" "Billing" [ billingView model ]
                |> Accordion.disabledSection
            ]
        ]
        model.accordion

By default opening a section closes the others; `setMultiple True` on the state
lets several stay open. The body of a closed section is not rendered at all.
`section` still builds its content eagerly (Elm is strict), `lazySection` takes a
function so that the content of a closed section is never computed.

The state is the list of open section keys and that mode. Read it with `isOpen`
and `openKeys`, and change it from the application with `open`, `openMany`,
`close`, `closeAll` and `toggle`, for instance to open the section that holds a
field with an error. `open`, `toggle` and a click on a header all follow the mode
of the state, so they never disagree: in the default mode they leave only the
opened section open, after `setMultiple True` they leave the others alone.
`openMany` sets exactly which sections are open, whatever the mode. The
`multiple` attribute of `view` still works, but it only affects clicks, so prefer
`setMultiple`.

Each header is a button inside a heading (level 3 unless you set `headingLevel`)
with `aria-expanded`. With six sections or fewer an open body is also a `region`
named by its header; with more, the bodies are left out of the landmarks so that
the page does not get a long list of them.

Keyboard: Enter and Space toggle the focused header. Arrow Up and Down move to
the previous and next enabled header, wrapping around at the ends, Home and End
to the first and last.

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

The accordion. The first argument wraps the accordion's `Msg` in your own
message type. Closed sections render only their header.

## Sections

### `Section`

```elm
type Section msg  -- opaque: no constructors are exposed
```

One section of the accordion: a header and a body. Make it with `section` or
`lazySection` and refine it with `withSubtitle`, `withIcon`, `withCount`,
`withBadge` and `disabledSection`. The `msg` is the message type of the Html in
the body and in `withBadge`.

### `section`

```elm
section : String -> String -> List (Html msg) -> Section msg
```

A section: the key, the title and the content of its body. The key identifies
the section in the state (`isOpen`, `open` and the others) and must be unique
within the accordion; the title is the text of the header.

    Accordion.section "shipping" "Shipping address" [ shippingView model ]

### `lazySection`

```elm
lazySection : String -> String -> (() -> List (Html msg)) -> Section msg
```

Like `section`, but the content is a function that is only called while the
section is open, so the content of a closed section is never computed. Use it for
bodies that are expensive to build.

    Accordion.lazySection "log" "Activity log" (\_ -> [ logView model ])

### `withSubtitle`

```elm
withSubtitle : String -> Section msg -> Section msg
```

A line of small gray text in the header, after the title. It is cut with an
ellipsis when the header is too narrow.

### `withIcon`

```elm
withIcon : Icon.Icon -> Section msg -> Section msg
```

An icon before the title. It is decorative: the title still names the header.

### `withCount`

```elm
withCount : Int -> Section msg -> Section msg
```

A small number pill at the right end of the header, such as the number of
items in the section. It is shown as it is, without shortening large numbers.

### `withBadge`

```elm
withBadge : Html msg -> Section msg -> Section msg
```

Any badge or status at the right end of the header, after the count if there
is one.

    Accordion.section "billing" "Billing" [ billingView model ]
        |> Accordion.withBadge (Badge.view [ Badge.tone Warning ] "Overdue")

### `disabledSection`

```elm
disabledSection : Section msg -> Section msg
```

Visible but cannot be opened: the header is a disabled button and the arrow
keys skip it. A disabled section is shown closed even when its key is in the
state.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the accordion. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `sections`

```elm
sections : List (Section msg) -> Attribute msg
```

The sections, from top to bottom. Their keys must be unique.

### `multiple`

```elm
multiple : Attribute msg
```

Lets several sections stay open when the user clicks headers. It is the same
as `setMultiple True` on the state, but only for clicks: `open` and `toggle` obey
the state alone, so prefer `setMultiple`. Without either, a click on the header of
a closed section opens that section and closes all the others.

### `bordered`

```elm
bordered : Attribute msg
```

A thin gray border around the whole accordion and a line between the sections,
on a white background. This is the default; it undoes an earlier `flush`.

### `flush`

```elm
flush : Attribute msg
```

No outer border and no background, only a thin line under each section and
above the first one. For use inside a card or a drawer.

### `small`

```elm
small : Attribute msg
```

Lower headers with smaller text, for dense panels.

### `headingLevel`

```elm
headingLevel : Int -> Attribute msg
```

The level, 1 to 6, of the heading element that wraps each header button
(`h3` by default; other numbers are moved into that range). Pick the level that
fits below the headings of the page around the accordion, so that the outline of
the page stays correct.

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of an accordion: the keys of the open sections, and whether several
may be open at once. Make one with `init`, keep it in your model, and give it to
`view`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of an accordion: a header was clicked, an arrow key was pressed.
Wrap it in a constructor of your own message type, pass that constructor to
`view`, and hand the messages you get back to `update`.

### `init`

```elm
init : String -> State
```

An accordion with every section closed, in the default mode: opening a section
closes the others. The id must be unique on the page: it is the prefix of the DOM
ids of the headers and bodies.

    Accordion.init "order-sections"

### `setMultiple`

```elm
setMultiple : Bool -> State -> State
```

Sets the mode of the state. With `True` several sections can be open at once;
with `False`, the default, opening a section closes the others. `open`, `toggle`
and a click on a header all follow it. Sections that are open now stay open.

    Accordion.init "order-sections" |> Accordion.setMultiple True

### `isOpen`

```elm
isOpen : String -> State -> Bool
```

Whether the section with this key is open.

### `openKeys`

```elm
openKeys : State -> List String
```

The keys of the open sections, in the order they were opened. Save them to
restore the accordion later with `openMany`.

### `open`

```elm
open : String -> State -> State
```

Opens one section, like a click on its header does: in the default mode the
other sections are closed, after `setMultiple True` they stay as they are. Use
`openMany` to set exactly which sections are open.

### `openMany`

```elm
openMany : List String -> State -> State
```

Opens exactly these sections and closes all the others, whatever the mode, for
example to restore what the user had open.

### `close`

```elm
close : String -> State -> State
```

Closes one section.

### `closeAll`

```elm
closeAll : State -> State
```

Closes every section.

### `toggle`

```elm
toggle : String -> State -> State
```

Opens a closed section, as `open` does, and closes an open one, like a click on
its header does. In the default mode opening a section closes the others.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Opens and closes sections when their headers are clicked, and moves keyboard
focus between the headers. The `Cmd` does the focus move, so map it with your
message constructor.
