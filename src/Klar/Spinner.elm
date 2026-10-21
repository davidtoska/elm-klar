module Klar.Spinner exposing
    ( view, panel
    , Attribute, size, label
    )

{-| Loading indicators: a small spinner for inline use and a centered panel for
a region that is still loading.

    import Klar.Spinner as Spinner
    import Klar.Theme exposing (Size(..))

    Spinner.view []

    Spinner.view [ Spinner.size Large, Spinner.label "Loading orders" ]

    Spinner.panel "Loading orders ..."

Use a spinner when you do not know what the content will look like or how long
the wait will be. When you can sketch the content, show a
[Klar.Skeleton](Klar-Skeleton) instead.

A spinner takes the color of the text around it, so it follows disabled and
danger states (only the large size is always drawn in the primary color). For
users who prefer reduced motion it turns more slowly.

A spinner with a `label` is a polite status message: screen readers announce
the label. Without a label the spinner is decoration and hidden from assistive
technology, so the text next to it should say what is going on. A
[Klar.Button](Klar-Button) with `loading` shows a spinner by itself.


# Spinners

@docs view, panel


# Attributes

@docs Attribute, size, label

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal
import Klar.Theme as Theme exposing (Size(..))


{-| A setting of a spinner. Make them with `size` and `label` and pass a list
to `view`; later attributes win over earlier ones.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { size : Size
    , label : String
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { size = Medium, label = "" }
        attributes


{-| The size of the spinner: `Small` (12px), `Medium` (14px, the default) or
`Large` (22px, drawn in the primary color).
-}
size : Size -> Attribute
size value =
    Attribute (\config -> { config | size = value })


{-| Text that screen readers announce as a polite status message, for example
"Loading orders". The default is no label, which makes the spinner a
decoration that is hidden from assistive technology.
-}
label : String -> Attribute
label value =
    Attribute (\config -> { config | label = value })


{-| An inline spinner, small enough to sit next to text or inside a button.
With a `label` it is a status message for screen readers; without one it is only
decoration (the text next to it, or `aria-busy` on the button, says what is
going on).

    Spinner.view [ Spinner.label "Saving" ]

-}
view : List Attribute -> Html msg
view attributes =
    let
        config =
            configure attributes

        classNames =
            Internal.cls [ "klar-spinner", "klar-spinner--" ++ Theme.sizeSuffix config.size ]
    in
    if String.isEmpty config.label then
        Html.span [ classNames, Attr.attribute "aria-hidden" "true" ] []

    else
        Html.span
            [ classNames
            , Attr.attribute "role" "status"
            , Attr.attribute "aria-live" "polite"
            ]
            [ Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text config.label ] ]


{-| A large spinner with a text below it, centered in the space around it, to
fill a panel or a table body while it loads. The text is visible, and screen
readers announce it as a status message.

    Spinner.panel "Loading orders ..."

-}
panel : String -> Html msg
panel text =
    Html.div
        [ Internal.cls [ "klar-spinner-panel" ]
        , Attr.attribute "role" "status"
        , Attr.attribute "aria-live" "polite"
        ]
        [ view [ size Large ]
        , Html.span [ Internal.cls [ "klar-spinner-panel__text" ] ] [ Html.text text ]
        ]
