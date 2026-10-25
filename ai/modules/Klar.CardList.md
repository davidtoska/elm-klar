# Klar.CardList

A responsive collection of records as compact cards, with labelled fields, selection and actions that remain ordinary keyboard controls.

Import: `import Klar.CardList as CardList` | Group: Tables and lists

Types: `Field`, `Attribute`

## Signatures

```elm
view :
    List (Attribute record id msg)
    -> { label : String, items : Remote.Remote (List record), ids : Ids.Ids id, id : record -> id, title : record -> String, fields : List (Field record msg) }
    -> Html msg

-- Fields
type Field record msg  -- opaque: no constructors are exposed
field : String -> (record -> Html msg) -> Field record msg

-- Attributes
type Attribute record id msg  -- opaque: no constructors are exposed
id : String -> Attribute record id msg
selection : List id -> (List id -> msg) -> Attribute record id msg
onOpen : (id -> msg) -> Attribute record id msg
actions : (record -> List (Html msg)) -> Attribute record id msg
onLoadMore : msg -> Attribute record id msg
onRetry : msg -> Attribute record id msg
locale : Locale.Locale -> Attribute record id msg
settings : Settings.Settings -> Attribute record id msg
```

## Documentation

A responsive collection of records as compact cards, with labelled fields,
selection and actions that remain ordinary keyboard controls.

Use when: a product catalogue or overview needs cards that fit a narrow screen.
Do not use when: rows must be sorted, filtered or edited in columns; use `Klar.Table`.

    import Html
    import Klar.CardList as CardList
    import Klar.Ids as Ids
    import Klar.Remote as Remote

    CardList.view []
        { label = "Products"
        , items = Remote.Loaded [ { id = 1, name = "Steel bracket", sku = "BR-01" } ]
        , ids = Ids.int
        , id = .id
        , title = .name
        , fields = [ CardList.field "SKU" (Html.text << .sku) ]
        }

`selection` is controlled by the application. Selecting or clearing the loaded
cards preserves selections on other pages. A card's title is a button only when
`onOpen` is supplied; actions and checkboxes are never nested in that button.
Records and ids must be unique within the list. Ordering and paging belong to the
application; this component never truncates the supplied records.

Every remote state is drawn, including empty retained data, refresh and failed
refresh with retry. Give the region a surrounding focus target and use
`Klar.focus` in its retry handler when the retry button would disappear.

### `view`

```elm
view :
    List (Attribute record id msg)
    -> { label : String, items : Remote.Remote (List record), ids : Ids.Ids id, id : record -> id, title : record -> String, fields : List (Field record msg) }
    -> Html msg
```

Draws every supplied record, keyed by its unique application id. `label`
names the region; `title` is plain text and `fields` are shown in order.

## Fields

### `Field`

```elm
type Field record msg  -- opaque: no constructors are exposed
```

A labelled value in a card. The record type is your application's own type.

### `field`

```elm
field : String -> (record -> Html msg) -> Field record msg
```

A field rendered as a description-list pair. Values may be text, badges or links.

## Attributes

### `Attribute`

```elm
type Attribute record id msg  -- opaque: no constructors are exposed
```

Optional card behaviour; later attributes win. By default cards are read only.

### `id`

```elm
id : String -> Attribute record id msg
```

A DOM id unique on the page and a stable focus target after retry or removal.
Absent by default. Use `Klar.focus` in the handler when its control disappears.

### `selection`

```elm
selection : List id -> (List id -> msg) -> Attribute record id msg
```

Enables selection, with the selected ids and the callback receiving the new
complete selection. Clearing loaded cards keeps ids from other pages.

### `onOpen`

```elm
onOpen : (id -> msg) -> Attribute record id msg
```

Turns each title into a button that sends its record's id. Absent by default.

### `actions`

```elm
actions : (record -> List (Html msg)) -> Attribute record id msg
```

Additional controls below each card's fields. Empty by default.

### `onLoadMore`

```elm
onLoadMore : msg -> Attribute record id msg
```

Shows a load-more button after the loaded cards. The application appends data.

### `onRetry`

```elm
onRetry : msg -> Attribute record id msg
```

Retry message for initial failures and failed refreshes. Absent by default.

### `locale`

```elm
locale : Locale.Locale -> Attribute record id msg
```

Built-in text language. Defaults to English.

### `settings`

```elm
settings : Settings.Settings -> Attribute record id msg
```

Settings used to format the time of retained data. Defaults to `Settings.default`.
