module Klar.PermissionMatrix exposing
    ( view, viewRemote
    , Matrix, matrix, Role, role, locked, Permission, permission, inGroup
    , Access, granted, denied, fromBool, isGranted, Cell, cell, direct
    , Change, changedRole, changedPermission, newAccess
    , State, init, Msg, update, query, setQuery, collapsedGroups, setCollapsedGroups
    , Attribute, onChange, saved, toolbarActions, density, ariaLabel, maxHeight, onRetry, locale
    )

{-| A grid of roles and permissions that says what each role may do, and lets an
administrator change it: the classic screen of an application with users.

Use when: an administrator sets which roles may do what, in a grid of roles and permissions.
Do not use when: only a list of options is chosen for one user, use `Klar.CheckboxGroup`.
Quick path: `init`, `update`, `matrix`, `onChange`, `viewRemote`

    import Klar.PermissionMatrix as PermissionMatrix
    import Klar.Remote as Remote

    -- model
    { access : PermissionMatrix.State -- PermissionMatrix.init "role-matrix"
    , grants : Remote Grants
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
        , PermissionMatrix.saved (cellOf savedGrants)
        , PermissionMatrix.onRetry Reload
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
[Klar.Table](Klar-Table).

**Roles and permissions are your own types.** A `role` and a `permission` can be
anything that has a key as text (`roleKey` and `permissionKey` of `matrix`). There is no
way back from the key to the value (as in `Tree.nodeIds`) because none is needed: the
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
Save and Discard. Nothing is kept inside the matrix: load a new baseline by giving a new
`saved`.

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
from Dispatcher", ", locked" (read-only) and ", unsaved change" when that is so. There is one
polite region. What a person does is announced in it ("Cancel orders granted to Supervisor.
2 unsaved changes"), from the value that `cell` gives afterwards, so a change you refuse is
not announced as made; while the filter is used it says how many permissions match.
Headers and the filter have names; the state is never colour alone.

**Size.** Only the permissions that are shown are turned into HTML, up to 500 rows (a
note says how many were cut: use the filter or the groups). Events are caught once on
the grid, so no cell has handlers of its own: 200 permissions and 25 roles are 5 000 cells
and stay responsive. Every message (a key that moves the focus, a toggle) builds the whole
grid again, as in any Elm view: the cells cannot be skipped with `Html.Lazy`, because the
roles, the permissions and the `cell` function are new values on every render. Header
checkboxes act on every permission that matches the filter, folded groups and rows beyond
the cap included.

The built-in text follows `locale` (English by default). Names come from you.


# Views

@docs view, viewRemote


# Roles and permissions

@docs Matrix, matrix, Role, role, locked, Permission, permission, inGroup


# Cells

@docs Access, granted, denied, fromBool, isGranted, Cell, cell, direct


# Changes

@docs Change, changedRole, changedPermission, newAccess


# State

@docs State, init, Msg, update, query, setQuery, collapsedGroups, setCollapsedGroups


# Attributes

@docs Attribute, onChange, saved, toolbarActions, density, ariaLabel, maxHeight, onRetry, locale

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Decode as Decode exposing (Decoder)
import Klar.Checkbox as Checkbox
import Klar.EmptyState as EmptyState
import Klar.ErrorState as ErrorState
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness
import Klar.Locale as Locale exposing (Locale)
import Klar.PermissionMatrix.Grid as Grid exposing (ColumnKey(..), RowKey(..))
import Klar.Remote as Remote exposing (Remote)
import Klar.Skeleton as Skeleton
import Klar.TextInput as TextInput
import Klar.Theme as Theme exposing (Density(..), Size(..))
import Set exposing (Set)



-- ROLES AND PERMISSIONS


{-| The data of one matrix: the roles, the permissions and what every cell says.
Build it from your own data on every render with `matrix`; it holds no state.
-}
type Matrix role permission
    = Matrix
        { roles : List (Role role)
        , roleKey : role -> String
        , permissions : List (Permission permission)
        , permissionKey : permission -> String
        , cell : role -> permission -> Cell
        }


{-| One role, a column. Make it with `role`.
-}
type Role role
    = Role
        { value : role
        , label : String
        , locked : Maybe String
        }


{-| One permission, a row. Make it with `permission`.
-}
type Permission permission
    = Permission
        { value : permission
        , label : String
        , group : Maybe String
        }


{-| The matrix. Everything in the record is needed, so nothing can be forgotten:
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

-}
matrix :
    { roles : List (Role role)
    , roleKey : role -> String
    , permissions : List (Permission permission)
    , permissionKey : permission -> String
    , cell : role -> permission -> Cell
    }
    -> Matrix role permission
matrix =
    Matrix


{-| A role with the name shown at the top of its column.

    PermissionMatrix.role Supervisor "Supervisor"

-}
role : role -> String -> Role role
role value text =
    Role { value = value, label = text, locked = Nothing }


{-| Says that nobody may change this role, and why: the column cannot be edited, its
header checkbox is not there, and the reason is written under the grid. Say why, as
the user would ask: "Administrator always has every permission". A blank reason
still locks the role and says "This role cannot be changed".
-}
locked : String -> Role role -> Role role
locked reason (Role data) =
    Role { data | locked = Just (Maybe.withDefault "" (Internal.nonEmpty reason |> Maybe.map String.trim)) }


{-| A permission with the name shown at the start of its row.

    PermissionMatrix.permission CancelOrders "Cancel orders"

-}
permission : permission -> String -> Permission permission
permission value text =
    Permission { value = value, label = text, group = Nothing }


{-| Puts the permission in a group, which has a row of its own that folds. Give the
permissions of a group in a row or not: the matrix gathers them, the groups in the
order in which they first appear. Permissions without a group stay together where
the first of them appeared, with no group row. A blank name means no group. A group has
no id of its own: its name is what the user reads and what the state remembers as folded,
so the names of two groups must differ, and a group that is renamed (for example by a change
of language) opens again.
-}
inGroup : String -> Permission permission -> Permission permission
inGroup name (Permission data) =
    Permission { data | group = Maybe.map String.trim (Internal.nonEmpty name) }



-- CELLS


{-| What a role may do with a permission: granted or denied. Opaque, so that a third
value (such as "own records only") can be added later without breaking anyone. Make
one with `granted`, `denied` or `fromBool`, and ask it with `isGranted`. It is what the
application stores and compares (`==` works).
-}
type Access
    = AccessGranted
    | AccessDenied


{-| The role may.
-}
granted : Access
granted =
    AccessGranted


{-| The role may not.
-}
denied : Access
denied =
    AccessDenied


{-| `True` is `granted` and `False` is `denied`, for the application that keeps a
`Bool` or a `Set` of what is granted.

    PermissionMatrix.direct (PermissionMatrix.fromBool (Set.member ( role, permission ) grants))

-}
fromBool : Bool -> Access
fromBool yes =
    if yes then
        AccessGranted

    else
        AccessDenied


{-| Whether the access lets the role do it.
-}
isGranted : Access -> Bool
isGranted access =
    access == AccessGranted


{-| What one cell says. The application knows two things about a role and a permission:
what was said for this role itself (its own access, if anything) and what it would
get from somewhere else (an inherited access: another role, a group, a policy). The cell
shows the first when there is one and the second otherwise. Make one with `cell`, or with
`direct` when nothing is inherited. Opaque, so that what a cell can say can grow.
-}
type Cell
    = Cell
        { own : Maybe Access
        , inherited : Maybe { access : Access, from : Maybe String }
        }


{-| A cell from what is known about the role and the permission.

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

-}
cell :
    { own : Maybe Access
    , inherited : Maybe { access : Access, from : Maybe String }
    }
    -> Cell
cell given =
    Cell
        { own = given.own
        , inherited =
            Maybe.map
                (\inheritance -> { inheritance | from = Maybe.andThen Internal.nonEmpty inheritance.from |> Maybe.map String.trim })
                given.inherited
        }


{-| A cell that has this access of its own and inherits nothing: the usual cell of a
matrix without inheritance.

    PermissionMatrix.direct PermissionMatrix.granted

-}
direct : Access -> Cell
direct access =
    Cell { own = Just access, inherited = Nothing }


{-| The facts of a cell, as the matrix uses them.
-}
type alias Facts =
    { access : Access
    , own : Maybe Access

    -- the access shown comes from somewhere else (the role has none of its own)
    , inheriting : Bool

    -- the role has an access of its own that replaces an inherited one
    , overriding : Bool
    , source : Maybe String
    , inheritedAccess : Maybe Access
    }


factsOf : Cell -> Facts
factsOf (Cell data) =
    let
        inheritedAccess =
            Maybe.map .access data.inherited
    in
    { access = Maybe.withDefault AccessDenied (firstJust data.own inheritedAccess)
    , own = data.own
    , inheriting = data.own == Nothing && data.inherited /= Nothing
    , overriding = data.own /= Nothing && data.inherited /= Nothing
    , source = Maybe.andThen .from data.inherited
    , inheritedAccess = inheritedAccess
    }


firstJust : Maybe a -> Maybe a -> Maybe a
firstJust first second =
    case first of
        Just _ ->
            first

        Nothing ->
            second


cellAccess : Cell -> Access
cellAccess theCell =
    (factsOf theCell).access


cellGranted : Cell -> Bool
cellGranted theCell =
    isGranted (cellAccess theCell)


{-| Two cells are the same when the role has the same access of its own in both. What is
inherited does not count: if a parent changes, the cell of the parent is the one that has
an unsaved change, not every cell below it.
-}
sameCell : Cell -> Cell -> Bool
sameCell (Cell a) (Cell b) =
    a.own == b.own


opposite : Access -> Access
opposite access =
    case access of
        AccessGranted ->
            AccessDenied

        AccessDenied ->
            AccessGranted


{-| What the role's own access has to become for the cell to show this access: nothing of
its own when the inherited access is the one wanted (so the cell inherits again), the access
itself otherwise.
-}
ownFor : Access -> Cell -> Maybe Access
ownFor target theCell =
    case (factsOf theCell).inheritedAccess of
        Just inheritedAccess ->
            if inheritedAccess == target then
                Nothing

            else
                Just target

        Nothing ->
            Just target


{-| What a click or a key on a cell asks for: the opposite of what it shows.
-}
toggled : Cell -> Maybe Access
toggled theCell =
    ownFor (opposite (cellAccess theCell)) theCell


{-| One change that the user asked for, in your own types: this role gets this access of
its own for this permission, or none of its own (it inherits again). A click on a cell makes a
list of one; the checkbox of a role or of a permission makes a list of every cell that has to
change (cells that already show the access are left out, and so are the cells of locked
roles). Read it with `changedRole`, `changedPermission` and `newAccess`.
-}
type Change role permission
    = Change
        { role : role
        , permission : permission
        , access : Maybe Access
        }


{-| The role of a change, as you gave it to `role`.
-}
changedRole : Change role permission -> role
changedRole (Change data) =
    data.role


{-| The permission of a change, as you gave it to `permission`.
-}
changedPermission : Change role permission -> permission
changedPermission (Change data) =
    data.permission


{-| The access the role should have of its own after the change: `Just` an access to store
for the role and the permission, or `Nothing` when the role should have none of its own and
inherit again, which means that what you stored for the pair is removed.

    case PermissionMatrix.newAccess change of
        Just access ->
            Dict.insert key access decisions

        Nothing ->
            Dict.remove key decisions

-}
newAccess : Change role permission -> Maybe Access
newAccess (Change data) =
    data.access



-- ATTRIBUTES


{-| A setting of the matrix. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones. `role` and `permission` are your own
types, `msg` is your message type.
-}
type Attribute role permission msg
    = Attribute (Config role permission msg -> Config role permission msg)


type alias Config role permission msg =
    { locale : Locale
    , onChange : Maybe (List (Change role permission) -> msg)
    , saved : Maybe (role -> permission -> Cell)
    , actions : List (Html msg)
    , density : Density
    , label : Maybe String
    , maxHeight : Maybe Int
    , onRetry : Maybe msg
    }


configure : List (Attribute role permission msg) -> Config role permission msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { locale = Locale.default
        , onChange = Nothing
        , saved = Nothing
        , actions = []
        , density = Normal
        , label = Nothing
        , maxHeight = Nothing
        , onRetry = Nothing
        }
        attributes


{-| Makes the matrix editable and says where changes go. A click or a key press on a cell
sends one message with a list of one `Change`; a header checkbox sends one message with all the
cells it changes. Delete or Backspace, and the "inherit again" mark, send a change that says
the role has no access of its own any more. Locked roles never change. Without `onChange` the matrix is read-only: the
cells are not clickable, there are no header checkboxes, and each cell shows its state as
an icon and a word.

    PermissionMatrix.onChange CellsChanged

-}
onChange : (List (Change role permission) -> msg) -> Attribute role permission msg
onChange toMsg =
    Attribute (\config -> { config | onChange = Just toMsg })


{-| The values as they were last saved, in the same form as `cell`. A cell where the role's
own access differs from the saved one (what is inherited does not count) is marked with a dot and
"unsaved change" for screen readers, and the number of such cells is counted above the grid.
Give a new function when the data has been saved or loaded again, and the marks are gone.
-}
saved : (role -> permission -> Cell) -> Attribute role permission msg
saved lookup =
    Attribute (\config -> { config | saved = Just lookup })


{-| Your own buttons, such as Save and Discard, shown at the end of the line above the grid,
next to the number of unsaved changes. The default is none.
-}
toolbarActions : List (Html msg) -> Attribute role permission msg
toolbarActions html =
    Attribute (\config -> { config | actions = html })


{-| The height of the rows: `Compact`, `Normal` (the default) or `Comfortable`, the same as
[Klar.Table](Klar-Table) (see [Klar.Theme](Klar-Theme)).
-}
density : Density -> Attribute role permission msg
density value =
    Attribute (\config -> { config | density = value })


{-| The accessible name of the grid, for example "Permissions of the roles". The default is
"Permissions", in the language of `locale`.
-}
ariaLabel : String -> Attribute role permission msg
ariaLabel text =
    Attribute (\config -> { config | label = Just text })


{-| The height in pixels at which the grid starts to scroll inside itself, with the headers
and the names of the permissions staying in view. The default is 70% of the height of the
window, so a long list scrolls instead of making the page long.
-}
maxHeight : Int -> Attribute role permission msg
maxHeight pixels =
    Attribute (\config -> { config | maxHeight = Just pixels })


{-| The message sent by the "Try again" button when `viewRemote` shows a failure that is
worth retrying.
-}
onRetry : msg -> Attribute role permission msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The language of the built-in text: the words of the cells, the names for screen readers,
the filter and the notes. The default is `Locale.default`, which is English. See
[Klar.Locale](Klar-Locale).
-}
locale : Locale -> Attribute role permission msg
locale value =
    Attribute (\config -> { config | locale = value })



-- STATE


{-| What the matrix remembers: the text in the filter, the groups that are folded, the
cell the keyboard is at, and the last thing a person did (for the announcement). It holds
no roles, no permissions and no values: those are yours. Make one with `init`.
-}
type State
    = State StateData


type alias StateData =
    { id : String
    , query : String
    , collapsed : Set String
    , focus : Maybe ( RowKey, ColumnKey )
    , acted : Maybe Subject
    }


{-| What the person did last, as keys: a cell, a whole role or a whole permission.
-}
type Subject
    = CellOf String String
    | RoleOf String
    | PermissionOf String


{-| A matrix with an empty filter, no group folded and the focus at the first cell. The
`String` is a DOM id that must be unique on the page: it is the id of the matrix and the
prefix of the ids of its cells.
-}
init : String -> State
init id =
    State { id = id, query = "", collapsed = Set.empty, focus = Nothing, acted = Nothing }


{-| The text in the filter box. Only the permissions that contain every word are shown.
-}
query : State -> String
query (State data) =
    data.query


{-| Sets the text of the filter, for example to clear it or to restore a saved view.
-}
setQuery : String -> State -> State
setQuery text (State data) =
    State { data | query = text, acted = Nothing }


{-| The names of the groups that are folded, in alphabetical order.
-}
collapsedGroups : State -> List String
collapsedGroups (State data) =
    Set.toList data.collapsed


{-| Folds exactly these groups (the others open), for example the groups the user folded
last time. While the filter has text, every group that has a match is open.
-}
setCollapsedGroups : List String -> State -> State
setCollapsedGroups names (State data) =
    State { data | collapsed = Set.fromList names }


{-| What happens inside the matrix: text typed in the filter, a group folded, the focus
moving. Wrap it in a constructor of your own message type, pass that constructor to `view`,
and hand the messages you get back to `update`.
-}
type Msg
    = QueryChanged String
    | GroupToggled String
    | Focused RowKey ColumnKey
    | Moved RowKey ColumnKey
    | Acted Subject
    | Noop


{-| Applies a message. The `Cmd` moves the browser's focus to the cell that an arrow key
reached, so map it with your message constructor.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State data) =
    case msg of
        QueryChanged text ->
            ( State { data | query = text, acted = Nothing }, Cmd.none )

        GroupToggled name ->
            ( State
                { data
                    | collapsed =
                        if Set.member name data.collapsed then
                            Set.remove name data.collapsed

                        else
                            Set.insert name data.collapsed
                }
            , Cmd.none
            )

        Focused row column ->
            ( State { data | focus = Just ( row, column ) }, Cmd.none )

        Moved row column ->
            ( State { data | focus = Just ( row, column ) }
            , Internal.focus (Grid.domId data.id row column) Noop
            )

        Acted subject ->
            ( State { data | acted = Just subject }, Cmd.none )

        Noop ->
            ( State data, Cmd.none )



-- TEXT


type alias Texts =
    { gridLabel : String
    , filterLabel : String
    , filterPlaceholder : String
    , corner : String
    , access : Access -> String
    , accessTitle : Access -> String
    , inheritedWord : String
    , inheritedPlain : String
    , inheritedFrom : String -> String
    , overrides : String -> Maybe String -> String
    , inheritAgain : String
    , lockedWord : String
    , changedWord : String
    , lockedDefault : String
    , grantAllRole : String -> String
    , grantShownRole : Int -> String -> String
    , grantRowToAll : String -> String
    , groupName : String -> Int -> String
    , groupSummary : String -> String -> Int -> Int -> String
    , changes : Int -> String
    , matchCount : Int -> Int -> String
    , cut : Int -> Int -> String
    , duplicates : Int -> Int -> String
    , noRoles : String
    , noPermissions : String
    , noMatch : String -> String
    , loading : String
    , announceCell : String -> String -> Access -> Maybe String -> String
    , announceRole : String -> Int -> Int -> String
    , announcePermission : String -> Int -> Int -> String
    , lockedNote : String -> String -> String
    }


texts : Locale -> Texts
texts loc =
    let
        pick nb en =
            Locale.pick loc { nb = nb, en = en }

        number n =
            Format.int loc n
    in
    { gridLabel = pick "Tilganger" "Permissions"
    , filterLabel = pick "Filtrer tilganger" "Filter permissions"
    , filterPlaceholder = pick "Filtrer tilganger ..." "Filter permissions ..."
    , corner = pick "Tilgang" "Permission"
    , access =
        \access ->
            case access of
                AccessGranted ->
                    pick "tillatt" "granted"

                AccessDenied ->
                    pick "nektet" "denied"
    , accessTitle =
        \access ->
            case access of
                AccessGranted ->
                    pick "Tillatt" "Granted"

                AccessDenied ->
                    pick "Nektet" "Denied"
    , inheritedWord = pick "Arvet" "Inherited"
    , inheritedPlain = pick "arvet" "inherited"
    , inheritedFrom = \source -> pick ("arvet fra " ++ source) ("inherited from " ++ source)
    , overrides =
        \inheritedWord source ->
            case source of
                Just from ->
                    pick ("overstyrer arvet verdi (" ++ inheritedWord ++ ") fra " ++ from) ("overrides inherited " ++ inheritedWord ++ " from " ++ from)

                Nothing ->
                    pick ("overstyrer arvet verdi (" ++ inheritedWord ++ ")") ("overrides inherited " ++ inheritedWord)
    , inheritAgain = pick "Bruk arvet verdi igjen" "Inherit again"
    , lockedWord = pick "låst" "locked"
    , changedWord = pick "ulagret endring" "unsaved change"
    , lockedDefault = pick "Denne rollen kan ikke endres" "This role cannot be changed"
    , grantAllRole = \name -> pick ("Gi " ++ name ++ " alle tilganger") ("Grant all permissions for " ++ name)
    , grantShownRole = \n name -> pick ("Gi " ++ name ++ " de " ++ number n ++ " viste tilgangene") ("Grant the " ++ number n ++ " permissions shown for " ++ name)
    , grantRowToAll = \name -> pick ("Gi " ++ name ++ " til alle roller") ("Grant " ++ name ++ " to all roles")
    , groupName = \name n -> pick (name ++ ", " ++ number n ++ " " ++ Format.plural loc n { one = "tilgang", other = "tilganger" }) (name ++ ", " ++ number n ++ " " ++ Format.plural loc n { one = "permission", other = "permissions" })
    , groupSummary = \name roleName yes total -> pick (name ++ ", " ++ roleName ++ ": " ++ number yes ++ " av " ++ number total ++ " tillatt") (name ++ ", " ++ roleName ++ ": " ++ number yes ++ " of " ++ number total ++ " granted")
    , changes = \n -> pick (number n ++ " " ++ Format.plural loc n { one = "ulagret endring", other = "ulagrede endringer" }) (number n ++ " unsaved " ++ Format.plural loc n { one = "change", other = "changes" })
    , matchCount = \shown total -> pick (number shown ++ " av " ++ number total ++ " tilganger samsvarer") (number shown ++ " of " ++ number total ++ " permissions match")
    , cut = \shown total -> pick ("Viser de første " ++ number shown ++ " av " ++ number total ++ " tilganger. Bruk filteret for å snevre inn.") ("Showing the first " ++ number shown ++ " of " ++ number total ++ " permissions. Use the filter to narrow the list.")
    , duplicates =
        \roles permissions ->
            let
                part n nbOne nbMany enOne enMany =
                    pick (number n ++ " " ++ Format.plural loc n { one = nbOne, other = nbMany }) (number n ++ " " ++ Format.plural loc n { one = enOne, other = enMany })

                parts =
                    List.filterMap identity
                        [ if roles > 0 then
                            Just (part roles "duplisert rolle" "dupliserte roller" "duplicate role" "duplicate roles")

                          else
                            Nothing
                        , if permissions > 0 then
                            Just (part permissions "duplisert tilgang" "dupliserte tilganger" "duplicate permission" "duplicate permissions")

                          else
                            Nothing
                        ]
            in
            String.join (pick " og " " and ") parts
                ++ pick " ble ignorert."
                    (if roles + permissions == 1 then
                        " was ignored."

                     else
                        " were ignored."
                    )
                ++ pick " Hver rolle og hver tilgang må ha en nøkkel som er forskjellig fra de andre." " Every role and every permission needs a key that differs from the others."
    , noRoles = pick "Ingen roller å vise" "No roles to show"
    , noPermissions = pick "Ingen tilganger å vise" "No permissions to show"
    , noMatch = \text -> pick ("Ingen tilganger samsvarer med «" ++ text ++ "»") ("No permission matches \"" ++ text ++ "\"")
    , loading = pick "Laster tilganger" "Loading permissions"
    , announceCell =
        \permissionName roleName access source ->
            let
                inheritance =
                    case source of
                        Just phrase ->
                            pick (" (" ++ phrase ++ ")") (" (" ++ phrase ++ ")")

                        Nothing ->
                            ""
            in
            case access of
                AccessGranted ->
                    pick (permissionName ++ ": tillatt for " ++ roleName ++ inheritance) (permissionName ++ " granted to " ++ roleName ++ inheritance)

                AccessDenied ->
                    pick (permissionName ++ ": nektet for " ++ roleName ++ inheritance) (permissionName ++ " denied to " ++ roleName ++ inheritance)
    , announceRole = \roleName yes total -> pick (roleName ++ ": " ++ number yes ++ " av " ++ number total ++ " tilganger tillatt") (roleName ++ ": " ++ number yes ++ " of " ++ number total ++ " permissions granted")
    , announcePermission = \permissionName yes total -> pick (permissionName ++ ": tillatt for " ++ number yes ++ " av " ++ number total ++ " roller") (permissionName ++ ": granted to " ++ number yes ++ " of " ++ number total ++ " roles")
    , lockedNote = \roleName reason -> roleName ++ ": " ++ reason
    }



-- VIEW


type alias RoleInfo role =
    { value : role
    , key : String
    , label : String
    , locked : Maybe String
    , index : Int
    }


type alias PermissionInfo permission =
    { value : permission
    , key : String
    , label : String
    , group : Maybe String
    , index : Int
    }


type alias Env role permission msg =
    { toMsg : Msg -> msg
    , config : Config role permission msg
    , t : Texts
    , state : StateData
    , roles : Array (RoleInfo role)
    , permissions : Array (PermissionInfo permission)
    , roleByKey : Dict String Int
    , permissionByKey : Dict String Int
    , cells : Array (Array Cell)
    , savedCells : Maybe (Array (Array Cell))
    , layout : Grid.Layout
    , rows : Array RowKey
    , columns : Array ColumnKey
    , rowIndex : Dict String Int
    , columnIndex : Dict String Int
    , stop : ( Int, Int )
    , editable : Bool
    , filtering : Bool
    , duplicateRoles : Int
    , duplicatePermissions : Int
    }


maxRows : Int
maxRows =
    500


pageRows : Int
pageRows =
    10


{-| The first role or permission with each key, in the order given.
-}
firstOfEachKey : (a -> String) -> List a -> ( List a, Int )
firstOfEachKey keyOf items =
    let
        ( _, kept ) =
            List.foldl
                (\item ( seen, found ) ->
                    let
                        key =
                            keyOf item
                    in
                    if Set.member key seen then
                        ( seen, found )

                    else
                        ( Set.insert key seen, item :: found )
                )
                ( Set.empty, [] )
                items
    in
    ( List.reverse kept, List.length items - List.length kept )


prepare : (Msg -> msg) -> Config role permission msg -> StateData -> Matrix role permission -> Env role permission msg
prepare toMsg config state (Matrix data) =
    let
        t =
            texts config.locale

        ( keptRoles, duplicateRoles ) =
            firstOfEachKey (\(Role r) -> data.roleKey r.value) data.roles

        ( keptPermissions, duplicatePermissions ) =
            firstOfEachKey (\(Permission p) -> data.permissionKey p.value) data.permissions

        roles =
            keptRoles
                |> List.indexedMap
                    (\index (Role r) ->
                        { value = r.value
                        , key = data.roleKey r.value
                        , label = r.label
                        , locked = Maybe.map (\reason -> Maybe.withDefault t.lockedDefault (Internal.nonEmpty reason)) r.locked
                        , index = index
                        }
                    )

        permissions =
            keptPermissions
                |> List.indexedMap
                    (\index (Permission p) ->
                        { value = p.value
                        , key = data.permissionKey p.value
                        , label = p.label
                        , group = p.group
                        , index = index
                        }
                    )

        cellsOf lookup =
            permissions
                |> List.map (\p -> roles |> List.map (\r -> lookup r.value p.value) |> Array.fromList)
                |> Array.fromList

        layout =
            Grid.layout
                { query = state.query, collapsed = state.collapsed, maxRows = maxRows }
                (List.map (\p -> { index = p.index, label = p.label, group = p.group }) permissions)

        permissionKeys =
            permissions |> List.map .key |> Array.fromList

        permissionKeyAt index =
            Array.get index permissionKeys |> Maybe.withDefault ""

        rowKeys =
            HeaderKey
                :: List.map
                    (\row ->
                        case row of
                            Grid.GroupRow name _ ->
                                GroupKey name

                            Grid.PermissionRow index ->
                                PermissionKey (permissionKeyAt index)
                    )
                    layout.rows

        columnKeys =
            LabelKey :: List.map (\r -> RoleKey r.key) roles

        indexOf token keys =
            keys
                |> List.indexedMap (\i key -> ( token key, i ))
                |> Dict.fromList

        rowIndex =
            indexOf Grid.rowToken rowKeys

        columnIndex =
            indexOf Grid.columnToken columnKeys

        firstStop =
            if List.length rowKeys >= 2 then
                ( 1, 1 )

            else
                ( 0, 1 )

        stop =
            case state.focus of
                Just ( row, column ) ->
                    case ( Dict.get (Grid.rowToken row) rowIndex, Dict.get (Grid.columnToken column) columnIndex ) of
                        ( Just r, Just c ) ->
                            if ( r, c ) == ( 0, 0 ) then
                                firstStop

                            else
                                ( r, c )

                        _ ->
                            firstStop

                Nothing ->
                    firstStop
    in
    { toMsg = toMsg
    , config = config
    , t = t
    , state = state
    , roles = Array.fromList roles
    , permissions = Array.fromList permissions
    , roleByKey = roles |> List.map (\r -> ( r.key, r.index )) |> Dict.fromList
    , permissionByKey = permissions |> List.map (\p -> ( p.key, p.index )) |> Dict.fromList
    , cells = cellsOf data.cell
    , savedCells = Maybe.map cellsOf config.saved
    , layout = layout
    , rows = Array.fromList rowKeys
    , columns = Array.fromList columnKeys
    , rowIndex = rowIndex
    , columnIndex = columnIndex
    , stop = stop
    , editable = config.onChange /= Nothing
    , filtering = String.trim state.query /= ""
    , duplicateRoles = duplicateRoles
    , duplicatePermissions = duplicatePermissions
    }


cellAt : Env role permission msg -> Int -> Int -> Maybe Cell
cellAt env permissionIndex roleIndex =
    env.cells |> Array.get permissionIndex |> Maybe.andThen (Array.get roleIndex)


savedAt : Env role permission msg -> Int -> Int -> Maybe Cell
savedAt env permissionIndex roleIndex =
    env.savedCells |> Maybe.andThen (Array.get permissionIndex) |> Maybe.andThen (Array.get roleIndex)


isChanged : Env role permission msg -> Int -> Int -> Bool
isChanged env permissionIndex roleIndex =
    case ( cellAt env permissionIndex roleIndex, savedAt env permissionIndex roleIndex ) of
        ( Just now, Just before ) ->
            not (sameCell now before)

        _ ->
            False


changedCount : Env role permission msg -> Int
changedCount env =
    case env.savedCells of
        Nothing ->
            0

        Just _ ->
            List.range 0 (Array.length env.permissions - 1)
                |> List.foldl
                    (\p total ->
                        List.range 0 (Array.length env.roles - 1)
                            |> List.foldl
                                (\r count ->
                                    if isChanged env p r then
                                        count + 1

                                    else
                                        count
                                )
                                total
                    )
                    0


roleAt : Env role permission msg -> Int -> Maybe (RoleInfo role)
roleAt env index =
    Array.get index env.roles


permissionAt : Env role permission msg -> Int -> Maybe (PermissionInfo permission)
permissionAt env index =
    Array.get index env.permissions


{-| Whether each cell that a header checkbox looks at is granted, in the order of the permissions or
of the roles.
-}
columnCells : Env role permission msg -> Int -> List Bool
columnCells env roleIndex =
    env.layout.matches
        |> List.filterMap (\p -> cellAt env p roleIndex)
        |> List.map cellGranted


rowCells : Env role permission msg -> Int -> List Bool
rowCells env permissionIndex =
    env.roles
        |> Array.toList
        |> List.filter (\r -> r.locked == Nothing)
        |> List.filterMap (\r -> cellAt env permissionIndex r.index)
        |> List.map cellGranted


{-| What an application is asked to change when a role's checkbox says `yes`.
-}
columnChanges : Env role permission msg -> Int -> Bool -> List (Change role permission)
columnChanges env roleIndex yes =
    case roleAt env roleIndex of
        Just r ->
            if r.locked /= Nothing then
                []

            else
                env.layout.matches
                    |> List.filterMap
                        (\p ->
                            case ( permissionAt env p, cellAt env p roleIndex ) of
                                ( Just info, Just theCell ) ->
                                    if cellGranted theCell == yes then
                                        Nothing

                                    else
                                        Just (Change { role = r.value, permission = info.value, access = ownFor (fromBool yes) theCell })

                                _ ->
                                    Nothing
                        )

        Nothing ->
            []


rowChanges : Env role permission msg -> Int -> Bool -> List (Change role permission)
rowChanges env permissionIndex yes =
    case permissionAt env permissionIndex of
        Just info ->
            env.roles
                |> Array.toList
                |> List.filter (\r -> r.locked == Nothing)
                |> List.filterMap
                    (\r ->
                        case cellAt env permissionIndex r.index of
                            Just theCell ->
                                if cellGranted theCell == yes then
                                    Nothing

                                else
                                    Just (Change { role = r.value, permission = info.value, access = ownFor (fromBool yes) theCell })

                            Nothing ->
                                Nothing
                    )

        Nothing ->
            []


{-| The matrix.

    PermissionMatrix.view MatrixMsg [ PermissionMatrix.onChange CellsChanged ] model.access (toMatrix grants)

-}
view : (Msg -> msg) -> List (Attribute role permission msg) -> State -> Matrix role permission -> Html msg
view toMsg attributes (State state) theMatrix =
    let
        config =
            configure attributes

        env =
            prepare toMsg config state theMatrix

        t =
            env.t
    in
    if Array.isEmpty env.roles then
        EmptyState.view [ EmptyState.compact, EmptyState.icon Icon.users, EmptyState.title t.noRoles ]

    else if Array.isEmpty env.permissions then
        EmptyState.view [ EmptyState.compact, EmptyState.icon Icon.shieldCheck, EmptyState.title t.noPermissions ]

    else
        Html.div
            [ Internal.cls
                [ "klar-permissions"
                , "klar-permissions--" ++ Theme.densitySuffix config.density
                , if env.editable then
                    ""

                  else
                    "klar-permissions--readonly"
                ]
            , Attr.id state.id
            ]
            [ viewToolbar env
            , viewBody env
            , viewNotes env
            , Html.div
                [ Internal.cls [ "klar-sr-only" ]
                , Attr.attribute "role" "status"
                , Attr.attribute "aria-live" "polite"
                ]
                [ Html.text (liveText env) ]
            ]


{-| The same for a matrix that comes from the backend. `Success` shows the matrix, `Failure` shows
the problem with a "Try again" button (`onRetry`), and `NotAsked` and `Loading` show a skeleton of
a grid.

    PermissionMatrix.viewRemote MatrixMsg [ PermissionMatrix.onRetry Reload ] model.access (Remote.map toMatrix model.grants)

-}
viewRemote : (Msg -> msg) -> List (Attribute role permission msg) -> State -> Remote (Matrix role permission) -> Html msg
viewRemote toMsg attributes state data =
    let
        config =
            configure attributes

        t =
            texts config.locale
    in
    case Tuple.first (Freshness.settle data) of
        Remote.Loaded theMatrix ->
            view toMsg attributes state theMatrix

        Remote.Failed problem ->
            ErrorState.view
                (List.filterMap identity
                    [ Just ErrorState.compact
                    , Just (ErrorState.locale config.locale)
                    , Maybe.map ErrorState.onRetry config.onRetry
                    ]
                )
                problem

        _ ->
            Html.div
                [ Internal.cls [ "klar-permissions", "klar-permissions--" ++ Theme.densitySuffix config.density, "klar-permissions--skeleton" ]
                , Attr.attribute "aria-busy" "true"
                ]
                (Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ] [ Html.text t.loading ]
                    :: Html.div [ Internal.cls [ "klar-permissions__skeleton-row", "klar-permissions__skeleton-row--head" ], Attr.attribute "aria-hidden" "true" ]
                        (Skeleton.line 40 :: List.map (\_ -> Skeleton.line 60) (List.range 1 4))
                    :: List.map
                        (\width ->
                            Html.div [ Internal.cls [ "klar-permissions__skeleton-row" ], Attr.attribute "aria-hidden" "true" ]
                                (Skeleton.line width :: List.map (\_ -> Skeleton.circle 18) (List.range 1 4))
                        )
                        [ 55, 70, 45, 60, 50, 65 ]
                )



-- TOOLBAR AND NOTES


viewToolbar : Env role permission msg -> Html msg
viewToolbar env =
    let
        t =
            env.t

        count =
            changedCount env

        hasSaved =
            env.config.saved /= Nothing
    in
    Html.div [ Internal.cls [ "klar-permissions__toolbar" ] ]
        [ Html.div [ Internal.cls [ "klar-permissions__filter" ] ]
            [ TextInput.view
                [ TextInput.id (env.state.id ++ "-filter")
                , TextInput.label t.filterLabel
                , TextInput.labelHidden
                , TextInput.search
                , TextInput.clearable
                , TextInput.size Small
                , TextInput.placeholder t.filterPlaceholder
                , TextInput.value env.state.query
                , TextInput.onInput (\text -> env.toMsg (QueryChanged text))
                , TextInput.locale env.config.locale
                ]
            ]
        , if hasSaved then
            Html.span
                [ Internal.cls
                    [ "klar-permissions__changes"
                    , if count > 0 then
                        "klar-permissions__changes--some"

                      else
                        ""
                    ]
                ]
                (if count > 0 then
                    [ Html.span [ Internal.cls [ "klar-permissions__dot" ], Attr.attribute "aria-hidden" "true" ] []
                    , Html.text (t.changes count)
                    ]

                 else
                    []
                )

          else
            Html.text ""
        , Internal.viewIf (not (List.isEmpty env.config.actions))
            (Html.div [ Internal.cls [ "klar-permissions__actions" ] ] env.config.actions)
        ]


viewNotes : Env role permission msg -> Html msg
viewNotes env =
    let
        t =
            env.t

        lockedRoles =
            env.roles |> Array.toList |> List.filterMap (\r -> Maybe.map (\reason -> ( r, reason )) r.locked)

        shown =
            List.length (List.filter isPermissionRow env.layout.rows)

        countNote =
            if env.layout.truncated then
                Just (t.cut shown (shown + env.layout.cutRows))

            else if env.filtering then
                Just (t.matchCount (List.length env.layout.matches) env.layout.total)

            else
                Nothing

        hasDuplicates =
            env.duplicateRoles > 0 || env.duplicatePermissions > 0
    in
    if countNote == Nothing && List.isEmpty lockedRoles && not hasDuplicates then
        Html.text ""

    else
        Html.div [ Internal.cls [ "klar-permissions__notes" ] ]
            [ Internal.viewIf hasDuplicates
                (Html.p [ Internal.cls [ "klar-permissions__note", "klar-permissions__note--warning" ] ]
                    [ Icon.sized Icon.Small Icon.warning
                    , Html.span [] [ Html.text (t.duplicates env.duplicateRoles env.duplicatePermissions) ]
                    ]
                )
            , case countNote of
                Just text ->
                    Html.p [ Internal.cls [ "klar-permissions__note" ] ] [ Html.text text ]

                Nothing ->
                    Html.text ""
            , Internal.viewIf (not (List.isEmpty lockedRoles))
                (Html.ul [ Internal.cls [ "klar-permissions__locked-list" ], Attr.attribute "role" "list" ]
                    (List.map
                        (\( r, reason ) ->
                            Html.li [ Attr.id (reasonId env r.key) ]
                                [ Icon.sized Icon.ExtraSmall Icon.lock
                                , Html.text (t.lockedNote r.label reason)
                                ]
                        )
                        lockedRoles
                    )
                )
            ]


isPermissionRow : Grid.Row -> Bool
isPermissionRow row =
    case row of
        Grid.PermissionRow _ ->
            True

        Grid.GroupRow _ _ ->
            False


reasonId : Env role permission msg -> String -> String
reasonId env roleKey =
    env.state.id ++ "/reason/" ++ Internal.percentEncode roleKey



-- THE GRID


viewBody : Env role permission msg -> Html msg
viewBody env =
    if List.isEmpty env.layout.rows then
        EmptyState.view
            [ EmptyState.compact
            , EmptyState.icon Icon.search
            , EmptyState.title (env.t.noMatch (String.trim env.state.query))
            ]

    else
        Html.div
            [ Internal.cls [ "klar-permissions__scroll" ]
            , Internal.styleVars
                ([ ( "--klar-pm-cols", String.fromInt (Array.length env.roles) ) ]
                    ++ (case env.config.maxHeight of
                            Just pixels ->
                                [ ( "max-height", Internal.px pixels ) ]

                            Nothing ->
                                []
                       )
                )
            , Events.on "focusin" (Decode.map env.toMsg (focusinDecoder env))
            , Events.on "click" (Decode.map env.toMsg (clickDecoder env))
            , Events.on "change" (Decode.map env.toMsg (changeDecoder env))
            , Events.preventDefaultOn "keydown" (Decode.map (Tuple.mapFirst env.toMsg) (keyDecoder env))
            ]
            [ viewTable env ]


viewTable : Env role permission msg -> Html msg
viewTable env =
    Html.table
        ([ Internal.cls [ "klar-permissions__grid" ]
         , Attr.attribute "role" "grid"
         , Attr.attribute "aria-label" (Maybe.withDefault env.t.gridLabel env.config.label)
         , Attr.attribute "aria-rowcount" (String.fromInt (Array.length env.rows))
         , Attr.attribute "aria-colcount" (String.fromInt (Array.length env.columns))
         , Internal.attrIf (not env.editable) (Attr.attribute "aria-readonly" "true")
         ]
            ++ (case env.config.onChange of
                    Just toMsg ->
                        [ Events.on "click" (cellClickDecoder env toMsg)
                        , Events.preventDefaultOn "keydown" (cellKeyDecoder env toMsg)
                        ]

                    Nothing ->
                        []
               )
        )
        [ Html.colgroup []
            (Html.col [ Internal.cls [ "klar-permissions__col-label" ] ] []
                :: List.map (\_ -> Html.col [ Internal.cls [ "klar-permissions__col-role" ] ] []) (Array.toList env.roles)
            )
        , Html.thead [ Attr.attribute "role" "rowgroup" ] [ viewHeaderRow env ]
        , Keyed.node "tbody"
            [ Attr.attribute "role" "rowgroup" ]
            (List.indexedMap (\index row -> viewRow env (index + 1) row) env.layout.rows)
        ]


{-| The attributes of an element that the arrow keys can stop at: its place in the
grid, and whether it is the one tab stop.
-}
placeAttrs : Env role permission msg -> Int -> Int -> List (Html.Attribute msg)
placeAttrs env row column =
    [ Attr.attribute "data-r" (String.fromInt row)
    , Attr.attribute "data-c" (String.fromInt column)
    ]


stopAttrs : Env role permission msg -> Int -> Int -> List (Html.Attribute msg)
stopAttrs env row column =
    case ( Array.get row env.rows, Array.get column env.columns ) of
        ( Just rowKey, Just columnKey ) ->
            placeAttrs env row column
                ++ [ Attr.id (Grid.domId env.state.id rowKey columnKey)
                   , Attr.tabindex
                        (if env.stop == ( row, column ) then
                            0

                         else
                            -1
                        )
                   ]

        _ ->
            placeAttrs env row column


viewHeaderRow : Env role permission msg -> Html msg
viewHeaderRow env =
    Html.tr [ Attr.attribute "role" "row", Internal.cls [ "klar-permissions__row", "klar-permissions__row--head" ] ]
        (Html.th
            [ Internal.cls [ "klar-permissions__th", "klar-permissions__th--corner" ]
            , Attr.attribute "role" "columnheader"
            , Attr.scope "col"
            ]
            [ Html.text env.t.corner ]
            :: List.map (viewRoleHeader env) (Array.toList env.roles)
        )


viewRoleHeader : Env role permission msg -> RoleInfo role -> Html msg
viewRoleHeader env r =
    let
        column =
            r.index + 1

        t =
            env.t

        shownCount =
            List.length env.layout.matches

        total =
            env.layout.total

        cells =
            columnCells env r.index

        checkbox =
            case ( env.config.onChange, r.locked, Grid.shouldGrant cells ) of
                ( Just toMsg, Nothing, Just _ ) ->
                    Just
                        (Checkbox.view
                            [ Checkbox.ariaLabel
                                (if env.filtering && shownCount < total then
                                    t.grantShownRole shownCount r.label

                                 else
                                    t.grantAllRole r.label
                                )
                            , Checkbox.size Small
                            , Checkbox.checked (Grid.summarize cells == Grid.AllGranted)
                            , Checkbox.indeterminate (Grid.summarize cells == Grid.SomeGranted)
                            , Checkbox.id (domIdOf env 0 column)
                            , Checkbox.tabIndex
                                (if env.stop == ( 0, column ) then
                                    0

                                 else
                                    -1
                                )
                            , Checkbox.onCheck (\yes -> toMsg (columnChanges env r.index yes))
                            ]
                        )

                _ ->
                    Nothing

        hasCheckbox =
            case checkbox of
                Just _ ->
                    True

                Nothing ->
                    False
    in
    Html.th
        ([ Internal.cls
            [ "klar-permissions__th"
            , "klar-permissions__th--role"
            , if r.locked /= Nothing then
                "klar-permissions__th--locked"

              else
                ""
            ]
         , Attr.attribute "role" "columnheader"
         , Attr.scope "col"

         -- the name of the column is the role: the checkbox in it has a name of its own
         , Internal.attrIf hasCheckbox (Attr.attribute "aria-label" r.label)
         , Internal.attrMaybe (\_ -> Attr.attribute "aria-describedby" (reasonId env r.key)) r.locked
         ]
            ++ (case checkbox of
                    Just _ ->
                        placeAttrs env 0 column

                    Nothing ->
                        stopAttrs env 0 column
               )
        )
        [ Internal.viewMaybe identity checkbox
        , Html.span [ Internal.cls [ "klar-permissions__name" ], Attr.title r.label ] [ Html.text r.label ]
        , Internal.viewIf (r.locked /= Nothing) (Html.span [ Internal.cls [ "klar-permissions__lock" ] ] [ Icon.sized Icon.ExtraSmall Icon.lock ])
        ]


domIdOf : Env role permission msg -> Int -> Int -> String
domIdOf env row column =
    case ( Array.get row env.rows, Array.get column env.columns ) of
        ( Just rowKey, Just columnKey ) ->
            Grid.domId env.state.id rowKey columnKey

        _ ->
            env.state.id


viewRow : Env role permission msg -> Int -> Grid.Row -> ( String, Html msg )
viewRow env rowNumber row =
    case row of
        Grid.GroupRow name members ->
            ( "g" ++ name, viewGroupRow env rowNumber name members )

        Grid.PermissionRow index ->
            case permissionAt env index of
                Just info ->
                    ( "p" ++ info.key, viewPermissionRow env rowNumber info )

                Nothing ->
                    ( "x" ++ String.fromInt rowNumber, Html.text "" )


viewGroupRow : Env role permission msg -> Int -> String -> List Int -> Html msg
viewGroupRow env rowNumber name members =
    let
        t =
            env.t

        open =
            env.filtering || not (Set.member name env.state.collapsed)

        total =
            List.length members

        labelCell =
            Html.th
                (Internal.cls [ "klar-permissions__th", "klar-permissions__th--group" ]
                    :: Attr.attribute "role" "rowheader"
                    :: Attr.scope "row"
                    :: Attr.attribute "aria-expanded"
                        (if open then
                            "true"

                         else
                            "false"
                        )
                    :: Attr.attribute "aria-label" (t.groupName name total)
                    :: stopAttrs env rowNumber 0
                )
                [ Html.span [ Internal.cls [ "klar-permissions__chevron" ], Attr.attribute "aria-hidden" "true" ]
                    [ Icon.sized Icon.Small
                        (if open then
                            Icon.chevronDown

                         else
                            Icon.chevronRight
                        )
                    ]
                , Html.span [ Internal.cls [ "klar-permissions__content", "klar-permissions__group-name" ] ] [ Html.text name ]
                , Html.span [ Internal.cls [ "klar-permissions__content", "klar-permissions__count", "klar-tabular" ] ] [ Html.text (String.fromInt total) ]
                ]

        summary r =
            let
                yes =
                    members
                        |> List.filterMap (\p -> cellAt env p r.index)
                        |> List.filter cellGranted
                        |> List.length
            in
            Html.td
                (Internal.cls [ "klar-permissions__cell", "klar-permissions__cell--summary" ]
                    :: Attr.attribute "role" "gridcell"
                    :: Attr.attribute "aria-label" (t.groupSummary name r.label yes total)
                    :: Attr.attribute "aria-expanded"
                        (if open then
                            "true"

                         else
                            "false"
                        )
                    :: stopAttrs env rowNumber (r.index + 1)
                )
                [ Html.span [ Internal.cls [ "klar-permissions__content", "klar-tabular" ] ]
                    [ Html.text (String.fromInt yes ++ "/" ++ String.fromInt total) ]
                ]
    in
    Html.tr [ Attr.attribute "role" "row", Internal.cls [ "klar-permissions__row", "klar-permissions__row--group" ] ]
        (labelCell :: List.map summary (Array.toList env.roles))


viewPermissionRow : Env role permission msg -> Int -> PermissionInfo permission -> Html msg
viewPermissionRow env rowNumber info =
    let
        t =
            env.t

        cells =
            rowCells env info.index

        checkbox =
            case ( env.config.onChange, Grid.shouldGrant cells ) of
                ( Just toMsg, Just _ ) ->
                    Just
                        (Checkbox.view
                            [ Checkbox.ariaLabel (t.grantRowToAll info.label)
                            , Checkbox.size Small
                            , Checkbox.checked (Grid.summarize cells == Grid.AllGranted)
                            , Checkbox.indeterminate (Grid.summarize cells == Grid.SomeGranted)
                            , Checkbox.id (domIdOf env rowNumber 0)
                            , Checkbox.tabIndex
                                (if env.stop == ( rowNumber, 0 ) then
                                    0

                                 else
                                    -1
                                )
                            , Checkbox.onCheck (\yes -> toMsg (rowChanges env info.index yes))
                            ]
                        )

                _ ->
                    Nothing

        hasCheckbox =
            case checkbox of
                Just _ ->
                    True

                Nothing ->
                    False

        header =
            Html.th
                (Internal.cls
                    [ "klar-permissions__th"
                    , "klar-permissions__th--permission"
                    , if info.group /= Nothing then
                        "klar-permissions__th--indented"

                      else
                        ""
                    ]
                    :: Attr.attribute "role" "rowheader"
                    :: Attr.scope "row"
                    :: Internal.attrIf hasCheckbox (Attr.attribute "aria-label" info.label)
                    :: (case checkbox of
                            Just _ ->
                                placeAttrs env rowNumber 0

                            Nothing ->
                                stopAttrs env rowNumber 0
                       )
                )
                [ Internal.viewMaybe identity checkbox
                , Html.span [ Internal.cls [ "klar-permissions__name" ], Attr.title info.label ] [ Html.text info.label ]
                ]
    in
    Html.tr [ Attr.attribute "role" "row", Internal.cls [ "klar-permissions__row" ] ]
        (header :: List.map (viewCell env rowNumber info) (Array.toList env.roles))


viewCell : Env role permission msg -> Int -> PermissionInfo permission -> RoleInfo role -> Html msg
viewCell env rowNumber info r =
    let
        t =
            env.t

        facts =
            factsOf (cellAt env info.index r.index |> Maybe.withDefault (direct denied))

        changed =
            isChanged env info.index r.index

        isLocked =
            r.locked /= Nothing

        -- the role has an access of its own over an inherited one, and may go back to inheriting
        canInheritAgain =
            env.editable && not isLocked && facts.overriding

        name =
            cellName t r.label info.label facts isLocked changed

        word =
            if facts.inheriting then
                Just (Maybe.withDefault t.inheritedWord facts.source)

            else if env.editable then
                Nothing

            else
                Just (t.accessTitle facts.access)

        glyph =
            case facts.access of
                AccessGranted ->
                    Icon.sized Icon.ExtraSmall Icon.check

                AccessDenied ->
                    if env.editable then
                        Html.text ""

                    else
                        Icon.sized Icon.ExtraSmall Icon.minus
    in
    Html.td
        ([ Internal.cls
            [ "klar-permissions__cell"
            , "klar-permissions__cell--" ++ accessSuffix facts.access
            , if facts.inheriting then
                "klar-permissions__cell--inherited"

              else
                ""
            , if facts.overriding then
                "klar-permissions__cell--override"

              else
                ""
            , if isLocked then
                "klar-permissions__cell--locked"

              else
                ""
            , if changed then
                "klar-permissions__cell--changed"

              else
                ""
            , if env.editable && not isLocked then
                "klar-permissions__cell--editable"

              else
                ""
            ]
         , Attr.attribute "role" "gridcell"
         , Attr.attribute "aria-label" name

         -- the cell can be focused and read, but not changed: that is "read-only", not "disabled"
         , Internal.attrIf isLocked (Attr.attribute "aria-readonly" "true")
         , Internal.attrIf canInheritAgain (Attr.attribute "aria-keyshortcuts" "Delete Backspace")
         , Internal.attrMaybe (\_ -> Attr.attribute "aria-describedby" (reasonId env r.key)) r.locked
         ]
            ++ stopAttrs env rowNumber (r.index + 1)
        )
        [ Html.span [ Internal.cls [ "klar-permissions__content" ], Attr.attribute "aria-hidden" "true" ]
            [ Html.span [ Internal.cls [ "klar-permissions__mark" ] ] [ glyph ]
            , case word of
                Just text ->
                    Html.span [ Internal.cls [ "klar-permissions__word" ], Attr.title text ] [ Html.text text ]

                Nothing ->
                    Html.text ""
            ]
        , Internal.viewIf changed (Html.span [ Internal.cls [ "klar-permissions__dot", "klar-permissions__dot--cell" ], Attr.attribute "aria-hidden" "true" ] [])

        -- for the pointer; the keyboard has Delete and Backspace, named in aria-keyshortcuts
        , Internal.viewIf canInheritAgain
            (Html.span
                [ Internal.cls [ "klar-permissions__reset" ]
                , Attr.attribute "data-r" (String.fromInt rowNumber)
                , Attr.attribute "data-c" (String.fromInt (r.index + 1))
                , Attr.attribute "data-reset" "1"
                , Attr.title t.inheritAgain
                , Attr.attribute "aria-hidden" "true"
                ]
                [ Icon.sized Icon.ExtraSmall Icon.undo ]
            )
        ]


accessSuffix : Access -> String
accessSuffix access =
    case access of
        AccessGranted ->
            "granted"

        AccessDenied ->
            "denied"


{-| "Supervisor, Cancel orders, granted", with what else is true of the cell.
-}
cellName : Texts -> String -> String -> Facts -> Bool -> Bool -> String
cellName t roleName permissionName facts isLocked changed =
    [ Just roleName
    , Just permissionName
    , Just (t.access facts.access)
    , if facts.inheriting then
        Just (Maybe.withDefault t.inheritedPlain (Maybe.map t.inheritedFrom facts.source))

      else
        Nothing
    , case ( facts.overriding, facts.inheritedAccess ) of
        ( True, Just fallback ) ->
            Just (t.overrides (t.access fallback) facts.source)

        _ ->
            Nothing
    , if isLocked then
        Just t.lockedWord

      else
        Nothing
    , if changed then
        Just t.changedWord

      else
        Nothing
    ]
        |> List.filterMap identity
        |> String.join ", "



-- ANNOUNCEMENTS


{-| The one polite region of the matrix. What a person did last is said from the value the
application gives now (so a change it refused is not announced as made), followed by how many
changes are unsaved. Typing in the filter forgets what was done, and the region says how many
permissions match instead.
-}
liveText : Env role permission msg -> String
liveText env =
    let
        t =
            env.t
    in
    case env.state.acted of
        Just _ ->
            let
                said =
                    announcement env

                unsaved =
                    changedCount env
            in
            if said /= "" && unsaved > 0 then
                said ++ ". " ++ t.changes unsaved

            else
                said

        Nothing ->
            if not env.filtering then
                ""

            else if List.isEmpty env.layout.matches then
                t.noMatch (String.trim env.state.query)

            else
                t.matchCount (List.length env.layout.matches) env.layout.total


{-| What a person did last, said from the value the application gives now.
-}
announcement : Env role permission msg -> String
announcement env =
    let
        t =
            env.t
    in
    case env.state.acted of
        Nothing ->
            ""

        Just (CellOf roleKey permissionKey) ->
            case ( Dict.get roleKey env.roleByKey, Dict.get permissionKey env.permissionByKey ) of
                ( Just r, Just p ) ->
                    case ( roleAt env r, permissionAt env p, cellAt env p r ) of
                        ( Just roleInfo, Just permissionInfo, Just found ) ->
                            let
                                facts =
                                    factsOf found
                            in
                            t.announceCell permissionInfo.label
                                roleInfo.label
                                facts.access
                                (if facts.inheriting then
                                    Just (Maybe.withDefault t.inheritedPlain (Maybe.map t.inheritedFrom facts.source))

                                 else
                                    Nothing
                                )

                        _ ->
                            ""

                _ ->
                    ""

        Just (RoleOf roleKey) ->
            case Dict.get roleKey env.roleByKey |> Maybe.andThen (roleAt env) of
                Just roleInfo ->
                    let
                        cells =
                            columnCells env roleInfo.index
                    in
                    t.announceRole roleInfo.label (List.length (List.filter identity cells)) (List.length cells)

                Nothing ->
                    ""

        Just (PermissionOf permissionKey) ->
            case Dict.get permissionKey env.permissionByKey |> Maybe.andThen (permissionAt env) of
                Just permissionInfo ->
                    let
                        cells =
                            rowCells env permissionInfo.index
                    in
                    t.announcePermission permissionInfo.label (List.length (List.filter identity cells)) (List.length cells)

                Nothing ->
                    ""



-- EVENTS: CAUGHT ONCE ON THE GRID
-- Every stop of the grid carries its place (data-r, data-c). A handler on the grid reads
-- the place of the element an event started on, so no cell needs a handler of its own.


type alias Target =
    { row : Int
    , column : Int

    -- the event started on the element that has the place, not on something inside it (a checkbox)
    , own : Bool

    -- the element is the "inherit again" mark of a cell
    , reset : Bool
    }


targetDecoder : Decoder Target
targetDecoder =
    Decode.field "target" (findTarget 0)


findTarget : Int -> Decoder Target
findTarget depth =
    Decode.oneOf
        [ Decode.map3 (\r c reset -> { row = r, column = c, own = depth == 0, reset = reset })
            (Decode.at [ "dataset", "r" ] intText)
            (Decode.at [ "dataset", "c" ] intText)
            (Decode.oneOf
                [ Decode.at [ "dataset", "reset" ] Decode.string |> Decode.map (\text -> text == "1")
                , Decode.succeed False
                ]
            )
        , if depth < 4 then
            Decode.field "parentElement" (Decode.lazy (\_ -> findTarget (depth + 1)))

          else
            Decode.fail "not inside the grid"
        ]


intText : Decoder Int
intText =
    Decode.string
        |> Decode.andThen
            (\text ->
                case String.toInt text of
                    Just n ->
                        Decode.succeed n

                    Nothing ->
                        Decode.fail "not a number"
            )


{-| A key press, with whether it is the browser repeating a key that is held down.
`Internal.KeyEvent` does not carry that, and holding Space on a cell must not flip it
again and again.
-}
type alias KeyPress =
    { key : String
    , ctrl : Bool
    , meta : Bool
    , shift : Bool
    , alt : Bool
    , repeat : Bool
    }


keyPress : Decoder KeyPress
keyPress =
    Decode.map2 (\event repeat -> { event | repeat = repeat })
        (Decode.map5 (\key ctrl meta shift alt -> { key = key, ctrl = ctrl, meta = meta, shift = shift, alt = alt, repeat = False })
            (Decode.field "key" Decode.string)
            (Decode.field "ctrlKey" Decode.bool)
            (Decode.field "metaKey" Decode.bool)
            (Decode.field "shiftKey" Decode.bool)
            (Decode.field "altKey" Decode.bool)
        )
        (Decode.oneOf [ Decode.field "repeat" Decode.bool, Decode.succeed False ])


plainKey : KeyPress -> Bool
plainKey press =
    not press.ctrl && not press.meta && not press.alt && not press.shift


{-| What a key does to the cell it is on.
-}
type Intent
    = Toggle
    | InheritAgain


cellIntent : KeyPress -> Maybe Intent
cellIntent press =
    if not (plainKey press) then
        Nothing

    else if press.key == " " || press.key == "Enter" then
        Just Toggle

    else if press.key == "Delete" || press.key == "Backspace" then
        Just InheritAgain

    else
        Nothing


rowKeyAt : Env role permission msg -> Int -> Maybe RowKey
rowKeyAt env row =
    Array.get row env.rows


columnKeyAt : Env role permission msg -> Int -> Maybe ColumnKey
columnKeyAt env column =
    Array.get column env.columns


{-| The cell of the matrix that a target is, if it is one: the permission, the role and
what the cell says.
-}
bodyCell : Env role permission msg -> Target -> Maybe { role : RoleInfo role, permission : PermissionInfo permission, cell : Cell }
bodyCell env target =
    case ( rowKeyAt env target.row, columnKeyAt env target.column ) of
        ( Just (PermissionKey permissionKey), Just (RoleKey roleKey) ) ->
            case ( Dict.get permissionKey env.permissionByKey, Dict.get roleKey env.roleByKey ) of
                ( Just p, Just r ) ->
                    case ( permissionAt env p, roleAt env r, cellAt env p r ) of
                        ( Just permissionInfo, Just roleInfo, Just found ) ->
                            Just { role = roleInfo, permission = permissionInfo, cell = found }

                        _ ->
                            Nothing

                _ ->
                    Nothing

        _ ->
            Nothing


{-| The change a click or a key on this cell asks for: toggling what the user sees, or going
back to inheriting. Only for a cell of a role that is not locked, and only to inherit again
where the role has an access of its own over an inherited one.
-}
cellChange : Env role permission msg -> Target -> Intent -> Maybe (Change role permission)
cellChange env target intent =
    if not target.own || not env.editable then
        Nothing

    else
        case bodyCell env target of
            Just found ->
                if found.role.locked /= Nothing then
                    Nothing

                else
                    case intent of
                        Toggle ->
                            Just (Change { role = found.role.value, permission = found.permission.value, access = toggled found.cell })

                        InheritAgain ->
                            if (factsOf found.cell).overriding then
                                Just (Change { role = found.role.value, permission = found.permission.value, access = Nothing })

                            else
                                Nothing

            Nothing ->
                Nothing


{-| A click: on the "inherit again" mark of a cell, or on the cell.
-}
clickIntent : Target -> Intent
clickIntent target =
    if target.reset then
        InheritAgain

    else
        Toggle


cellClickDecoder : Env role permission msg -> (List (Change role permission) -> msg) -> Decoder msg
cellClickDecoder env toMsg =
    targetDecoder
        |> Decode.andThen
            (\target ->
                case cellChange env target (clickIntent target) of
                    Just change ->
                        Decode.succeed (toMsg [ change ])

                    Nothing ->
                        Decode.fail "not a cell that can change"
            )


{-| The keys that change a cell, for the application. A key that is held down and repeats
changes nothing after the first press.
-}
cellKeyDecoder : Env role permission msg -> (List (Change role permission) -> msg) -> Decoder ( msg, Bool )
cellKeyDecoder env toMsg =
    Decode.map2 Tuple.pair keyPress targetDecoder
        |> Decode.andThen
            (\( press, target ) ->
                case ( press.repeat, cellIntent press ) of
                    ( False, Just intent ) ->
                        case cellChange env target intent of
                            Just change ->
                                Decode.succeed ( toMsg [ change ], True )

                            Nothing ->
                                Decode.fail "not a cell that can change"

                    _ ->
                        Decode.fail "not a key for a cell"
            )


{-| What was done to a target, as the subject of the announcement: a cell the person can
change, or a header checkbox.
-}
subjectOf : Env role permission msg -> Target -> Maybe Subject
subjectOf env target =
    case ( rowKeyAt env target.row, columnKeyAt env target.column ) of
        ( Just HeaderKey, Just (RoleKey roleKey) ) ->
            Just (RoleOf roleKey)

        ( Just (PermissionKey permissionKey), Just LabelKey ) ->
            Just (PermissionOf permissionKey)

        ( Just (PermissionKey permissionKey), Just (RoleKey roleKey) ) ->
            Just (CellOf roleKey permissionKey)

        _ ->
            Nothing


focusinDecoder : Env role permission msg -> Decoder Msg
focusinDecoder env =
    targetDecoder
        |> Decode.andThen
            (\target ->
                case ( rowKeyAt env target.row, columnKeyAt env target.column ) of
                    ( Just row, Just column ) ->
                        if ( target.row, target.column ) == env.stop then
                            Decode.fail "the focus is where it was"

                        else
                            Decode.succeed (Focused row column)

                    _ ->
                        Decode.fail "not a stop"
            )


clickDecoder : Env role permission msg -> Decoder Msg
clickDecoder env =
    targetDecoder
        |> Decode.andThen
            (\target ->
                if not target.own then
                    Decode.fail "a click on a control inside the cell"

                else
                    case rowKeyAt env target.row of
                        Just (GroupKey name) ->
                            if env.filtering then
                                Decode.fail "groups stay open while filtering"

                            else
                                Decode.succeed (GroupToggled name)

                        _ ->
                            case ( cellChange env target (clickIntent target), subjectOf env target ) of
                                ( Just _, Just subject ) ->
                                    Decode.succeed (Acted subject)

                                _ ->
                                    Decode.fail "nothing to remember"
            )


changeDecoder : Env role permission msg -> Decoder Msg
changeDecoder env =
    targetDecoder
        |> Decode.andThen
            (\target ->
                if target.own then
                    Decode.fail "not a header checkbox"

                else
                    case subjectOf env target of
                        Just (CellOf _ _) ->
                            Decode.fail "not a header checkbox"

                        Just subject ->
                            Decode.succeed (Acted subject)

                        Nothing ->
                            Decode.fail "not a header checkbox"
            )


navigationKey : KeyPress -> Maybe Grid.Key
navigationKey press =
    if press.alt || press.meta || press.shift then
        Nothing

    else
        case ( press.key, press.ctrl ) of
            ( "ArrowUp", False ) ->
                Just Grid.Up

            ( "ArrowDown", False ) ->
                Just Grid.Down

            ( "ArrowLeft", False ) ->
                Just Grid.Left

            ( "ArrowRight", False ) ->
                Just Grid.Right

            ( "Home", False ) ->
                Just Grid.Home

            ( "End", False ) ->
                Just Grid.End

            ( "Home", True ) ->
                Just Grid.CtrlHome

            ( "End", True ) ->
                Just Grid.CtrlEnd

            ( "PageUp", False ) ->
                Just Grid.PageUp

            ( "PageDown", False ) ->
                Just Grid.PageDown

            _ ->
                Nothing


{-| The keys of the grid, for the matrix itself. The arrow keys repeat when held (the
focus keeps moving). Space, Enter, Delete and Backspace on a cell are the application's
business (see `cellKeyDecoder`); here they are only remembered, once, and a held key
changes nothing more. Space on a stop that does not change anything does not scroll the
page.
-}
keyDecoder : Env role permission msg -> Decoder ( Msg, Bool )
keyDecoder env =
    Decode.map2 Tuple.pair keyPress targetDecoder
        |> Decode.andThen
            (\( press, target ) ->
                case navigationKey press of
                    Just key ->
                        let
                            ( row, column ) =
                                Grid.move
                                    { rows = Array.length env.rows, columns = Array.length env.columns, page = pageRows }
                                    key
                                    ( target.row, target.column )
                        in
                        case ( rowKeyAt env row, columnKeyAt env column ) of
                            ( Just rowKey, Just columnKey ) ->
                                if ( row, column ) == ( target.row, target.column ) then
                                    Decode.succeed ( Noop, True )

                                else
                                    Decode.succeed ( Moved rowKey columnKey, True )

                            _ ->
                                Decode.fail "no such cell"

                    Nothing ->
                        case ( target.own, cellIntent press ) of
                            ( True, Just intent ) ->
                                if press.repeat then
                                    Decode.succeed ( Noop, True )

                                else
                                    case rowKeyAt env target.row of
                                        Just (GroupKey name) ->
                                            if intent /= Toggle then
                                                Decode.fail "not a key of a group row"

                                            else if env.filtering then
                                                Decode.succeed ( Noop, True )

                                            else
                                                Decode.succeed ( GroupToggled name, True )

                                        _ ->
                                            case ( cellChange env target intent, subjectOf env target ) of
                                                ( Just _, Just subject ) ->
                                                    Decode.succeed ( Acted subject, True )

                                                _ ->
                                                    if press.key == " " then
                                                        Decode.succeed ( Noop, True )

                                                    else
                                                        Decode.fail "nothing to do"

                            _ ->
                                Decode.fail "not a key of the grid"
            )
