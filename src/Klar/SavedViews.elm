module Klar.SavedViews exposing
    ( view
    , State, init, Msg, update
    , SavedView, savedView, withNote, asDefault, asShared, asLocked, withQuery, withKey
    , Change(..), changes
    , encode, decoder
    , views, active, defaultView, revision, isOpen, setViews, setActive, apply, startSave
    , Attribute, currentRule, currentQuery, remote, onRetry, label, locale, size, alignEnd
    )

{-| Named, saved filters ("views"): a dropdown button that lists the saved
views and lets the user apply one, save the current filter under a new name,
rename and delete views (after an inline confirmation), mark one as the default
view and reset to it.

Use when: users want to save, name and reapply their filters.
Do not use when: the filter is fixed and has no names to remember (use `Klar.FilterBar` alone).
Quick path: `init`, `setViews`, `update`, `view`, `revision`, `active`

Use it next to a [Klar.FilterBar](Klar-FilterBar) or a
[Klar.RuleBuilder](Klar-RuleBuilder). a view is a name and a
[Klar.Rule](Klar-Rule) `Rule`, and optionally a table query (see below).

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
(a [Table.Query](Klar-Table#Query)). Give `currentQuery (Table.query model.table)` to
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
of `active`. With [Klar.ServerList](Klar-ServerList), `ServerList.toQueryString` writes
the link (the view, the filters and the page, every text safely encoded: a name is user
text, and `Url.percentEncode` throws on half of an emoji) and
`ServerList.fromQueryString` reads it. There is no clipboard in pure Elm, so a "Copy link" is the link in a read-only
[Klar.TextInput](Klar-TextInput) that the user selects (`TextInput.readOnly True`), shown
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


# View

@docs view


# State

@docs State, init, Msg, update


# Defining views

@docs SavedView, savedView, withNote, asDefault, asShared, asLocked, withQuery, withKey


## A backend that keeps each view

@docs Change, changes


## Keeping the views

The library keeps nothing. `encode` and `decoder` write and read one view as JSON, so
the application can keep its list wherever it keeps user settings: its backend, the
address, a cookie that it sets through a port of its own.

    -- the list, as text
    Encode.encode 0 (Encode.list SavedViews.encode (SavedViews.views model.views))

    -- and back (a text that does not read gives no views)
    Decode.decodeString (Decode.list SavedViews.decoder) text
        |> Result.withDefault []
        |> (\stored -> SavedViews.setViews stored model.views)

@docs encode, decoder


# Reading and replacing the list

@docs views, active, defaultView, revision, isOpen, setViews, setActive, apply, startSave


# Attributes

@docs Attribute, currentRule, currentQuery, remote, onRetry, label, locale, size, alignEnd

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Remote)
import Klar.Rule as Rule exposing (Rule)
import Klar.RuleBuilder.Support as Support
import Klar.Settings as Settings
import Klar.Table as Table
import Klar.TextInput as TextInput
import Klar.Theme exposing (Size(..), Tone(..))



-- SAVED VIEWS


{-| A named rule. The `name` identifies the view and must be unique, ignoring
case. The `note` is a short description shown under the name. `isDefault` marks
the view that "Reset" returns to; at most one view is the default. `isShared`
is set by the application, and the list shows a badge for it. `query` is the search,
sort, filters and page size of the table, when the view holds them. `key` is the id your
backend gave the view (`withKey`), `Nothing` until it is stored; a rename keeps it, so
`changes` can tell a rename from a new view.

Make views with `savedView`, or build the record yourself, for example from
stored data.

-}
type alias SavedView =
    { name : String
    , rule : Rule
    , note : Maybe String
    , isDefault : Bool
    , isShared : Bool
    , query : Maybe Table.Query
    , key : Maybe String
    , isLocked : Bool
    }


{-| One view as JSON: the name, the rule (`Rule.encode`), the note, the two flags, the
table query (`Table.encodeQuery`) when it has one, and the key when it has one. It carries
a version, `"v": 1`.
-}
encode : SavedView -> Encode.Value
encode saved =
    Encode.object
        [ ( "v", Encode.int 1 )
        , ( "name", Encode.string saved.name )
        , ( "rule", Rule.encode saved.rule )
        , ( "note", Maybe.map Encode.string saved.note |> Maybe.withDefault Encode.null )
        , ( "default", Encode.bool saved.isDefault )
        , ( "shared", Encode.bool saved.isShared )
        , ( "query", Maybe.map Table.encodeQuery saved.query |> Maybe.withDefault Encode.null )
        , ( "key", Maybe.map Encode.string saved.key |> Maybe.withDefault Encode.null )
        , ( "locked", Encode.bool saved.isLocked )
        ]


{-| Reads what `encode` wrote. The name (not empty) and the rule are required; the note,
the flags and the query may be missing, a field it does not know is ignored, and a version
newer than 1 is refused. A query that is there but cannot be read (see
`Table.queryDecoder`) fails the view: silently dropping it would apply the rule alone
and show another table than the one that was saved. The rule is read as `Rule.decoder`
reads it.

    Decode.decodeString SavedViews.decoder text

-}
decoder : Decoder SavedView
decoder =
    Decode.oneOf [ Decode.field "v" Decode.int, Decode.succeed 1 ]
        |> Decode.andThen
            (\version ->
                if version > 1 then
                    Decode.fail ("This view was written by a newer version (v" ++ String.fromInt version ++ ")")

                else
                    Decode.map8 SavedView
                        (Decode.field "name" Decode.string
                            |> Decode.andThen
                                (\name ->
                                    if String.isEmpty (String.trim name) then
                                        Decode.fail "A view needs a name"

                                    else
                                        Decode.succeed name
                                )
                        )
                        (Decode.field "rule" Rule.decoder)
                        (Decode.oneOf [ Decode.field "note" (Decode.nullable Decode.string), Decode.succeed Nothing ])
                        (Decode.oneOf [ Decode.field "default" Decode.bool, Decode.succeed False ])
                        (Decode.oneOf [ Decode.field "shared" Decode.bool, Decode.succeed False ])
                        (Decode.maybe (Decode.field "query" Decode.value)
                            |> Decode.andThen
                                (\present ->
                                    case present of
                                        Nothing ->
                                            Decode.succeed Nothing

                                        Just _ ->
                                            Decode.field "query" (Decode.nullable Table.queryDecoder)
                                )
                        )
                        (Decode.oneOf [ Decode.field "key" (Decode.nullable Decode.string), Decode.succeed Nothing ])
                        (Decode.oneOf [ Decode.field "locked" Decode.bool, Decode.succeed False ])
            )


{-| A view with a name and a rule, no note, not the default.

    SavedViews.savedView "Unpaid orders" unpaid

-}
savedView : String -> Rule -> SavedView
savedView name rule =
    { name = name, rule = rule, note = Nothing, isDefault = False, isShared = False, query = Nothing, key = Nothing, isLocked = False }


{-| Adds a short description, shown under the name in the list.

    SavedViews.savedView "Unpaid orders" unpaid
        |> SavedViews.withNote "Open orders older than a week"

-}
withNote : String -> SavedView -> SavedView
withNote note saved =
    { saved | note = Just note }


{-| Makes this the default view: the one that "Reset" returns to. The user can
change the default in the list.
-}
asDefault : SavedView -> SavedView
asDefault saved =
    { saved | isDefault = True }


{-| Marks the view as shared (with colleagues, the team ...). The list shows a
"Shared" badge. The application decides what that means and who may see the view.
-}
asShared : SavedView -> SavedView
asShared saved =
    { saved | isShared = True }


{-| Locks the view: the user can apply it and make it their default, but not rename,
update or delete it, for a team view that someone else owns. The list shows a lock in
place of those actions. `isLocked = True` in stored data does the same.
-}
asLocked : SavedView -> SavedView
asLocked saved =
    { saved | isLocked = True }


{-| Gives the view a table query: search text, sort, column filters and page size
(the page is not kept). Use it for views you make yourself; the ones the user saves
get it from `currentQuery`.
-}
withQuery : Table.Query -> SavedView -> SavedView
withQuery q saved =
    { saved | query = Just (firstPage q) }


firstPage : Table.Query -> Table.Query
firstPage q =
    { q | page = 1 }


{-| Gives the view the id your backend keeps it under. Give it to every stored view
(in the list for `setViews`), and `changes` says what to send per view.

    SavedViews.savedView stored.name rule |> SavedViews.withKey stored.id

-}
withKey : String -> SavedView -> SavedView
withKey key saved =
    { saved | key = Just key }


{-| What to send to a backend that keeps each view by its key:

  - `Created view`: a view the user saved. It has no key yet: store it, and give the
    list back to `setViews` with the key the backend gave it (`withKey`).
  - `Updated view`: a view with a key whose name, note, rule, query or default changed
    (a rename keeps the key, so it is an update, not a new view).
  - `Deleted key`: the key of a view that the user deleted.

-}
type Change
    = Created SavedView
    | Updated SavedView
    | Deleted String


{-| The changes from one list of views to the next, for a backend that keeps each view
by its key: compare `views` before and after `update` (with
[Klar.ServerList](Klar-ServerList): the views before, and the `save` of the step).
Views without a key are new ones: a view without a key that is not in the list before
is `Created`. Unchanged views give nothing.

    SavedViews.changes (SavedViews.views model.views) (SavedViews.views views)
        |> List.map storeChange

-}
changes : List SavedView -> List SavedView -> List Change
changes before after =
    let
        keyed list =
            List.filterMap (\saved -> Maybe.map (\key -> ( key, saved )) saved.key) list

        earlier key =
            keyed before |> List.filter (\( k, _ ) -> k == key) |> List.head |> Maybe.map Tuple.second

        later =
            keyed after |> List.map Tuple.first

        createdOrUpdated =
            List.filterMap
                (\saved ->
                    case saved.key of
                        Just key ->
                            case earlier key of
                                Just old ->
                                    if old == saved then
                                        Nothing

                                    else
                                        Just (Updated saved)

                                Nothing ->
                                    Just (Created saved)

                        Nothing ->
                            if List.member saved before then
                                Nothing

                            else
                                Just (Created saved)
                )
                after

        deleted =
            keyed before
                |> List.filter (\( key, _ ) -> not (List.member key later))
                |> List.map (\( key, _ ) -> Deleted key)
    in
    createdOrUpdated ++ deleted



-- STATE


{-| The state of the saved views button: the list of views, which one is active,
whether the list is open and the form that is open in it (save, rename or
delete). Make one with `init`, keep it in your model and pass it to `view` and
`update`.
-}
type State
    = State Inner


type alias Inner =
    { id : String
    , views : List SavedView
    , active : Maybe String
    , revision : Int
    , open : Bool
    , mode : Mode
    }


type Mode
    = Browsing
    | Saving Form
    | Renaming String Form
    | Deleting String


type alias Form =
    { name : String
    , note : String
    , problem : Maybe Problem
    }


type Problem
    = Missing
    | Taken


{-| No views, nothing active. The `String` is the DOM id of the wrapper around
the button and its list, and must be unique on the page; the ids of the controls
inside start with it.

    SavedViews.init "order-views"

-}
init : String -> State
init id =
    State
        { id = id
        , views = []
        , active = Nothing
        , revision = 0
        , open = False
        , mode = Browsing
        }


{-| Every saved view, in the order of the list. Compare it before and after
`update` to know when to store the views: it changes when the user saves,
renames, deletes or updates a view, or changes the default.
-}
views : State -> List SavedView
views (State s) =
    s.views


{-| The view the user applied last, if it still exists. Saving the current
filter under a new name makes the new view active too, without applying
anything.
-}
active : State -> Maybe SavedView
active (State s) =
    s.active |> Maybe.andThen (\name -> find name s.views)


{-| The view marked as the default, if any. "Reset" returns to it.
-}
defaultView : State -> Maybe SavedView
defaultView (State s) =
    s.views |> List.filter .isDefault |> List.head


{-| Goes up by one every time the user applies a view or resets. Compare it
before and after `update`: when it changed, load the rule of `active` (or an
empty rule when nothing is active) into your filters.
-}
revision : State -> Int
revision (State s) =
    s.revision


{-| Is the list open?
-}
isOpen : State -> Bool
isOpen (State s) =
    s.open


{-| Replaces the list, for example with the views loaded from the backend. Names
must be unique, ignoring case and surrounding spaces: later duplicates are
dropped. Only the first view marked as default stays the default. The active
view stays active if it is still in the list. A form that is open in the list stays
open while the view it is about is still there, so a refresh from the backend never
throws away a name the user is typing; the name is checked again when it is saved.
-}
setViews : List SavedView -> State -> State
setViews list (State s) =
    let
        unique =
            List.foldl
                (\saved kept ->
                    if List.any (\other -> sameName other.name saved.name) kept then
                        kept

                    else
                        kept ++ [ saved ]
                )
                []
                list

        firstDefault =
            unique |> List.filter .isDefault |> List.head |> Maybe.map .name

        cleaned =
            List.map (\saved -> { saved | isDefault = Just saved.name == firstDefault }) unique

        stillThere name =
            List.any (\saved -> saved.name == name) cleaned
    in
    State
        { s
            | views = cleaned
            , active = s.active |> Maybe.andThen (\name -> find name cleaned |> Maybe.map .name)
            , mode =
                case s.mode of
                    Renaming original _ ->
                        if stillThere original then
                            s.mode

                        else
                            Browsing

                    Deleting name ->
                        if stillThere name then
                            s.mode

                        else
                            Browsing

                    Saving _ ->
                        s.mode

                    Browsing ->
                        Browsing
        }


{-| Marks the view with this name as active, without applying anything: use it
when the application has already loaded the rule, for example at start-up. The name
is matched like names are compared, ignoring case and surrounding spaces. A name that
is not in the list, or `Nothing`, means that no view is active.
-}
setActive : Maybe String -> State -> State
setActive name (State s) =
    State { s | active = name |> Maybe.andThen (\wanted -> find wanted s.views |> Maybe.map .name) }


{-| Applies the view with this name, as if the user had picked it: it becomes
active and `revision` goes up, so the application loads its rule and query the
way it does after `update`. Use it for a link that names a view; the name is matched
ignoring case and surrounding spaces (`?view=open%20orders` finds "Open orders"). A
name that is not in the list changes nothing.
-}
apply : String -> State -> State
apply name (State s) =
    case find name s.views of
        Just saved ->
            State { s | active = Just saved.name, revision = s.revision + 1, open = False, mode = Browsing }

        Nothing ->
            State s


{-| Opens the list with the form for saving the current view open, and moves focus
to its name field. Use it for a command or a shortcut ("New saved view"); map the
`Cmd` with your wrapper of the component's `Msg`. The form needs `currentRule` in the
attributes of `view`; without it the list opens with focus on "Reset".
-}
startSave : State -> ( State, Cmd Msg )
startSave (State s) =
    ( State { s | open = True, mode = Saving { name = "", note = "", problem = Nothing } }
    , Internal.focusFirst [ nameDomId s.id, resetDomId s.id ] NoOp
    )


{-| The view with this name, ignoring case and surrounding spaces (names are unique
that way).
-}
find : String -> List SavedView -> Maybe SavedView
find name list =
    list |> List.filter (\saved -> sameName saved.name name) |> List.head


sameName : String -> String -> Bool
sameName a b =
    String.toLower (String.trim a) == String.toLower (String.trim b)


checkName : List SavedView -> Maybe String -> String -> Maybe Problem
checkName list except name =
    if String.trim name == "" then
        Just Missing

    else if List.any (\saved -> sameName saved.name name && Just saved.name /= except) list then
        Just Taken

    else
        Nothing



-- UPDATE


{-| A message from the saved views component. Wrap it in one of your own
messages and pass it to `update`.
-}
type Msg
    = Toggled
    | Opened
    | Closed
    | Left
    | Picked String
    | ResetPicked
    | SaveStarted
    | NameTyped String
    | NoteTyped String
    | SaveConfirmed Rule (Maybe Table.Query)
    | RenameStarted String
    | RenameConfirmed
    | DeleteAsked String
    | DeleteConfirmed String
    | DefaultToggled String
    | ActiveUpdated Rule (Maybe Table.Query)
    | ModeCancelled
    | FocusItem Int
    | NoOp


{-| Applies a message from the component. The command moves keyboard focus (into
the list, back to the button ...), so map it with `Cmd.map`. Compare `revision`
before and after to know when the user applied a view, and `views` to know when
to store the list.
-}
update : Msg -> State -> ( State, Cmd Msg )
update msg (State s) =
    case msg of
        Toggled ->
            if s.open then
                close s

            else
                open s

        Opened ->
            if s.open then
                ( State s, Cmd.none )

            else
                open s

        Closed ->
            close s

        Left ->
            ( State { s | open = False, mode = Browsing }, Cmd.none )

        Picked name ->
            ( State { s | active = Just name, revision = s.revision + 1, open = False, mode = Browsing }
            , Internal.focus (triggerDomId s.id) NoOp
            )

        ResetPicked ->
            ( State
                { s
                    | active = s.views |> List.filter .isDefault |> List.head |> Maybe.map .name
                    , revision = s.revision + 1
                    , open = False
                    , mode = Browsing
                }
            , Internal.focus (triggerDomId s.id) NoOp
            )

        SaveStarted ->
            ( State { s | mode = Saving { name = "", note = "", problem = Nothing } }
            , Internal.focus (nameDomId s.id) NoOp
            )

        NameTyped text ->
            ( State { s | mode = mapForm (\form -> { form | name = text, problem = Nothing }) s.mode }, Cmd.none )

        NoteTyped text ->
            ( State { s | mode = mapForm (\form -> { form | note = text }) s.mode }, Cmd.none )

        SaveConfirmed rule query ->
            case s.mode of
                Saving form ->
                    case checkName s.views Nothing form.name of
                        Just problem ->
                            ( State { s | mode = Saving { form | problem = Just problem } }
                            , Internal.focus (nameDomId s.id) NoOp
                            )

                        Nothing ->
                            let
                                name =
                                    String.trim form.name

                                note =
                                    if String.trim form.note == "" then
                                        Nothing

                                    else
                                        Just (String.trim form.note)
                            in
                            ( State
                                { s
                                    | views = s.views ++ [ { name = name, rule = rule, note = note, isDefault = False, isShared = False, query = query, key = Nothing, isLocked = False } ]
                                    , active = Just name
                                    , open = False
                                    , mode = Browsing
                                }
                            , Internal.focus (triggerDomId s.id) NoOp
                            )

                _ ->
                    ( State s, Cmd.none )

        RenameStarted name ->
            if isLockedView name s.views then
                ( State s, Cmd.none )

            else
                ( State
                    { s
                        | mode =
                            Renaming name
                                { name = name
                                , note = find name s.views |> Maybe.andThen .note |> Maybe.withDefault ""
                                , problem = Nothing
                                }
                    }
                , Internal.focus (renameDomId s.id) NoOp
                )

        RenameConfirmed ->
            case s.mode of
                Renaming original form ->
                    case checkName s.views (Just original) form.name of
                        Just problem ->
                            ( State { s | mode = Renaming original { form | problem = Just problem } }
                            , Internal.focus (renameDomId s.id) NoOp
                            )

                        Nothing ->
                            let
                                name =
                                    String.trim form.name

                                note =
                                    if String.trim form.note == "" then
                                        Nothing

                                    else
                                        Just (String.trim form.note)
                            in
                            ( State
                                { s
                                    | views =
                                        List.map
                                            (\saved ->
                                                if saved.name == original then
                                                    { saved | name = name, note = note }

                                                else
                                                    saved
                                            )
                                            s.views
                                    , active =
                                        if s.active == Just original then
                                            Just name

                                        else
                                            s.active
                                    , mode = Browsing
                                }
                            , Internal.focus (itemDomId s.id (indexOf original s.views)) NoOp
                            )

                _ ->
                    ( State s, Cmd.none )

        DeleteAsked name ->
            if isLockedView name s.views then
                ( State s, Cmd.none )

            else
                ( State { s | mode = Deleting name }, Internal.focus (confirmDomId s.id) NoOp )

        DeleteConfirmed name ->
            if isLockedView name s.views then
                ( State s, Cmd.none )

            else
                let
                    index =
                        indexOf name s.views

                    remaining =
                        List.filter (\saved -> saved.name /= name) s.views
                in
                ( State
                    { s
                        | views = remaining
                        , active =
                            if s.active == Just name then
                                Nothing

                            else
                                s.active
                        , mode = Browsing
                    }
                , if List.isEmpty remaining then
                    -- "Save current view" is there only with `currentRule`; "Reset" always is
                    Internal.focusFirst [ saveDomId s.id, resetDomId s.id ] NoOp

                  else
                    Internal.focus (itemDomId s.id (min index (List.length remaining - 1))) NoOp
                )

        DefaultToggled name ->
            ( State
                { s
                    | views =
                        List.map
                            (\saved ->
                                if saved.name == name then
                                    { saved | isDefault = not saved.isDefault }

                                else
                                    { saved | isDefault = False }
                            )
                            s.views
                }
            , Cmd.none
            )

        ActiveUpdated rule query ->
            ( State
                { s
                    | views =
                        List.map
                            (\saved ->
                                if Just saved.name == s.active then
                                    { saved | rule = rule, query = orElse saved.query query }

                                else
                                    saved
                            )
                            s.views
                }
            , s.active
                |> Maybe.map (\name -> Internal.focus (itemDomId s.id (indexOf name s.views)) NoOp)
                |> Maybe.withDefault Cmd.none
            )

        ModeCancelled ->
            ( State { s | mode = Browsing }
            , case s.mode of
                Renaming original _ ->
                    Internal.focus (itemDomId s.id (indexOf original s.views)) NoOp

                Deleting name ->
                    Internal.focus (itemDomId s.id (indexOf name s.views)) NoOp

                Saving _ ->
                    Internal.focus (saveDomId s.id) NoOp

                Browsing ->
                    Cmd.none
            )

        FocusItem index ->
            ( State s, Internal.focus (itemDomId s.id index) NoOp )

        NoOp ->
            ( State s, Cmd.none )


isLockedView : String -> List SavedView -> Bool
isLockedView name list =
    List.any (\saved -> saved.name == name && saved.isLocked) list


orElse : Maybe a -> Maybe a -> Maybe a
orElse fallback maybe =
    case maybe of
        Just _ ->
            maybe

        Nothing ->
            fallback


open : Inner -> ( State, Cmd Msg )
open s =
    ( State { s | open = True, mode = Browsing }
    , if List.isEmpty s.views then
        Internal.focusFirst [ saveDomId s.id, resetDomId s.id ] NoOp

      else
        Internal.focus
            (itemDomId s.id
                (case s.active of
                    Just name ->
                        indexOf name s.views

                    Nothing ->
                        0
                )
            )
            NoOp
    )


close : Inner -> ( State, Cmd Msg )
close s =
    ( State { s | open = False, mode = Browsing }
    , if s.open then
        Internal.focus (triggerDomId s.id) NoOp

      else
        Cmd.none
    )


mapForm : (Form -> Form) -> Mode -> Mode
mapForm change mode =
    case mode of
        Saving form ->
            Saving (change form)

        Renaming original form ->
            Renaming original (change form)

        other ->
            other


indexOf : String -> List SavedView -> Int
indexOf name list =
    list
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, saved ) -> saved.name == name)
        |> List.head
        |> Maybe.map Tuple.first
        |> Maybe.withDefault 0



