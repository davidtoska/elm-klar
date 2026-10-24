# Klar.PermissionMatrix

A grid of roles and permissions that says what each role may do, and lets an administrator change it: the classic screen of an application with users.

Import: `import Klar.PermissionMatrix as PermissionMatrix` | Group: Access and approval

Types: `Msg`, `Cell`, `Role`, `State`, `Access`, `Change`, `Matrix`, `Attribute`, `Permission`

## Signatures

```elm
-- Views
view :
    (Msg -> msg)
    -> List (Attribute role permission msg)
    -> State
    -> Matrix role permission
    -> Html msg
viewRemote :
    (Msg -> msg)
    -> List (Attribute role permission msg)
    -> State
    -> Remote.Remote (Matrix role permission)
    -> Html msg

-- Roles and permissions
type Matrix role permission  -- opaque: no constructors are exposed
type Role role  -- opaque: no constructors are exposed
type Permission permission  -- opaque: no constructors are exposed
matrix :
    { roles : List (Role role), roleKey : role -> String, permissions : List (Permission permission), permissionKey : permission -> String, cell : role -> permission -> Cell }
    -> Matrix role permission
role : role -> String -> Role role
locked : String -> Role role -> Role role
permission : permission -> String -> Permission permission
inGroup : String -> Permission permission -> Permission permission

-- Cells
type Access  -- opaque: no constructors are exposed
type Cell  -- opaque: no constructors are exposed
granted : Access
denied : Access
fromBool : Bool -> Access
isGranted : Access -> Bool
cell : { own : Maybe Access, inherited : Maybe { access : Access, from : Maybe String } } -> Cell
direct : Access -> Cell

-- Changes
type Change role permission  -- opaque: no constructors are exposed
changedRole : Change role permission -> role
changedPermission : Change role permission -> permission
newAccess : Change role permission -> Maybe Access
unsavedChanges :
    (role -> permission -> Cell)
    -> Matrix role permission
    -> List (Change role permission)

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )
query : State -> String
setQuery : String -> State -> State
collapsedGroups : State -> List String
setCollapsedGroups : List String -> State -> State

-- Attributes
type Attribute role permission msg  -- opaque: no constructors are exposed
onChange : (List (Change role permission) -> msg) -> Attribute role permission msg
saved : (role -> permission -> Cell) -> Attribute role permission msg
toolbarActions : List (Html msg) -> Attribute role permission msg
density : Theme.Density -> Attribute role permission msg
ariaLabel : String -> Attribute role permission msg
maxHeight : Int -> Attribute role permission msg
onRetry : msg -> Attribute role permission msg
settings : Settings.Settings -> Attribute role permission msg
locale : Locale.Locale -> Attribute role permission msg
```

## Documentation

A grid of roles and permissions that says what each role may do, and lets an
administrator change it: the classic screen of an application with users.

