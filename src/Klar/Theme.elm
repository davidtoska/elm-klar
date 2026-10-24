module Klar.Theme exposing
    ( Theme, Mode(..)
    , klar, ocean, teal, indigo, violet, plum, slate, graphite, sand, contrast
    , all, name, key, fromKey, style
    , Tone(..), Size(..), Density(..)
    )

{-| The look of the application: ten themes, each in a light and a dark mode, and
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


# Themes

There are ten, and an application chooses one (an internal application usually
picks one for the company and leaves it): `klar` (the default blue), `ocean`,
`teal`, `indigo`, `violet`, `plum`, `slate`, `graphite` (no color), `sand` (warm
grays) and `contrast` (high contrast, for people who need it). None of them is
green, amber or red, so an accent is never mistaken for success, a warning or an
error. Each has a light and a dark mode; the mode is `Light`, `Dark` or `System`
(follow the operating system). The choice lives in `Klar.Settings` and is drawn by
`Klar.stylesheetFor`:

    import Klar
    import Klar.Settings as Settings
    import Klar.Theme as Theme exposing (Mode(..))

    settings =
        Settings.default
            |> Settings.withTheme Theme.ocean
            |> Settings.withMode System

    view model =
        Html.div [] [ Klar.stylesheetFor model.settings, page ]

A page that draws `Klar.css` itself instead of using `Klar.stylesheet` puts `Theme.style`
after it. The colors of a theme are computed in Elm
and drawn as custom properties on `:root`, so there is one theme for the whole page.

@docs Theme, Mode
@docs klar, ocean, teal, indigo, violet, plum, slate, graphite, sand, contrast
@docs all, name, key, fromKey, style


# The tokens

The stylesheet (see [`Klar.stylesheet`](Klar#stylesheet)) defines its design
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


# Tones, sizes and density

@docs Tone, Size, Density

-}

import Html exposing (Html)
import Klar.Internal.Palette as Palette



-- THEMES


{-| One of the ten themes. The type is opaque: it is one of the values below.
-}
type Theme
    = Theme Palette.Spec


{-| Whether the page is light, dark, or follows the operating system.
`System` is dark when the person has asked the system for a dark mode, and light
otherwise. A page without a choice is `Light`.
-}
type Mode
    = Light
    | Dark
    | System


{-| The default: calm gray, white and blue.
-}
klar : Theme
klar =
    pick "klar"


{-| Cyan blue.
-}
ocean : Theme
ocean =
    pick "ocean"


{-| Blue green.
-}
teal : Theme
teal =
    pick "teal"


{-| Deep blue.
-}
indigo : Theme
indigo =
    pick "indigo"


{-| Blue violet.
-}
violet : Theme
violet =
    pick "violet"


{-| Muted purple.
-}
plum : Theme
plum =
    pick "plum"


{-| Steel: a blue so quiet that the page is almost gray.
-}
slate : Theme
slate =
    pick "slate"


{-| No color at all, only grays.
-}
graphite : Theme
graphite =
    pick "graphite"


{-| Warm, paper-like grays with a blue accent.
-}
sand : Theme
sand =
    pick "sand"


{-| High contrast: black on white, or white on black, with strong borders. For
people who need it, and a good choice for a wall display.
-}
contrast : Theme
contrast =
    pick "contrast"


pick : String -> Theme
pick wanted =
    Palette.specs
        |> List.filter (\spec -> spec.key == wanted)
        |> List.head
        |> Maybe.withDefault (Palette.Spec "klar" "Klar" 212 1 213 15 False True)
        |> Theme


{-| All ten, in the order to offer them in a list.

    List.map Theme.name Theme.all -- [ "Klar", "Ocean", "Teal", ... ]

-}
all : List Theme
all =
    List.map Theme Palette.specs


{-| The name to show a person: "Ocean".
-}
name : Theme -> String
name (Theme spec) =
    spec.name


{-| A short stable text for a theme (`"ocean"`), to store a choice with
(`fromKey` reads it back). The keys never change.
-}
key : Theme -> String
key (Theme spec) =
    spec.key


{-| The theme with that key, if there is one. Use it on a stored choice, and fall
back to `klar` on `Nothing`.
-}
fromKey : String -> Maybe Theme
fromKey wanted =
    all
        |> List.filter (\theme -> key theme == wanted)
        |> List.head


{-| The `style` element that sets the colors of a theme in a mode. It is empty for
`klar` in `Light`, because the stylesheet is that already. Put it after the
stylesheet; `Klar.stylesheetFor` does both.
-}
style : Theme -> Mode -> Html msg
style (Theme spec) mode =
    let
        light =
            Palette.css (Palette.declarations spec False)

        dark =
            Palette.css (Palette.declarations spec True)

        text =
            case mode of
                Light ->
                    light

                Dark ->
                    dark

                System ->
                    light ++ "@media (prefers-color-scheme:dark){" ++ dark ++ "}"
    in
    Html.node "style" [] [ Html.text text ]


{-| The meaning of a color: what a message, badge, tag or banner is about.

  - `Neutral`: plain information or no particular meaning
  - `Primary`: the accent color of the application
  - `Info`: something worth noting
  - `Success`: it worked, or the state is good
  - `Warning`: needs attention but nothing is broken
  - `Danger`: an error, or an action that cannot be undone

-}
type Tone
    = Neutral
    | Primary
    | Info
    | Success
    | Warning
    | Danger


{-| The size of a control: `Small` (26px high), `Medium` (32px, the default) or
`Large` (40px).
-}
type Size
    = Small
    | Medium
    | Large


{-| How tightly rows and cells are packed: `Compact` (28px rows), `Normal`
(36px, the default) or `Comfortable` (46px). A table shows more rows in the same
space when it is compact, and is easier to hit with a finger when it is
comfortable.

The application says its density once, in its [Klar.Settings](Klar-Settings), and
every component follows it; a component that is given a density of its own keeps it.

-}
type Density
    = Compact
    | Normal
    | Comfortable
