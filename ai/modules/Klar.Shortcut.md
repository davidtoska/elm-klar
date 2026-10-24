# Klar.Shortcut

Global keyboard shortcuts for the whole application, including sequences of two keys such as `g` then `m`.

Import: `import Klar.Shortcut as Shortcut` | Group: Data and utilities

Types: `Msg`, `Keys`, `State`, `Shortcut`

## Signatures

```elm
-- Defining shortcuts
type Shortcut msg  -- opaque: no constructors are exposed
shortcut : Keys -> String -> String -> msg -> Shortcut msg
inInputs : Shortcut msg -> Shortcut msg
keysOf : Shortcut msg -> Keys
groupOf : Shortcut msg -> String
labelOf : Shortcut msg -> String
firesInInputs : Shortcut msg -> Bool

-- Keys
type Keys  -- opaque: no constructors are exposed
char : Char -> Keys
function : Int -> Keys
escape : Keys
enter : Keys
tab : Keys
space : Keys
backspace : Keys
delete : Keys
home : Keys
end : Keys
pageUp : Keys
pageDown : Keys
up : Keys
down : Keys
left : Keys
right : Keys
mod : Keys -> Keys
alt : Keys -> Keys
shift : Keys -> Keys
sequence : List Keys -> Keys

-- Wiring
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : State
update : List (Shortcut msg) -> Msg -> State -> ( State, Maybe msg )
listen : (Msg -> msg) -> List (Shortcut msg) -> State -> Html.Attribute msg
subscription : (Msg -> msg) -> List (Shortcut msg) -> State -> Sub msg

-- Showing keys
keycaps : Keys -> List (List String)
```

## Documentation

Global keyboard shortcuts for the whole application, including sequences of
two keys such as `g` then `m`.

Use when: the application needs global keyboard shortcuts, including sequences of two keys.
Do not use when: a key only matters inside one component (use that component's own key handling).
Quick path: `init`, `listen`, `subscription`, `update`

A shortcut is the keys, a group and a label (which
[Klar.ShortcutHelp](Klar.ShortcutHelp.md) lists) and the message to send. Keep all
shortcuts in one list and give that list to `listen`, `subscription` and
`update`.

    import Klar.Shortcut as Shortcut

    shortcuts : List (Shortcut.Shortcut Msg)
    shortcuts =
        [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette
            |> Shortcut.inInputs
        , Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) "Navigation" "Go to orders" GoToOrders
        , Shortcut.shortcut (Shortcut.char '?') "Help" "Show the keyboard shortcuts" OpenHelp
        ]

**Keys** are values of the opaque type `Keys`, built from the keys themselves,
so a misspelled key name cannot happen. `char 'k'` is a letter, a digit or a
symbol (`char '?'`, `char '/'`, `char '+'`), and the named keys are `escape`,
`enter`, `tab`, `space`, `backspace`, `delete`, `home`, `end`, `pageUp`,
`pageDown`, the arrows `up`, `down`, `left` and `right`, and `function 2` for F2.
`mod` is Ctrl (or Cmd on a Mac) and is put around keys: `mod (char 'k')`,
`shift enter`, `alt up`, `mod (shift (char 'n'))`. `shift` counts for letters and
named keys but not for symbols: the key for a question mark is simply
`char '?'`. A **sequence** is several keys one after the other:
`sequence [ char 'g', char 'o' ]` means `g`, then `o`, each within 1.2 seconds of
the one before. A key that is a shortcut by itself cannot also start a sequence.

**Wiring**, once, at the root of the application:

    -- model
    { shortcuts : Shortcut.State } -- Shortcut.init

    -- view: the root element listens, and takes focus so that it keeps it
    Html.div
        [ Shortcut.listen ShortcutMsg shortcuts model.shortcuts
        , Attr.tabindex -1
        ]
        [ page ]

    -- subscriptions
    Shortcut.subscription ShortcutMsg shortcuts model.shortcuts

    -- update
    ShortcutMsg m ->
        let
            ( state, fired ) =
                Shortcut.update shortcuts m model.shortcuts

            next =
                { model | shortcuts = state }
        in
        case fired of
            Just msg ->
                update msg next

            Nothing ->
                ( next, Cmd.none )