Use when: an administrator sets which roles may do what, in a grid of roles and permissions.
Do not use when: only a list of options is chosen for one user, use `Klar.CheckboxGroup`.
Quick path: `init`, `update`, `matrix`, `onChange`, `saved`, `unsavedChanges`, `viewRemote`

    import Klar
    import Klar.Button as Button
    import Klar.PermissionMatrix as PermissionMatrix
    import Klar.Remote as Remote

    -- model
    { access : PermissionMatrix.State -- PermissionMatrix.init "role-matrix"
    , grants : Remote Grants -- what the grid shows, with the changes not saved yet
    , savedGrants : Grants -- what the server has: set it when the grants load and when a save succeeds
    }

    -- update
    MatrixMsg m ->
        let
            ( access, cmd ) =
                PermissionMatrix.update m model.access
        in
        ( { model | access = access }, Cmd.map MatrixMsg cmd )

    CellsChanged changes ->
        ( { model | grants = Remote.map (applyChanges changes) model.grants }, Cmd.none )

    Save ->
        let
            changes =
                PermissionMatrix.unsavedChanges (cellOf model.savedGrants)
                    (toMatrix (Remote.withDefault model.savedGrants model.grants))
        in
        ( model, Api.saveGrants changes GrantsSaved )

    Reload ->
        -- "Try again" goes away while the grants load: the matrix takes the focus
        ( { model | grants = Remote.refresh model.grants }
        , Cmd.batch [ Api.loadGrants GrantsLoaded, Klar.focus "role-matrix" NoOp ]
        )

    applyChanges changes grants =
        List.foldl store grants changes

    store change =
        case PermissionMatrix.newAccess change of
            Just access ->
                Grants.set (PermissionMatrix.changedRole change) (PermissionMatrix.changedPermission change) access

            Nothing ->
                Grants.remove (PermissionMatrix.changedRole change) (PermissionMatrix.changedPermission change)

    -- view
    PermissionMatrix.viewRemote MatrixMsg
        [ PermissionMatrix.onChange CellsChanged
        , PermissionMatrix.saved (cellOf model.savedGrants)
        , PermissionMatrix.toolbarActions
            [ Button.view [ Button.primary, Button.small, Button.onClick Save ] "Save" ]
        , PermissionMatrix.onRetry Reload
        , PermissionMatrix.settings model.settings
        ]
        model.access
        (Remote.map toMatrix model.grants)

    toMatrix : Grants -> PermissionMatrix.Matrix Role Permission
    toMatrix grants =
        PermissionMatrix.matrix
            { roles =
                [ PermissionMatrix.role Picker "Picker"
                , PermissionMatrix.role Supervisor "Supervisor"
                , PermissionMatrix.role Administrator "Administrator"
                    |> PermissionMatrix.locked "Administrator always has every permission"
                ]
            , roleKey = Role.toString
            , permissions =
                [ PermissionMatrix.permission ViewOrders "View orders" |> PermissionMatrix.inGroup "Orders"
                , PermissionMatrix.permission CancelOrders "Cancel orders" |> PermissionMatrix.inGroup "Orders"
                , PermissionMatrix.permission AdjustStock "Adjust stock" |> PermissionMatrix.inGroup "Stock"
                ]
            , permissionKey = Permission.toString
            , cell = cellOf grants
            }

    cellOf : Grants -> Role -> Permission -> PermissionMatrix.Cell
    cellOf grants role permission =
        PermissionMatrix.direct (PermissionMatrix.fromBool (Grants.has role permission grants))

Use it for the screen where roles get their permissions. Roles are the columns
and permissions the rows, in groups if you give them one (`inGroup`). Each cell is
granted or denied, directly or by inheritance; you decide what a cell says (the `cell`
function of `matrix`), the matrix draws it, and asks you to change it (`onChange`).
Without `onChange` the matrix is read-only: the cells say what they are with an icon and
a word, and nothing can be changed. For a list of the same rights per person, use
[Klar.Table](Klar.Table.md).

**Roles and permissions are your own types.** A `role` and a `permission` can be
anything that has a key as text (`roleKey` and `permissionKey` of `matrix`). There is no
way back from the key to the value (as in `Ids.make`) because none is needed: the
matrix keeps your values in the `Matrix` it is given on every render and hands them back
in a `Change`, so you never parse an id. Keys name the cells in the page and in the
state, so a key must be different for every role and every permission. One that has been
seen before is left out, and a note above the grid says how many were ignored, so a
screen that decides access never hides that. The `State` only holds text and numbers
(the filter, the folded groups, where the focus is), never your types.

**You hold the values.** `cell` gives the cell of every role and permission on every
render, and `onChange` reports what the user asked for as a list of `Change`: one for a
cell, many for a row or a column. One click or key press makes one message. What you
store is up to you; a change says what a role should have `newAccess` of its own: an
access (store it) or nothing (it inherits again: remove what you stored).

