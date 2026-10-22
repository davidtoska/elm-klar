module Klar.Theme exposing
    ( Tone(..), Size(..), Density(..)
    , toneSuffix, sizeSuffix, densitySuffix
    )

{-| The small shared vocabulary of the components: the color of a message
(`Tone`), the size of a control (`Size`) and how tightly rows are packed
(`Density`).

Use when: you give a component a tone, a size or a density, or write a component of your own that follows them.
Do not use when: the whole look should change, which a person does with the CSS custom properties of the stylesheet (see `Klar`), never the application code.

    import Klar.Badge as Badge
    import Klar.Button as Button
    import Klar.Theme exposing (Size(..), Tone(..))

    Badge.view [ Badge.tone Success ] "Shipped"

    Button.view [ Button.size Large ] "Place order"

These are the only exposed custom types that components share. Everything else
about the look of Klar lives in the stylesheet, as CSS custom properties.


# Restyling

The stylesheet (see [`Klar.stylesheet`](Klar#stylesheet)) defines its design
tokens on `:root`. A component never uses a literal color, spacing or radius, only
`var(--klar-...)`, so redefining a token restyles every component at once. Put
your own CSS after the library's, and redefine tokens where you need them, on
`:root` for the whole page or on a container for part of it:

    :root {
      --klar-primary: #0b7285;
      --klar-primary-hover: #095c6b;
      --klar-font: "Inter", system-ui, sans-serif;
    }

The tokens you will use most:

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
to `--klar-blue-900`, and the green, amber and red scales) is also a set of
tokens. The default look is calm and light: gray, white and blue. The page
`color-scheme` is `light`. Every token is defined in the `:root` block at the top
of `css/klar.css` in the source of the package.


# Tones, sizes and density

@docs Tone, Size, Density


# Building your own components

If you make components of your own that should look like Klar's, the suffixes
below are the modifier names its stylesheet uses: `"klar-badge--" ++ toneSuffix
Success` is `"klar-badge--success"`.

@docs toneSuffix, sizeSuffix, densitySuffix

-}


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


{-| The modifier of a tone in the class names of the stylesheet.

    Theme.toneSuffix Warning -- "warning"

-}
toneSuffix : Tone -> String
toneSuffix tone =
    case tone of
        Neutral ->
            "neutral"

        Primary ->
            "primary"

        Info ->
            "info"

        Success ->
            "success"

        Warning ->
            "warning"

        Danger ->
            "danger"


{-| The modifier of a size in the class names of the stylesheet: `"sm"`, `"md"`
or `"lg"`.
-}
sizeSuffix : Size -> String
sizeSuffix size =
    case size of
        Small ->
            "sm"

        Medium ->
            "md"

        Large ->
            "lg"


{-| The modifier of a density in the class names of the stylesheet:
`"compact"`, `"normal"` or `"comfortable"`.
-}
densitySuffix : Density -> String
densitySuffix density =
    case density of
        Compact ->
            "compact"

        Normal ->
            "normal"

        Comfortable ->
            "comfortable"
