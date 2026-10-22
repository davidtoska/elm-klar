# Klar.Kbd

Keyboard keys as key caps, for hints and documentation: "Ctrl K", "Shift Enter", or a sequence such as "G then O".

Import: `import Klar.Kbd as Kbd` | Group: Actions

Types: `Platform`, `Attribute`

## Signatures

```elm
-- Keys
view : List Attribute -> Shortcut.Keys -> Html msg
key : List Attribute -> String -> Html msg
toString : List Attribute -> Shortcut.Keys -> String

-- Attributes
type Attribute  -- opaque: no constructors are exposed
platform : Platform -> Attribute
locale : Locale.Locale -> Attribute
small : Attribute
inline : Attribute

-- Platform
type Platform  -- opaque: no constructors are exposed
mac : Platform
pc : Platform
platformFromUserAgent : String -> Platform
```

## Documentation

Keyboard keys as key caps, for hints and documentation: "Ctrl K",
"Shift Enter", or a sequence such as "G then O".

    import Klar.Kbd as Kbd
    import Klar.Shortcut as Shortcut

    -- the same value that Shortcut.shortcut listens to
    openPalette : Shortcut.Keys
    openPalette =
        Shortcut.mod (Shortcut.char 'k')

    Kbd.view [] openPalette

    Kbd.view [ Kbd.small ] (Shortcut.sequence [ Shortcut.char 'g', Shortcut.char 'o' ])

The keys are the typed [Klar.Shortcut](Klar.Shortcut.md) `Keys`, so the hint that
the application shows and the shortcut that it listens to are one value, and a
key is never written as a string. `Shortcut.mod` is Ctrl on most keyboards and
Cmd on a Mac. Plain Elm cannot tell which keyboard the user has, so it is
`platform`: `pc` by default (Ctrl, Alt, Shift) or `mac` (the symbols for Cmd,
Option and Shift, in the order a Mac writes them). The application can read
`navigator.userAgent` in its flags and give it to `platformFromUserAgent`.

**Screen readers** do not read the key caps, which are decoration. They get one
phrase instead, in the language of `locale`: "Control plus K", "Shift plus
Enter", "G then O", "Command plus question mark". The symbols for Cmd and Option
on a Mac are read by name.

Use `view` next to a label ("Search Ctrl K"), in the text of a help page
(`inline`), or in a [Klar.Tooltip](Klar.Tooltip.md). The hint of a
[Klar.Menu](Klar.Menu.md) item and the shortcut of a tooltip are plain text:
`toString` writes the same keys as a `String` for them.

    Menu.item "Duplicate" Duplicate
        |> Menu.withHint (Kbd.toString [ Kbd.platform model.platform ] duplicateKeys)

This module only shows keys. The shortcut itself is made and listened to with
[Klar.Shortcut](Klar.Shortcut.md), and [Klar.ShortcutHelp](Klar.ShortcutHelp.md) lists
all of them.

A key that [Klar.Shortcut](Klar.Shortcut.md) has no value for (`Fn`, `Insert`, a
mouse "Click") is a plain text with `key`. It is shown and read exactly as it is
written, never translated, and `platform` does not change it.

## Keys

### `view`

```elm
view : List Attribute -> Shortcut.Keys -> Html msg
```

The key caps for these keys: one cap for each key, grouped as one
combination for each step of a sequence, with the word "then" between the steps.
Keys with no steps (an empty `sequence`) draw nothing.

    Kbd.view [] (Shortcut.shift Shortcut.enter) -- Shift Enter

    Kbd.view [ Kbd.platform Kbd.mac ] (Shortcut.mod (Shortcut.shift (Shortcut.char 'n'))) -- ⇧ ⌘ N

### `key`

```elm
key : List Attribute -> String -> Html msg
```

One key cap with a text of your own, for a key that
[Klar.Shortcut](Klar.Shortcut.md) does not know. The text is shown and read as it
is written; an empty text draws nothing.

    Kbd.key [] "Fn"

    Kbd.key [ Kbd.inline ] "Click"

### `toString`

```elm
toString : List Attribute -> Shortcut.Keys -> String
```

The same keys as plain text, for the places that take a `String`: the hint of
a menu item, the shortcut of a tooltip, a label. A PC writes the caps with a plus
between them (`Ctrl+Shift+K`), a Mac with a space (`⇧ ⌘ K`), and the steps of a
sequence are joined with "then" (`G then O`). The text can be given to
[`Tooltip.shortcut`](Klar.Tooltip.md#shortcut), which reads both spellings.

    Kbd.toString [] (Shortcut.mod (Shortcut.char 'k')) -- "Ctrl+K"

    Kbd.toString [ Kbd.platform Kbd.mac ] (Shortcut.mod (Shortcut.char 'k')) -- "⌘ K"

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of the key caps. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones. Keys send no messages, so the
type has no `msg` parameter.

### `platform`

```elm
platform : Platform -> Attribute
```

The keyboard to write the keys for. The default is `pc`.

    Kbd.view [ Kbd.platform Kbd.mac ] (Shortcut.mod (Shortcut.char 'k'))

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

The language of the text that screen readers get and of the word between the
steps of a sequence ("then"). The default is `Locale.default`, which is
`Locale.en`. The caps themselves (`Ctrl`, `K`) are the same in every language.

### `small`

```elm
small : Attribute
```

Compact caps (16px) for a menu, a tooltip or a field that shows its shortcut
at the end. The default is 20px.

### `inline`

```elm
inline : Attribute
```

Caps that follow the size of the surrounding text, for a key in a sentence
or a paragraph: they do not make the line taller. This replaces `small`, and the
other way round.

## Platform

### `Platform`

```elm
type Platform  -- opaque: no constructors are exposed
```

Which keyboard to write the keys for: `pc` (the default) or `mac`. Make one
with `pc`, `mac` or `platformFromUserAgent`.

### `mac`

```elm
mac : Platform
```

A Mac (and an iPhone or iPad with a keyboard): the `mod` key is Cmd and is
shown as ⌘, Alt is Option (⌥) and Shift is ⇧. Enter, Tab, Backspace and Delete
are shown as their symbols as well, and the modifiers come before the key in the
order a Mac writes them (⌥ ⇧ ⌘).

### `pc`

```elm
pc : Platform
```

Windows, Linux and everything that is not a Mac: Ctrl, Alt and Shift are
written as words. This is the default.

### `platformFromUserAgent`

```elm
platformFromUserAgent : String -> Platform
```

Reads the platform from the text of `navigator.userAgent` or
`navigator.platform`, which the application passes in as a flag: anything that
names a Mac, an iPhone, an iPad or an iPod is `mac`, everything else (also an
empty text) is `pc`. The text is only a guess about the keyboard, and a user can
change it, so use it for hints and nothing else.

    -- index.html:  Elm.Main.init({ flags: { userAgent: navigator.userAgent } })
    Kbd.platformFromUserAgent flags.userAgent