**Inheritance.** A role may get a permission from somewhere else: another role, a group.
Say both what was decided for the role itself (`own`) and what it would inherit
(`inherited`, with where from) in `cell`. A cell that only inherits is drawn with a dashed
box and the source. Clicking it, or Space or Enter, overrides it with the opposite. When the
role has an access of its own over an inherited one, the cell has a small mark in its corner
and offers to go back: an "inherit again" mark under the pointer, and Delete or Backspace on the keyboard (named in
the cell's `aria-keyshortcuts`). Toggling an own value to what would be inherited anyway
also returns to inheriting. In every case you get a `Change` whose `newAccess` is `Nothing`,
so no application has to work out inheritance to undo an override.

**Unsaved changes.** Give `saved` the values as they were last saved, and the cells where
the role's own access differs are marked with a dot (and "unsaved change" for screen
readers) and counted above the grid, next to your own buttons (`toolbarActions`), for
Save and Discard. `unsavedChanges` gives the same cells as a list of `Change`, which is
what a Save request sends. Nothing is kept inside the matrix: load a new baseline by giving
a new `saved`.

**Remote data and focus.** `viewRemote` draws a skeleton while the matrix loads, the
problem with "Try again" (`onRetry`) when it failed, and the matrix when it is there. Data
that is `Kept` stays on the screen and editable: dimmed and busy while it is refreshed, and
with "Old data from 14:05" and a retry above the grid when the last refresh failed (the time
in the zone of `settings`). The grid is the same element while it refreshes, so the focus
stays on the cell it was on. The id given to `init` is on the frame of the matrix in every
state, and the frame can take focus: "Try again" goes away while the data loads, so call
`Klar.focus` with that id in the update branch of the retry message.

**Keyboard.** The grid is one tab stop. The arrow keys move between cells, `Home` and
`End` to the first and last cell of the row, `Ctrl+Home` and `Ctrl+End` to the first
and last cell of the matrix, `PageUp` and `PageDown` ten rows. `Space` or `Enter` toggles the
cell, once however long the key is held; `Delete` or `Backspace` inherits again. The header
of a role and the header of a permission hold a checkbox that grants or denies the whole
column or row (partly granted shows a dash; a click grants the rest, and a cell that
already shows the access is left alone). Headers and group rows are stops too: `Enter` or
`Space` on a group row folds it. Typing in the filter box keeps the permissions that contain
every word, with their group, and opens the groups that have a match.

**Locked roles.** `locked` takes the reason ("Administrator always has every permission")
and turns the column to read-only, with a lock and the reason written under the grid.
Header checkboxes skip a locked column.

**Accessibility.** The grid is a `grid` with sticky headers. A cell is read as "Supervisor,
Cancel orders, granted", with ", inherited from Dispatcher", ", overrides inherited denied
from Dispatcher", ", locked" (read-only) and ", unsaved change" when that is so. An editable
grid is described by a short instruction ("Space or Enter changes a cell") and every cell that
can change names its keys in `aria-keyshortcuts`. There is one polite region. What a person
does is announced in it ("Cancel orders granted to Supervisor. 2 unsaved changes"), from the
value that `cell` gives afterwards, so a change you refuse is not announced as made. The
number is the one the change led to, so a save does not say the change again, and the
announcement is cleared after five seconds, so a refresh later does not either. While the
filter is used the region says how many permissions match. Headers and the filter have names;
the state is never colour alone.

**Size.** Only the permissions that are shown are turned into HTML, up to 500 rows (a
note says how many were cut: use the filter or the groups). Events are caught once on
the grid, so no cell has handlers of its own, and each cell is drawn from a few plain values
with `Html.Lazy`: a key that moves the focus draws two cells again, and a toggle the cells it
changed, also in a grid of 200 permissions and 25 roles (5 000 cells). Header checkboxes act
on every permission that matches the filter, folded groups and rows beyond the cap included.

The built-in text follows `locale` (English by default). Names come from you.

## Views

### `view`

```elm
view :
    (Msg -> msg)
    -> List (Attribute role permission msg)
    -> State
    -> Matrix role permission
    -> Html msg
```

The matrix.

    PermissionMatrix.view MatrixMsg [ PermissionMatrix.onChange CellsChanged ] model.access (toMatrix grants)

### `viewRemote`

```elm
viewRemote :
    (Msg -> msg)
    -> List (Attribute role permission msg)
    -> State
    -> Remote.Remote (Matrix role permission)
    -> Html msg
```

