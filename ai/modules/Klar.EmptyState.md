# Klar.EmptyState

What to show when there is nothing to show: an empty list, no search results, a first-run screen.

Import: `import Klar.EmptyState as EmptyState` | Group: Status and feedback

Types: `Attribute`

## Signatures

```elm
-- View
view : List (Attribute msg) -> Html msg

-- Content
type Attribute msg  -- opaque: no constructors are exposed
icon : Icon.Icon -> Attribute msg
title : String -> Attribute msg
description : String -> Attribute msg
actions : List (Html msg) -> Attribute msg

-- Look and text
compact : Attribute msg
headingLevel : Int -> Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

What to show when there is nothing to show: an empty list, no search
results, a first-run screen.

Use when: a list or a screen of your own is empty and the user should be told why and what to do next.
Do not use when: a request failed (use `Klar.ErrorState`).

    import Klar.Button as Button
    import Klar.EmptyState as EmptyState
    import Klar.Icon as Icon

    EmptyState.view
        [ EmptyState.icon Icon.search
        , EmptyState.title "No matching orders"
        , EmptyState.description "Try a different search or clear the filters."
        , EmptyState.actions [ Button.view [ Button.onClick ClearFilters ] "Clear filters" ]
        ]

Say what is missing and, where it helps, what the user can do about it: a
button that clears the filters or creates the first item. For a request that
failed use [Klar.ErrorState](Klar.ErrorState.md) instead.

The components that show remote data ([Klar.Table](Klar.Table.md),
[Klar.Tree](Klar.Tree.md), [Klar.ListItem](Klar.ListItem.md) ...) render an empty
state themselves when a list comes back empty, and take a list of these
attributes to change it (`Table.emptyState`); use `view` for the views you build
on your own.

An empty state is ordinary content: it has no live region, so screen readers do
not announce it when it appears. When it answers what the user typed (a search
with no results), say so in a live region that stays on the page, such as the
result count of the search, rather than in the empty state.

## View

### `view`

```elm
view : List (Attribute msg) -> Html msg
```

A centered block with an icon, a title, an optional description and
optional actions.

    EmptyState.view [ EmptyState.title "No orders yet" ]

## Content

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of an empty state. Make them with the functions below and pass a
list to `view`; later attributes win over earlier ones.

### `icon`

```elm
icon : Icon.Icon -> Attribute msg
```

The large icon above the title. The default is `Icon.inbox`.

### `title`

```elm
title : String -> Attribute msg
```

The headline, such as "No orders yet": say what is missing. Without one the
state says "Nothing to show" (in the `locale`), so it is never only an icon. An
empty title (or one of spaces only) renders no headline element at all.

### `description`

```elm
description : String -> Attribute msg
```

A sentence under the title that says why there is nothing here or what to
do about it. There is none by default.

### `actions`

```elm
actions : List (Html msg) -> Attribute msg
```

Buttons or links below the text, for the obvious next steps, such as
"Create order" and "Import orders". The first is the main one. There are none
by default.

## Look and text

### `compact`

```elm
compact : Attribute msg
```

Less vertical space and a smaller icon, for use inside tables and small
panels. It follows a compact density of the application (`Klar.Settings`) without it.

### `headingLevel`

```elm
headingLevel : Int -> Attribute msg
```

Makes the title a heading of this level (1 to 6), for an empty state that is
the main content of a page or a section, so that screen reader users find it by
its heading. The default is no heading: a plain line, right inside a table cell
or a popup.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text, which is the default title ("Nothing to
show" in English). The default is `Locale.default`, which is English.
