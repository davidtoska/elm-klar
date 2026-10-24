# Klar.BulkBar

The bar of actions for the items the user has selected: "12 selected: Export, Delete".

Import: `import Klar.BulkBar as BulkBar` | Group: Pages and flow

Types: `Attribute`

## Signatures

```elm
-- View
view :
    List (Attribute msg)
    -> { toolbar : Html msg, selected : Int, onClear : msg }
    -> List (Html msg)
    -> Html msg

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
selectAllMatching : { total : Int, onPage : Int, onSelectAll : msg } -> Attribute msg
id : String -> Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

The bar of actions for the items the user has selected: "12 selected: Export,
Delete".

Use when: a list, a grid of cards or another selectable collection needs actions for the selected items.
Do not use when: the items are in a `Klar.Table`, which draws a bar of its own for its selection (`Table.bulkActions`).

    import Klar.BulkBar as BulkBar
    import Klar.Button as Button
    import Klar.Icon as Icon
    import Klar.Toolbar as Toolbar

    BulkBar.view
        [ BulkBar.id "orders-bulk"
        , BulkBar.selectAllMatching
            { total = model.matching, onPage = List.length model.page, onSelectAll = SelectAllOrders }
        ]
        { toolbar = Toolbar.view [ Toolbar.ariaLabel "Orders" ] [ searchField, newOrderButton ]
        , selected = Set.size model.selected
        , onClear = ClearSelection
        }
        [ Button.view [ Button.icon Icon.download, Button.onClick ExportSelected ] "Export"
        , Button.view [ Button.danger, Button.icon Icon.trash, Button.onClick DeleteSelected ] "Delete"
        ]

Use it for a list, a grid of cards or any selectable collection that has no bar of
its own ([Klar.Table](Klar.Table.md) draws one for its selection). You keep the
selection in your model and tell the bar how many items are selected.

## Where the bar goes

Selecting the first item must not push the content down, and clearing the last one
must not pull it up. So the bar does not appear above or below the list: it takes
the place of the toolbar that is already there, in the same box. You hand that
`toolbar` to `view`; it is always drawn, and while something is selected the bar
covers it (the toolbar keeps its place, its size and its state, a search field
keeps its text, but it cannot be reached with the keyboard or the mouse until the
bar goes away). The bar has the size of the toolbar: `Toolbar.small` and `Toolbar.large`
change both. The place is as tall as the taller of the two, always: with a count
of zero (or less) the bar is drawn all the same, out of sight and out of reach of the
mouse, the keyboard and screen readers, as it would look for a whole page of ticked items
(with the offer to select everything), so that its height is counted even when the bar
wraps onto two lines in a narrow column. A list with no toolbar of its own should pass a
quiet `Toolbar` with a label, such as the name of the list: the place is kept for the
bar, and an empty one would leave a gap. The bar asks for no focus when it appears.

## Keyboard and announcements

The controls are ordinary buttons in the order the eye reads them: the count, the
offer to select everything, your actions, and "Clear selection" last. The bar listens
to no keys. In particular `Escape` does not clear the selection: it also closes
menus and dialogs and empties search fields, so whether it means "clear" is a
decision for the application (a [Klar.Shortcut](Klar.Shortcut.md) of its own).

The count is announced politely (`role="status"` with `aria-live="polite"`) by one
region that is always on the page and whose text changes, so a screen reader finishes
what it is reading and then says "12 selected", never a new announcement for every
click of a quick selection. Only changes are announced: a bar that is drawn for the
first time with items already selected says nothing. The count going down to zero is
not announced either; say what happened yourself, with a [Klar.Toast](Klar.Toast.md). The
bar is a group named with the count ("Actions, 12 selected"), so a screen reader that
moves into it with `Tab` hears how many items its buttons act on.

## Focus

"Select all N matching" stays where it is when it has been used: it turns into an
inactive button, "All matching selected" (`aria-disabled`, so that it keeps focus),
and nothing is lost.

"Clear selection", and any action of yours that empties the selection (Delete), take
the whole bar away, and with it the button that has focus. A focused element that
disappears leaves focus on the page body: a screen reader says nothing, and only some
browsers continue the next `Tab` from where the button was. The bar cannot move focus
itself, since it keeps no state and a click sends a single message, so the application
does it in the same `update`, with one call that works for all of these cases: give the
bar an `id` and move focus to it with [`Klar.focus`](Klar.md#focus).

    ClearSelection ->
        ( { model | selected = Set.empty }
        , Klar.focus "orders-bulk" NoOp
        )

The id is on the box that the toolbar and the bar share. That box is on the page whether
or not something is selected, so it is there to receive focus when the bar has gone, and
the next `Tab` reaches the first control of the toolbar. If you would rather return to
the list, focus the list yourself.

**Selecting from the toolbar.** While something is selected the toolbar is inert, and a
focused element that becomes inert loses focus to the page. Keep the controls that
select (the box that ticks the whole page) in the list, not in the toolbar. When a
selection can start while focus is in the toolbar (a shortcut pressed in its search
field), call `Klar.focus` with the same id in that `update` too: the next `Tab` then
reaches the bar.

## View

### `view`

```elm
view :
    List (Attribute msg)
    -> { toolbar : Html msg, selected : Int, onClear : msg }
    -> List (Html msg)
    -> Html msg
```

The toolbar with the bar over it. `toolbar` is what the bar covers while
something is selected; `selected` is the number of selected items (zero or less
draws no bar); `onClear` is the message sent by "Clear selection". The `actions`
are your buttons and menus, which sit at the end of the bar before "Clear
selection". Use ghost or ordinary buttons: the bar has the size of the toolbar it
covers, and `Toolbar.small` and `Toolbar.large` change both together.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the bar. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `selectAllMatching`

```elm
selectAllMatching : { total : Int, onPage : Int, onSelectAll : msg } -> Attribute msg
```

Says that more items match than the page shows, so the bar can say "200 of
12,340 selected" and offer "Select all 12,340 matching".

  - `total` is the number of items that could be selected: everything that matches
    the search and the filters, on every page.
  - `onPage` is the number of items on the page the user sees.
  - `onSelectAll` is the message sent by the button. Your `update` selects everything
    that matches, so that the next `view` has `selected` equal to `total`.

The offer is made only when the selection is at least as large as the page, and
only when something is left to select: a person who ticked a row or two is not
asked, while one who ticked the whole page is. Once everything is selected the
button stays in its place as an inactive "All matching selected", and a screen reader
is told "All 12,340 selected".

A `total` that cannot be true, below 1 or below the number selected (the selection and
the count can disagree for a moment while a new search is on its way), is taken as
"the total is not known": the bar says "12 selected" and makes no offer and no claim
about everything. It never says "12 of 3 selected" or "All 12 selected" on such a
number.

Without `selectAllMatching` the bar says "12 selected" and offers nothing.

### `id`

```elm
id : String -> Attribute msg
```

The DOM id of the box that the toolbar and the bar share, which must be unique on
the page. With it the box can take focus, so that `Klar.focus` has a place to put it
when the bar goes away. There is no id by default.

    Klar.focus "orders-bulk" NoOp

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in text: the count, "Clear selection", "Select all
N matching" and the name of the group of buttons. The default is
[`Locale.default`](Klar.Locale.md#default), which is English. Numbers are written the
way the language does ("12,340" or "12 340").
