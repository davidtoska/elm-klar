module Klar.Table.Keyboard exposing (..)

{-| Row keyboard, range selection and control-target event decoders.
-}

import Json.Decode as Decode exposing (Decoder)
import Klar.Internal.Window as Window
import Klar.Table.DomIds exposing (rowDomId)
import Klar.Table.Identity exposing (isJust, keysBetween)
import Klar.Table.Selection exposing (isLongClientTable, selectableKeys)
import Klar.Table.Types exposing (Ctx, Msg(..), RowInfo)


{-| The keys a Shift range runs over, in the order of the table: the rows of the
page that can be selected, or every matching one in a client table that scrolls.
Only asked for when the user makes a range.
-}
rangeKeys : Ctx row msg -> List String
rangeKeys ctx =
    if isLongClientTable ctx then
        selectableKeys ctx

    else
        ctx.pageKeys


{-| The message of a Shift range that ends on this row, which gets the state the
row is about to get (`checked`), as in a mail client; `Nothing` without an anchor
on this page.
-}
rangeMsg : Ctx row msg -> String -> Bool -> Maybe msg
rangeMsg ctx key checked =
    ctx.model.anchor
        |> Maybe.andThen (\anchorKey -> keysBetween anchorKey key (rangeKeys ctx))
        |> Maybe.map (\keys -> ctx.toMsg (RangeSelected keys checked key))


{-| Keys on a focused row, and the keys that move between rows on its checkbox
and its menu button.
-}
rowKeys : Ctx row msg -> RowInfo msg -> Decoder ( msg, Bool )
rowKeys ctx info =
    Decode.map5 (\key targetId command alt shift -> { key = key, targetId = targetId, command = command, alt = alt, shift = shift })
        (Decode.field "key" Decode.string)
        (Decode.oneOf [ Decode.at [ "target", "id" ] Decode.string, Decode.succeed "" ])
        (Decode.map2 (||)
            (Decode.field "ctrlKey" Decode.bool)
            (Decode.field "metaKey" Decode.bool)
        )
        (Decode.field "altKey" Decode.bool)
        (Decode.field "shiftKey" Decode.bool)
        |> Decode.andThen
            (\event ->
                if event.targetId /= info.domId then
                    -- On the row's checkbox or menu button the keys that move to other
                    -- rows still work, unless the control used the key itself (the
                    -- menu button opens its menu with ArrowDown).
                    if List.member event.key [ "ArrowDown", "ArrowUp", "Home", "End", "PageDown", "PageUp" ] && not event.command && not event.alt then
                        Decode.map2 Tuple.pair
                            (Decode.oneOf [ Decode.at [ "target", "type" ] Decode.string, Decode.succeed "" ])
                            (Decode.oneOf [ Decode.field "defaultPrevented" Decode.bool, Decode.succeed False ])
                            |> Decode.andThen
                                (\( targetType, prevented ) ->
                                    if not prevented && (targetType == "checkbox" || event.targetId == info.menuTrigger) then
                                        case rowKeyMsg ctx info event.key event.shift of
                                            Just msg ->
                                                Decode.succeed ( msg, True )

                                            Nothing ->
                                                Decode.fail "unhandled key"

                                    else
                                        Decode.fail "not on a control of the row"
                                )

                    else
                        Decode.fail "not on the row"

                else if event.command && not event.alt && String.toLower event.key == "a" && ctx.hasSelect then
                    -- Ctrl+A (Cmd+A): every row of the page, or every matching row of a table that scrolls
                    Decode.succeed ( ctx.toMsg (RowsSelected (rangeKeys ctx) True), True )

                else if event.command || event.alt then
                    Decode.fail "a key with Ctrl, Cmd or Alt"

                else
                    case rowKeyMsg ctx info event.key event.shift of
                        Just msg ->
                            Decode.succeed ( msg, True )

                        Nothing ->
                            Decode.fail "unhandled key"
            )


