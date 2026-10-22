# Klar.Tabs

Tabs that switch between views of the same thing: the overview of an order, its history and its files.

Import: `import Klar.Tabs as Tabs` | Group: Navigation

Types: `Msg`, `Tab`, `State`, `Attribute`

## Signatures

```elm
-- Views
view : (Msg -> msg) -> List Attribute -> State -> Html msg
panel : State -> String -> (() -> Html msg) -> Html msg
panels : State -> List ( String, () -> Html msg ) -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> String -> State
active : State -> String
setActive : String -> State -> State
resolve : List Tab -> State -> State
update : Msg -> State -> ( State, Cmd Msg )

-- Tabs
type Tab  -- opaque: no constructors are exposed
tab : String -> String -> Tab
withIcon : Icon.Icon -> Tab -> Tab
withCount : Int -> Tab -> Tab
withTitle : String -> Tab -> Tab
disabledTab : Tab -> Tab

-- Attributes
type Attribute  -- opaque: no constructors are exposed
tabs : List Tab -> Attribute
ariaLabel : String -> Attribute
boxed : Attribute
small : Attribute
fill : Attribute
manual : Attribute
withoutPanels : Attribute
```

## Documentation

Tabs that switch between views of the same thing: the overview of an order,
its history and its files.

The component is stateful: it owns which tab is active and which tab has
keyboard focus. The application reads the active tab with `active` and compares
it before and after an update to react, for instance to change the URL. To set
the tab from outside, when the route changes, use `setActive`.

    import Klar.Icon as Icon
    import Klar.Tabs as Tabs

    -- model: tabs : Tabs.State
    -- init:  Tabs.init "order-tabs" "overview"

    -- update
    TabsMsg m ->
        let
            ( tabs, cmd ) =
                Tabs.update m model.tabs
        in
        ( { model | tabs = tabs }, Cmd.map TabsMsg cmd )

    -- view
    Html.div []
        [ Tabs.view TabsMsg
            [ Tabs.ariaLabel "Order sections"
            , Tabs.tabs
                [ Tabs.tab "overview" "Overview"
                , Tabs.tab "history" "History" |> Tabs.withCount 12
                , Tabs.tab "files" "Files" |> Tabs.withIcon Icon.paperclip
                , Tabs.tab "billing" "Billing" |> Tabs.disabledTab
                ]
            ]
            model.tabs
        , Tabs.panel model.tabs "overview" (\_ -> overviewView model)
        , Tabs.panel model.tabs "history" (\_ -> historyView model)
        ]

`panel` renders its content only while its tab is active (the function is not
even called for the others), so heavy tab content costs nothing until it is
opened. Tabs that choose a route, a filter or the contents of a table somewhere
else have no panels: add `withoutPanels` so that they do not point at panels
that are not in the page. [Klar.PageHeader](Klar.PageHeader.md) takes such a strip.

The active key should belong to an enabled tab. When it may not, because it comes
from the URL or because a tab becomes disabled while it is active, the strip shows
the first enabled tab as selected, but `panel` and `panels` only see the state.
Pass the state through `resolve` once and give the result to `view`, `panel` and
`panels`: all three then agree on the same tab.

Keyboard: Left and Right arrow move to the previous and next tab and select it,
wrapping around at the ends (Home and End jump to the first and last). With
`manual` the arrows only move focus and Enter or Space selects, which is better
when switching is expensive. Only one tab is in the Tab order (roving tabindex),
the active one or, with `manual`, the one that last had focus, so Tab goes from
the tab list straight into the panel. Disabled tabs are skipped.

The strip is a `tablist` of `tab` buttons and each panel a `tabpanel` named by
its tab. Name the strip with `ariaLabel`. A strip wider than its container
scrolls sideways.

## Views

### `view`

```elm
view : (Msg -> msg) -> List Attribute -> State -> Html msg
```

The tab list. The first argument wraps the strip's `Msg` in your own message
type. The panels are separate: see `panel` and `panels`. When the active key
belongs to no enabled tab, the first enabled tab is shown as selected; give the
panels the state from `resolve` so that they follow.

### `panel`

```elm
panel : State -> String -> (() -> Html msg) -> Html msg
```

The content of one tab: the state, the key of the tab, and a function that
builds the content. The panel is rendered only while the tab is active; the
function is not called otherwise. Put it below the strip, and give it the state
from `resolve` when the active key may not belong to an enabled tab.

    Tabs.panel model.tabs "history" (\_ -> historyView model)

### `panels`

```elm
panels : State -> List ( String, () -> Html msg ) -> Html msg
```

