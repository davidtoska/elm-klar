# Klar.Tabs

Tabs that switch between views of the same thing: the overview of an order, its history and its files.

Import: `import Klar.Tabs as Tabs` | Group: Navigation

Types: `Msg`, `Tab`, `State`, `Attribute`

## Signatures

```elm
-- View
view : (Msg key -> msg) -> List (Attribute key msg) -> State key -> Html msg

-- State
type State key  -- opaque: no constructors are exposed
type Msg key  -- opaque: no constructors are exposed
init : String -> key -> State key
active : State key -> key
setActive : key -> State key -> State key
update : Msg key -> State key -> ( State key, Cmd (Msg key) )

-- Tabs
type Tab key msg  -- opaque: no constructors are exposed
tab : key -> String -> Tab key msg
withPanel : (() -> Html msg) -> Tab key msg -> Tab key msg
withIcon : Icon.Icon -> Tab key msg -> Tab key msg
withCount : Int -> Tab key msg -> Tab key msg
withTitle : String -> Tab key msg -> Tab key msg
disabledTab : Tab key msg -> Tab key msg

-- Attributes
type Attribute key msg  -- opaque: no constructors are exposed
tabs : List (Tab key msg) -> Attribute key msg
ariaLabel : String -> Attribute key msg
boxed : Attribute key msg
small : Attribute key msg
fill : Attribute key msg
vertical : Attribute key msg
manual : Attribute key msg
locale : Locale.Locale -> Attribute key msg
```

## Documentation

Tabs that switch between views of the same thing: the overview of an order,
its history and its files.

Use when: the user switches between views of the same thing, such as the overview, history and files of an order.
Do not use when: sections should open and close in place (use `Klar.Accordion`) or the user moves through ordered steps (use `Klar.Stepper`).
Quick path: `init`, `update`, `view`, `tab`, `withPanel`, `active`

The tabs are values of your own type, so a misspelled tab is a compile error and the
active one is matched with a `case`. The component is stateful: it owns which tab is
active. The application reads it with `active` and compares it before and after an
update to react, for instance to change the URL. To set the tab from outside, when the
route changes, use `setActive`.

    import Klar.Icon as Icon
    import Klar.Tabs as Tabs

    type Section
        = Overview
        | History
        | Files
        | Billing

    -- model: tabs : Tabs.State Section
    -- init:  Tabs.init "order-tabs" Overview
    -- Msg:   TabsMsg (Tabs.Msg Section)

    -- update
    TabsMsg m ->
        let
            ( tabs, cmd ) =
                Tabs.update m model.tabs
        in
        ( { model | tabs = tabs }, Cmd.map TabsMsg cmd )

    -- view
    Tabs.view TabsMsg
        [ Tabs.ariaLabel "Order sections"
        , Tabs.tabs
            [ Tabs.tab Overview "Overview"
                |> Tabs.withPanel (\_ -> overviewView model)
            , Tabs.tab History "History"
                |> Tabs.withCount 12
                |> Tabs.withPanel (\_ -> historyView model)
            , Tabs.tab Files "Files"
                |> Tabs.withIcon Icon.paperclip
                |> Tabs.withPanel (\_ -> filesView model)
            , Tabs.tab Billing "Billing" |> Tabs.disabledTab
            ]
        ]
        model.tabs

`view` draws the strip and, under it, the panel of the active tab: the strip and the
panel always agree, also when the active tab is disabled or not in the list (then the
first enabled tab is shown as active, and its panel). Only the panel of the active tab
is built (the function is not even called for the others), so heavy tab content costs
nothing until it is opened.

Tabs that choose a route, a filter or the contents of a table somewhere else have no
panels: leave out `withPanel`, and the strip claims no panel. That is the strip for
[Klar.PageHeader](Klar.PageHeader.md): the page below is the view of the route (or a `case`
on `active`).

Keyboard: Left and Right arrow (Up and Down with `vertical`) move to the previous and
next tab and select it, wrapping around at the ends; Home and End jump to the first and
last. With `manual` the arrows only move focus and Enter or Space selects, which is
better when switching is expensive. Only the active tab is in the Tab order (roving
tabindex), so Tab goes from the tab list straight into the panel. Disabled tabs are
skipped.

The strip is a `tablist` of `tab` buttons and the panel a `tabpanel` named by its tab.
Name the strip with `ariaLabel`. A strip wider than its container scrolls sideways.

## View

### `view`

```elm
view : (Msg key -> msg) -> List (Attribute key msg) -> State key -> Html msg
```

The tab list, and under it (beside it, with `vertical`) the panel of the active tab
when the tabs have panels. The first argument wraps the strip's `Msg` in your own message
type. When the active key belongs to no enabled tab, the first enabled tab is shown as
active, with its panel.

## State

### `State`

```elm
type State key  -- opaque: no constructors are exposed
```

The state of a tab strip: which tab is active. Make one with `init`, keep it in your
model, and give it to `view`.

