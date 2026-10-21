module Klar.Tooltip exposing
    ( attrs, attrsWith, withShortcut, placeBelow
    , wrap
    , Option, shortcut, below, focusable, id
    )

{-| Short hints that appear when the pointer rests on an element or the keyboard
focuses it. There is no state and there are no messages: it is all CSS.

Use a tooltip to explain an icon-only button, to show a keyboard shortcut or to
say why something is unavailable. Do not hide information the user needs in one.

    import Klar.Tooltip as Tooltip

    -- on any element that accepts attributes
    Button.iconOnly [ Button.htmlAttrs (Tooltip.attrs "Delete order") ] Icon.trash "Delete order"

    -- with the keyboard shortcut
    Button.iconOnly
        [ Button.htmlAttrs (Tooltip.attrs "Open search" |> Tooltip.withShortcut "Ctrl K") ]
        Icon.search
        "Search"

    -- around something you cannot put attributes on (a badge, a disabled
    -- button, a truncated text)
    Tooltip.wrap [] "A shipped order cannot be deleted" (Button.view [ Button.disabled True ] "Delete")

    Tooltip.wrap [ Tooltip.shortcut "Ctrl K" ] "Open search" child

There are two flavors. `attrs` adds a data attribute to the element and lets
the stylesheet draw the tip: plain text, with the shortcut after a middle dot.
`wrap` renders a real `role="tooltip"` element next to the content, linked with
`aria-describedby`, and draws the shortcut as key caps. A few rules of thumb:

  - A tooltip is a visual aid for sighted users. The element must have a name
    of its own (icon buttons get it from `aria-label`).
  - Do not combine it with a native `title`. `attrs` clears it.
  - `wrap` builds the id of the tip from its text and shortcuts, unless you give
    an `id`. Two wrapped tooltips on one page with the same text, the same
    shortcuts and no `id` therefore share an id: the page has a duplicate id, and
    the second wrapper is described by the first tip (which has the same words).
    Give each its own `id`, or use `attrs`, which needs no id.
  - The tip appears after a short delay on hover, and a shorter one on keyboard
    focus. It sits centered above the element and flips below it when there is
    no room, and it is kept inside the window at the left and right edges, so a
    table, a card or a dialog does not cut it off. Browsers without CSS anchor
    positioning show it centered above the element and do none of this.
  - `attrs` works on elements that can have pseudo-elements, which excludes
    `input`, `img` and similar. Use `wrap` for those.
  - There is no built-in text, so there is no `locale`.


# On an element

@docs attrs, attrsWith, withShortcut, placeBelow


# Around an element

@docs wrap


# Options

@docs Option, shortcut, below, focusable, id

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal
import Klar.Text as Text


{-| A setting for `attrsWith` and `wrap`. Make one with `shortcut`, `below`,
`focusable` or `id`.
-}
type Option
    = Shortcut String
    | Below
    | Focusable
    | Id String


{-| The keyboard shortcut to show next to the text: `shortcut "Ctrl K"`. Separate
the keys with a space or a `+`. With `attrs` it follows the text after a middle
dot ("Open search · Ctrl K"), with `wrap` it is drawn as key caps.
-}
shortcut : String -> Option
shortcut =
    Shortcut


{-| Show the tip below the element instead of above it (it still flips to the
other side when there is no room).
-}
below : Option
below =
    Below


{-| Lets the keyboard reach the element that carries the tip (`tabindex="0"`):
the wrapper for `wrap`, the element itself for `attrsWith`. Use it so that the
tip of a truncated text or a badge can be read without a pointer. Leave it out
for buttons and links, which can be focused already.
-}
focusable : Option
focusable =
    Focusable


{-| The DOM id of the tip that `wrap` draws; the wrapper refers to it with
`aria-describedby`. Without it the id is built from the text and the shortcuts,
so two tooltips with the same words on one page share an id: give each its own
when a page repeats a tip (on every row of a table, say), or use `attrs`, which
needs no id. `attrsWith` ignores it.

    Tooltip.wrap [ Tooltip.id ("delete-tip-" ++ order.id) ] "Delete order" deleteButton

-}
id : String -> Option
id =
    Id


{-| Attributes that give an element a tooltip with this text. Add them to the
attributes of the element, or hand them to a component that takes raw
attributes, such as `Button.htmlAttrs`.
-}
attrs : String -> List (Html.Attribute msg)
attrs text =
    attrsWith [] text


{-| Like `attrs`, with options.

    Tooltip.attrsWith [ Tooltip.below, Tooltip.shortcut "Ctrl K" ] "Open search"

-}
attrsWith : List Option -> String -> List (Html.Attribute msg)
attrsWith options text =
    [ Attr.attribute "data-tip" text
    , Attr.title ""
    ]
        ++ List.concatMap optionAttrs options


{-| Adds the keyboard shortcut to the attributes of `attrs`. It is shown after
the text and announced as `aria-keyshortcuts`, with the key names that ARIA
uses: `Ctrl` becomes `Control`, `Cmd` becomes `Meta`, `Option` becomes `Alt` and
`Esc` becomes `Escape`.

    Tooltip.attrs "Open search" |> Tooltip.withShortcut "Ctrl K"

-}
withShortcut : String -> List (Html.Attribute msg) -> List (Html.Attribute msg)
withShortcut keys list =
    list ++ optionAttrs (Shortcut keys)


{-| Shows the tip below the element, for the attributes of `attrs`.

    Tooltip.attrs "Sort by date" |> Tooltip.placeBelow

-}
placeBelow : List (Html.Attribute msg) -> List (Html.Attribute msg)
placeBelow list =
    list ++ optionAttrs Below


optionAttrs : Option -> List (Html.Attribute msg)
optionAttrs option =
    case option of
        Shortcut keys ->
            [ Attr.attribute "data-tip-key" ("· " ++ keys)
            , Attr.attribute "aria-keyshortcuts" (ariaShortcut keys)
            ]

        Below ->
            [ Attr.attribute "data-tip-below" "" ]

        Focusable ->
            [ Attr.tabindex 0 ]

        Id _ ->
            []


{-| The keys of a shortcut as written (`"Ctrl K"`, `"Cmd+Shift+P"`): split at
spaces and plus signs.
-}
keyNames : String -> List String
keyNames keys =
    keys
        |> String.words
        |> List.concatMap (String.split "+")
        |> List.filter (\part -> part /= "")


{-| A shortcut in the notation of `aria-keyshortcuts`: keys joined by `+`, the
modifiers called `Control`, `Meta`, `Alt` and `Shift`. `"Ctrl K"` becomes
`"Control+K"` and `"Cmd Esc"` becomes `"Meta+Escape"`.
-}
ariaShortcut : String -> String
ariaShortcut keys =
    keys
        |> keyNames
        |> List.map ariaKey
        |> String.join "+"


{-| One key under the name ARIA gives it: the modifiers `Control`, `Meta`,
`Alt` and `Shift`, then the names of `KeyboardEvent.key` (`Escape`, `Enter`,
`ArrowUp` ...), `Space` and `Plus` for the two keys that cannot stand for
themselves, and a single letter in upper case. The names people write for them
(`Ctrl`, `Cmd`, `Option`, `Esc`, `Return`, `Del`, `PgUp` and the Mac symbols)
are mapped; anything else is kept as it is.
-}
ariaKey : String -> String
ariaKey key =
    let
        lower =
            String.toLower key
    in
    case List.filter (\( names, _ ) -> List.member lower names) ariaKeyNames of
        ( _, name ) :: _ ->
            name

        [] ->
            if String.length key == 1 || isFunctionKey lower then
                String.toUpper key

            else
                key


{-| `f1` ... `f24`.
-}
isFunctionKey : String -> Bool
isFunctionKey lower =
    String.startsWith "f" lower
        && (String.length lower == 2 || String.length lower == 3)
        && String.all Char.isDigit (String.dropLeft 1 lower)


{-| The names people write for a key (in lower case) and the name that ARIA
gives it. The symbols are the Mac ones: control, command, option, shift, return,
tab, backspace and the arrows.
-}
ariaKeyNames : List ( List String, String )
ariaKeyNames =
    [ ( [ "ctrl", "control", "⌃" ], "Control" )
    , ( [ "cmd", "command", "meta", "win", "windows", "super", "⌘" ], "Meta" )
    , ( [ "alt", "option", "opt", "⌥" ], "Alt" )
    , ( [ "shift", "⇧" ], "Shift" )
    , ( [ "esc", "escape", "⎋" ], "Escape" )
    , ( [ "enter", "return", "↩", "↵", "⏎" ], "Enter" )
    , ( [ "tab", "⇥" ], "Tab" )
    , ( [ "space", "spacebar" ], "Space" )
    , ( [ "backspace", "⌫" ], "Backspace" )
    , ( [ "del", "delete", "⌦" ], "Delete" )
    , ( [ "ins", "insert" ], "Insert" )
    , ( [ "home" ], "Home" )
    , ( [ "end" ], "End" )
    , ( [ "pageup", "pgup" ], "PageUp" )
    , ( [ "pagedown", "pgdn" ], "PageDown" )
    , ( [ "up", "arrowup", "↑" ], "ArrowUp" )
    , ( [ "down", "arrowdown", "↓" ], "ArrowDown" )
    , ( [ "left", "arrowleft", "←" ], "ArrowLeft" )
    , ( [ "right", "arrowright", "→" ], "ArrowRight" )
    , ( [ "plus" ], "Plus" )
    ]


{-| A small, stable number for a text (no two different texts are likely to get
the same one).
-}
textHash : String -> Int
textHash text =
    String.foldl (\char hash -> modBy 2147483629 (hash * 31 + Char.toCode char)) 7 text


{-| Wraps an element in a tooltip, for things that cannot take the attributes of
`attrs`. The wrapper is an inline box around the content; the tip is a real
element with `role="tooltip"`, which the wrapper refers to with
`aria-describedby`. Two wrapped tooltips with the same text and shortcuts on one
page need different `id`s.

    Tooltip.wrap [ Tooltip.below ] "Only warehouse staff can do this" (Badge.view [] "Locked")

-}
wrap : List Option -> String -> Html msg -> Html msg
wrap options text child =
    let
        keys =
            List.filterMap
                (\option ->
                    case option of
                        Shortcut value ->
                            Just value

                        _ ->
                            Nothing
                )
                options

        explicitId =
            List.foldl
                (\option found ->
                    case option of
                        Id value ->
                            Just value

                        _ ->
                            found
                )
                Nothing
                options

        -- Without an `id` option the text and the shortcuts decide the id, so two
        -- tips that start alike (a long sentence with a different end) must not
        -- share one: a hash of the whole follows the readable start of the text.
        -- A page that repeats a tip cannot get distinct ids from a pure function
        -- (it does not know where the element ends up), hence the `id` option.
        tipId =
            case explicitId of
                Just value ->
                    value

                Nothing ->
                    "klar-tip-"
                        ++ Internal.sanitizeId (String.left 24 (String.toLower text))
                        ++ "-"
                        ++ String.fromInt (textHash (String.join "\n" (text :: keys)))

        isBelow =
            List.member Below options

        isFocusable =
            List.member Focusable options
    in
    Html.span
        [ Internal.cls [ "klar-tip-wrap" ]
        , Attr.attribute "aria-describedby" tipId
        , Internal.attrIf isBelow (Attr.attribute "data-tip-below" "")
        , Internal.attrIf isFocusable (Attr.tabindex 0)
        ]
        [ child
        , Html.span
            [ Internal.cls [ "klar-tip-bubble" ]
            , Attr.id tipId
            , Attr.attribute "role" "tooltip"
            ]
            (Html.text text
                :: List.map
                    (\value ->
                        Html.span [ Internal.cls [ "klar-tip-bubble__keys" ] ]
                            [ Text.kbdCombo (keyNames value) ]
                    )
                    keys
            )
        ]
