# Klar.Theme

The look of the application: ten themes, each in a light and a dark mode, and the small shared vocabulary of the components: the color of a message (`Tone`), the size of a control (`Size`) and how ...

Import: `import Klar.Theme as Theme` | Group: Foundations

Types: `Mode`, `Size`, `Tone`, `Theme`, `Density`

## Signatures

```elm
-- Themes
type Theme  -- opaque: no constructors are exposed
type Mode = Light | Dark | System
klar : Theme
ocean : Theme
teal : Theme
indigo : Theme
violet : Theme
plum : Theme
slate : Theme
graphite : Theme
sand : Theme
contrast : Theme
all : List Theme
name : Locale.Locale -> Theme -> String
key : Theme -> String
fromKey : String -> Maybe Theme
style : Theme -> Mode -> Html msg

-- Light and dark
modes : List Mode
modeName : Locale.Locale -> Mode -> String
modeKey : Mode -> String
modeFromKey : String -> Maybe Mode

-- Tones, sizes and density
type Tone = Neutral | Primary | Info | Success | Warning | Danger
type Size = Small | Medium | Large
type Density = Compact | Normal | Comfortable
```

## Documentation

The look of the application: ten themes, each in a light and a dark mode, and
the small shared vocabulary of the components: the color of a message (`Tone`),
the size of a control (`Size`) and how tightly rows are packed (`Density`).