{-| The menu key and Shift+F10 can also arrive as a `contextmenu` event, which
the browser answers with its own menu unless the page does something with it.
That event has `button` 0 when it comes from the keyboard (or a long press) and
2 from a right click, which keeps the browser's menu.
-}
rowContextMenu : RowInfo msg -> Decoder ( msg, Bool )
rowContextMenu info =
    Decode.field "button" Decode.int
        |> Decode.andThen
            (\button ->
                case ( button, info.menu ) of
                    ( 0, Just msg ) ->
                        Decode.succeed ( msg, True )

                    _ ->
                        Decode.fail "a right click, or a row without a menu"
            )


rowKeyMsg : Ctx row msg -> RowInfo msg -> String -> Bool -> Maybe msg
rowKeyMsg ctx info key shift =
    let
        focusRow target =
            if target >= 0 && target < ctx.rowCount && target /= info.index then
                if ctx.config.virtual then
                    Just (ctx.toMsg (FocusVirtualRow target (rowDomId ctx.model.id target) ctx.geometry))

                else
                    Just (ctx.toMsg (FocusRow target (rowDomId ctx.model.id target)))

            else
                Just (ctx.toMsg NoOp)

        -- ten rows at a time, or a screenful when the table scrolls; otherwise the
        -- page scrolls away from the focused row
        jump =
            if ctx.config.virtual then
                Window.rowsPerScreen ctx.geometry

            else
                10
    in
    case key of
        "ArrowDown" ->
            focusRow (info.index + 1)

        "ArrowUp" ->
            focusRow (info.index - 1)

        "Home" ->
            focusRow 0

        "End" ->
            focusRow (ctx.rowCount - 1)

        "PageDown" ->
            focusRow (min (ctx.rowCount - 1) (info.index + jump))

        "PageUp" ->
            focusRow (max 0 (info.index - jump))

        "Enter" ->
            case info.click of
                Just msg ->
                    Just msg

                Nothing ->
                    -- a row that does nothing else when clicked opens its menu
                    if isJust ctx.config.onRowClick || ctx.hasExpand then
                        Nothing

                    else
                        info.menu

        -- the context menu key and Shift+F10: the row's "more" menu
        "ContextMenu" ->
            info.menu

        "F10" ->
            if shift then
                info.menu

            else
                Nothing

        " " ->
            if ctx.hasSelect && not info.disabled then
                -- Shift+Space: the rows from the anchor to this one
                case
                    if shift then
                        rangeMsg ctx info.key (not info.selected)

                    else
                        Nothing
                of
                    Just msg ->
                        Just msg

                    Nothing ->
                        Just (ctx.toMsg (RowSelected info.key (not info.selected)))

            else
                Nothing

        "ArrowRight" ->
            if ctx.hasExpand && not info.expanded && not info.disabled then
                Just (ctx.toMsg (ExpandToggled info.key))

            else
                Nothing

        "ArrowLeft" ->
            if ctx.hasExpand && info.expanded && not info.disabled then
                Just (ctx.toMsg (ExpandToggled info.key))

            else
                Nothing

        _ ->
            Nothing


{-| A row click, unless it started on a control inside the row (a button, a
link, a checkbox, a menu, an inline action).
-}
ignoreControls : msg -> Decoder msg
ignoreControls msg =
    Decode.field "target" (startsOnControl 0)
        |> Decode.andThen
            (\onControl ->
                if onControl then
                    Decode.fail "click on a control"

                else
                    Decode.succeed msg
            )


startsOnControl : Int -> Decoder Bool
startsOnControl depth =
    Decode.map2 Tuple.pair
        (Decode.oneOf [ Decode.field "tagName" Decode.string, Decode.succeed "" ])
        (Decode.oneOf [ Decode.field "className" Decode.string, Decode.succeed "" ])
        |> Decode.andThen
            (\( tag, className ) ->
                if tag == "" || tag == "TR" || tag == "TABLE" || depth > 20 then
                    Decode.succeed False

                else if
                    List.member tag [ "A", "BUTTON", "INPUT", "SELECT", "TEXTAREA", "LABEL", "SUMMARY" ]
                        || String.contains "klar-anchor" className
                        || String.contains "klar-layer" className
                        || String.contains "klar-table__td--control" className
                then
                    Decode.succeed True

                else
                    Decode.oneOf
                        [ Decode.field "parentElement" (Decode.lazy (\_ -> startsOnControl (depth + 1)))
                        , Decode.succeed False
                        ]
            )
