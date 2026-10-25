# Klar.SavedViews

Named, saved filters ("views"): a dropdown button that lists the saved views and lets the user apply one, save the current filter under a new name, rename and delete views (after an inline ...

Import: `import Klar.SavedViews as SavedViews` | Group: Rules and filters

Types: `Msg`, `State`, `Change`, `Attribute`, `SavedView`

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
    , key : Maybe String
    , isLocked : Bool
    }
savedView : String -> Rule.Rule -> SavedView
withNote : String -> SavedView -> SavedView
asDefault : SavedView -> SavedView
asShared : SavedView -> SavedView
asLocked : SavedView -> SavedView
withQuery : Table.Query -> SavedView -> SavedView
withKey : String -> SavedView -> SavedView

-- A backend that keeps each view
type Change = Created SavedView | Updated SavedView | Deleted String
changes : List SavedView -> List SavedView -> List Change

-- Keeping the views
encode : SavedView -> Json.Encode.Value
decoder : Json.Decode.Decoder SavedView

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
currentRule : Rule.Rule -> Attribute msg
currentQuery : Table.Query -> Attribute msg
remote : Remote.Remote a -> Attribute msg
onRetry : msg -> Attribute msg
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
    SavedViews.view ViewsMsg [ SavedViews.currentRule model.rule ] model.views

Here `applyRule` stands for whatever puts a rule into your filters, for example
`FilterBar.setRule`, and `model.rule` is the rule they show now.

**Applying goes through the application**: picking a view only marks it active
and bumps `revision`. The application compares `revision` before and after
`update` and loads the rule of `active` into its filters. Picking the same view
again (to throw away changes) also bumps `revision`.

**Storage**: the state holds the list, nothing is stored. The application saves
`views` (and the name of `active`) where it keeps user settings, typically through
its backend, with `encode` (see "Keeping the views" below), and restores them with
`setViews` and `setActive`. Compare `views` before and after `update` to know when to
save: the list changes when the user saves, renames, deletes or updates a view or
changes the default.

**Views from a backend** come later than the page: give `view` the `Remote` of that
request with `remote` (and `onRetry`), so the list says it is loading instead of "No
saved views yet", and shows a failure with a retry.

`currentRule` is the rule the application shows now. It is what "Save current
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
what `currentRule` is, so give `currentRule` to `view` (without it there is no form and
the list just opens).

    ( views, cmd ) =
        SavedViews.startSave model.views

    -- ( { model | views = views }, Cmd.map ViewsMsg cmd )

**Shared views**: a view is shared when the application says so (`asShared`, or
`isShared = True` in stored data); the list shows a "Shared" badge. A view that someone
else owns is also `asLocked`: it can be applied and made the default, not renamed,
updated or deleted. Klar stores
nothing, so who may see a view is the backend's business. A link to a view is a
route of your own that names it, and `apply` is what that route does:

    -- when the route says view=name: marks it active and bumps `revision`
    { model | views = SavedViews.apply name model.views }

Compare `revision` after `apply` as after `update` and load the rule (and query)
of `active`. With [Klar.ServerList](Klar.ServerList.md), `ServerList.toQueryString` writes
the link (the view, the filters and the page, every text safely encoded: a name is user
text, and `Url.percentEncode` throws on half of an emoji) and
`ServerList.fromQueryString` reads it. There is no clipboard in pure Elm, so a "Copy link" is the link in a read-only
[Klar.TextInput](Klar.TextInput.md) that the user selects (`TextInput.readOnly True`), shown
in a dialog or a toast of your own.

**A dialog, not a menu**: the list holds forms (the name of a new view, a rename, the
confirmation of a deletion), and a menu may not hold text fields. It is a non-modal
dialog, `role="dialog"` named "Saved views", opened by a button with
`aria-haspopup="dialog"` and `aria-expanded`; the page behind stays usable, focus
goes to the active view, `Escape` closes it and gives focus back to the button, and
leaving it with `Tab` closes it. Checked with axe (wcag2a to wcag22aa and best
practice) with the list open, with a deletion to confirm, a rename and the save form.

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

    SavedViews.view ViewsMsg [ SavedViews.currentRule model.rule ] model.views

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
    , key : Maybe String
    , isLocked : Bool
    }
