# Klar.SavedViews

Named, saved filters ("views"): a dropdown button that lists the saved views and lets the user apply one, save the current filter under a new name, rename and delete views (after an inline ...

Import: `import Klar.SavedViews as SavedViews` | Group: Rules and filters

Types: `Msg`, `State`, `Attribute`, `SavedView`

## Signatures

```elm
-- View
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- Defining views
type alias SavedView =
    { name : String
    , rule : Rule.Rule
    , note : Maybe String
    , isDefault : Bool
    , isShared : Bool
    , query : Maybe Table.Query
    }
savedView : String -> Rule.Rule -> SavedView
withNote : String -> SavedView -> SavedView
asDefault : SavedView -> SavedView
asShared : SavedView -> SavedView
withQuery : Table.Query -> SavedView -> SavedView

-- Reading and replacing the list
views : State -> List SavedView
active : State -> Maybe SavedView
defaultView : State -> Maybe SavedView
revision : State -> Int
isOpen : State -> Bool
setViews : List SavedView -> State -> State
setActive : Maybe String -> State -> State
apply : String -> State -> State
startSave : State -> ( State, Cmd Msg )

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
current : Rule.Rule -> Attribute msg
currentQuery : Table.Query -> Attribute msg
label : String -> Attribute msg
locale : Locale.Locale -> Attribute msg
size : Theme.Size -> Attribute msg
alignEnd : Attribute msg
```

## Documentation

Named, saved filters ("views"): a dropdown button that lists the saved
views and lets the user apply one, save the current filter under a new name,
rename and delete views (after an inline confirmation), mark one as the default
view and reset to it.

Use when: users want to save, name and reapply their filters.
Do not use when: the filter is fixed and has no names to remember (use `Klar.FilterBar` alone).
Quick path: `init`, `setViews`, `update`, `view`, `revision`, `active`

Use it next to a [Klar.FilterBar](Klar.FilterBar.md) or a
[Klar.RuleBuilder](Klar.RuleBuilder.md). a view is a name and a
[Klar.Rule](Klar.Rule.md) `Rule`, and optionally a table query (see below).

    import Klar.Rule as Rule
    import Klar.SavedViews as SavedViews

    -- model
    { views : SavedViews.State }
    -- SavedViews.init "order-views" |> SavedViews.setViews storedViews

    -- update
    ViewsMsg m ->
        let
            ( views, cmd ) =
                SavedViews.update m model.views

            next =
                { model | views = views }
        in
        if SavedViews.revision views /= SavedViews.revision model.views then
            -- the user applied a view (or "Reset"): load its rule
            ( applyRule (SavedViews.active views |> Maybe.map .rule |> Maybe.withDefault Rule.emptyGroup) next
            , Cmd.map ViewsMsg cmd
            )

        else
            ( next, Cmd.map ViewsMsg cmd )

    -- view
    SavedViews.view ViewsMsg [ SavedViews.current model.rule ] model.views

Here `applyRule` stands for whatever puts a rule into your filters, for example
`FilterBar.setRule`, and `model.rule` is the rule they show now.

**Applying goes through the application**: picking a view only marks it active
and bumps `revision`. The application compares `revision` before and after
`update` and loads the rule of `active` into its filters. Picking the same view
again (to throw away changes) also bumps `revision`.

**Storage**: the state holds the list, nothing is stored. The application saves
`views` (and `active`) where it keeps user settings, typically through its
backend, with `Rule.encode` for the rules, and restores them with `setViews` and
`setActive`. Compare `views` before and after `update` to know when to save:
the list changes when the user saves, renames, deletes or updates a view or
changes the default.

`current` is the rule the application shows now. It is what "Save current
view ..." saves, and the active view is marked "modified" when its rule differs
from it. The button shows the name of the active view, or "Views" when there is
none.

**The whole query**: a view holds a rule, and it can also hold what the table next
to the filters shows: the search text, the sort, the column filters and the page size
(a [Table.Query](Klar.Table.md#query)). Give `currentQuery (Table.query model.table)` to
`view`: "Save current view ..." then saves it with the rule, "modified" compares it too,
and `active` carries it in `.query`. Applying goes through the application like the
rule: `Table.setQuery` (the page is always 1). Without `currentQuery` a view holds
only the rule, and a view that holds no query leaves the table as it is.

    -- after the user applied a view
    case SavedViews.active views |> Maybe.andThen .query of
        Just q ->
            { next | table = Table.setQuery q next.table }

        Nothing ->
            next

**Open the save form from a command or a shortcut**: `startSave` opens the list
with the "Save current view" form open and focus in its name field, so that a
command palette entry or a shortcut needs no dialog of your own. The form saves
what `current` is, so give `current` to `view` (without it there is no form and
the list just opens).

    ( views, cmd ) =
        SavedViews.startSave model.views

    -- ( { model | views = views }, Cmd.map ViewsMsg cmd )

**Shared views**: a view is shared when the application says so (`asShared`, or
`isShared = True` in stored data); the list shows a "Shared" badge. Klar stores
nothing, so who may see a view is the backend's business. A link to a view is a
route of your own that names it, and `apply` is what that route does:

    -- the link a "Copy link" button copies
    "#/orders?view=" ++ Url.percentEncode name

    -- when the route says view=name: marks it active and bumps `revision`
    { model | views = SavedViews.apply name model.views }

Compare `revision` after `apply` as after `update` and load the rule (and query)
of `active`.

**Keyboard**: `ArrowDown` on the button opens the list. `ArrowUp`, `ArrowDown`,
`Home` and `End` move between the views, `Enter` applies the view that has focus,
and `Escape` cancels a rename, a deletion or a save and otherwise closes the
list. Names must not be empty and must be unique, ignoring case. The built-in
text follows `locale`, which is English by default.

## View

### `view`

```elm
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
```

The button and, when open, the list of views with its actions: apply, mark as
default, rename and delete a view, save the current filter, update the active
view with the changes, and reset. The first argument turns the component's
messages into yours.

    SavedViews.view ViewsMsg [ SavedViews.current model.rule ] model.views

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of the saved views button: the list of views, which one is active,
whether the list is open and the form that is open in it (save, rename or
delete). Make one with `init`, keep it in your model and pass it to `view` and
`update`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

A message from the saved views component. Wrap it in one of your own
messages and pass it to `update`.

### `init`

```elm
init : String -> State
```

No views, nothing active. The `String` is the DOM id of the wrapper around
the button and its list, and must be unique on the page; the ids of the controls
inside start with it.

    SavedViews.init "order-views"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Applies a message from the component. The command moves keyboard focus (into
the list, back to the button ...), so map it with `Cmd.map`. Compare `revision`
before and after to know when the user applied a view, and `views` to know when
to store the list.

## Defining views

### `SavedView`

```elm
type alias SavedView =
    { name : String
    , rule : Rule.Rule
    , note : Maybe String
    , isDefault : Bool
    , isShared : Bool
    , query : Maybe Table.Query
    }
```

A named rule. The `name` identifies the view and must be unique, ignoring
case. The `note` is a short description shown under the name. `isDefault` marks
the view that "Reset" returns to; at most one view is the default. `isShared`
is set by the application, and the list shows a badge for it. `query` is the search,
sort, filters and page size of the table, when the view holds them.

Make views with `savedView`, or build the record yourself, for example from
stored data.

### `savedView`

```elm
savedView : String -> Rule.Rule -> SavedView
```

A view with a name and a rule, no note, not the default.

    SavedViews.savedView "Unpaid orders" unpaid

### `withNote`

```elm
withNote : String -> SavedView -> SavedView
```

Adds a short description, shown under the name in the list.

    SavedViews.savedView "Unpaid orders" unpaid
        |> SavedViews.withNote "Open orders older than a week"

### `asDefault`

```elm
asDefault : SavedView -> SavedView
```

Makes this the default view: the one that "Reset" returns to. The user can
change the default in the list.

### `asShared`

```elm
asShared : SavedView -> SavedView
```

Marks the view as shared (with colleagues, the team ...). The list shows a
"Shared" badge. The application decides what that means and who may see the view.

### `withQuery`

```elm
withQuery : Table.Query -> SavedView -> SavedView
```

Gives the view a table query: search text, sort, column filters and page size
(the page is not kept). Use it for views you make yourself; the ones the user saves
get it from `currentQuery`.

## Reading and replacing the list

### `views`

```elm
views : State -> List SavedView
```

Every saved view, in the order of the list. Compare it before and after
`update` to know when to store the views: it changes when the user saves,
renames, deletes or updates a view, or changes the default.

### `active`

```elm
active : State -> Maybe SavedView
```

The view the user applied last, if it still exists. Saving the current
filter under a new name makes the new view active too, without applying
anything.

### `defaultView`

```elm
defaultView : State -> Maybe SavedView
```

The view marked as the default, if any. "Reset" returns to it.

### `revision`

```elm
revision : State -> Int
```

Goes up by one every time the user applies a view or resets. Compare it
before and after `update`: when it changed, load the rule of `active` (or an
empty rule when nothing is active) into your filters.

### `isOpen`

```elm
isOpen : State -> Bool
```

Is the list open?

### `setViews`

```elm
setViews : List SavedView -> State -> State
```

Replaces the list, for example with the views loaded from the backend. Names
must be unique, ignoring case and surrounding spaces: later duplicates are
dropped. Only the first view marked as default stays the default. The active
view stays active if it is still in the list, and a form that is open in the
list is closed.

### `setActive`

```elm
setActive : Maybe String -> State -> State
```

Marks the view with this name as active, without applying anything: use it
when the application has already loaded the rule, for example at start-up. A
name that is not in the list, or `Nothing`, means that no view is active.

### `apply`

```elm
apply : String -> State -> State
```

Applies the view with this name, as if the user had picked it: it becomes
active and `revision` goes up, so the application loads its rule and query the
way it does after `update`. Use it for a link that names a view. A name that is not
in the list changes nothing.

### `startSave`

```elm
startSave : State -> ( State, Cmd Msg )
```

Opens the list with the form for saving the current view open, and moves focus
to its name field. Use it for a command or a shortcut ("New saved view"); map the
`Cmd` with your wrapper of the component's `Msg`. The form needs `current` in the
attributes of `view`.

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the saved views button. Make them with the functions below and
pass a list to `view`; later attributes win over earlier ones.

### `current`

```elm
current : Rule.Rule -> Attribute msg
```

The rule the application shows now. It is what "Save current view ..."
saves, and what the active view is compared with: the view is marked "modified"
when the two differ (ignoring node ids). Without it the list can only apply
views, not save them.

### `currentQuery`

```elm
currentQuery : Table.Query -> Attribute msg
```

The query of the table next to the filters, `Table.query model.table`. A view
that is saved holds it with the rule (the page is left out), and the active view is
"modified" when its query differs from it. Without it views hold only the rule.

### `label`

```elm
label : String -> Attribute msg
```

The button text when no view is active. The default is "Views". While a view
is active the button shows its name instead.

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the component's own text: the button, the list and its
messages. The default is `Locale.default`, which is `Locale.en`. The names and notes of
the views come from the application.

### `size`

```elm
size : Theme.Size -> Attribute msg
```

The size of the button, a [Klar.Theme](Klar.Theme.md) `Size`. The default is
`Medium`; `Small` matches the controls of a filter bar.

### `alignEnd`

```elm
alignEnd : Attribute msg
```

Opens the list towards the left: its right edge lines up with the right edge
of the button. Use it when the button sits at the right edge of the page.