Use when: the application picks one of the ten themes, or a person picks the mode (light, dark or the system's); or you give a component a tone, a size or a density.
Do not use when: you want colors of your own. There is no way to make one on purpose: the themes are drawn so that every pair of colors in the library keeps WCAG AA contrast, which a color picked in a form would not.
Quick path: `Theme.ocean`, `Settings.withTheme`, `Settings.withMode`, `Klar.stylesheetFor`

    import Klar.Badge as Badge
    import Klar.Button as Button
    import Klar.Theme exposing (Size(..), Tone(..))

    Badge.view [ Badge.tone Success ] "Shipped"

    Button.view [ Button.size Large ] "Place order"

These are the only exposed custom types that components share. Everything else
about the look of Klar lives in the stylesheet, as CSS custom properties.

## Themes

There are ten, and an application chooses one (an internal application usually
picks one for the company and leaves it): `klar` (the default blue), `ocean`,
`teal`, `indigo`, `violet`, `plum`, `slate`, `graphite` (no color), `sand` (warm
grays) and `contrast` (high contrast, for people who need it). None of them is
green, amber or red, so an accent is never mistaken for success, a warning or an
error. Each has a light and a dark mode; the mode is `Light`, `Dark` or `System`
(follow the operating system). The choice lives in `Klar.Settings` and is drawn by
`Klar.stylesheetFor` (the plain `Klar.stylesheet` draws only `klar` in `Light`):

    import Klar
    import Klar.Settings as Settings
    import Klar.Theme as Theme exposing (Mode(..))

    settings =
        Settings.default
            |> Settings.withTheme Theme.ocean
            |> Settings.withMode System

    view model =
        Html.div [] [ Klar.stylesheetFor model.settings, page ]

A choice the person makes is stored with `key` and `modeKey` and read back with
`fromKey` and `modeFromKey`; `name` and `modeName` are the texts of a picker:

    Radio.options (List.map (\theme -> Radio.option (Theme.key theme) (Theme.name model.locale theme)) Theme.all)

A page that draws `Klar.css` itself instead of using `Klar.stylesheet` puts `Theme.style`
after it. The colors of a theme are computed in Elm
and drawn as custom properties on `:root`, so there is one theme for the whole page.

### `Theme`

```elm
type Theme  -- opaque: no constructors are exposed
```

One of the ten themes. The type is opaque: it is one of the values below.

### `Mode`

```elm
type Mode = Light | Dark | System
```

Whether the page is light, dark, or follows the operating system.
`System` is dark when the person has asked the system for a dark mode, and light
otherwise. A page without a choice is `Light`.

### `klar`

```elm
klar : Theme
```

The default: calm gray, white and blue.

### `ocean`

```elm
ocean : Theme
```

Cyan blue.

### `teal`

```elm
teal : Theme
```

Blue green.

### `indigo`

```elm
indigo : Theme
```

Deep blue.

### `violet`

```elm
violet : Theme
```

Blue violet.

### `plum`

```elm
plum : Theme
```

Muted purple.

### `slate`

```elm
slate : Theme
```

Steel: a blue so quiet that the page is almost gray.

### `graphite`

```elm
graphite : Theme
```

No color at all, only grays.

### `sand`

```elm
sand : Theme
```

Warm, paper-like grays with a blue accent.

### `contrast`

```elm
contrast : Theme
```

High contrast: black on white, or white on black, with strong borders. For
people who need it, and a good choice for a wall display.

### `all`

```elm
all : List Theme
```

All ten, in the order to offer them in a list.

    List.map (Theme.name Locale.en) Theme.all -- [ "Klar", "Ocean", "Teal", ... ]

### `name`

```elm
name : Locale.Locale -> Theme -> String
```

The name to show a person, in the language of the locale: "Ocean" in
English, "Hav" in Norwegian. To store a choice, use `key`.

    Theme.name Locale.nb Theme.graphite -- "Grafitt"

### `key`

```elm
key : Theme -> String
```

A short stable text for a theme (`"ocean"`), to store a choice with
(`fromKey` reads it back). The keys never change.

### `fromKey`

```elm
fromKey : String -> Maybe Theme
```

The theme with that key, if there is one. Use it on a stored choice, and fall
back to `klar` on `Nothing`.

### `style`

```elm
style : Theme -> Mode -> Html msg
```

The `style` element that sets the colors of a theme in a mode. It is empty for
`klar` in `Light`, because the stylesheet is that already. Put it after the
stylesheet; `Klar.stylesheetFor` does both.

## Light and dark

### `modes`

```elm
modes : List Mode
```

The three modes, in the order to offer them: `Light`, `Dark`, `System`.

### `modeName`

```elm
modeName : Locale.Locale -> Mode -> String
```

The name of a mode to show a person: "Light", "Dark" or "System" in English,
"Lys", "Mørk" or "System" in Norwegian.

    SegmentedControl.options
        (List.map (\m -> SegmentedControl.option (Theme.modeKey m) (Theme.modeName model.locale m)) Theme.modes)

### `modeKey`

```elm
modeKey : Mode -> String
```

A short stable text for a mode (`"light"`, `"dark"`, `"system"`), to store the
person's choice with; `modeFromKey` reads it back. The keys never change.

### `modeFromKey`

```elm
modeFromKey : String -> Maybe Mode
```

The mode with that key, if there is one. Use it on a stored choice, and fall
back to `Light` (or `System`) on `Nothing`.

    Theme.modeFromKey "dark" -- Just Dark

## The tokens

The stylesheet (see [`Klar.stylesheet`](Klar.md#stylesheet)) defines its design
tokens on `:root`. A component never uses a literal color, spacing or radius, only
`var(--klar-...)`. The list is a reference: an application chooses its look with a theme
(`Settings.withTheme`, `Klar.stylesheetFor`) and writes no CSS. A token redefined by hand is
outside what Klar checks, so its contrast is not promised.

The tokens:

  - Color: `--klar-primary`, `--klar-primary-hover`, `--klar-primary-subtle`,
    `--klar-success`, `--klar-warning`, `--klar-danger`, `--klar-info` (each with
    `-subtle` and `-border` variants), `--klar-bg`, `--klar-surface`,
    `--klar-border`, `--klar-text`, `--klar-text-secondary`, `--klar-text-muted`.
  - Text: `--klar-font`, `--klar-font-mono`, `--klar-text-xs` to
    `--klar-text-3xl` (13px is the body size).
  - Space and shape: `--klar-space-1` to `--klar-space-12` (a 4px grid),
    `--klar-radius-sm`, `--klar-radius`, `--klar-radius-lg`.
  - Controls and rows: `--klar-control-sm` (26px), `--klar-control` (32px),
    `--klar-control-lg` (40px), `--klar-row-compact` (28px), `--klar-row` (36px),
    `--klar-row-comfortable` (46px).
  - Layout: `--klar-header-h`, `--klar-sidebar-w`, `--klar-page-max`.
  - Depth and motion: `--klar-shadow-xs` to `--klar-shadow-lg`,
    `--klar-dur-fast`, `--klar-dur`, `--klar-dur-slow`, `--klar-ease`.
  - Focus: `--klar-focus-color` and `--klar-focus-ring`, the ring drawn around
    the control that has the keyboard focus.
  - Stacking: `--klar-z-sticky` to `--klar-z-palette`, the layers of sticky
    headers, popups, drawers, dialogs, toasts and tooltips. Change them only if
    your own layers must sit between two of Klar's.

The palette behind them (`--klar-gray-25` to `--klar-gray-900`, `--klar-blue-50`
to `--klar-blue-900`, which is the accent scale of whatever theme is chosen, and the green, amber and red scales) is also a set of
tokens. The default look is calm and light: gray, white and blue. The page
`color-scheme` is `light`, or `dark` in a dark mode. Every token is defined in the `:root` block at the start
of `Klar.css`.

## Tones, sizes and density

### `Tone`

```elm
type Tone = Neutral | Primary | Info | Success | Warning | Danger
```

The meaning of a color: what a message, badge, tag or banner is about.

  - `Neutral`: plain information or no particular meaning
  - `Primary`: the accent color of the application
  - `Info`: something worth noting
  - `Success`: it worked, or the state is good
  - `Warning`: needs attention but nothing is broken
  - `Danger`: an error, or an action that cannot be undone

### `Size`

```elm
type Size = Small | Medium | Large
```

The size of a control: `Small`, `Medium` (the default) or `Large`. At `Normal`
density they are 26, 32 and 40 pixels high; the density of the page moves them
(26, 28 and 36 at `Compact`, 32, 40 and 48 at `Comfortable`), so size things by the
name, not by the pixels.

### `Density`

```elm
type Density = Compact | Normal | Comfortable
```

How tightly rows and cells are packed: `Compact` (28px rows), `Normal`
(36px, the default) or `Comfortable` (46px). A table shows more rows in the same
space when it is compact, and is easier to hit with a finger when it is
comfortable.

The application says its density once, in its [Klar.Settings](Klar.Settings.md), and
every component follows it; a component that is given a density of its own keeps it.
