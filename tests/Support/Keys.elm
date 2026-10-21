module Support.Keys exposing (parse)

{-| Reads the notation `"mod+k"`, `"g o"`, `"shift+enter"`, `"mod++"` into `Shortcut.Keys`, so
that tests can describe many key combinations briefly. The library itself has no text
notation: it takes `Keys` built with `char`, the named keys, `mod`, `alt`, `shift` and
`sequence`, and this is a test helper written with exactly those.
-}

import Klar.Shortcut as Shortcut exposing (Keys)


parse : String -> Keys
parse text =
    Shortcut.sequence (List.map step (String.words (String.toLower text)))


step : String -> Keys
step text =
    let
        ( modifiers, key ) =
            split text
    in
    List.foldr applyModifier (named key) modifiers


split : String -> ( List String, String )
split text =
    if text == "+" then
        ( [], "+" )

    else if String.endsWith "++" text then
        ( String.dropRight 2 text |> String.split "+" |> List.filter (\part -> part /= ""), "+" )

    else
        case List.reverse (String.split "+" text |> List.filter (\part -> part /= "")) of
            last :: before ->
                ( List.reverse before, last )

            [] ->
                ( [], "" )


applyModifier : String -> Keys -> Keys
applyModifier modifier keys =
    case modifier of
        "alt" ->
            Shortcut.alt keys

        "option" ->
            Shortcut.alt keys

        "shift" ->
            Shortcut.shift keys

        _ ->
            -- mod, ctrl, control, cmd, command, meta
            Shortcut.mod keys


named : String -> Keys
named key =
    case key of
        "esc" ->
            Shortcut.escape

        "escape" ->
            Shortcut.escape

        "enter" ->
            Shortcut.enter

        "tab" ->
            Shortcut.tab

        "space" ->
            Shortcut.space

        "backspace" ->
            Shortcut.backspace

        "delete" ->
            Shortcut.delete

        "home" ->
            Shortcut.home

        "end" ->
            Shortcut.end

        "pageup" ->
            Shortcut.pageUp

        "pagedown" ->
            Shortcut.pageDown

        "up" ->
            Shortcut.up

        "down" ->
            Shortcut.down

        "left" ->
            Shortcut.left

        "right" ->
            Shortcut.right

        _ ->
            case ( String.uncons key, String.toInt (String.dropLeft 1 key) ) of
                ( Just ( 'f', _ ), Just n ) ->
                    Shortcut.function n

                ( Just ( c, "" ), _ ) ->
                    Shortcut.char c

                _ ->
                    Shortcut.sequence []
