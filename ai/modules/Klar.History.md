# Klar.History

Undo and redo for a form or an editor: a value, the values it had before and the values it had before you undid them.

Import: `import Klar.History as History` | Group: Pages and flow

Types: `Option`, `History`, `Attribute`

## Signatures

```elm
-- History
type History key a  -- opaque: no constructors are exposed
init : a -> History key a
withLimit : Int -> History key a -> History key a
present : History key a -> a

-- Recording
type Option key  -- opaque: no constructors are exposed
record : List (Option key) -> a -> History key a -> History key a
label : String -> Option key
coalesce : key -> Option key
endBurst : History key a -> History key a

-- Undo and redo
undo : History key a -> History key a
redo : History key a -> History key a
canUndo : History key a -> Bool
canRedo : History key a -> Bool
undoLabel : History key a -> Maybe String
redoLabel : History key a -> Maybe String

-- The saved point
markSaved : History key a -> History key a
isAtSavedPoint : History key a -> Bool
saved : History key a -> a
clear : History key a -> History key a
reset : a -> History key a -> History key a

-- Controls and shortcuts
type Attribute  -- opaque: no constructors are exposed
controls : List Attribute -> { onUndo : msg, onRedo : msg } -> History key a -> Html msg
locale : Locale.Locale -> Attribute
showShortcuts : Attribute
shortcuts : Locale.Locale -> { onUndo : msg, onRedo : msg } -> List (Shortcut.Shortcut msg)
```

## Documentation

Undo and redo for a form or an editor: a value, the values it had before and
the values it had before you undid them.

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
the saved one; call `markSaved` after a successful save and `reset` after loading
another record. `isAtSavedPoint` is true whenever the present value equals the saved
one, also after typing a change and undoing it, so it is the dirty flag of the form:
`LeaveGuard.setDirty OrderForm (not (History.isAtSavedPoint history))`.

The controls (`controls`) are two icon buttons and a polite live region: after an undo
a screen reader says "Undid: Changed quantity", after a redo "Redid: Changed quantity".
The next change to the history, of any kind, takes the announcement away again. They are
the only visible part of this module.

## History

### `History`

```elm
type History key a  -- opaque: no constructors are exposed
```

A value with its past and its future. `key` is your own type for bursts that
become one step (use `()` when you do not coalesce) and `a` is the value. Make one
with `init`.

### `init`

```elm
init : a -> History key a
```

A history that starts at this value, which is also the saved one. It keeps
100 steps; see `withLimit`.

    History.init { quantity = "1", note = "" }

### `withLimit`

```elm
withLimit : Int -> History key a -> History key a
```

How many steps the history keeps in all: the ones `undo` goes back through
and the ones `redo` brings back, together. Older steps are dropped. A limit below 1
counts as 1. The default is 100. A smaller limit than before drops the oldest steps
at once, and the steps to redo before the steps to undo.

### `present`

```elm
present : History key a -> a
```

The value now. This is what the form shows and the application saves.

## Recording

### `Option`

```elm
type Option key  -- opaque: no constructors are exposed
```

A setting of one edit: its label and its burst. Make them with `label` and
`coalesce`; later ones win over earlier ones.

### `record`

```elm
record : List (Option key) -> a -> History key a -> History key a
```

Records the value as the new present one and forgets what could have been
redone. The list says what the edit was called (`label`) and which burst it belongs to
(`coalesce`); with `[]` it is a step of its own. A value that equals the present one
changes nothing at all.

    History.record [ History.label "Changed note" ] { draft | note = text } model.history

When the edit joins a burst, the step keeps the label of the latest edit that had one.

### `label`

```elm
label : String -> Option key
```

What the edit was called: "Changed quantity". It is the name of the step in
the tooltips of the controls and in what a screen reader is told after an undo
("Undid: Changed quantity"). A step without a label is called "the last change".

### `coalesce`

```elm
coalesce : key -> Option key
```

Puts the edit in a burst. When the edit before this one was recorded with the same
key and nothing came between them, the two become one step: the first one's starting
point and this one's result. The key is your own type, so that two fields cannot be
mixed up.

    History.coalesce Quantity

### `endBurst`

```elm
endBurst : History key a -> History key a
```

Ends the burst that is open, so that the next edit starts a step of its own
even if it has the same key. Call it when the field loses focus.

## Undo and redo

### `undo`

```elm
undo : History key a -> History key a
```

Goes back one step. With nothing to undo it changes nothing. The step that
was undone can be redone.

### `redo`

```elm
redo : History key a -> History key a
```

Goes forward one step that was undone. With nothing to redo it changes
nothing.