-- DOM IDS


triggerDomId : String -> String
triggerDomId id =
    id ++ "-trigger"


popupDomId : String -> String
popupDomId id =
    id ++ "-popup"


itemDomId : String -> Int -> String
itemDomId id index =
    id ++ "-item-" ++ String.fromInt index


nameDomId : String -> String
nameDomId id =
    id ++ "-name"


noteDomId : String -> String
noteDomId id =
    id ++ "-note"


renameDomId : String -> String
renameDomId id =
    id ++ "-rename"


confirmDomId : String -> String
confirmDomId id =
    id ++ "-confirm"


saveDomId : String -> String
saveDomId id =
    id ++ "-save"


resetDomId : String -> String
resetDomId id =
    id ++ "-reset"


questionDomId : String -> String
questionDomId id =
    id ++ "-question"



-- ATTRIBUTES


{-| A setting of the saved views button. Make them with the functions below and
pass a list to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { current : Maybe Rule
    , currentQuery : Maybe Table.Query
    , locale : Locale
    , label : Maybe String
    , alignEnd : Bool
    , size : Size
    , source : Source
    , onRetry : Maybe msg
    }


{-| How the request for the views stands, from `remote`.
-}
type Source
    = Waiting
    | FailedWith Remote.Problem
    | Ready Freshness


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { current = Nothing
        , currentQuery = Nothing
        , locale = Locale.default
        , label = Nothing
        , alignEnd = False
        , size = Medium
        , source = Ready Freshness.Fresh
        , onRetry = Nothing
        }
        attributes


{-| The rule the application shows now. It is what "Save current view ..."
saves, and what the active view is compared with: the view is marked "modified"
when the two differ (ignoring node ids). Without it the list can only apply
views, not save them.
-}
currentRule : Rule -> Attribute msg
currentRule rule =
    Attribute (\config -> { config | current = Just rule })


{-| Takes loading, failure, refreshing and old data from the `Remote` of the request
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

-}
remote : Remote a -> Attribute msg
remote data =
    Attribute
        (\config ->
            let
                ( settled, freshness ) =
                    Freshness.settle data
            in
            { config
                | source =
                    case settled of
                        Remote.NotAsked ->
                            Waiting

                        Remote.Loading ->
                            Waiting

                        Remote.Failed problem ->
                            FailedWith problem

                        _ ->
                            Ready freshness
            }
        )


{-| The message of the "Try again" button, shown when loading the views failed (and the
problem is worth retrying, see `Remote.isRetryable`). While the views load again the
button stays in its place, busy, so keyboard focus is not lost.
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| The query of the table next to the filters, `Table.query model.table`. A view
that is saved holds it with the rule (the page is left out), and the active view is
"modified" when its query differs from it. Without it views hold only the rule.
-}
currentQuery : Table.Query -> Attribute msg
currentQuery q =
    Attribute (\config -> { config | currentQuery = Just (firstPage q) })


{-| The language of the component's own text: the button, the list and its
messages. The default is `Locale.default`, which is `Locale.en`. The names and notes of
the views come from the application.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| The button text when no view is active. The default is "Views". While a view
is active the button shows its name instead.
-}
label : String -> Attribute msg
label value =
    Attribute (\config -> { config | label = Just value })


{-| Opens the list towards the left: its right edge lines up with the right edge
of the button. Use it when the button sits at the right edge of the page.
-}
alignEnd : Attribute msg
alignEnd =
    Attribute (\config -> { config | alignEnd = True })


{-| The size of the button, a [Klar.Theme](Klar-Theme) `Size`. The default is
`Medium`; `Small` matches the controls of a filter bar.
-}
size : Size -> Attribute msg
size value =
    Attribute (\config -> { config | size = value })



-- VIEW


type alias Ctx msg =
    { toMsg : Msg -> msg
    , config : Config msg
    , state : Inner
    , texts : Texts
    , modified : Bool
    }


{-| The button and, when open, the list of views with its actions: apply, mark as
default, rename and delete a view, save the current filter, update the active
view with the changes, and reset. The first argument turns the component's
messages into yours.

    SavedViews.view ViewsMsg [ SavedViews.currentRule model.rule ] model.views

-}
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
view toMsg attributes (State s) =
    let
        config =
            configure attributes

        t =
            texts config.locale

        activeView =
            s.active |> Maybe.andThen (\name -> find name s.views)

        modified =
            case ( activeView, config.current ) of
                ( Just saved, Just rule ) ->
                    not (Support.same saved.rule rule)
                        || (case ( saved.query, config.currentQuery ) of
                                ( Just held, Just now ) ->
                                    held /= now

                                _ ->
                                    False
                           )

                _ ->
                    False

        ctx =
            { toMsg = toMsg, config = config, state = s, texts = t, modified = modified }

        text =
            case activeView of
                Just saved ->
                    if modified then
                        saved.name ++ " (" ++ t.modified ++ ")"

                    else
                        saved.name

                Nothing ->
                    Maybe.withDefault t.views config.label
    in
    Html.div [ Internal.cls [ "klar-anchor", "klar-savedviews" ], Attr.id s.id ]
        [ Button.view
            [ Button.icon Icon.bookmark
            , Button.iconRight Icon.chevronDown
            , Button.size config.size
            , Button.id (triggerDomId s.id)
            , Button.expanded s.open
            , Button.title
                (case activeView of
                    Just _ ->
                        t.activeView ++ ": " ++ text

                    Nothing ->
                        t.title
                )
            , Button.htmlAttrs
                [ Attr.attribute "aria-haspopup" "dialog"
                , Internal.onKeys [ ( "ArrowDown", toMsg Opened ) ]
                ]
            , Button.onClick (toMsg Toggled)
            ]
            text
        , if s.open then
            viewPopup ctx activeView

          else
            Html.text ""
        ]


viewPopup : Ctx msg -> Maybe SavedView -> Html msg
viewPopup ctx activeView =
    let
        t =
            ctx.texts

        s =
            ctx.state

        escape =
            case s.mode of
                Browsing ->
                    ctx.toMsg Closed

                _ ->
                    ctx.toMsg ModeCancelled

        defaultName =
            s.views |> List.filter .isDefault |> List.head |> Maybe.map .name
    in
    Html.div
        [ Internal.cls [ "klar-layer" ]
        , Events.onClick (ctx.toMsg Closed)
        , Internal.onKeysPassive [ ( "Escape", escape ) ]
        ]
        [ Html.div
            [ Internal.cls
                [ "klar-popup"
                , "klar-savedviews__popup"
                , if ctx.config.alignEnd then
                    "klar-popup--end"

                  else
                    ""
                ]
            , Attr.id (popupDomId s.id)
            , Attr.attribute "role" "dialog"
            , Attr.attribute "aria-label" t.title
            , Attr.tabindex -1
            , Internal.onClickStop (ctx.toMsg NoOp)
            , Support.onFocusLeave (popupDomId s.id) (ctx.toMsg Left)
            ]
            [ Html.div [ Internal.cls [ "klar-savedviews__heading" ] ] [ Html.text t.title ]
            , viewViews ctx
            , Html.div [ Internal.cls [ "klar-savedviews__separator" ] ] []
            , viewSaveArea ctx activeView
            , Html.div [ Internal.cls [ "klar-savedviews__separator" ] ] []
            , viewAction
                { id = resetDomId s.id
                , icon = Icon.undo
                , label = t.reset
                , hint =
                    case defaultName of
                        Just name ->
                            Just name

                        Nothing ->
                            Just t.noFilters
                , msg = ctx.toMsg ResetPicked
                }
            ]
        ]


{-| The views, or what stands in for them: loading, a failure with a retry, or the
empty text. The list keeps its element in every state where views are shown, so the
view that has focus keeps it through a refresh.
-}
viewViews : Ctx msg -> Html msg
viewViews ctx =
    let
        t =
            ctx.texts

        s =
            ctx.state

        status text button =
            Html.div [ Internal.cls [ "klar-savedviews__empty", "klar-savedviews__status" ] ]
                [ Html.span [ Attr.attribute "role" "status" ] [ Html.text text ]
                , button
                ]
    in
    case ( ctx.config.source, s.views ) of
        ( Waiting, [] ) ->
            -- after "Try again" the button stays, busy, so focus stays on it
            status t.loading
                (case ctx.config.onRetry of
                    Just _ ->
                        Button.view [ Button.small, Button.loading True ] t.retry

                    Nothing ->
                        Html.text ""
                )

        ( FailedWith problem, [] ) ->
            status (Remote.title ctx.config.locale problem)
                (case ( ctx.config.onRetry, Remote.isRetryable problem ) of
                    ( Just msg, True ) ->
                        Button.view [ Button.small, Button.icon Icon.refresh, Button.onClick msg ] t.retry

                    _ ->
                        Html.text ""
                )

        ( _, [] ) ->
            Html.p [ Internal.cls [ "klar-savedviews__empty" ] ] [ Html.text t.noViews ]

        ( source, list ) ->
            let
                freshness =
                    case source of
                        -- views on the screen, and the request failed or is on its way
                        Ready value ->
                            value

                        Waiting ->
                            Freshness.Refreshing

                        FailedWith problem ->
                            Freshness.Stale { problem = problem, at = Nothing, refreshing = False }
            in
            Html.div []
                [ Freshness.notice
                    { locale = ctx.config.locale
                    , settings = Settings.default
                    , onRetry = ctx.config.onRetry
                    , inline = True
                    }
                    (case freshness of
                        -- no clock here: "Old data", without a time in an unknown zone
                        Freshness.Stale value ->
                            Freshness.Stale { value | at = Nothing }

                        other ->
                            other
                    )
                , Html.ul
                    [ Internal.cls [ "klar-savedviews__list", Freshness.className freshness ]
                    , Freshness.busyAttr freshness
                    ]
                    (List.indexedMap (viewItem ctx) list)
                ]


viewItem : Ctx msg -> Int -> SavedView -> Html msg
viewItem ctx index saved =
    let
        t =
            ctx.texts

        s =
            ctx.state

        isActive =
            s.active == Just saved.name

        count =
            List.length s.views

        navigation =
            Internal.onKeys
                [ ( "ArrowDown", ctx.toMsg (FocusItem (modBy count (index + 1))) )
                , ( "ArrowUp", ctx.toMsg (FocusItem (modBy count (index - 1))) )
                , ( "Home", ctx.toMsg (FocusItem 0) )
                , ( "End", ctx.toMsg (FocusItem (count - 1)) )
                ]
    in
    case s.mode of
        Renaming original form ->
            if original == saved.name then
                Html.li [ Internal.cls [ "klar-savedviews__item", "klar-savedviews__item--form" ] ]
                    [ viewForm ctx
                        { nameId = renameDomId s.id
                        , nameLabel = t.newName
                        , form = form
                        , withNote = True
                        , confirm = ctx.toMsg RenameConfirmed
                        , confirmLabel = t.save
                        }
                    ]

            else
                viewRow ctx index saved isActive navigation

        Deleting name ->
            if name == saved.name then
                -- focus lands on Cancel: the question is its description, so a screen
                -- reader says what is being cancelled
                Html.li [ Internal.cls [ "klar-savedviews__item", "klar-savedviews__item--confirm" ] ]
                    [ Html.span [ Internal.cls [ "klar-savedviews__question" ] ]
                        [ Icon.sized Icon.Small Icon.warning
                        , Html.span [ Internal.cls [ "klar-truncate" ], Attr.id (questionDomId s.id) ] [ Html.text (t.deleteQuestion saved.name) ]
                        ]
                    , Html.span [ Internal.cls [ "klar-savedviews__confirm-actions" ] ]
                        [ Button.view
                            [ Button.small
                            , Button.id (confirmDomId s.id)
                            , Button.htmlAttrs [ Attr.attribute "aria-describedby" (questionDomId s.id) ]
                            , Button.onClick (ctx.toMsg ModeCancelled)
                            ]
                            t.cancel
                        , Button.view
                            [ Button.small
                            , Button.danger
                            , Button.htmlAttrs [ Attr.attribute "aria-describedby" (questionDomId s.id) ]
                            , Button.onClick (ctx.toMsg (DeleteConfirmed saved.name))
                            ]
                            t.delete
                        ]
                    ]

            else
                viewRow ctx index saved isActive navigation

        _ ->
            viewRow ctx index saved isActive navigation


viewRow : Ctx msg -> Int -> SavedView -> Bool -> Html.Attribute msg -> Html msg
viewRow ctx index saved isActive navigation =
    let
        t =
            ctx.texts

        s =
            ctx.state
    in
    Html.li
        [ Internal.cls
            [ "klar-savedviews__item"
            , if isActive then
                "klar-savedviews__item--active"

              else
                ""
            ]
        ]
        [ Html.button
            [ Internal.cls [ "klar-savedviews__apply" ]
            , Attr.type_ "button"
            , Attr.id (itemDomId s.id index)
            , Internal.attrIf isActive (Attr.attribute "aria-current" "true")
            , Events.onClick (ctx.toMsg (Picked saved.name))
            , navigation
            ]
            [ Html.span [ Internal.cls [ "klar-savedviews__check" ] ]
                [ if isActive then
                    Icon.sized Icon.Small Icon.check

                  else
                    Html.text ""
                ]
            , Html.span [ Internal.cls [ "klar-savedviews__text" ] ]
                [ Html.span [ Internal.cls [ "klar-savedviews__name" ] ]
                    [ Html.span [ Internal.cls [ "klar-truncate" ] ] [ Html.text saved.name ]
                    , if saved.isDefault then
                        Badge.view [ Badge.size Small, Badge.tone Info ] t.defaultBadge

                      else
                        Html.text ""
                    , if saved.isShared then
                        Badge.view [ Badge.size Small ] t.sharedBadge

                      else
                        Html.text ""
                    , if isActive && ctx.modified then
                        Html.span [ Internal.cls [ "klar-savedviews__modified" ] ] [ Html.text t.modified ]

                      else
                        Html.text ""
                    ]
                , case saved.note of
                    Just note ->
                        Html.span [ Internal.cls [ "klar-savedviews__note", "klar-truncate" ] ] [ Html.text note ]

                    Nothing ->
                        Html.text ""
                ]
            ]
        , Html.span [ Internal.cls [ "klar-savedviews__row-actions" ] ]
            [ -- a toggle keeps its name; aria-pressed says whether it is on
              Button.iconOnly
                [ Button.ghost
                , Button.small
                , Button.pressed saved.isDefault
                , Button.onClick (ctx.toMsg (DefaultToggled saved.name))
                ]
                Icon.star
                (t.defaultView ++ ": " ++ saved.name)
            , if saved.isLocked then
                Html.span [ Internal.cls [ "klar-savedviews__lock" ], Attr.title t.locked ]
                    [ Icon.sized Icon.Small Icon.lock
                    , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text t.locked ]
                    ]

              else
                Button.iconOnly
                    [ Button.ghost
                    , Button.small
                    , Button.onClick (ctx.toMsg (RenameStarted saved.name))
                    ]
                    Icon.edit
                    (t.rename ++ ": " ++ saved.name)
            , if saved.isLocked then
                Html.text ""

              else
                Button.iconOnly
                    [ Button.ghost
                    , Button.small
                    , Button.onClick (ctx.toMsg (DeleteAsked saved.name))
                    ]
                    Icon.trash
                    (t.delete ++ ": " ++ saved.name)
            ]
        ]


