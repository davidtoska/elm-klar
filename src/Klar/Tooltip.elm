module Klar.Tooltip exposing
    ( attrs
    , wrap
    , Option, shortcut, platform, below, focusable, id
    )

{-| Short hints that appear when the pointer rests on an element or the keyboard
focuses it. There is no state and there are no messages: it is all CSS.

Use when: an icon-only button, a keyboard shortcut or an unavailable control needs a short hint on hover or focus.
Do not use when: the user needs the information to proceed (put it in the page, or use `Klar.Popover` for richer content).

    import Klar.Button as Button
    import Klar.Shortcut as Shortcut
    import Klar.Tooltip as Tooltip

    -- on any element that takes attributes
    Button.iconOnly [ Button.htmlAttrs (Tooltip.attrs [] "Delete order") ] Icon.trash "Delete order"

    -- with the keyboard shortcut, the same `Shortcut.Keys` that Klar.Shortcut listens to
    Button.iconOnly
        [ Button.htmlAttrs (Tooltip.attrs [ Tooltip.shortcut (Shortcut.mod (Shortcut.char 'k')) ] "Open search") ]
        Icon.search
        "Search"

    -- a control that is unavailable stays focusable (ariaDisabled, never
    -- disabled), so that the keyboard reaches it and hears why
    Button.view
        [ Button.ariaDisabled True
        , Button.htmlAttrs (Tooltip.attrs [] "A shipped order cannot be deleted")
        ]
        "Delete"

    -- a real tooltip element, linked to the control the function draws
    Tooltip.wrap [ Tooltip.id "delete-tip" ]
        "A shipped order cannot be deleted"
        (\tip -> Button.view [ Button.ariaDisabled True, Button.htmlAttrs tip ] "Delete")

There are two flavors. `attrs` adds a data attribute to the element and lets the
stylesheet draw the tip: plain text, with the shortcut after a middle dot. `wrap`
renders a real `role="tooltip"` element next to the content, which the control
refers to with `aria-describedby`, and draws the shortcut as key caps. A few rules
of thumb:

  - A tooltip is a visual aid for sighted users. The element must have a name
    of its own (icon buttons get it from `aria-label`). `wrap` also gives screen
    readers the text, as the description of the control.
  - Do not combine it with a native `title`. `attrs` clears it.
  - `wrap` needs an id for its tip. Without the `id` option it is built from the
    text and the shortcut, so two wrapped tips on one page with the same words
    share an id: give each its own `id` when a page repeats a tip (on every row
    of a table, say), or use `attrs`, which needs no id.
  - The tip appears after a short delay on hover, and a shorter one on keyboard
    focus. It sits centered above the element and flips below it when there is
    no room, and it is kept inside the window at the left and right edges, so a
    table, a card or a dialog does not cut it off. Browsers without CSS anchor
    positioning show it centered above the element and do none of this. On a
    touch screen it shows on focus only.
  - `attrs` works on elements that can have pseudo-elements, which excludes
    `input`, `img` and similar. Use `wrap` for those.
  - `Escape` does not hide a tip: moving the pointer away or the focus on does.
  - There is no built-in text, so there is no `locale`.


# On an element

@docs attrs


# Around an element

@docs wrap


# Options

@docs Option, shortcut, platform, below, focusable, id

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal
import Klar.Kbd as Kbd
import Klar.Shortcut as Shortcut


{-| A setting for `attrs` and `wrap`. Make one with `shortcut`, `platform`,
`below`, `focusable` or `id`.
-}
type Option
    = ShortcutKeys Shortcut.Keys
    | OnPlatform Kbd.Platform
    | Below
    | Focusable
    | Id String


{-| The keyboard shortcut to show next to the text: the same
[`Shortcut.Keys`](Klar-Shortcut#Keys) that [Klar.Shortcut](Klar-Shortcut) listens
to, so the hint cannot drift from the binding. With `attrs` it follows the text
after a middle dot ("Open search · Ctrl+K"), with `wrap` it is drawn as key caps.
It is announced as `aria-keyshortcuts`, in the key names of ARIA (`Control+K`);
a sequence of keys (`G` then `O`) is shown but not announced, since ARIA has no
words for one.

    Tooltip.shortcut (Shortcut.mod (Shortcut.char 'k'))

-}
shortcut : Shortcut.Keys -> Option
shortcut =
    ShortcutKeys


{-| Which keyboard to write the shortcut for: [`Kbd.pc`](Klar-Kbd#pc), the
default (Ctrl, Alt, Shift), or [`Kbd.mac`](Klar-Kbd#mac) (⌘, ⌥, ⇧, and `mod` is
Cmd). Pass the same platform you give [Klar.Kbd](Klar-Kbd).
-}
platform : Kbd.Platform -> Option
platform =
    OnPlatform


{-| Show the tip below the element instead of above it (it still flips to the
other side when there is no room).
-}
below : Option
below =
    Below


{-| Lets the keyboard reach the element that carries the tip (`tabindex="0"`):
the element itself for `attrs`, the wrapper for `wrap` (which then carries the
`aria-describedby` too, and hands the function no attributes). Use it for content
that cannot take focus: a truncated text, a badge, a disabled link. Leave it out
for buttons and links, which can be focused already.
-}
focusable : Option
focusable =
    Focusable


{-| The DOM id of the tip that `wrap` draws; the control refers to it with
`aria-describedby`. Without it the id is built from the text and the shortcut, so
two tooltips with the same words on one page share an id: give each its own when a
page repeats a tip (on every row of a table, say), or use `attrs`, which needs no
id. `attrs` ignores it.

    Tooltip.wrap [ Tooltip.id ("delete-tip-" ++ order.id) ] "Delete order" deleteButton

-}
id : String -> Option
id =
    Id


{-| Attributes that give an element a tooltip with this text. Add them to the
attributes of the element, or hand them to a component that takes raw
attributes, such as `Button.htmlAttrs`.

    Tooltip.attrs [] "Sort by date"

    Tooltip.attrs [ Tooltip.below, Tooltip.shortcut (Shortcut.mod (Shortcut.char 'k')) ] "Open search"

-}
attrs : List Option -> String -> List (Html.Attribute msg)
attrs options text =
    let
        settings =
            settle options
    in
    [ Attr.attribute "data-tip" text
    , Attr.title ""
    , Internal.attrIf settings.below (Attr.attribute "data-tip-below" "")
    , Internal.attrIf settings.focusable (Attr.tabindex 0)
    ]
        ++ (case settings.keys of
                Just keys ->
                    [ Attr.attribute "data-tip-key" ("· " ++ Kbd.toString [ Kbd.platform settings.platform ] keys)
                    , ariaKeys settings.platform keys
                    ]

                Nothing ->
                    []
           )


type alias Settings =
    { keys : Maybe Shortcut.Keys
    , platform : Kbd.Platform
    , below : Bool
    , focusable : Bool
    , id : Maybe String
    }


{-| The options, the last of a kind winning.
-}
settle : List Option -> Settings
settle options =
    List.foldl
        (\option settings ->
            case option of
                ShortcutKeys keys ->
                    { settings | keys = Just keys }

                OnPlatform value ->
                    { settings | platform = value }

                Below ->
                    { settings | below = True }

                Focusable ->
                    { settings | focusable = True }

                Id value ->
                    { settings | id = Just value }
        )
        { keys = Nothing, platform = Kbd.pc, below = False, focusable = False, id = Nothing }
        options


{-| `aria-keyshortcuts` for one combination; nothing for a sequence, which ARIA
cannot express.
-}
ariaKeys : Kbd.Platform -> Shortcut.Keys -> Html.Attribute msg
ariaKeys which keys =
    case Shortcut.keycaps keys of
        [ step ] ->
            Attr.attribute "aria-keyshortcuts"
                (step
                    |> List.map
                        (\cap ->
                            -- `mod` is written Ctrl; on a Mac it is the Command key
                            if cap == "Ctrl" && which == Kbd.mac then
                                "Meta"

                            else
                                ariaKey cap
                        )
                    |> String.join "+"
                )

        _ ->
            Internal.noAttr


{-| One key under the name ARIA gives it: the modifiers `Control`, `Meta`,
`Alt` and `Shift`, then the names of `KeyboardEvent.key` (`Escape`, `Enter`,
`ArrowUp` ...), `Space` and `Plus` for the two keys that cannot stand for
themselves, and a single letter in upper case. The names the key caps use
(`Ctrl`, `Esc`, the arrows) are mapped; anything else is kept as it is.
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


{-| The names of a key (in lower case) and the name that ARIA gives it.
-}
ariaKeyNames : List ( List String, String )
ariaKeyNames =
    [ ( [ "ctrl", "control" ], "Control" )
    , ( [ "cmd", "command", "meta" ], "Meta" )
    , ( [ "alt", "option" ], "Alt" )
    , ( [ "shift" ], "Shift" )
    , ( [ "esc", "escape" ], "Escape" )
    , ( [ "enter", "return" ], "Enter" )
    , ( [ "tab" ], "Tab" )
    , ( [ "space" ], "Space" )
    , ( [ "backspace" ], "Backspace" )
    , ( [ "del", "delete" ], "Delete" )
    , ( [ "home" ], "Home" )
    , ( [ "end" ], "End" )
    , ( [ "pageup" ], "PageUp" )
    , ( [ "pagedown" ], "PageDown" )
    , ( [ "↑" ], "ArrowUp" )
    , ( [ "↓" ], "ArrowDown" )
    , ( [ "←" ], "ArrowLeft" )
    , ( [ "→" ], "ArrowRight" )
    , ( [ "+" ], "Plus" )
    ]


{-| A small, stable number for a text (no two different texts are likely to get
the same one).
-}
textHash : String -> Int
textHash text =
    String.foldl (\char hash -> modBy 2147483629 (hash * 31 + Char.toCode char)) 7 text


{-| A tooltip as a real element (`role="tooltip"`) next to a control. The function
draws the control and receives the attributes to put on it: the `aria-describedby`
that links it to the tip, so that a screen reader reads the tip as the description
of the control when it gets focus. Hand them to `Button.htmlAttrs`, or put them on
your own element.

    Tooltip.wrap [ Tooltip.below, Tooltip.id "pin-tip" ]
        "Pin to the top"
        (\tip -> Button.iconOnly [ Button.htmlAttrs tip ] Icon.bookmark "Pin")

For content that cannot take focus (a badge, a truncated text, a disabled link),
add `focusable`: the wrapper becomes the tab stop and carries the
`aria-describedby` itself, and the function receives no attributes.

    Tooltip.wrap [ Tooltip.focusable ] "Only warehouse staff can do this" (\_ -> Badge.view [] "Locked")

-}
wrap : List Option -> String -> (List (Html.Attribute msg) -> Html msg) -> Html msg
wrap options text child =
    let
        settings =
            settle options

        -- Without an `id` option the text and the shortcut decide the id, so two
        -- tips that start alike (a long sentence with a different end) must not
        -- share one: a hash of the whole follows the readable start of the text.
        -- A page that repeats a tip cannot get distinct ids from a pure function
        -- (it does not know where the element ends up), hence the `id` option.
        tipId =
            case settings.id of
                Just value ->
                    value

                Nothing ->
                    "klar-tip-"
                        ++ Internal.sanitizeId (String.left 24 (String.toLower text))
                        ++ "-"
                        ++ String.fromInt
                            (textHash
                                (String.join "\n"
                                    (text :: List.map (Kbd.toString [ Kbd.platform settings.platform ]) (List.filterMap identity [ settings.keys ]))
                                )
                            )

        describedBy =
            Attr.attribute "aria-describedby" tipId
    in
    Html.span
        [ Internal.cls [ "klar-tip-wrap" ]
        , Internal.attrIf settings.below (Attr.attribute "data-tip-below" "")
        , Internal.attrIf settings.focusable (Attr.tabindex 0)
        , Internal.attrIf settings.focusable describedBy
        ]
        [ child
            (if settings.focusable then
                []

             else
                [ describedBy ]
            )
        , Html.span
            [ Internal.cls [ "klar-tip-bubble" ]
            , Attr.id tipId
            , Attr.attribute "role" "tooltip"
            ]
            (Html.text text
                :: (case settings.keys of
                        Just keys ->
                            [ Html.span [ Internal.cls [ "klar-tip-bubble__keys" ] ]
                                [ Kbd.view [ Kbd.small, Kbd.platform settings.platform ] keys ]
                            ]

                        Nothing ->
                            []
                   )
            )
        ]
