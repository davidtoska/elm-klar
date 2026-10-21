module Klar.Menu.Scroll exposing
    ( Edge(..)
    , edge
    , reveal
    , scrollTop
    )

{-| Keeps the highlighted item of a menu in view.

A menu that is taller than its maximum height scrolls, and the keys move the
highlight through it: this module scrolls the list so that the highlighted item
can be seen. The items have different heights (an item, a separator, a heading),
so the item is measured in the page, not calculated from a row height.

Not meant for application code.

-}

import Browser.Dom as Dom
import Task


{-| How far to scroll for an item. The first and the last item that can be
picked show the edge of the list with them, so that the heading, the separator
or the disabled items next to them are seen too; any other item is brought into
view with as little scrolling as possible.
-}
type Edge
    = Nearest
    | Top
    | Bottom


{-| The edge for an item, given the indices of all the items that can be picked.
-}
edge : List Int -> Int -> Edge
edge enabled index =
    case ( List.head enabled, List.head (List.reverse enabled) ) of
        ( Just first, Just last ) ->
            if first == last then
                Nearest

            else if index == first then
                Top

            else if index == last then
                Bottom

            else
                Nearest

        _ ->
            Nearest


{-| Scroll the list (the element with the first id, which is the one that
scrolls) so that the item (the element with the second id) can be seen. The
message is sent when it is done, whether it worked or not.
-}
reveal : { list : String, item : String, edge : Edge } -> msg -> Cmd msg
reveal options done =
    (case options.edge of
        Top ->
            Dom.setViewportOf options.list 0 0

        Bottom ->
            Dom.getViewportOf options.list
                |> Task.andThen (\found -> Dom.setViewportOf options.list 0 found.scene.height)

        Nearest ->
            Task.map3
                (\box scroll item -> scrollTop { box = box, scroll = scroll, item = item })
                (Dom.getElement options.list)
                (Dom.getViewportOf options.list)
                (Dom.getElement options.item)
                |> Task.andThen (Dom.setViewportOf options.list 0)
    )
        |> Task.attempt (\_ -> done)


{-| The scroll position at which the item is fully in view, with as little
scrolling as possible: where it is now if the item can be seen already.

`box` is the list as the page measures it (its border box), `scroll` the part of
the list that scrolls, `item` the item. The border of the list is not measured
but worked out: what the border box has more in height than the part that
scrolls is the border, half at the top and half at the bottom.

-}
scrollTop : { box : Dom.Element, scroll : Dom.Viewport, item : Dom.Element } -> Float
scrollTop { box, scroll, item } =
    let
        border =
            max 0 ((box.element.height - scroll.viewport.height) / 2)

        seenTop =
            box.element.y + border

        seenBottom =
            seenTop + scroll.viewport.height

        itemTop =
            item.element.y

        itemBottom =
            itemTop + item.element.height

        wanted =
            if itemTop < seenTop then
                scroll.viewport.y - (seenTop - itemTop)

            else if itemBottom > seenBottom then
                scroll.viewport.y + (itemBottom - seenBottom)

            else
                scroll.viewport.y
    in
    clamp 0 (max 0 (scroll.scene.height - scroll.viewport.height)) wanted