### `Msg`

```elm
type Msg key  -- opaque: no constructors are exposed
```

The messages of a tab strip: a tab was clicked, an arrow key was pressed. Wrap it in
a constructor of your own message type (`TabsMsg (Tabs.Msg Section)`), pass that
constructor to `view`, and hand the messages you get back to `update`.

### `init`

```elm
init : String -> key -> State key
```

A tab strip with one tab active. The first argument is a DOM id that must be
unique on the page: it is the prefix of the ids of the tabs and of the panel. The second
is the key of the tab that is active at first.

    Tabs.init "order-tabs" Overview

### `active`

```elm
active : State key -> key
```

The key of the active tab: the one given to `init` or `setActive`, or the one the
user picked. Compare it before and after `update` to react when the user picks another
tab.

    Tabs.active tabs /= Tabs.active model.tabs

### `setActive`

```elm
setActive : key -> State key -> State key
```

Selects a tab from the application, for instance when the route changes. It
does not move keyboard focus. When the key belongs to no enabled tab, `view` shows the
first enabled tab as active.

### `update`

```elm
update : Msg key -> State key -> ( State key, Cmd (Msg key) )
```

Selects tabs and moves keyboard focus between them. The `Cmd` moves the focus
to the tab the arrow keys reached, so map it with your message constructor.

## Tabs

### `Tab`

```elm
type Tab key msg  -- opaque: no constructors are exposed
```

One tab of the strip, with a key of your own type. Make it with `tab` and refine it
with `withPanel`, `withIcon`, `withCount`, `withTitle` and `disabledTab`. The `msg` is
the message type of the content of its panel.

### `tab`

```elm
tab : key -> String -> Tab key msg
```

A tab: its key (a value of your own type, unique within the strip and compared with
`==`), then the label, the text of the tab.

    Tabs.tab History "History"

### `withPanel`

```elm
withPanel : (() -> Html msg) -> Tab key msg -> Tab key msg
```

The content shown under the strip while this tab is active, as a function that is
only called then. A strip whose tabs have no panel claims none (`aria-controls` is left
out), for tabs that choose a route or a filter.

    Tabs.tab History "History"
        |> Tabs.withPanel (\_ -> historyView model)

### `withIcon`

```elm
withIcon : Icon.Icon -> Tab key msg -> Tab key msg
```

An icon before the label. It is decorative: the label still names the tab.

### `withCount`

```elm
withCount : Int -> Tab key msg -> Tab key msg
```

A small number after the label, such as the number of items behind the tab. It is
shown whole, grouped the way the language of `locale` writes numbers ("12 345" in
Norwegian).

### `withTitle`

```elm
withTitle : String -> Tab key msg -> Tab key msg
```

A native tooltip (the `title` attribute) for the tab, for example to explain
why it is disabled.

    Tabs.tab Billing "Billing"
        |> Tabs.disabledTab
        |> Tabs.withTitle "Available once the order is confirmed"

### `disabledTab`

```elm
disabledTab : Tab key msg -> Tab key msg
```

Visible but not selectable: the tab is a disabled button and the arrow keys
skip it. Combine with `withTitle` to say why.

## Attributes

### `Attribute`

```elm
type Attribute key msg  -- opaque: no constructors are exposed
```

A setting of the tab strip. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones. `key` is the type of your tabs and `msg`
your message type, of the content of the panels.

### `tabs`

```elm
tabs : List (Tab key msg) -> Attribute key msg
```

The tabs, in order. At least one of them should be enabled; when the active key
belongs to no enabled tab, the first enabled one is shown as active.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute key msg
```

The accessible name of the tab list: what the tabs switch between, for example
"Order sections". There is no default; without it the list has no name.

### `boxed`

```elm
boxed : Attribute key msg
```

Draws the tabs as boxes joined to the panel below, which gets a border of its
own. The default is a plain line under the strip with the active tab underlined.
A `vertical` strip always has the line look.

### `small`

```elm
small : Attribute key msg
```

Lower tabs with smaller text, for tight spaces.

### `fill`

```elm
fill : Attribute key msg
```

The tabs share the full width of the strip equally, instead of being only as
wide as their labels. No effect on a `vertical` strip.

### `vertical`

```elm
vertical : Attribute key msg
```

Stacks the tabs from top to bottom, with the panel beside them, for settings pages
and detail panes. The arrow keys are Up and Down, and the list says
`aria-orientation="vertical"`. The default is a horizontal strip.

### `manual`

```elm
manual : Attribute key msg
```

Manual activation: the arrow keys only move the focus, and Enter or Space
selects the focused tab. Without it the arrows move and select in one go, which
is right when switching is cheap. Use `manual` when switching is expensive, such
as a tab that loads data. The active tab stays the one in the Tab order.

### `locale`

```elm
locale : Locale.Locale -> Attribute key msg
```

The language the counts of `withCount` are written in (digit grouping). Default
`Locale.en`.