viewSaveArea : Ctx msg -> Maybe SavedView -> Html msg
viewSaveArea ctx activeView =
    let
        t =
            ctx.texts

        s =
            ctx.state
    in
    case ( s.mode, ctx.config.current ) of
        ( Saving form, Just rule ) ->
            Html.div [ Internal.cls [ "klar-savedviews__save" ] ]
                [ viewForm ctx
                    { nameId = nameDomId s.id
                    , nameLabel = t.name
                    , form = form
                    , withNote = True
                    , confirm = ctx.toMsg (SaveConfirmed rule ctx.config.currentQuery)
                    , confirmLabel = t.save
                    }
                ]

        ( _, Just rule ) ->
            Html.div [ Internal.cls [ "klar-savedviews__actions" ] ]
                [ viewAction
                    { id = saveDomId s.id
                    , icon = Icon.save
                    , label = t.saveCurrent
                    , hint = Nothing
                    , msg = ctx.toMsg SaveStarted
                    }
                , case activeView of
                    Just saved ->
                        if ctx.modified && not saved.isLocked then
                            viewAction
                                { id = s.id ++ "-update"
                                , icon = Icon.refresh
                                , label = t.updateView saved.name
                                , hint = Nothing
                                , msg = ctx.toMsg (ActiveUpdated rule ctx.config.currentQuery)
                                }

                        else
                            Html.text ""

                    Nothing ->
                        Html.text ""
                ]

        ( _, Nothing ) ->
            Html.text ""


