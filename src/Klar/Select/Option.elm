module Klar.Select.Option exposing
    ( Option
    , disabledOption
    , mapOption
    , option
    , withColor
    , withDescription
    , withGroup
    , withIcon
    , withKeywords
    , withMeta
    , withTone
    )

{-| Internal. The option record of the select family and its builders, shared by
`Klar.Select`, `Klar.MultiSelect`, `Klar.Autocomplete`, `Klar.Transfer` and
`Klar.Rule`. Applications make options with `Klar.Select` (`Select.option`, the
`with*` functions and the type `Select.Option`), which is the same record: one way
to make an option.
-}

import Klar.Color exposing (Color)
import Klar.Icon exposing (Icon)
import Klar.Theme exposing (Tone)


{-| One choice in a list (the same record as `Klar.Select.Option`). It is plain
data: make it with `option` and the `with*` functions.

  - `value` is what the application stores: its own id type (a `CustomerId`, a code, an `Int`).
    Values are compared with `==`, so use data, not functions, and keep it unique within one list
  - `label` is what the user sees and searches
  - `description` is a short secondary text, shown dimmed after the label and searched too
  - `group` lists the option under a heading, together with the options of the same group
  - `disabled` shows the option dimmed and keeps it from being chosen
  - `icon` is drawn before the label
  - `tone` and `color` mark the option with a small dot before the label, a status color that
    follows the theme or a color from your data (never both; the last one set wins)
  - `keywords` are extra words that also match but are never shown (synonyms, codes, old names)

-}
type alias Option id =
    { value : id
    , label : String
    , description : Maybe String
    , group : Maybe String
    , disabled : Bool
    , icon : Maybe Icon
    , tone : Maybe Tone
    , color : Maybe Color
    , keywords : List String
    , meta : Maybe String
    }


{-| An option with a value (what the application stores) and a label (what the
user sees and searches), and nothing else: no description, group or icon, not
disabled, no keywords. Add those with the `with*` functions.

    Option.option "de" "Germany"
        |> Option.withDescription "DE"
        |> Option.withGroup "Europe"

-}
option : id -> String -> Option id
option value label =
    { value = value
    , label = label
    , description = Nothing
    , group = Nothing
    , disabled = False
    , icon = Nothing
    , tone = Nothing
    , color = Nothing
    , keywords = []
    , meta = Nothing
    }


{-| A short secondary text, shown dimmed after the label and in the tooltip of
the option. It is searched too, but a match in the description ranks below the
same match in the label.
-}
withDescription : String -> Option id -> Option id
withDescription text opt =
    { opt | description = Just text }


{-| A short value at the end of the row, in tabular figures: a stock count, a
code, a price. It is searched like the description.
-}
withMeta : String -> Option id -> Option id
withMeta text opt =
    { opt | meta = Just text }


{-| Lists the option under a heading with this name. Options with the same
group are shown together, in the order the groups first appear, and options
without a group come first, under no heading. While the user searches, the
group with the best match comes first.
-}
withGroup : String -> Option id -> Option id
withGroup name opt =
    { opt | group = Just name }


{-| An icon drawn before the label of the option in the list. `Klar.Select` also
shows it in the closed field next to the chosen label.
-}
withIcon : Icon -> Option id -> Option id
withIcon icon opt =
    { opt | icon = Just icon }


{-| A small dot in a status color before the label: `Success` is green, `Warning`
amber, `Danger` red. The color follows the theme and the dark mode. Use it for a
status; for a color that is a value of your data use `withColor`. The label must
say the same ("Delayed"), because a color alone is not read by everyone.

    Option.option "late" "Delayed" |> Option.withTone Danger

-}
withTone : Tone -> Option id -> Option id
withTone tone opt =
    { opt | tone = Just tone, color = Nothing }


{-| A small dot in a color from your data before the label, in the list and in the
closed field. It is how a select over rows of a database shows each row's own color: build the option from the
row and give it the color of the row.

    Option.option status.id status.name
        |> (Color.hex status.color
                |> Maybe.map Option.withColor
                |> Maybe.withDefault identity
           )

The options may come from the server and change with every search; the color is part of the
option, so it arrives with it. A chosen value keeps its color as long as the select has its option.

-}
withColor : Color -> Option id -> Option id
withColor color opt =
    { opt | color = Just color, tone = Nothing }


{-| Extra words that also match the option, for example a synonym, an old name
or a code. They are searched but never shown. Calling it again adds to the
keywords.
-}
withKeywords : List String -> Option id -> Option id
withKeywords words opt =
    { opt | keywords = opt.keywords ++ words }


{-| Shows the option dimmed and keeps it from being chosen: it cannot be clicked,
highlighted or reached with the arrow keys. It is still searched and counted.
-}
disabledOption : Option id -> Option id
disabledOption opt =
    { opt | disabled = True }


{-| Gives the option another kind of value and keeps everything else (label,
description, group, icon, keywords, disabled). It is how an option over an
application's id type becomes an option over its text key.

    Option.option (CountryId "de") "Germany"
        |> Option.mapOption (\(CountryId code) -> code)
    -- an option over "de", still labelled "Germany"

-}
mapOption : (a -> b) -> Option a -> Option b
mapOption change opt =
    { value = change opt.value
    , label = opt.label
    , description = opt.description
    , group = opt.group
    , disabled = opt.disabled
    , icon = opt.icon
    , tone = opt.tone
    , color = opt.color
    , keywords = opt.keywords
    , meta = opt.meta
    }
