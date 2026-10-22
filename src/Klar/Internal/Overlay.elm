module Klar.Internal.Overlay exposing
    ( Around
    , Layer
    , Overlay
    , dialog
    , layer
    , map
    , toasts
    )

{-| What `Klar.Overlay` is made of. An overlay is a value that knows whether it is
open and how to draw itself given what the others around it are doing. The page
(`Klar.Overlay.host`, `Klar.AppShell`) collects the list, so it learns by itself
that a dialog is open (the page behind becomes inert), which dialog is on top
(only that one watches the focus), and where the toasts go.
-}

import Html exposing (Html)
import Html.Events as Events
import Json.Decode as Decode
import Klar.Internal as Internal


{-| A dialog, a drawer, a palette or the stack of toasts, ready to be placed in the
list of overlays of a page.
-}
type Overlay msg
    = Overlay (Data msg)


type alias Data msg =
    { kind : Kind
    , open : Bool

    -- Dialogs: where the first `Tab` past the last element lands (the chain of
    -- ids to try), or `Nothing` when the overlay keeps its own focus (the palette).
    , entry : Maybe (List String)

    -- A closed dialog listens to the focus on the page, to know what to give
    -- focus back to when it opens and closes later.
    , watch : Maybe (String -> msg)
    , render : Around -> Html msg
    }


type Kind
    = Dialog
    | Toasts


{-| What an overlay is told about the others when it is drawn.
-}
type alias Around =
    { -- The dialog on top of all open ones.
      top : Bool

    -- Dialogs: there is a toast stack that closes the tab loop.
    , toastsFollow : Bool

    -- Toasts: the entry of the dialog on top, if one is open.
    , trap : Maybe (List String)
    }


dialog :
    { open : Bool
    , entry : Maybe (List String)
    , watch : Maybe (String -> msg)
    , render : { top : Bool, toastsFollow : Bool } -> Html msg
    }
    -> Overlay msg
dialog options =
    Overlay
        { kind = Dialog
        , open = options.open
        , entry = options.entry
        , watch = options.watch
        , render = \around -> options.render { top = around.top, toastsFollow = around.toastsFollow }
        }


toasts : { render : { trap : Maybe (List String) } -> Html msg } -> Overlay msg
toasts options =
    Overlay
        { kind = Toasts
        , open = False
        , entry = Nothing
        , watch = Nothing
        , render = \around -> options.render { trap = around.trap }
        }


map : (a -> b) -> Overlay a -> Overlay b
map change (Overlay data) =
    Overlay
        { kind = data.kind
        , open = data.open
        , entry = data.entry
        , watch = Maybe.map (\toMsg id -> change (toMsg id)) data.watch
        , render = \around -> Html.map change (data.render around)
        }


{-| The result of looking at all the overlays of a page.
-}
type alias Layer msg =
    { blocked : Bool
    , overlays : List (Html msg)
    , watch : List (Html msg) -> List (Html msg)
    }


layer : List (Overlay msg) -> Layer msg
layer overlays =
    let
        dialogs =
            List.filter (\(Overlay data) -> data.kind == Dialog) overlays

        stacks =
            List.filter (\(Overlay data) -> data.kind == Toasts) overlays

        openDialogs =
            List.filter (\(Overlay data) -> data.open) dialogs

        topIndex =
            List.indexedMap Tuple.pair dialogs
                |> List.filter (\( _, Overlay data ) -> data.open)
                |> List.reverse
                |> List.head
                |> Maybe.map Tuple.first

        topDialog =
            List.reverse openDialogs |> List.head

        hasToasts =
            not (List.isEmpty stacks)

        around isTop =
            { top = isTop
            , toastsFollow = hasToasts
            , trap = Maybe.andThen (\(Overlay data) -> data.entry) topDialog
            }

        -- One wrapper for every dialog, open or not, so that the page keeps its
        -- place in the DOM when a dialog opens; only a closed one listens.
        watchers =
            List.map (\(Overlay data) -> data.watch) dialogs
    in
    { blocked = not (List.isEmpty openDialogs)
    , overlays =
        List.indexedMap (\index (Overlay data) -> data.render (around (Just index == topIndex))) dialogs
            -- toasts last, so that they come after the dialogs in the tab order
            ++ List.map (\(Overlay data) -> data.render (around False)) stacks
    , watch = \children -> List.foldl wrapWatcher children watchers
    }


wrapWatcher : Maybe (String -> msg) -> List (Html msg) -> List (Html msg)
wrapWatcher watch children =
    [ Html.div
        [ Internal.cls [ "klar-contents" ]
        , Internal.attrMaybe
            (\toMsg ->
                Events.on "focusin"
                    (Decode.at [ "target", "id" ] Decode.string
                        |> Decode.andThen
                            (\id ->
                                if id == "" then
                                    Decode.fail "nothing to remember"

                                else
                                    Decode.succeed (toMsg id)
                            )
                    )
            )
            watch
        ]
        children
    ]
