module Klar.Overlay.Focus exposing
    ( unhandled, escape
    , insidePopup, isInside
    , guard, Guard(..), lostDecoder
    )

{-| What the overlays (`Modal`, `Drawer`, `ConfirmDialog`, `Popover`, `Toast`) share
about keys and keyboard focus. Not exposed: the components use it, the application
never sees it.


# Keys

Keys are layered (the decision of the whole library): a control that handles a key
prevents its default, and an overlay around it ignores a key event whose
`defaultPrevented` is true. The `Enter` or `Escape` that ends an IME composition is
never acted on.

@docs unhandled, escape


# Where an element is

@docs insidePopup, isInside


# Lost focus

@docs guard, Guard, lostDecoder

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Klar.Internal as Internal


{-| Succeeds for a key event that nothing handled yet. It fails when an inner
control prevented the default (it handled the key itself: a field that cleared its
text, a popup that closed), and while an IME composition runs (`isComposing`, or
`keyCode` 229): that `Enter` or `Escape` belongs to the composition.
-}
unhandled : Decoder ()
unhandled =
    Decode.map3
        (\prevented composing code -> not prevented && not composing && code /= 229)
        (optionalBool "defaultPrevented")
        (optionalBool "isComposing")
        (Decode.oneOf [ Decode.field "keyCode" Decode.int, Decode.succeed 0 ])
        |> Decode.andThen
            (\free ->
                if free then
                    Decode.succeed ()

                else
                    Decode.fail "handled already, or part of a composition"
            )


optionalBool : String -> Decoder Bool
optionalBool name =
    Decode.oneOf [ Decode.field name Decode.bool, Decode.succeed False ]


{-| `Escape` pressed inside the element with this id, that nothing handled yet (see
`unhandled`) and that was not pressed in a popup open inside it (a select, a menu:
that popup closes itself). Sends the message and prevents the default, so that the
layers around (a dialog under a popover, a global shortcut) leave it alone.
-}
escape : String -> msg -> Decoder ( msg, Bool )
escape ownerId msg =
    unhandled
        |> Decode.andThen (\_ -> Decode.field "key" Decode.string)
        |> Decode.andThen
            (\key ->
                if key /= "Escape" then
                    Decode.fail "not Escape"

                else
                    Decode.field "target" (insidePopup ownerId)
                        |> Decode.andThen
                            (\nested ->
                                if nested then
                                    Decode.fail "handled by a popup"

                                else
                                    Decode.succeed ( msg, True )
                            )
            )


{-| Walk up from a node to the element with this id: `True` if a popup layer
(`.klar-layer` or `.klar-popup`) lies on the way.
-}
insidePopup : String -> Decoder Bool
insidePopup ownerId =
    climb ownerId 0


climb : String -> Int -> Decoder Bool
climb ownerId depth =
    if depth > 60 then
        Decode.succeed False

    else
        Decode.oneOf
            [ Decode.field "id" Decode.string
                |> Decode.andThen
                    (\id ->
                        if id == ownerId then
                            Decode.succeed False

                        else
                            Decode.fail "keep climbing"
                    )
            , Decode.field "className" Decode.string
                |> Decode.andThen
                    (\names ->
                        let
                            tokens =
                                String.words names
                        in
                        if List.member "klar-layer" tokens || List.member "klar-popup" tokens then
                            Decode.succeed True

                        else
                            Decode.fail "keep climbing"
                    )
            , Decode.field "parentElement" (Decode.lazy (\_ -> climb ownerId (depth + 1)))
            , Decode.succeed False
            ]


{-| Is the node, or one of its ancestors, the element with this id?
-}
isInside : String -> Decoder Bool
isInside ownerId =
    inside ownerId 0


inside : String -> Int -> Decoder Bool
inside ownerId depth =
    if depth > 60 then
        Decode.succeed False

    else
        Decode.oneOf
            [ Decode.field "id" Decode.string
                |> Decode.andThen
                    (\id ->
                        if id == ownerId then
                            Decode.succeed True

                        else
                            Decode.fail "keep climbing"
                    )
            , Decode.field "parentElement" (Decode.lazy (\_ -> inside ownerId (depth + 1)))
            , Decode.succeed False
            ]


{-| What a guard watches for.

  - `Modal`: no overlay holds focus. A modal dialog takes focus back whatever has it,
    since nothing outside it may.
  - `Idle`: no overlay holds focus and nothing else does either (focus fell to the
    body). A popover or the toast stack only picks up focus that was dropped, never
    focus that the user or the application moved to the page.

-}
type Guard
    = Modal
    | Idle


{-| An invisible element that tells its surface when focus is lost. The stylesheet
runs the animation `klar-focus-lost` on it while no part of any overlay contains
focus (the element that had it was removed or disabled, and the page fell back to
the body). That start is the only signal pure Elm can get: browsers send no event
when a focused element disappears. The animation waits a few frames before it
starts, so a dialog that just opened, and moves focus into itself in the next frame,
is not taken for one that lost it.

The stylesheet (`Klar.Internal.Css.Overlay`) names the surfaces that hold focus
(`.klar-modal__dialog`, `.klar-popover__popup`, `.klar-toasts`, the palette), and
the guard must be a direct child of one of the first three.

-}
guard : Guard -> msg -> Html msg
guard kind lost =
    Html.span
        [ Internal.cls [ "klar-modal__guard" ]
        , Attr.attribute "aria-hidden" "true"
        , Events.on "animationstart" (lostDecoder kind lost)
        ]
        []


{-| The `animationstart` of a guard that means focus was lost.
-}
lostDecoder : Guard -> msg -> Decoder msg
lostDecoder kind lost =
    Decode.field "animationName" Decode.string
        |> Decode.andThen
            (\name ->
                if name /= "klar-focus-lost" then
                    Decode.fail "another animation"

                else
                    case kind of
                        Modal ->
                            Decode.succeed lost

                        Idle ->
                            Decode.oneOf
                                [ Decode.at [ "target", "ownerDocument", "activeElement" ]
                                    (Decode.nullable (Decode.field "tagName" Decode.string))
                                , Decode.succeed Nothing
                                ]
                                |> Decode.andThen
                                    (\active ->
                                        case active of
                                            Nothing ->
                                                Decode.succeed lost

                                            Just "BODY" ->
                                                Decode.succeed lost

                                            Just _ ->
                                                Decode.fail "something on the page has focus"
                                    )
            )