`listen` is an attribute of an element, so that it can stop the browser's own
action for the keys (Ctrl+K, `/`); with the `host` of [Klar.Modal](Klar.Modal.md)
put it in the `attributes` of the host, which can take focus already.
`subscription` catches the key presses that happen while nothing has focus, so
that shortcuts keep working after a dialog has closed.

**When shortcuts fire**: while the user types in a text field, a text area, a
select or any editable element, a shortcut fires only if it is marked
`inInputs`, also when it uses Ctrl, Alt or Cmd. Keys pressed inside a modal
dialog ([Klar.Modal](Klar.Modal.md), [Klar.Drawer](Klar.Drawer.md) or the
[command palette](Klar.CommandPalette.md)), but not in a field, only reach
shortcuts with Ctrl, Alt or Cmd (not Ctrl+A or Cmd+A, which select everything)
and those marked `inInputs`: a sequence like `g o` must not take the user away
behind an open dialog. Everywhere else every shortcut fires. Holding a key down
does not repeat a shortcut. A symbol typed with AltGr (on a German keyboard `[`
is AltGr and 8) counts as the plain symbol, not as Ctrl+Alt, and in a field it is
text that never fires a shortcut.

## Defining shortcuts

### `Shortcut`

```elm
type Shortcut msg  -- opaque: no constructors are exposed
```

One keyboard shortcut: keys, a group and a label for the help sheet, and the
message to send. The type is opaque, so that it can grow; make one with `shortcut`
and read it with `keysOf`, `groupOf` and `labelOf`.

### `shortcut`

```elm
shortcut : Keys -> String -> String -> msg -> Shortcut msg
```

A shortcut. The arguments are the keys, the group, the label and the message
to send. The group and the label are for [Klar.ShortcutHelp](Klar.ShortcutHelp.md),
so write them for people.

    Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette

    Shortcut.shortcut (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ]) "Navigation" "Go to orders" GoToOrders

`mod` is Ctrl, or Cmd on a Mac, depending on the keyboard. The help sheet and
`keycaps` always write it as "Ctrl".

### `inInputs`

```elm
inInputs : Shortcut msg -> Shortcut msg
```

Lets the shortcut fire while the user types in a field (a text field, a text
area, a select or an editable element), and inside a modal dialog. Without it
the shortcut does not fire while the user types, not even with Ctrl, Alt or Cmd,
and inside a dialog only combinations with Ctrl, Alt or Cmd (except Ctrl+A)
fire. Use it for keys that make sense while typing, like `escape` or
`mod (char 'k')`. A character typed with AltGr never fires a shortcut in a field,
with or without this.

    Shortcut.shortcut Shortcut.escape "Navigation" "Close" CloseMenu
        |> Shortcut.inInputs

### `keysOf`

```elm
keysOf : Shortcut msg -> Keys
```

The keys of a shortcut.

### `groupOf`

```elm
groupOf : Shortcut msg -> String
```

The heading a shortcut is listed under in the help sheet.

### `labelOf`

```elm
labelOf : Shortcut msg -> String
```

What a shortcut does, as written for the help sheet.

### `firesInInputs`

```elm
firesInInputs : Shortcut msg -> Bool
```

Whether the shortcut was marked with `inInputs`.

## Keys

### `Keys`

```elm
type Keys  -- opaque: no constructors are exposed
```

The keys of a shortcut: one key, a key with modifiers, or a sequence of them.
Build them with `char`, the named keys, `mod`, `alt`, `shift` and `sequence`.

### `char`

```elm
char : Char -> Keys
```

A letter, a digit or a symbol: `char 'k'`, `char '?'`, `char '/'`. Letters are
not case sensitive (`char 'K'` is `char 'k'`); use `shift` for the shifted key.

### `function`

```elm
function : Int -> Keys
```

A function key, `function 1` to `function 12`. A number outside that range is
taken as the nearest one.

### `escape`