```

A named rule. The `name` identifies the view and must be unique, ignoring
case. The `note` is a short description shown under the name. `isDefault` marks
the view that "Reset" returns to; at most one view is the default. `isShared`
is set by the application, and the list shows a badge for it. `query` is the search,
sort, filters and page size of the table, when the view holds them. `key` is the id your
backend gave the view (`withKey`), `Nothing` until it is stored; a rename keeps it, so
`changes` can tell a rename from a new view.

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

### `asLocked`

```elm
asLocked : SavedView -> SavedView
```

Locks the view: the user can apply it and make it their default, but not rename,
update or delete it, for a team view that someone else owns. The list shows a lock in
place of those actions. `isLocked = True` in stored data does the same.

### `withQuery`

```elm
withQuery : Table.Query -> SavedView -> SavedView
```

Gives the view a table query: search text, sort, column filters and page size
(the page is not kept). Use it for views you make yourself; the ones the user saves
get it from `currentQuery`.

### `withKey`

```elm
withKey : String -> SavedView -> SavedView
```

Gives the view the id your backend keeps it under. Give it to every stored view
(in the list for `setViews`), and `changes` says what to send per view.

    SavedViews.savedView stored.name rule |> SavedViews.withKey stored.id

### A backend that keeps each view

### `Change`

```elm
type Change = Created SavedView | Updated SavedView | Deleted String
```

What to send to a backend that keeps each view by its key:

  - `Created view`: a view the user saved. It has no key yet: store it, and give the
    list back to `setViews` with the key the backend gave it (`withKey`).
  - `Updated view`: a view with a key whose name, note, rule, query or default changed
    (a rename keeps the key, so it is an update, not a new view).
  - `Deleted key`: the key of a view that the user deleted.

### `changes`

```elm
changes : List SavedView -> List SavedView -> List Change
```

The changes from one list of views to the next, for a backend that keeps each view
by its key: compare `views` before and after `update` (with
[Klar.ServerList](Klar.ServerList.md): the views before, and the `save` of the step).
Views without a key are new ones: a view without a key that is not in the list before
is `Created`. Unchanged views give nothing.

    SavedViews.changes (SavedViews.views model.views) (SavedViews.views views)
        |> List.map storeChange

### Keeping the views

The library keeps nothing. `encode` and `decoder` write and read one view as JSON, so
the application can keep its list wherever it keeps user settings: its backend, the
address, a cookie that it sets through a port of its own.

    -- the list, as text
    Encode.encode 0 (Encode.list SavedViews.encode (SavedViews.views model.views))

    -- and back (a text that does not read gives no views)
    Decode.decodeString (Decode.list SavedViews.decoder) text
        |> Result.withDefault []
        |> (\stored -> SavedViews.setViews stored model.views)

### `encode`

```elm
encode : SavedView -> Json.Encode.Value
```

One view as JSON: the name, the rule (`Rule.encode`), the note, the two flags, the
table query (`Table.encodeQuery`) when it has one, and the key when it has one. It carries
a version, `"v": 1`.

### `decoder`

```elm
decoder : Json.Decode.Decoder SavedView
```

Reads what `encode` wrote. The name (not empty) and the rule are required; the note,
the flags and the query may be missing, a field it does not know is ignored, and a version
newer than 1 is refused. A query that is there but cannot be read (see
`Table.queryDecoder`) fails the view: silently dropping it would apply the rule alone
and show another table than the one that was saved. The rule is read as `Rule.decoder`
reads it.

    Decode.decodeString SavedViews.decoder text

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
view stays active if it is still in the list. A form that is open in the list stays
open while the view it is about is still there, so a refresh from the backend never
throws away a name the user is typing; the name is checked again when it is saved.

### `setActive`

```elm
setActive : Maybe String -> State -> State
```

Marks the view with this name as active, without applying anything: use it
when the application has already loaded the rule, for example at start-up. The name
is matched like names are compared, ignoring case and surrounding spaces. A name that
is not in the list, or `Nothing`, means that no view is active.

### `apply`

```elm
apply : String -> State -> State
```

Applies the view with this name, as if the user had picked it: it becomes
active and `revision` goes up, so the application loads its rule and query the
way it does after `update`. Use it for a link that names a view; the name is matched
ignoring case and surrounding spaces (`?view=open%20orders` finds "Open orders"). A
name that is not in the list changes nothing.

### `startSave`

```elm
startSave : State -> ( State, Cmd Msg )
```

Opens the list with the form for saving the current view open, and moves focus
to its name field. Use it for a command or a shortcut ("New saved view"); map the
`Cmd` with your wrapper of the component's `Msg`. The form needs `currentRule` in the
attributes of `view`; without it the list opens with focus on "Reset".

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the saved views button. Make them with the functions below and
pass a list to `view`; later attributes win over earlier ones.

### `currentRule`

```elm
currentRule : Rule.Rule -> Attribute msg
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

### `remote`

```elm
remote : Remote.Remote a -> Attribute msg
```

Takes loading, failure, refreshing and old data from the `Remote` of the request
that brings the views; the views themselves are the ones of `setViews`, as always.
While nothing has come the list says that it is loading (not "No saved views yet"),
a failure with no views to show says what went wrong with a retry (`onRetry`), and
views that are `Kept` stay: dimmed and busy while they are refreshed, marked "Old data"
with a retry when the refresh failed. Without it the views count as loaded.

    SavedViews.view ViewsMsg
        [ SavedViews.currentRule model.rule
        , SavedViews.remote model.storedViews
        , SavedViews.onRetry LoadViews
        ]
        model.views

### `onRetry`

```elm
onRetry : msg -> Attribute msg
```

The message of the "Try again" button, shown when loading the views failed (and the
problem is worth retrying, see `Remote.isRetryable`). While the views load again the
button stays in its place, busy, so keyboard focus is not lost.

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
