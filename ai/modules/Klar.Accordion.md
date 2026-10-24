# Klar.Accordion

Sections that open and close in place: the details of a record, groups of settings, advanced filters.

Import: `import Klar.Accordion as Accordion` | Group: Structure

Types: `Msg`, `State`, `Section`, `Attribute`

## Signatures

```elm
-- View
view : (Msg key -> msg) -> List (Attribute msg) -> State key -> List (Section key msg) -> Html msg

-- Sections
type Section key msg  -- opaque: no constructors are exposed
section : Ids.Ids key -> key -> String -> List (Html msg) -> Section key msg
lazySection : Ids.Ids key -> key -> String -> (() -> List (Html msg)) -> Section key msg
withSubtitle : String -> Section key msg -> Section key msg
withIcon : Icon.Icon -> Section key msg -> Section key msg
withCount : Int -> Section key msg -> Section key msg
withBadge : Html msg -> Section key msg -> Section key msg
disabledSection : Section key msg -> Section key msg

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
bordered : Attribute msg
flush : Attribute msg
small : Attribute msg
headingLevel : Int -> Attribute msg

-- State
type State key  -- opaque: no constructors are exposed
type Msg key  -- opaque: no constructors are exposed
init : String -> State key
setMultiple : Bool -> State key -> State key
update : Msg key -> State key -> ( State key, Cmd (Msg key) )

-- Open sections
isExpanded : key -> State key -> Bool
expandedIds : State key -> List key
expand : key -> State key -> State key
collapse : key -> State key -> State key
toggle : key -> State key -> State key
expandAll : List (Section key msg) -> State key -> State key
collapseAll : State key -> State key
setExpandedIds : List key -> State key -> State key
```

## Documentation

Sections that open and close in place: the details of a record, groups of
settings, advanced filters.

Use when: sections of content should open and close in place, such as the details of a record or groups of settings.
Do not use when: the sections are views the user switches between (use `Klar.Tabs`), or one block of content opens on its own (a `Klar.Card` with a button of your own).
Quick path: `init`, `update`, `view`, `section`, `isExpanded`, `expand`

    import Klar.Accordion as Accordion
    import Klar.Ids as Ids exposing (Ids)

    type OrderSection
        = Shipping
        | Items
        | Log

    sectionIds : Ids OrderSection
    sectionIds =
        Ids.list
            (\key ->
                case key of
                    Shipping ->
                        "shipping"

                    Items ->
                        "items"

                    Log ->
                        "log"
            )
            [ Shipping, Items, Log ]

Then the model, the update and the view:

    -- model: accordion : Accordion.State OrderSection
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
        []
        model.accordion
        [ Accordion.section sectionIds Shipping "Shipping address" [ shippingView model ]
        , Accordion.section sectionIds Items "Line items" [ itemsView model ]
            |> Accordion.withCount 4
        , Accordion.lazySection sectionIds Log "Activity log" (\_ -> [ logView model ])
        ]

The sections are keyed by a type of your own (`OrderSection`), compared with
`==`, so a typo is a compile error and not a section that silently never opens.
The [Klar.Ids](Klar.Ids.md) writes a key as text once, for the DOM ids of the
headers and bodies; plain text keys take `Ids.string`.

By default opening a section closes the others; `setMultiple True` on the state
lets several stay open. The state is the list of open sections and that mode.
Read it with `isExpanded` and `expandedIds`, and change it from the application
with `expand`, `collapse`, `toggle`, `expandAll`, `collapseAll` and
`setExpandedIds`, for instance to open the section that holds a field with an
error. `expand`, `toggle` and a click on a header all follow the mode of the
state, so they never disagree: in the default mode they leave only the opened
section open, after `setMultiple True` they leave the others alone.
`setExpandedIds` and `expandAll` set exactly which sections are open, whatever the
mode.

The body of a closed `section` stays in the page, hidden (`hidden="until-found"`):
the find-in-page of the browser finds its text, and a link to an id inside it
opens the section by itself (in Chrome and Edge; elsewhere it is plain hidden). A
`lazySection` takes a function, so the content of a closed one is never computed
and not in the page.

Each header is a button inside a heading (level 3 unless you set `headingLevel`)
with `aria-expanded`. With six sections or fewer a body is also a `region` named
by its header; with more, the bodies are left out of the landmarks so that the
page does not get a long list of them. The sections are keyed, so a section that
appears above the focused header does not move the focus to another section.

Keyboard: Enter and Space toggle the focused header. Arrow Up and Down move to
the previous and next enabled header, wrapping around at the ends, Home and End
to the first and last.

## View

### `view`

```elm
view : (Msg key -> msg) -> List (Attribute msg) -> State key -> List (Section key msg) -> Html msg
```

The accordion: the constructor that wraps its messages, the attributes, the
state and the sections from top to bottom (their keys must be unique).

## Sections

### `Section`

```elm
type Section key msg  -- opaque: no constructors are exposed
```