The same for a matrix that comes from the backend. `Loaded` shows the matrix, `Failed`
shows the problem with a "Try again" button (`onRetry`), and `NotAsked` and `Loading` show a
skeleton of a grid. `Kept` shows the matrix it keeps, editable as `Loaded`: dimmed and
`aria-busy` while it is refreshed, and with "Old data from 14:05" and a retry above the grid
when the last refresh failed. The frame of the matrix has the id of `init` in every state.

    PermissionMatrix.viewRemote MatrixMsg [ PermissionMatrix.onRetry Reload ] model.access (Remote.map toMatrix model.grants)

## Roles and permissions

### `Matrix`

```elm
type Matrix role permission  -- opaque: no constructors are exposed
```

The data of one matrix: the roles, the permissions and what every cell says.
Build it from your own data on every render with `matrix`; it holds no state.

### `Role`

```elm
type Role role  -- opaque: no constructors are exposed
```

One role, a column. Make it with `role`.

### `Permission`

```elm
type Permission permission  -- opaque: no constructors are exposed
```

One permission, a row. Make it with `permission`.

### `matrix`

```elm
matrix :
    { roles : List (Role role), roleKey : role -> String, permissions : List (Permission permission), permissionKey : permission -> String, cell : role -> permission -> Cell }
    -> Matrix role permission
```

The matrix. Everything in the record is needed, so nothing can be forgotten:
the roles (the columns) and how a role is written as a key, the permissions (the
rows) and how a permission is written as a key, and what each cell says.

The keys are text that is different for every role, and for every permission: they
name the cells in the page and in the state. Use the same text that your own type
has for its URLs or its database. A role or a permission whose key has been seen
before is left out, and a note above the grid says so. `cell` is called for every pair
on every render, so keep it cheap (a `Dict` or a `Set` lookup).

    PermissionMatrix.matrix
        { roles = [ PermissionMatrix.role Picker "Picker" ]
        , roleKey = Role.toString
        , permissions = [ PermissionMatrix.permission ViewOrders "View orders" ]
        , permissionKey = Permission.toString
        , cell = \r p -> PermissionMatrix.direct (PermissionMatrix.fromBool (Grants.has r p grants))
        }

### `role`

```elm
role : role -> String -> Role role
```

A role with the name shown at the top of its column.

    PermissionMatrix.role Supervisor "Supervisor"

### `locked`

```elm
locked : String -> Role role -> Role role
```

Says that nobody may change this role, and why: the column cannot be edited, its
header checkbox is not there, and the reason is written under the grid. Say why, as
the user would ask: "Administrator always has every permission". A blank reason
still locks the role and says "This role cannot be changed".

### `permission`

```elm
permission : permission -> String -> Permission permission
```

A permission with the name shown at the start of its row.

    PermissionMatrix.permission CancelOrders "Cancel orders"

### `inGroup`

```elm
inGroup : String -> Permission permission -> Permission permission
```

Puts the permission in a group, which has a row of its own that folds. Give the
permissions of a group in a row or not: the matrix gathers them, the groups in the
order in which they first appear. Permissions without a group stay together where
the first of them appeared, with no group row. A blank name means no group. A group has
no id of its own: its name is what the user reads and what the state remembers as folded,
so the names of two groups must differ, and a group that is renamed (for example by a change
of language) opens again.

## Cells

### `Access`

```elm
type Access  -- opaque: no constructors are exposed
```

What a role may do with a permission: granted or denied. Opaque, so that a third
value (such as "own records only") can be added later without breaking anyone. Make
one with `granted`, `denied` or `fromBool`, and ask it with `isGranted`. It is what the
application stores and compares (`==` works).

### `Cell`

```elm
type Cell  -- opaque: no constructors are exposed
```

What one cell says. The application knows two things about a role and a permission:
what was said for this role itself (its own access, if anything) and what it would
get from somewhere else (an inherited access: another role, a group, a policy). The cell
shows the first when there is one and the second otherwise. Make one with `cell`, or with
`direct` when nothing is inherited. Opaque, so that what a cell can say can grow.

