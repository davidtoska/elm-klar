module Klar.Table.Popup exposing (..)

{-| Table popup markup and decoding of focus and clicks outside it.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Internal as Internal
import Klar.Table.DomIds exposing (bulkDomId, detailDomId, filterInputId, popupDomId, popupSuffix, rowDomId, scrollDomId, triggerDomId)
import Klar.Table.Types exposing (Align(..), Attribute(..), Column(..), ColumnAttribute(..), ColumnConfig, ColumnId(..), Config, Ctx, Data, DataStatus(..), Direction(..), Draft(..), Filter(..), FilterKind(..), Footer(..), Model, MoneyTotal, Msg(..), Picked(..), Popup(..), Query, RowInfo, Rows(..), Selection(..), SortBy(..), Source(..), State(..))


{-| The popup recipe: a click-away layer, Escape closes and gives focus back
to the trigger, focus leaving the popup (Tab) closes it.
-}
viewPopup : Ctx row msg -> Popup -> { title : String, alignEnd : Bool } -> List (Html msg) -> Html msg
viewPopup ctx popup options content =
    let
        popupId =
            popupDomId ctx.model.id popup
    in
    Html.div
        [ Internal.cls [ "klar-layer" ]

        -- Clicks inside the popup are ignored here instead of being stopped in
        -- the popup: a handler that stops propagation makes Elm render in the
        -- middle of the click, which resets checkboxes before their change
        -- event fires.
        , Events.on "click" (outsideClick popupId (ctx.toMsg PopupClosed))

        -- Escape closes the popup and is used up, so that a dialog around the table stays open
        , Internal.onKeys [ ( "Escape", ctx.toMsg PopupClosed ) ]
        ]
        [ Html.div
            [ Internal.cls
                [ "klar-popup"
                , "klar-table__popover"
                , if options.alignEnd then
                    "klar-popup--end"

                  else
                    ""
                ]
            , Attr.id popupId
            , Attr.tabindex -1
            , Attr.attribute "role" "dialog"
            , Attr.attribute "aria-label" options.title
            , Events.on "focusout" (focusLeft popupId (ctx.toMsg PopupLeft))
            ]
            (Html.div [ Internal.cls [ "klar-table__popover-title" ] ] [ Html.text options.title ] :: content)
        ]


{-| Fires when focus moves to an element outside the popup (Tab, Shift+Tab).
Focus moving inside, or to nothing (the window lost focus), is ignored.
-}
focusLeft : String -> msg -> Decoder msg
focusLeft popupId msg =
    Decode.field "relatedTarget" (Decode.nullable (isInside popupId 0))
        |> Decode.andThen
            (\inside ->
                case inside of
                    Just False ->
                        Decode.succeed msg

                    _ ->
                        Decode.fail "focus stayed inside"
            )


{-| A click on the click-away layer itself, not one that started inside the
popup.
-}
outsideClick : String -> msg -> Decoder msg
outsideClick popupId msg =
    Decode.field "target" (isInside popupId 0)
        |> Decode.andThen
            (\inside ->
                if inside then
                    Decode.fail "click inside the popup"

                else
                    Decode.succeed msg
            )


isInside : String -> Int -> Decoder Bool
isInside targetId depth =
    Decode.oneOf [ Decode.field "id" Decode.string, Decode.succeed "" ]
        |> Decode.andThen
            (\elementId ->
                if elementId == targetId then
                    Decode.succeed True

                else if depth > 40 then
                    Decode.succeed False

                else
                    Decode.oneOf
                        [ Decode.field "parentElement" (Decode.null False)
                        , Decode.field "parentElement" (Decode.lazy (\_ -> isInside targetId (depth + 1)))
                        , Decode.succeed False
                        ]
            )
