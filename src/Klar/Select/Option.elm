module Klar.Select.Option exposing
    ( Option
    , option, withDescription, withGroup, withIcon, withKeywords, disabledOption, mapOption
    )

{-| The option model shared by [Klar.Select](Klar-Select),
[Klar.MultiSelect](Klar-MultiSelect) and [Klar.Autocomplete](Klar-Autocomplete).

Most applications do not import this module. `Klar.Select` re-exports `Option`,
`option` and the `with*` helpers, and the other two components take the same
`Option` values. Import it when you build options in a module that has no select
of its own (a data module, a simulated backend).

    import Klar.Select.Option as Option

    suppliers : List (Option.Option String)
    suppliers =
        [ Option.option "acme" "Acme Supplies"
            |> Option.withDescription "Berlin"
            |> Option.withGroup "Preferred"
        , Option.option "globex" "Globex"
            |> Option.withKeywords [ "Globex Corporation" ]
        , Option.option "initech" "Initech"
            |> Option.disabledOption
        ]

The value of an option is of whatever type you choose: a `String`, an `Int`, an id
type of your own. To search a list of options the way a select does, use
`Klar.Select.filter`.


# Options

@docs Option
@docs option, withDescription, withGroup, withIcon, withKeywords, disabledOption, mapOption

-}

import Klar.Icon exposing (Icon)


{-| One choice in a list. It is plain data: make it with `option` and the
`with*` functions, or write the record yourself.

  - `value` is what the application stores: its own id type (a `CustomerId`, a code, an `Int`).
    Values are compared with `==`, so use data, not functions, and keep it unique within one list
  - `label` is what the user sees and searches
  - `description` is a short secondary text, shown dimmed after the label and searched too
  - `group` lists the option under a heading, together with the options of the same group
  - `disabled` shows the option dimmed and keeps it from being chosen
  - `icon` is drawn before the label
  - `keywords` are extra words that also match but are never shown (synonyms, codes, old names)

-}
type alias Option id =
    { value : id
    , label : String
    , description : Maybe String
    , group : Maybe String
    , disabled : Bool
    , icon : Maybe Icon
    , keywords : List String
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
    , keywords = []
    }


{-| A short secondary text, shown dimmed after the label and in the tooltip of
the option. It is searched too, but a match in the description ranks below the
same match in the label.
-}
withDescription : String -> Option id -> Option id
withDescription text opt =
    { opt | description = Just text }


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
    , keywords = opt.keywords
    }
