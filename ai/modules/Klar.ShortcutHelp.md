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
locale : Locale.Locale -> Attribute msg
```

## Documentation

The cheat sheet of keyboard shortcuts: a dialog that lists every shortcut of
the application, grouped, with key caps and a small filter box.

Use when: the user needs a cheat sheet of the keyboard shortcuts the application listens to.
Do not use when: you only need to show one shortcut next to a control (use `Klar.Tooltip`).
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

The shortcuts are listed under their `group`, in the order in which the groups
first appear, each with its label and its keys as key caps (a sequence such as
`g o` reads "G then O"). The filter box matches the label, the group and the
keys. A shortcut that also works while the user types in a field (`inInputs`) is
marked "works in fields"; a note at the bottom says that the others do not. The
`mod` in the keys of a shortcut is Ctrl, or Cmd on a Mac, depending on the
keyboard, but the sheet always writes it as "Ctrl". The built-in text follows
`locale`, which is English by default; the groups and labels come from your
shortcuts.

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
yours. A `mod` in the keys of a shortcut (Ctrl, or Cmd on a Mac) is always
written as "Ctrl" on the sheet.

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

### `locale`

```elm
locale : Locale.Locale -> Attribute msg
```

The language of the built-in texts: the heading, the filter box, the notes and
the Close button. The default is `Locale.default`, which is `Locale.en`. The groups and
labels of the shortcuts come from the application.