viewForm :
    Ctx msg
    ->
        { nameId : String
        , nameLabel : String
        , form : Form
        , withNote : Bool
        , confirm : msg
        , confirmLabel : String
        }
    -> Html msg
viewForm ctx options =
    let
        t =
            ctx.texts

        problem =
            options.form.problem
                |> Maybe.map
                    (\p ->
                        case p of
                            Missing ->
                                t.missing

                            Taken ->
                                t.taken
                    )
    in
    Html.div [ Internal.cls [ "klar-savedviews__form" ] ]
        [ TextInput.view
            [ TextInput.id options.nameId
            , TextInput.label options.nameLabel
            , TextInput.required
            , TextInput.size Small
            , TextInput.value options.form.name
            , TextInput.placeholder t.namePlaceholder
            , TextInput.maxLength 60
            , TextInput.autocomplete "off"
            , TextInput.onInput (\text -> ctx.toMsg (NameTyped text))
            , TextInput.onEnter options.confirm
            , TextInput.errorMaybe problem
            , TextInput.locale ctx.config.locale
            ]
        , if options.withNote then
            TextInput.view
                [ TextInput.id (noteDomId ctx.state.id)
                , TextInput.label t.note
                , TextInput.optionalText t.optional
                , TextInput.size Small
                , TextInput.value options.form.note
                , TextInput.autocomplete "off"
                , TextInput.onInput (\text -> ctx.toMsg (NoteTyped text))
                , TextInput.onEnter options.confirm
                , TextInput.locale ctx.config.locale
                ]

          else
            Html.text ""
        , Html.div [ Internal.cls [ "klar-savedviews__form-actions" ] ]
            [ Button.view [ Button.small, Button.onClick (ctx.toMsg ModeCancelled) ] t.cancel
            , Button.view [ Button.small, Button.primary, Button.onClick options.confirm ] options.confirmLabel
            ]
        ]


