# Klar.ShortcutHelp

The cheat sheet of keyboard shortcuts: a dialog that lists every shortcut of the application, grouped, with key caps and a small filter box.

Import: `import Klar.ShortcutHelp as ShortcutHelp` | Group: Overlays

Types: `Msg`, `State`, `Attribute`

## Signatures

```elm
-- View
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> List (Shortcut.Shortcut a)
    -> State
    -> Overlay.Overlay msg

-- State
type State  -- opaque: no constructors are exposed
type Msg  -- opaque: no constructors are exposed
init : String -> State
update : Msg -> State -> ( State, Cmd Msg )

-- Opening and closing
open : String -> State -> ( State, Cmd Msg )
close : State -> ( State, Cmd Msg )
isOpen : State -> Bool

-- Attributes
type Attribute msg  -- opaque: no constructors are exposed
title : String -> Attribute msg
platform : Kbd.Platform -> Attribute msg
extra : List { group : String, label : String, keys : Shortcut.Keys } -> Attribute msg
locale : Locale.Locale -> Attribute msg
```

## Documentation

The cheat sheet of keyboard shortcuts: a dialog that lists every shortcut of
the application, grouped, with key caps and a small filter box.

Use when: the user needs a cheat sheet of the keyboard shortcuts the application listens to.
Do not use when: you only need to show one shortcut next to a control (use `Klar.Kbd`, or the shortcut of a `Klar.Tooltip`).
Quick path: `init`, `open`, `update`, `view`, `close`, `isOpen`

It is built from the same list of [Klar.Shortcut](Klar.Shortcut.md) shortcuts that
the application listens to, so the sheet always says what the keys really do.

    import Klar.Shortcut as Shortcut
    import Klar.ShortcutHelp as ShortcutHelp

    -- model
    { help : ShortcutHelp.State } -- ShortcutHelp.init "shortcut-help"

    -- one of the shortcuts, so that "?" opens the sheet
    Shortcut.shortcut (Shortcut.char '?') "Help" "Show the keyboard shortcuts" OpenHelp

    -- update
    OpenHelp ->
        let
            ( help, cmd ) =
                ShortcutHelp.open "" model.help
        in
        ( { model | help = help }, Cmd.map HelpMsg cmd )

    HelpMsg m ->
        let
            ( help, cmd ) =
                ShortcutHelp.update m model.help
        in
        ( { model | help = help }, Cmd.map HelpMsg cmd )

    -- view: the same list as you give to Shortcut.listen
    ShortcutHelp.view HelpMsg [] shortcuts model.help

The sheet is a [Klar.Modal](Klar.Modal.md): it moves focus to the filter box, keeps
`Tab` inside, closes with `Escape` or the "Close" button and returns focus to
where it came from. It returns an [`Overlay`](Klar.Overlay.md#overlay): put it in
the list of overlays of the page, which makes the page behind it inert.

The shortcuts are listed under their `group` (a heading, so a screen reader can
jump between the groups), in the order in which the groups first appear, each
with its label and its keys drawn by [Klar.Kbd](Klar.Kbd.md): key caps for the eye
(a sequence such as `g o` reads "G then O") and one spoken phrase for a screen
reader ("Control plus K", "question mark"). The keys are written for the
`platform`: `Kbd.pc` (Ctrl, the default) or `Kbd.mac` (⌘). The filter box
matches the label, the group and the keys, also by their other names ("cmd",
"control", "escape", "pgup"), and a polite status says how many shortcuts match.
A shortcut that also works while the user types in a field (`inInputs`) is marked
"works in fields"; a note at the bottom says that the others do not, and that
only the shortcuts with Ctrl, Alt or Cmd work while a dialog is open. The
built-in text follows `locale`, which is English by default; the groups and
labels come from your shortcuts.

## View

### `view`

```elm
view :
    (Msg -> msg)
    -> List (Attribute msg)
    -> List (Shortcut.Shortcut a)
    -> State
    -> Overlay.Overlay msg
```

The sheet for these shortcuts: give it the same list as `Shortcut.listen`.
Renders nothing while closed. The first argument turns the sheet's messages into
yours. A `mod` in the keys of a shortcut is written as Ctrl, or as ⌘ with
`platform Kbd.mac`.

    ShortcutHelp.view HelpMsg [ ShortcutHelp.title "Keys" ] shortcuts model.help

## State

### `State`

```elm
type State  -- opaque: no constructors are exposed
```

The state of the sheet: whether it is open, where focus goes back to, and
what is typed in the filter box. Make one with `init` and keep it in your model.

### `Msg`

```elm
type Msg  -- opaque: no constructors are exposed
```

A message from the sheet. Wrap it in one of your own messages and pass it to
`update`.

### `init`

```elm
init : String -> State
```

A closed sheet. The `String` is the DOM id of the dialog and must be unique
on the page; the ids of its filter box and Close button start with it.

    ShortcutHelp.init "shortcut-help"

### `update`

```elm
update : Msg -> State -> ( State, Cmd Msg )
```

Handles the filter box, closing and focus. The command moves keyboard focus,
so map it with `Cmd.map`.

## Opening and closing

### `open`

```elm
open : String -> State -> ( State, Cmd Msg )
```

Opens the sheet with an empty filter and moves focus to the filter box.
`opener` is the DOM id of the element that gets focus back when the sheet closes.
With `""` (the usual case when a shortcut opened it) focus goes back to the
element that had it, if that element has an id.

### `close`

```elm
close : State -> ( State, Cmd Msg )
```

Closes the sheet and gives focus back to its opener.

### `isOpen`

```elm
isOpen : State -> Bool
```

Is the sheet open? The page is made inert by the overlay the sheet returns, so
you need this for your own logic only (a shortcut that toggles the sheet, say).

## Attributes

### `Attribute`

```elm
type Attribute msg  -- opaque: no constructors are exposed
```

A setting of the sheet. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.

### `title`

```elm
title : String -> Attribute msg
```

The heading of the dialog, which is also its accessible name. The default is
"Keyboard shortcuts".

### `platform`

```elm
platform : Kbd.Platform -> Attribute msg
```

The keyboard to write the keys for, as in [Klar.Kbd](Klar.Kbd.md): `Kbd.pc` (the
default: Ctrl, Alt, Shift) or `Kbd.mac` (⌘, ⌥, ⇧ in the order a Mac writes them).
Read it once from the user agent with `Kbd.platformFromUserAgent`.
[Klar.Shortcut](Klar.Shortcut.md) finds a Mac by itself, a view cannot: without
this a Mac user reads "Ctrl K" for a shortcut that fires on ⌘ K.

    ShortcutHelp.platform (Kbd.platformFromUserAgent flags.userAgent)

### `extra`

```elm
extra : List { group : String, label : String, keys : Shortcut.Keys } -> Attribute msg
```

Keys worth knowing that are not shortcuts of the application: the keys of
Klar's own components (`Shift+F10` for the menu of a row, `Enter` to edit a cell)
or of your own widgets. They are listed under their group like the shortcuts,
after them, and found by the filter, but never listened to. The default is none.

    ShortcutHelp.extra
        [ { group = "Tables", label = "Open the menu of the row", keys = Shortcut.shift (Shortcut.function 10) }
        , { group = "Tables", label = "Edit the cell", keys = Shortcut.enter }
        ]

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in texts: the heading, the filter box, the notes,
the spoken names of the keys and the Close button. The default is `Locale.default`, which is `Locale.en`. The groups and
labels of the shortcuts come from the application.
