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
action : Html msg -> Attribute msg

-- Look
compact : Attribute msg
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
        , EmptyState.action (Button.view [ Button.onClick ClearFilters ] "Clear filters")
        ]

Say what is missing and, where it helps, what the user can do about it: a
button that clears the filters or creates the first item. For a request that
failed use [Klar.ErrorState](Klar.ErrorState.md) instead.

The components that show remote data ([Klar.Table](Klar.Table.md),
[Klar.Tree](Klar.Tree.md), [Klar.ListItem](Klar.ListItem.md) ...) render an empty
state themselves when a list comes back empty; use this module for the views
you build on your own. An empty state is ordinary content: it has no live
region, so screen readers do not announce it when it appears.

## View

### `view`

```elm
view : List (Attribute msg) -> Html msg
```

A centered block with an icon, a title, an optional description and an
optional action.

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

The headline, such as "No orders yet". Give one: a state says what is
missing. The default is no title, and an empty title (or one of spaces only)
renders no headline element at all.

### `description`

```elm
description : String -> Attribute msg
```

A sentence under the title that says why there is nothing here or what to
do about it. There is none by default.

### `action`

```elm
action : Html msg -> Attribute msg
```

A button or link below the text, for the obvious next step.

## Look

### `compact`

```elm
compact : Attribute msg
```

Less vertical space and a smaller icon, for use inside tables and small
panels. It follows a compact density of the application (`Klar.Settings`) without it.