viewAction : { id : String, icon : Icon, label : String, hint : Maybe String, msg : msg } -> Html msg
viewAction options =
    Html.button
        [ Internal.cls [ "klar-savedviews__action" ]
        , Attr.type_ "button"
        , Attr.id options.id
        , Events.onClick options.msg
        ]
        [ Html.span [ Internal.cls [ "klar-savedviews__action-icon" ] ] [ Icon.view options.icon ]
        , Html.span [ Internal.cls [ "klar-savedviews__action-label", "klar-truncate" ] ] [ Html.text options.label ]
        , case options.hint of
            Just hint ->
                Html.span [ Internal.cls [ "klar-savedviews__action-hint", "klar-truncate" ] ] [ Html.text hint ]

            Nothing ->
                Html.text ""
        ]



-- TEXT


type alias Texts =
    { views : String
    , title : String
    , activeView : String
    , noViews : String
    , defaultBadge : String
    , sharedBadge : String
    , modified : String
    , defaultView : String
    , rename : String
    , delete : String
    , deleteQuestion : String -> String
    , saveCurrent : String
    , updateView : String -> String
    , reset : String
    , noFilters : String
    , name : String
    , newName : String
    , namePlaceholder : String
    , note : String
    , optional : String
    , save : String
    , cancel : String
    , missing : String
    , taken : String
    , loading : String
    , retry : String
    , locked : String
    }