### `canUndo`

```elm
canUndo : History key a -> Bool
```

Is there a step to go back to?

### `canRedo`

```elm
canRedo : History key a -> Bool
```

Is there an undone step to come forward to?

### `undoLabel`

```elm
undoLabel : History key a -> Maybe String
```

The label of the step `undo` would take back, if it has one: "Changed
quantity". `Nothing` when there is nothing to undo or the step has no label.

### `redoLabel`

```elm
redoLabel : History key a -> Maybe String
```

The label of the step `redo` would bring back, if it has one.

## The saved point

### `markSaved`

```elm
markSaved : History key a -> History key a
```

Says that the present value is the saved one. Call it when a save has
succeeded. The steps stay, so the user can still undo past the save, and it ends
the burst that is open: what is typed after a save is a step of its own, so that
one undo goes back to what was saved.

### `isAtSavedPoint`

```elm
isAtSavedPoint : History key a -> Bool
```

Is the present value equal to the saved one? It is, right after `init`,
`markSaved` and `reset`, and again whenever an undo or a redo (or an edit that
undoes another) brings the value back. `not (isAtSavedPoint history)` is the dirty flag
of the form.

### `saved`

```elm
saved : History key a -> a
```

The value that counts as saved, for a "Discard changes" that records it:

    History.record [ History.label "Discarded changes" ] (History.saved model.history) model.history

### `clear`

```elm
clear : History key a -> History key a
```

Forgets every step back and forward and keeps the present and the saved value:
the next undo has nothing to go to. For a history that must not reach past a
save: `history |> History.markSaved |> History.clear`.

### `reset`

```elm
reset : a -> History key a -> History key a
```

Starts over from this value, which is also the saved one: the form has loaded
another record. Every step is forgotten; the limit stays.

## Controls and shortcuts

`Klar.History` does not listen to the keyboard: keys for the whole page are the job of
[Klar.Shortcut](Klar.Shortcut.md). `shortcuts` makes the two shortcuts, and you give them
to `Shortcut.listen`, `Shortcut.subscription` and `Shortcut.update` with your
others:

    Shortcut.listen ShortcutMsg (History.shortcuts Locale.en { onUndo = UndoPressed, onRedo = RedoPressed } ++ others) model.shortcuts

`Ctrl Z` in a text field is the field's own undo unless the shortcut is marked
`Shortcut.inInputs`. If the history records every key typed in the fields, mark
them (`List.map Shortcut.inInputs`), so that `Ctrl Z` undoes the history and not the
text of the one field.

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of the controls. Make them with the functions below and pass a list
to `controls`; later attributes win over earlier ones.

### `controls`

```elm
controls : List Attribute -> { onUndo : msg, onRedo : msg } -> History key a -> Html msg
```

Two icon buttons, "Undo" and "Redo", and a polite live region. The buttons are
named after the step they would take: "Undo: Changed quantity". They stay in place and
in the tab order when there is nothing to do (`aria-disabled`), so a user who undoes
everything does not lose focus; they do nothing then. After an undo or a redo the live
region says what happened, "Undid: Changed quantity", once and politely. It is empty
again after the next change to the history: an edit, `endBurst`, `markSaved`,
`withLimit`, `clear` or `reset`. (An edit that equals the present value, and an undo or
redo with nothing to do, change nothing and leave it as it was.) The live region is
always on the page, as it must be to be heard.

    History.controls [] { onUndo = UndoPressed, onRedo = RedoPressed } model.history

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

The language of the built-in text: the names of the buttons, "Undid: ..." and
"Redid: ..." for screen readers, and the name of the group. The default is
[`Locale.default`](Klar.Locale.md#default), which is English.

### `showShortcuts`

```elm
showShortcuts : Attribute
```

Shows `Ctrl Z` and `Ctrl Shift Z` in the tooltips and tells assistive
technology about them (`aria-keyshortcuts`). Add it only when the application has
registered `shortcuts`: a hint for a key that does nothing is a lie.

### `shortcuts`

```elm
shortcuts : Locale.Locale -> { onUndo : msg, onRedo : msg } -> List (Shortcut.Shortcut msg)
```

The shortcuts: `Ctrl Z` for undo, and `Ctrl Shift Z` and `Ctrl Y` (the Windows
convention) for redo; `Cmd` instead of `Ctrl` on a Mac. They are listed in the group
"Edit" of the shortcut sheet, redo twice, once for each pair of keys. Add them to the
list you give to [Klar.Shortcut](Klar.Shortcut.md); see the top of this section for the
fields that are typed in.