One section of the accordion: a header and a body. Make it with `section` or
`lazySection` and refine it with `withSubtitle`, `withIcon`, `withCount`,
`withBadge` and `disabledSection`. The `key` is your type of section keys, the
`msg` the message type of the Html in the body and in `withBadge`.

### `section`

```elm
section : Ids.Ids key -> key -> String -> List (Html msg) -> Section key msg
```

A section: the `Ids` of your key type, the key, the title and the content of
its body. The key identifies the section in the state (`isExpanded`, `expand` and
the others) and must be unique within the accordion; the title is the text of the
header.

    Accordion.section sectionIds Shipping "Shipping address" [ shippingView model ]

The body of a closed section stays in the page, hidden, so that find-in-page
reaches it (see the top of this page). Use `lazySection` for a body that is
expensive to build.

### `lazySection`

```elm
lazySection : Ids.Ids key -> key -> String -> (() -> List (Html msg)) -> Section key msg
```

Like `section`, but the content is a function that is only called while the
section is open, so the content of a closed section is never computed and not in
the page. Use it for bodies that are expensive to build.

    Accordion.lazySection sectionIds Log "Activity log" (\_ -> [ logView model ])

### `withSubtitle`

```elm
withSubtitle : String -> Section key msg -> Section key msg
```

A line of small gray text in the header, after the title. It is cut with an
ellipsis when the header is too narrow.

### `withIcon`

```elm
withIcon : Icon.Icon -> Section key msg -> Section key msg
```

An icon before the title. It is decorative: the title still names the header.

### `withCount`

```elm
withCount : Int -> Section key msg -> Section key msg
```

A small number pill at the right end of the header, such as the number of
items in the section. It is shown as it is, without shortening large numbers.

### `withBadge`

```elm
withBadge : Html msg -> Section key msg -> Section key msg
```

A badge or status at the right end of the header, after the count if there
is one. It is drawn inside the header button, so it must not be a button or a
link itself (a click on it opens and closes the section).

    Accordion.section sectionIds Billing "Billing" [ billingView model ]
        |> Accordion.withBadge (Badge.view [ Badge.tone Warning ] "Overdue")

### `disabledSection`

```elm
disabledSection : Section key msg -> Section key msg
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
type State key  -- opaque: no constructors are exposed
```

The state of an accordion: the keys of the open sections, and whether several
may be open at once. Make one with `init`, keep it in your model, and give it to
`view`. The `key` is your type of section keys.

### `Msg`

```elm
type Msg key  -- opaque: no constructors are exposed
```

The messages of an accordion: a header was clicked, an arrow key was pressed,
the browser found text in a closed section. Wrap it in a constructor of your own
message type, pass that constructor to `view`, and hand the messages you get back
to `update`.

### `init`

```elm
init : String -> State key
```

An accordion with every section closed, in the default mode: opening a section
closes the others. The id must be unique on the page: it is the prefix of the DOM
ids of the headers and bodies.

    Accordion.init "order-sections"

### `setMultiple`

```elm
setMultiple : Bool -> State key -> State key
```

Sets the mode of the state, the one place where it is set. With `True` several
sections can be open at once; with `False`, the default, opening a section closes
the others. `expand`, `toggle` and a click on a header all follow it. Sections
that are open now stay open.

    Accordion.init "order-sections" |> Accordion.setMultiple True

### `update`

```elm
update : Msg key -> State key -> ( State key, Cmd (Msg key) )
```

Opens and closes sections when their headers are clicked, and moves keyboard
focus between the headers. The `Cmd` does the focus move, so map it with your
message constructor.

## Open sections

### `isExpanded`

```elm
isExpanded : key -> State key -> Bool
```

Whether the section with this key is open.

### `expandedIds`

```elm
expandedIds : State key -> List key
```

The keys of the open sections, in the order they were opened. Save them to
restore the accordion later with `setExpandedIds`.

### `expand`

```elm
expand : key -> State key -> State key
```

Opens one section, like a click on its header does: in the default mode the
other sections are closed, after `setMultiple True` they stay as they are. Use
`setExpandedIds` to set exactly which sections are open.

### `collapse`

```elm
collapse : key -> State key -> State key
```

Closes one section.

### `toggle`

```elm
toggle : key -> State key -> State key
```

Opens a closed section, as `expand` does, and closes an open one, like a click
on its header does. In the default mode opening a section closes the others.

### `expandAll`

```elm
expandAll : List (Section key msg) -> State key -> State key
```

Opens every section that can be opened (not the `disabledSection`s), whatever
the mode; sections that are open stay open. Give it the same sections that you
give to `view`.

    Accordion.expandAll (orderSections model) model.accordion

### `collapseAll`

```elm
collapseAll : State key -> State key
```

Closes every section.

### `setExpandedIds`

```elm
setExpandedIds : List key -> State key -> State key
```

Opens exactly these sections and closes all the others, whatever the mode, for
example to restore what the user had open.