texts : Locale -> Texts
texts lang =
    Locale.pick lang
        { nb =
            { views = "Visninger"
            , title = "Lagrede visninger"
            , activeView = "Aktiv visning"
            , noViews = "Ingen lagrede visninger ennå. Lagre filteret du har nå for å finne det igjen."
            , defaultBadge = "Standard"
            , sharedBadge = "Delt"
            , modified = "endret"
            , defaultView = "Standardvisning"
            , rename = "Gi nytt navn"
            , delete = "Slett"
            , deleteQuestion = \name -> "Slette «" ++ name ++ "»?"
            , saveCurrent = "Lagre gjeldende visning ..."
            , updateView = \name -> "Oppdater «" ++ name ++ "» med endringene"
            , reset = "Tilbakestill"
            , noFilters = "ingen filtre"
            , name = "Navn på visningen"
            , newName = "Nytt navn"
            , namePlaceholder = "For eksempel «Forfalt i Oslo»"
            , note = "Merknad"
            , optional = "(valgfritt)"
            , save = "Lagre"
            , cancel = "Avbryt"
            , missing = "Skriv inn et navn."
            , taken = "Det finnes allerede en visning med dette navnet."
            , loading = "Laster lagrede visninger …"
            , retry = "Prøv igjen"
            , locked = "Låst: kan ikke gis nytt navn eller slettes"
            }
        , en =
            { views = "Views"
            , title = "Saved views"
            , activeView = "Active view"
            , noViews = "No saved views yet. Save the current filter to find it again."
            , defaultBadge = "Default"
            , sharedBadge = "Shared"
            , modified = "modified"
            , defaultView = "Default view"
            , rename = "Rename"
            , delete = "Delete"
            , deleteQuestion = \name -> "Delete “" ++ name ++ "”?"
            , saveCurrent = "Save current view ..."
            , updateView = \name -> "Update “" ++ name ++ "” with the changes"
            , reset = "Reset"
            , noFilters = "no filters"
            , name = "Name of the view"
            , newName = "New name"
            , namePlaceholder = "For example “Overdue in Oslo”"
            , note = "Note"
            , optional = "(optional)"
            , save = "Save"
            , cancel = "Cancel"
            , missing = "Enter a name."
            , taken = "There is already a view with this name."
            , loading = "Loading saved views …"
            , retry = "Try again"
            , locked = "Locked: cannot be renamed or deleted"
            }
        }