### `granted`

```elm
granted : Access
```

The role may.

### `denied`

```elm
denied : Access
```

The role may not.

### `fromBool`

```elm
fromBool : Bool -> Access
```

`True` is `granted` and `False` is `denied`, for the application that keeps a
`Bool` or a `Set` of what is granted.

    PermissionMatrix.direct (PermissionMatrix.fromBool (Set.member ( role, permission ) grants))

### `isGranted`

```elm
isGranted : Access -> Bool
```

Whether the access lets the role do it.

### `cell`

```elm
cell : { own : Maybe Access, inherited : Maybe { access : Access, from : Maybe String } } -> Cell
```

A cell from what is known about the role and the permission.

  - `own`: what was said for this role itself. `Nothing` when nothing was.
  - `inherited`: what the role gets from somewhere else, and where from (a name such
    as "Dispatcher" or "Floor staff group", shown in the cell and read by screen
    readers), or `Nothing` when there is nothing to inherit.

The four cases: `own` and nothing inherited is a plain, direct cell; only `inherited` is a
cell that inherits (a dashed box with the source); both is a cell that overrides what it
would inherit (a plain box that can be returned to inheriting); neither says "denied".

    PermissionMatrix.cell
        { own = Dict.get ( role, permission ) decisions
        , inherited =
            parentOf role
                |> Maybe.map (\above -> { access = accessOf above permission, from = Just (nameOf above) })
        }

Toggling and inheriting again are explained in the module documentation.

### `direct`

```elm
direct : Access -> Cell
```

A cell that has this access of its own and inherits nothing: the usual cell of a
matrix without inheritance.

    PermissionMatrix.direct PermissionMatrix.granted

## Changes

### `Change`

```elm
type Change role permission  -- opaque: no constructors are exposed
```

One change that the user asked for, in your own types: this role gets this access of
its own for this permission, or none of its own (it inherits again). A click on a cell makes a
list of one; the checkbox of a role or of a permission makes a list of every cell that has to
change (cells that already show the access are left out, and so are the cells of locked
roles). Read it with `changedRole`, `changedPermission` and `newAccess`.

### `changedRole`

```elm
changedRole : Change role permission -> role
```

The role of a change, as you gave it to `role`.

### `changedPermission`

```elm
changedPermission : Change role permission -> permission
```

The permission of a change, as you gave it to `permission`.

### `newAccess`

```elm
newAccess : Change role permission -> Maybe Access
```

The access the role should have of its own after the change: `Just` an access to store
for the role and the permission, or `Nothing` when the role should have none of its own and
inherit again, which means that what you stored for the pair is removed.

    case PermissionMatrix.newAccess change of
        Just access ->
            Dict.insert key access decisions

        Nothing ->
            Dict.remove key decisions

### `unsavedChanges`

```elm
unsavedChanges :
    (role -> permission -> Cell)
    -> Matrix role permission
    -> List (Change role permission)
```

The unsaved changes of a matrix, for the request that saves them: one `Change` for every
role and permission whose own access in the matrix differs from the saved one, with the own
access the role has now as `newAccess` (`Nothing`: it inherits now, remove what was stored).
Give it the same function as `saved`. These are the cells that the matrix marks with a dot
and counts above the grid, by the same rule (what is inherited does not count), in the order
of the permissions and then of the roles; a role or a permission whose key was seen before
is left out, as in the grid.

    PermissionMatrix.unsavedChanges (cellOf model.savedGrants) (toMatrix grants)

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

What the matrix remembers: the text in the filter, the groups that are folded, the
cell the keyboard is at, and the last thing a person did (for the announcement). It holds
no roles, no permissions and no values: those are yours. Make one with `init`.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

What happens inside the matrix: text typed in the filter, a group folded, the focus
moving. Wrap it in a constructor of your own message type, pass that constructor to `view`,
and hand the messages you get back to `update`.

### `init`

```elm
init : String -> State
```

