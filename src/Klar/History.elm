module Klar.History exposing
    ( History, init, withLimit, present
    , record, Option, label, coalesce, endBurst
    , undo, redo, canUndo, canRedo, undoLabel, redoLabel, movedAt
    , markSaved, markSavedAs, isAtSavedPoint, saved, clear, reset
    , controls, Attribute, locale, showShortcuts, shortcuts
    )

{-| Undo and redo for a form or an editor: a value, the values it had before and
the values it had before you undid them.

Use when: a form or an editor needs undo and redo, or a dirty check against the last saved value.
Do not use when: only a "leave without saving" question is needed, use `Klar.LeaveGuard`.
Quick path: `init`, `record`, `undo`, `redo`, `isAtSavedPoint`, `controls`

    import Klar.History as History exposing (History)

    type Field
        = Quantity
        | Note

    -- model:   history : History Field Draft        (History.init draft)

    -- the user types in the quantity field: one burst, one step
    QuantityTyped text ->
        ( { model
            | history =
                History.record
                    [ History.label "Changed quantity", History.coalesce Quantity ]
                    { draft | quantity = text }
                    model.history
          }
        , Cmd.none
        )

    UndoPressed ->
        ( { model | history = History.undo model.history }, Cmd.none )

    -- view
    History.controls [] { onUndo = UndoPressed, onRedo = RedoPressed } model.history

    -- dirty: the value differs from what is saved
    not (History.isAtSavedPoint model.history)

A `History` is a plain value, like a `Dict`. It holds the present value, the values
before it (`undo` goes back through them) and the values after it (`redo` comes
forward again), and one value that stands for what is saved. It knows nothing about
forms, fields or the page: you decide what the value is and when it changes. Recording
a new value forgets whatever could still be redone, as every editor does.

**States are compared with `==`.** `record` ignores a value that equals the present one
and `isAtSavedPoint` compares with the saved one, so a value that holds a function
(`==` cannot compare functions) crashes the program. Keep functions out of the value:
ids, strings, numbers, records and custom types are fine.

**Memory.** Elm shares what has not changed between two values, so the steps of a
history are not copies: recording a record with one changed field adds the new record
and the one field. The history keeps at most `limit` steps, those to undo and those
to redo together (100 by default, see `withLimit`); older steps are dropped.

**Bursts.** Typing in a field records a new value for every key. Give those edits the
same `coalesce` key and they become one step, so that one undo takes back the whole
word. The key is your own type, a union of the fields, for example. A burst ends when
another edit with another key (or none) is recorded, with `undo`, `redo`, `markSaved`,
`endBurst` (call it when the field loses focus) and with anything that changes the
history as a whole. A burst that ends where it began leaves no step.

**The saved point** is the value that counts as saved. `init` makes the first value
the saved one; call `markSaved` after a successful save (`markSavedAs` when the
backend answers with the record as it stored it) and `reset` after loading
another record. `isAtSavedPoint` is true whenever the present value equals the saved
one, also after typing a change and undoing it, so it is the dirty flag of the form:
`LeaveGuard.setDirty OrderForm (not (History.isAtSavedPoint history))`.

The controls (`controls`) are two icon buttons and a polite live region: after an undo
a screen reader says "Undid: Changed quantity", after a redo "Redid: Changed quantity".
The next change to the history, of any kind, takes the announcement away again. They are
the only visible part of this module.


# History

@docs History, init, withLimit, present


# Recording

@docs record, Option, label, coalesce, endBurst


# Undo and redo

@docs undo, redo, canUndo, canRedo, undoLabel, redoLabel, movedAt


# The saved point

@docs markSaved, markSavedAs, isAtSavedPoint, saved, clear, reset


# Controls and shortcuts

`Klar.History` does not listen to the keyboard: keys for the whole page are the job of
[Klar.Shortcut](Klar-Shortcut). `shortcuts` makes the two shortcuts, and you give them
to `Shortcut.listen`, `Shortcut.subscription` and `Shortcut.update` with your
others:

    Shortcut.listen ShortcutMsg (History.shortcuts [] { onUndo = UndoPressed, onRedo = RedoPressed } ++ others) model.shortcuts

`Ctrl Z` in a text field is the field's own undo unless the shortcut is marked
`Shortcut.inInputs`. If the history records every key typed in the fields, mark
them (`List.map Shortcut.inInputs`), so that `Ctrl Z` undoes the history and not the
text of the one field.

@docs controls, Attribute, locale, showShortcuts, shortcuts

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Keyed as Keyed
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Internal as Internal
import Klar.Internal.Keys as Notation
import Klar.Locale as Locale exposing (Locale)
import Klar.Shortcut as Shortcut exposing (Shortcut)



-- THE HISTORY


{-| A value with its past and its future. `key` is your own type for bursts that
become one step (use `()` when you do not coalesce) and `a` is the value. Make one
with `init`.
-}
type History key a
    = History
        { limit : Int
        , past : List (Step key a)
        , present : a
        , future : List (Step key a)
        , saved : a
        , burst : Maybe key
        , moved : Maybe (Moved key)
        }


{-| One step: a value on the other side of an edit, what the edit was called, and
the `coalesce` key it was recorded with. In `past` it is the value before the edit;
in `future` the value after it.
-}
type alias Step key a =
    { value : a
    , label : Maybe String
    , key : Maybe key
    }


{-| The last undo or redo: its label for the announcement and the key of its step.
-}
type Moved key
    = Undone (Maybe String) (Maybe key)
    | Redone (Maybe String) (Maybe key)


defaultLimit : Int
defaultLimit =
    100


{-| A history that starts at this value, which is also the saved one. It keeps
100 steps; see `withLimit`.

    History.init { quantity = "1", note = "" }

-}
init : a -> History key a
init value =
    History
        { limit = defaultLimit
        , past = []
        , present = value
        , future = []
        , saved = value
        , burst = Nothing
        , moved = Nothing
        }


{-| How many steps the history keeps in all: the ones `undo` goes back through
and the ones `redo` brings back, together. Older steps are dropped. A limit below 1
counts as 1. The default is 100. A smaller limit than before drops the oldest steps
at once, and the steps to redo before the steps to undo.
-}
withLimit : Int -> History key a -> History key a
withLimit limit (History state) =
    let
        kept =
            max 1 limit

        past =
            List.take kept state.past
    in
    History
        { state
            | limit = kept
            , past = past
            , future = List.take (kept - List.length past) state.future
            , moved = Nothing
        }


{-| The value now. This is what the form shows and the application saves.
-}
present : History key a -> a
present (History state) =
    state.present



-- RECORDING


{-| A setting of one edit: its label and its burst. Make them with `label` and
`coalesce`; later ones win over earlier ones.
-}
type Option key
    = Option (Edit key -> Edit key)


type alias Edit key =
    { label : Maybe String
    , key : Maybe key
    }


{-| What the edit was called: "Changed quantity". It is the name of the step in
the tooltips of the controls and in what a screen reader is told after an undo
("Undid: Changed quantity"). A step without a label is called "the last change".
-}
label : String -> Option key
label text =
    Option (\edit -> { edit | label = Just text })


{-| Puts the edit in a burst. When the edit before this one was recorded with the same
key and nothing came between them, the two become one step: the first one's starting
point and this one's result. The key is your own type, so that two fields cannot be
mixed up.

    History.coalesce Quantity

-}
coalesce : key -> Option key
coalesce key =
    Option (\edit -> { edit | key = Just key })


{-| Records the value as the new present one and forgets what could have been
redone. The list says what the edit was called (`label`) and which burst it belongs to
(`coalesce`); with `[]` it is a step of its own. A value that equals the present one
changes nothing at all.

    History.record [ History.label "Changed note" ] { draft | note = text } model.history

When the edit joins a burst, the step keeps the label of the latest edit that had one.

-}
record : List (Option key) -> a -> History key a -> History key a
record options value (History state) =
    if value == state.present then
        History state

    else
        let
            edit =
                List.foldl (\(Option change) current -> change current) { label = Nothing, key = Nothing } options

            joins =
                case ( edit.key, state.burst ) of
                    ( Just key, Just open ) ->
                        key == open

                    _ ->
                        False
        in
        case ( joins, state.past ) of
            ( True, first :: earlier ) ->
                if value == first.value then
                    -- the burst has come back to where it began: no step is left
                    History { state | past = earlier, present = value, future = [], burst = Nothing, moved = Nothing }

                else
                    History
                        { state
                            | past = { first | label = orElse edit.label first.label } :: earlier
                            , present = value
                            , future = []
                            , moved = Nothing
                        }

            _ ->
                History
                    { state
                        | past = List.take state.limit ({ value = state.present, label = edit.label, key = edit.key } :: state.past)
                        , present = value
                        , future = []
                        , burst = edit.key
                        , moved = Nothing
                    }


orElse : Maybe a -> Maybe a -> Maybe a
orElse first second =
    case first of
        Just _ ->
            first

        Nothing ->
            second


{-| Ends the burst that is open, so that the next edit starts a step of its own
even if it has the same key. Call it when the field loses focus.
-}
endBurst : History key a -> History key a
endBurst (History state) =
    History { state | burst = Nothing, moved = Nothing }



-- UNDO AND REDO


{-| Goes back one step. With nothing to undo it changes nothing. The step that
was undone can be redone.
-}
undo : History key a -> History key a
undo (History state) =
    case state.past of
        [] ->
            History state

        step :: earlier ->
            History
                { state
                    | past = earlier
                    , present = step.value
                    , future = List.take state.limit ({ value = state.present, label = step.label, key = step.key } :: state.future)
                    , burst = Nothing
                    , moved = Just (Undone step.label step.key)
                }


{-| Goes forward one step that was undone. With nothing to redo it changes
nothing.
-}
redo : History key a -> History key a
redo (History state) =
    case state.future of
        [] ->
            History state

        step :: later ->
            History
                { state
                    | past = List.take state.limit ({ value = state.present, label = step.label, key = step.key } :: state.past)
                    , present = step.value
                    , future = later
                    , burst = Nothing
                    , moved = Just (Redone step.label step.key)
                }


{-| Is there a step to go back to?
-}
canUndo : History key a -> Bool
canUndo (History state) =
    not (List.isEmpty state.past)


{-| Is there an undone step to come forward to?
-}
canRedo : History key a -> Bool
canRedo (History state) =
    not (List.isEmpty state.future)


{-| The label of the step `undo` would take back, if it has one: "Changed
quantity". `Nothing` when there is nothing to undo or the step has no label.
-}
undoLabel : History key a -> Maybe String
undoLabel (History state) =
    state.past |> List.head |> Maybe.andThen .label


{-| The label of the step `redo` would bring back, if it has one.
-}
redoLabel : History key a -> Maybe String
redoLabel (History state) =
    state.future |> List.head |> Maybe.andThen .label


{-| Where the last `undo` or `redo` changed the value: the `coalesce` key of the step it
went across, such as the field that was edited. After Ctrl Z on a long form the change
can be out of sight. For the shortcut, move focus to it, so that the user sees what was
undone (`fieldId` is your own function from a key to the DOM id of its field); the
buttons of `controls` keep focus instead, so that the user can press them again:

    UndoKey ->
        let
            history =
                History.undo model.history
        in
        ( { model | history = history }
        , case History.movedAt history of
            Just field ->
                Klar.focus (fieldId field) NoOp

            Nothing ->
                Cmd.none
        )

`Nothing` when the step had no key, when nothing was undone or redone, and after the
next change of any kind (the same rule as the announcement of `controls`).

-}
movedAt : History key a -> Maybe key
movedAt (History state) =
    case state.moved of
        Just (Undone _ key) ->
            key

        Just (Redone _ key) ->
            key

        Nothing ->
            Nothing



-- THE SAVED POINT


{-| Says that the present value is the saved one. Call it when a save has
succeeded. The steps stay, so the user can still undo past the save, and it ends
the burst that is open: what is typed after a save is a step of its own, so that
one undo goes back to what was saved.
-}
markSaved : History key a -> History key a
markSaved (History state) =
    History { state | saved = state.present, burst = Nothing, moved = Nothing }


{-| Says that this value is the saved one and the present one: the save succeeded and
the backend answered with the record as it stored it (a new version, a time of the
change, trimmed text). The steps stay, so the user can still undo past the save, and
`isAtSavedPoint` is true against the stored record. No step is recorded: the user did
not make this change. It ends the open burst, like `markSaved`.

    Saved (Ok stored) ->
        ( { model | history = History.markSavedAs stored model.history }, Cmd.none )

-}
markSavedAs : a -> History key a -> History key a
markSavedAs value (History state) =
    History { state | present = value, saved = value, burst = Nothing, moved = Nothing }


{-| Is the present value equal to the saved one? It is, right after `init`,
`markSaved` and `reset`, and again whenever an undo or a redo (or an edit that
undoes another) brings the value back. `not (isAtSavedPoint history)` is the dirty flag
of the form.
-}
isAtSavedPoint : History key a -> Bool
isAtSavedPoint (History state) =
    state.present == state.saved


{-| The value that counts as saved, for a "Discard changes" that records it:

    History.record [ History.label "Discarded changes" ] (History.saved model.history) model.history

-}
saved : History key a -> a
saved (History state) =
    state.saved


{-| Forgets every step back and forward and keeps the present and the saved value:
the next undo has nothing to go to. For a history that must not reach past a
save: `history |> History.markSaved |> History.clear`.
-}
clear : History key a -> History key a
clear (History state) =
    History { state | past = [], future = [], burst = Nothing, moved = Nothing }


{-| Starts over from this value, which is also the saved one: the form has loaded
another record. Every step is forgotten; the limit stays.
-}
reset : a -> History key a -> History key a
reset value (History state) =
    History
        { state
            | past = []
            , present = value
            , future = []
            , saved = value
            , burst = Nothing
            , moved = Nothing
        }



-- CONTROLS


{-| A setting of the controls and the shortcuts. Make them with the functions below
and pass a list to `controls` or `shortcuts`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config -> Config)


type alias Config =
    { locale : Locale
    , showShortcuts : Bool
    }


configure : List (Attribute msg) -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { locale = Locale.default, showShortcuts = False }
        attributes


{-| The language of the built-in text: the names of the buttons, "Undid: ..." and
"Redid: ..." for screen readers, the name of the group, and the names of the shortcuts
on the shortcut sheet. The default is [`Locale.default`](Klar-Locale#default), which is
English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| Shows `Ctrl Z` and `Ctrl Shift Z` in the tooltips and tells assistive
technology about them (`aria-keyshortcuts`). Add it only when the application has
registered `shortcuts`: a hint for a key that does nothing is a lie.
-}
showShortcuts : Attribute msg
showShortcuts =
    Attribute (\config -> { config | showShortcuts = True })


undoKeys : List Shortcut.Keys
undoKeys =
    [ Shortcut.mod (Shortcut.char 'z') ]


{-| `Ctrl Shift Z`, and `Ctrl Y`, which is what Windows applications use.
-}
redoKeys : List Shortcut.Keys
redoKeys =
    [ Shortcut.mod (Shortcut.shift (Shortcut.char 'z'))
    , Shortcut.mod (Shortcut.char 'y')
    ]


{-| The shortcuts: `Ctrl Z` for undo, and `Ctrl Shift Z` and `Ctrl Y` (the Windows
convention) for redo; `Cmd` instead of `Ctrl` on a Mac. They are listed in the group
"Edit" of the shortcut sheet, redo twice, once for each pair of keys. Add them to the
list you give to [Klar.Shortcut](Klar-Shortcut); see the top of this section for the
fields that are typed in. The attributes are those of `controls`, and only `locale`
applies here: it names the shortcuts and their group (`showShortcuts` is about the
buttons of `controls`, so it changes nothing in this list).

    History.shortcuts [ History.locale model.locale ] { onUndo = UndoPressed, onRedo = RedoPressed }

-}
shortcuts : List (Attribute msg) -> { onUndo : msg, onRedo : msg } -> List (Shortcut msg)
shortcuts attributes messages =
    let
        language =
            (configure attributes).locale

        group =
            Locale.pick language { nb = "Redigering", en = "Edit" }
    in
    List.map (\keys -> Shortcut.shortcut keys group (Locale.pick language { nb = "Angre", en = "Undo" }) messages.onUndo) undoKeys
        ++ List.map (\keys -> Shortcut.shortcut keys group (Locale.pick language { nb = "Gjør om", en = "Redo" }) messages.onRedo) redoKeys


{-| Two icon buttons, "Undo" and "Redo", and a polite live region. The buttons are
named after the step they would take: "Undo: Changed quantity". They stay in place and
in the tab order when there is nothing to do (`aria-disabled`), so a user who undoes
everything does not lose focus; they do nothing then. After an undo or a redo the live
region says what happened, "Undid: Changed quantity", once and politely. It is empty
again after the next change to the history: an edit, `endBurst`, `markSaved`,
`withLimit`, `clear` or `reset`. (An edit that equals the present value, and an undo or
redo with nothing to do, change nothing and leave it as it was.) The live region is
always on the page, as it must be to be heard.

    History.controls [] { onUndo = UndoPressed, onRedo = RedoPressed } model.history

-}
controls : List (Attribute msg) -> { onUndo : msg, onRedo : msg } -> History key a -> Html msg
controls attributes messages ((History state) as history) =
    let
        config =
            configure attributes

        language =
            config.locale

        named base step =
            case step of
                Just text ->
                    base ++ ": " ++ text

                Nothing ->
                    base

        withHint name keys =
            if config.showShortcuts then
                name ++ " (" ++ String.join ", " (List.map keyCaps keys) ++ ")"

            else
                name

        hintAttributes keys =
            if config.showShortcuts then
                [ Button.htmlAttrs [ Attr.attribute "aria-keyshortcuts" (String.join " " (List.map ariaKeys keys)) ] ]

            else
                []

        undoName =
            named (Locale.pick language { nb = "Angre", en = "Undo" }) (undoLabel history)

        redoName =
            named (Locale.pick language { nb = "Gjør om", en = "Redo" }) (redoLabel history)
    in
    Html.div
        [ Internal.cls [ "klar-history" ]
        , Attr.attribute "role" "group"
        , Attr.attribute "aria-label" (Locale.pick language { nb = "Angre og gjør om", en = "Undo and redo" })
        ]
        [ Button.iconOnly
            ([ Button.ghost
             , Button.ariaDisabled (not (canUndo history))
             , Button.title (withHint undoName undoKeys)
             , Button.onClick messages.onUndo
             ]
                ++ hintAttributes undoKeys
            )
            Icon.undo
            undoName
        , Button.iconOnly
            ([ Button.ghost
             , Button.ariaDisabled (not (canRedo history))
             , Button.title (withHint redoName redoKeys)
             , Button.onClick messages.onRedo
             ]
                ++ hintAttributes redoKeys
            )
            Icon.redo
            redoName
        , Html.div
            [ Internal.cls [ "klar-history__live", "klar-sr-only" ]
            , Attr.attribute "role" "status"
            , Attr.attribute "aria-live" "polite"
            , Attr.attribute "aria-atomic" "true"
            ]
            [ Keyed.node "span"
                []
                (case state.moved of
                    Just moved ->
                        [ ( announcementKey moved history, Html.text (announcement language moved) ) ]

                    Nothing ->
                        []
                )
            ]
        ]


{-| "Ctrl+Shift+Z" for the tooltip.
-}
keyCaps : Shortcut.Keys -> String
keyCaps keys =
    Notation.words keys
        |> List.map (String.join "+")
        |> String.join " "


{-| `aria-keyshortcuts` names the keys the way `KeyboardEvent.key` does.
-}
ariaKeys : Shortcut.Keys -> String
ariaKeys keys =
    Notation.words keys
        |> List.map (\step -> String.join "+" (List.map ariaKey step))
        |> String.join " "


ariaKey : String -> String
ariaKey cap =
    if cap == "Ctrl" then
        "Control"

    else
        cap


announcement : Locale -> Moved key -> String
announcement language moved =
    case moved of
        Undone (Just text) _ ->
            Locale.pick language { nb = "Angret: " ++ text, en = "Undid: " ++ text }

        Undone Nothing _ ->
            Locale.pick language { nb = "Angret siste endring", en = "Undid the last change" }

        Redone (Just text) _ ->
            Locale.pick language { nb = "Gjort om: " ++ text, en = "Redid: " ++ text }

        Redone Nothing _ ->
            Locale.pick language { nb = "Gjort om endringen", en = "Redid the change" }


{-| A screen reader announces a change of the live region, and a text that is
replaced by the same text is no change. So that two undos in a row with the same
label are both heard, the announcement is a keyed child that is replaced by
another one for every step.
-}
announcementKey : Moved key -> History key a -> String
announcementKey moved (History state) =
    String.join "-"
        [ case moved of
            Undone _ _ ->
                "undone"

            Redone _ _ ->
                "redone"
        , String.fromInt (List.length state.past)
        , String.fromInt (List.length state.future)
        ]
