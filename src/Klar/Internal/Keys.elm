module Klar.Internal.Keys exposing
    ( Keys(..)
    , normalizeStep
    , steps
    , words
    )

{-| The keys of a shortcut, shared by [Klar.Shortcut](Klar-Shortcut) (which makes
and listens to them) and [Klar.Kbd](Klar-Kbd) (which draws them). `Shortcut.Keys`
is an alias of this type, so the application never sees the text inside.

The text is the notation of the keys: `"mod+k"`, `"g o"` (a sequence), `"shift+enter"`,
`"mod++"` (the plus key with Ctrl), always normalized by `normalizeStep`.

-}


{-| The keys, in the notation above.
-}
type Keys
    = Keys String


{-| `"g m"` -> `[ "g", "m" ]`; `"mod+k"` -> `[ "mod+k" ]`.
-}
steps : String -> List String
steps keys =
    keys
        |> String.words
        |> List.map normalizeStep


{-| One step with its modifiers in a fixed order (`mod`, `alt`, `shift`) and the
other names of the modifiers (`ctrl`, `cmd`, `option` ...) replaced.
-}
normalizeStep : String -> String
normalizeStep original =
    let
        step =
            String.toLower original

        parts =
            String.split "+" step
                |> List.filter (\part -> part /= "")
                |> List.map modifierName

        isModifier part =
            part == "mod" || part == "alt" || part == "shift"

        key =
            -- the plus key itself: "+", "mod++", "shift++"
            if step == "+" || String.endsWith "++" step then
                "+"

            else
                parts |> List.filter (not << isModifier) |> List.reverse |> List.head |> Maybe.withDefault ""

        has modifier =
            List.member modifier parts
    in
    String.concat
        [ if has "mod" then
            "mod+"

          else
            ""
        , if has "alt" then
            "alt+"

          else
            ""
        , if has "shift" then
            "shift+"

          else
            ""
        , key
        ]


{-| Other names for the modifiers: `ctrl` and `cmd` are `mod`, `option` is `alt`. A
modifier that is not known would otherwise be taken for the key and swallowed.
-}
modifierName : String -> String
modifierName part =
    case part of
        "ctrl" ->
            "mod"

        "control" ->
            "mod"

        "cmd" ->
            "mod"

        "command" ->
            "mod"

        "meta" ->
            "mod"

        "option" ->
            "alt"

        _ ->
            part


{-| The words of the keys, one list for each step of a sequence: the modifiers in
the order Ctrl, Alt, Shift and then the key. These are the words that
[Klar.Kbd](Klar-Kbd) turns into caps and spoken names, so this is the one table
of key names; nothing else draws them.

    words (Keys "mod+k") == [ [ "Ctrl", "K" ] ]

    words (Keys "g m") == [ [ "G" ], [ "M" ] ]

    words (Keys "pageup") == [ [ "PageUp" ] ]

-}
words : Keys -> List (List String)
words (Keys keys) =
    steps keys
        |> List.map (\step -> List.map capName (stepParts step))


{-| The modifiers and the key of a step, as `steps` normalizes it: `"mod+k"` is
`[ "mod", "k" ]`, `"mod++"` is `[ "mod", "+" ]` and `"+"` is `[ "+" ]`.
-}
stepParts : String -> List String
stepParts step =
    if step == "+" then
        [ "+" ]

    else if String.endsWith "++" step then
        (String.dropRight 2 step |> String.split "+" |> List.filter (\part -> part /= "")) ++ [ "+" ]

    else
        String.split "+" step |> List.filter (\part -> part /= "")


capName : String -> String
capName part =
    case part of
        "mod" ->
            "Ctrl"

        "alt" ->
            "Alt"

        "shift" ->
            "Shift"

        "esc" ->
            "Esc"

        "enter" ->
            "Enter"

        "space" ->
            "Space"

        "tab" ->
            "Tab"

        "backspace" ->
            "Backspace"

        "delete" ->
            "Delete"

        "home" ->
            "Home"

        "end" ->
            "End"

        "pageup" ->
            "PageUp"

        "pagedown" ->
            "PageDown"

        "up" ->
            "↑"

        "down" ->
            "↓"

        "left" ->
            "←"

        "right" ->
            "→"

        other ->
            String.toUpper other