All the panels in one go, as a list of keys with their content functions.
Only the panel of the active tab is built; as for `panel`, the state from
`resolve` makes it the tab that the strip shows.

    Tabs.panels model.tabs
        [ ( "overview", \_ -> overviewView model )
        , ( "history", \_ -> historyView model )
        ]

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of a tab strip: which tab is active and which tab has keyboard
focus. Make one with `init`, keep it in your model, and give it to `view`,
`panel` and `panels`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

The messages of a tab strip: a tab was clicked, an arrow key was pressed.
Wrap it in a constructor of your own message type, pass that constructor to
`view`, and hand the messages you get back to `update`.

### `init`

```elm
init : String -> String -> State
```

A tab strip with one tab active. The first argument is a DOM id that must be
unique on the page: it is the prefix of the ids of the tabs and panels. The second
is the key of the tab that is active at first.

    Tabs.init "order-tabs" "overview"

### `active`

```elm
active : State -> String
```

The key of the active tab. Compare it before and after `update` to react when
the user picks another tab.

    Tabs.active tabs /= Tabs.active model.tabs

### `setActive`

```elm
setActive : String -> State -> State
```

Selects a tab from the application, for instance when the route changes. It
does not move keyboard focus. The key should belong to an enabled tab; when you
cannot be sure of that, draw the tabs from `resolve`.

### `resolve`

```elm
resolve : List Tab -> State -> State
```

The state as the strip shows it: when the active key belongs to no tab, or to
a disabled one, the first enabled tab becomes the active one (the key is empty
when no tab is enabled); otherwise nothing changes. `view` does this for itself,
but `panel` and `panels` only see the state, so resolve it once, with the same
tabs that you give to `tabs`, and hand the result to all three.

    let
        resolved =
            Tabs.resolve orderTabs model.tabs
    in
    Html.div []
        [ Tabs.view TabsMsg [ Tabs.tabs orderTabs ] resolved
        , Tabs.panel resolved "overview" (\_ -> overviewView model)
        , Tabs.panel resolved "history" (\_ -> historyView model)
        ]

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Selects tabs and moves keyboard focus between them. The `Cmd` moves the focus
to the tab the arrow keys reached, so map it with your message constructor.

## Tabs

### `Tab`

```elm
type Tab  -- opaque: no constructors are exposed
```

One tab of the strip. Make it with `tab` and refine it with `withIcon`,
`withCount`, `withTitle` and `disabledTab`.

### `tab`

```elm
tab : String -> String -> Tab
```

A tab: the key first, then the label. The key identifies the tab in the
state (`active`, `setActive`) and names its panel (`panel`), so it must be
unique within the strip. The label is the text of the tab.

    Tabs.tab "history" "History"

### `withIcon`

```elm
withIcon : Icon.Icon -> Tab -> Tab
```

An icon before the label. It is decorative: the label still names the tab.

### `withCount`

```elm
withCount : Int -> Tab -> Tab
```

A small number after the label, such as the number of items behind the tab.
It is shown as it is, without shortening large numbers.

### `withTitle`

```elm
withTitle : String -> Tab -> Tab
```

A native tooltip (the `title` attribute) for the tab, for example to explain
why it is disabled.

    Tabs.tab "billing" "Billing"
        |> Tabs.disabledTab
        |> Tabs.withTitle "Available once the order is confirmed"

### `disabledTab`

```elm
disabledTab : Tab -> Tab
```

Visible but not selectable: the tab is a disabled button and the arrow keys
skip it. Combine with `withTitle` to say why.

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of the tab strip. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones. The strip's messages are
the separate `Msg`, so the type has no `msg` parameter.

### `tabs`

```elm
tabs : List Tab -> Attribute
```

The tabs, in order. At least one of them should be enabled, and the key of
the active tab (see `init` and `setActive`) should belong to an enabled tab;
`resolve` makes sure of it.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute
```

The accessible name of the tab list: what the tabs switch between, for example
"Order sections". There is no default; without it the list has no name.

### `boxed`

```elm
boxed : Attribute
```

Draws the tabs as boxes joined to the panel below, which gets a border of its
own. The default is a plain line under the strip with the active tab underlined.

### `small`

```elm
small : Attribute
```

Lower tabs with smaller text, for tight spaces.

### `fill`

```elm
fill : Attribute
```

The tabs share the full width of the strip equally, instead of being only as
wide as their labels.

### `manual`

```elm
manual : Attribute
```

Manual activation: the arrow keys only move the focus, and Enter or Space
selects the focused tab. Without it the arrows move and select in one go, which
is right when switching is cheap. Use `manual` when switching is expensive, such
as a tab that loads data.

### `withoutPanels`

```elm
withoutPanels : Attribute
```

Says that no `panel` or `panels` follows the strip: the tabs choose a route, a
filter or the contents of a table somewhere else. Without panels the active tab
must not claim a panel that is not in the page, so it leaves out `aria-controls`.
