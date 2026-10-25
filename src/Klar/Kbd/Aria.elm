module Klar.Kbd.Aria exposing (keyShortcuts)

{-| The `aria-keyshortcuts` value of a shortcut, for the components that show a
shortcut next to the element it triggers (a menu item).

Not meant for application code.

-}

import Klar.Internal.Keys as Notation
import Klar.Shortcut as Shortcut exposing (Keys)


{-| The keys in the syntax of `aria-keyshortcuts`: the modifiers `Control` (or
`Meta`, the `mod` key on a Mac), `Alt` and `Shift`, then the key under the name
`KeyboardEvent.key` gives it (`Escape`, `ArrowUp`, `K`), joined with `+`.
`Nothing` for a sequence ("G then O"), which the attribute cannot say: a space in
its value separates two shortcuts, not two steps of one.
-}
keyShortcuts : { mac : Bool } -> Keys -> Maybe String
keyShortcuts platform keys =
    case Notation.words keys of
        [ words ] ->
            if List.isEmpty words then
                Nothing

            else
                Just (String.join "+" (List.map (ariaName platform) words))

        _ ->
            Nothing


ariaName : { mac : Bool } -> String -> String
ariaName platform word =
    case String.toLower word of
        "ctrl" ->
            if platform.mac then
                "Meta"

            else
                "Control"

        "alt" ->
            "Alt"

        "shift" ->
            "Shift"

        "esc" ->
            "Escape"

        "enter" ->
            "Enter"

        "space" ->
            "Space"

        "tab" ->
            "Tab"

        "↑" ->
            "ArrowUp"

        "↓" ->
            "ArrowDown"

        "←" ->
            "ArrowLeft"

        "→" ->
            "ArrowRight"

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

        "+" ->
            "Plus"

        _ ->
            if String.length word == 1 then
                String.toUpper word

            else
                word