A matrix with an empty filter, no group folded and the focus at the first cell. The
`String` is a DOM id that must be unique on the page: it is the id of the frame of the
matrix, which can take focus with `Klar.focus` in every state (loading, failed, loaded), and
the prefix of the ids of its cells.

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Applies a message. The `Cmd` moves the browser's focus to the cell that an arrow key
reached, and clears an announcement after a while, so map it with your message constructor.

### `query`

```elm
query : State -> String
```

The text in the filter box. Only the permissions that contain every word are shown.

### `setQuery`

```elm
setQuery : String -> State -> State
```

Sets the text of the filter, for example to clear it or to restore a saved view.

### `collapsedGroups`

```elm
collapsedGroups : State -> List String
```

The names of the groups that are folded, in alphabetical order.

### `setCollapsedGroups`

```elm
setCollapsedGroups : List String -> State -> State
```

Folds exactly these groups (the others open), for example the groups the user folded
last time. While the filter has text, every group that has a match is open.

## Attributes

### `Attribute`

```elm
type Attribute role permission msg  -- opaque: no constructors are exposed
```

A setting of the matrix. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones. `role` and `permission` are your own
types, `msg` is your message type.

### `onChange`

```elm
onChange : (List (Change role permission) -> msg) -> Attribute role permission msg
```

Makes the matrix editable and says where changes go. A click or a key press on a cell
sends one message with a list of one `Change`; a header checkbox sends one message with all the
cells it changes. Delete or Backspace, and the "inherit again" mark, send a change that says
the role has no access of its own any more. Locked roles never change. Without `onChange` the matrix is read-only: the
cells are not clickable, there are no header checkboxes, and each cell shows its state as
an icon and a word.

    PermissionMatrix.onChange CellsChanged

### `saved`

```elm
saved : (role -> permission -> Cell) -> Attribute role permission msg
```

The values as they were last saved, in the same form as `cell`. A cell where the role's
own access differs from the saved one (what is inherited does not count) is marked with a dot and
"unsaved change" for screen readers, and the number of such cells is counted above the grid.
Give a new function when the data has been saved or loaded again, and the marks are gone.

### `toolbarActions`

```elm
toolbarActions : List (Html msg) -> Attribute role permission msg
```

Your own buttons, such as Save and Discard, shown at the end of the line above the grid,
next to the number of unsaved changes. The default is none.

### `density`

```elm
density : Theme.Density -> Attribute role permission msg
```

The height of the rows: `Compact`, `Normal` or `Comfortable`, the same as
[Klar.Table](Klar.Table.md) (see [Klar.Theme](Klar.Theme.md)). Without it the rows follow the
density of the application (`Klar.Settings`), which is `Normal` unless it says otherwise;
with it the matrix has this density whatever the application's is.

### `ariaLabel`

```elm
ariaLabel : String -> Attribute role permission msg
```

The accessible name of the grid, for example "Permissions of the roles". The default is
"Permissions", in the language of `locale`.

### `maxHeight`

```elm
maxHeight : Int -> Attribute role permission msg
```

The height in pixels at which the grid starts to scroll inside itself, with the headers
and the names of the permissions staying in view. The default is 70% of the height of the
window, so a long list scrolls instead of making the page long.

### `onRetry`

```elm
onRetry : msg -> Attribute role permission msg
```

The message sent by the "Try again" button when `viewRemote` shows a failure that is
worth retrying, or old data whose refresh failed. Without it there is no such button. The
button goes away while the data loads: in the update branch of this message, call
`Klar.focus` with the id given to `init`.

    PermissionMatrix.onRetry Reload

### `settings`

```elm
settings : Settings.Settings -> Attribute role permission msg
```

The settings of the application (`Klar.Settings`): the time zone of "Old data from
14:05" when `viewRemote` shows data whose refresh failed. Without it the time is written in
UTC and says so.

    PermissionMatrix.settings model.settings

### `locale`

```elm
locale : Locale.Locale -> Attribute role permission msg
```

The language of the built-in text: the words of the cells, the names for screen readers,
the filter and the notes. The default is `Locale.default`, which is English. See
[Klar.Locale](Klar.Locale.md).