```elm
escape : Keys
```

The Escape key.

### `enter`

```elm
enter : Keys
```

The Enter key.

### `tab`

```elm
tab : Keys
```

The Tab key.

### `space`

```elm
space : Keys
```

The space bar.

### `backspace`

```elm
backspace : Keys
```

The Backspace key.

### `delete`

```elm
delete : Keys
```

The Delete key.

### `home`

```elm
home : Keys
```

The Home key.

### `end`

```elm
end : Keys
```

The End key.

### `pageUp`

```elm
pageUp : Keys
```

The Page Up key.

### `pageDown`

```elm
pageDown : Keys
```

The Page Down key.

### `up`

```elm
up : Keys
```

The up arrow.

### `down`

```elm
down : Keys
```

The down arrow.

### `left`

```elm
left : Keys
```

The left arrow.

### `right`

```elm
right : Keys
```

The right arrow.

### `mod`

```elm
mod : Keys -> Keys
```

Ctrl, or Cmd on a Mac, held with the keys: `mod (char 'k')`. On a sequence it
applies to every key of the sequence.

### `alt`

```elm
alt : Keys -> Keys
```

Alt (Option on a Mac) held with the keys: `alt up`.

### `shift`

```elm
shift : Keys -> Keys
```

Shift held with the keys: `shift enter`, `mod (shift (char 'n'))`. It counts for
letters and named keys, not for symbols.

### `sequence`

```elm
sequence : List Keys -> Keys
```

Several keys one after the other, each within 1.2 seconds of the one before:
`sequence [ char 'g', char 'o' ]`. A sequence of one is that key, and an empty
list is a key that is never pressed.

## Wiring

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

What the shortcuts hold on to between key presses: the keys of a sequence
that is waiting for its next key, and when the last of them was pressed. Make one
with `init` and keep it in your model.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

A message from `listen` or `subscription`. Wrap it in one of your own
messages and pass it to `update`.

### `init`

```elm
init : State
```

The state to start with, when no sequence is under way.

### `update`

```elm
update : List (Shortcut msg) -> Msg -> State -> ( State, Maybe msg )
```

Applies a message from `listen` or `subscription`. The result is the new
state and, when a shortcut fired, the message of that shortcut: handle it like
any other message of your application (see the wiring at the top of this page).
Give it the same list of shortcuts as `listen`.

### `listen`

```elm
listen : (Msg -> msg) -> List (Shortcut msg) -> State -> Html.Attribute msg
```

An attribute for the focusable root element of the application (give it
`tabindex -1`). It hears the key presses of everything inside the element and
prevents the browser's own action for the ones that trigger a shortcut, so
Ctrl+K does not reach the browser. A key that only starts a sequence is not
prevented.

    Html.div
        [ Shortcut.listen ShortcutMsg shortcuts model.shortcuts
        , Attr.tabindex -1
        ]
        [ page ]

### `subscription`

```elm
subscription : (Msg -> msg) -> List (Shortcut msg) -> State -> Sub msg
```

Catches the key presses that happen while nothing has focus (the target is
the page itself), so that shortcuts keep working after a dialog has closed and
focus was lost. Key presses on a focused element are left to `listen`.

## Showing keys

### `keycaps`

```elm
keycaps : Keys -> List (List String)
```

Key caps as text, one list per step of the sequence, for a place that needs the
names of the keys. To draw them, give the `Keys` to `Kbd.view` of [Klar.Kbd](Klar.Kbd.md).

    Shortcut.keycaps (Shortcut.mod (Shortcut.char 'k')) == [ [ "Ctrl", "K" ] ]

    Shortcut.keycaps (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'm' ]) == [ [ "G" ], [ "M" ] ]

    Shortcut.keycaps (Shortcut.char '?') == [ [ "?" ] ]

    Shortcut.keycaps (Shortcut.mod (Shortcut.char '+')) == [ [ "Ctrl", "+" ] ]

`mod` means Ctrl, or Cmd on a Mac, depending on the keyboard, but it is always
written as "Ctrl" here. The arrow keys are shown as arrows.
