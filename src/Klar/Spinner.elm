module Klar.Spinner exposing
    ( view, panel
    , Attribute, size, label, loading, compact
    )

{-| Loading indicators: a small spinner for inline use and a centered panel for
a region that is still loading.

Use when: you do not know what the content will look like or how long the wait will be.
Do not use when: you can sketch the content (use `Klar.Skeleton`), want a bar that shows how far a task has come (use `Klar.Progress`), or the region shows a `Remote` (use `Klar.RemoteView`, which draws loading, failure and old data for you).

    import Klar.Spinner as Spinner
    import Klar.Theme exposing (Size(..))

    -- always in the view; it spins and is announced while model.saving is True
    Spinner.view [ Spinner.label "Saving order", Spinner.loading model.saving ]

    Spinner.view [ Spinner.size Large ]

    Spinner.panel [] "Loading orders ..."

Use a spinner when you do not know what the content will look like or how long
the wait will be. When you can sketch the content, show a
[Klar.Skeleton](Klar-Skeleton) instead.

A spinner takes the color of the text around it, so it follows disabled and
danger states (only the large size is always drawn in the primary color). For
users who prefer reduced motion it turns more slowly, at the same speed as every
other turning indicator of Klar.

**Screen readers.** A spinner with a `label` is a polite live region. Screen
readers announce a live region reliably only when its text changes while it is
on the page, not when it arrives with its text. So keep a labelled spinner in the
view and switch it with `loading`: the region stays, and only its text comes and
goes. Without a label the spinner is decoration and hidden from assistive
technology, so the text next to it should say what is going on. A
[Klar.Button](Klar-Button) with `loading` shows a spinner by itself.


# Spinners

@docs view, panel


# Attributes

@docs Attribute, size, label, loading, compact

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal
import Klar.Theme as Theme exposing (Size(..))


{-| A setting of a spinner. Make them with the functions below and pass a list
to `view` or `panel`; later attributes win over earlier ones.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { size : Maybe Size
    , label : String
    , loading : Bool
    , compact : Bool
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { size = Nothing, label = "", loading = True, compact = False }
        attributes


{-| The size of the spinner: `Small` (12px), `Medium` (14px, the default of
`view`) or `Large` (22px, drawn in the primary color, the default of `panel`).
-}
size : Size -> Attribute
size value =
    Attribute (\config -> { config | size = Just value })


{-| Text that screen readers announce as a polite status message, for example
"Saving order". The default is no label, which makes the spinner a decoration
that is hidden from assistive technology. It has no effect on `panel`, whose
text is visible.
-}
label : String -> Attribute
label value =
    Attribute (\config -> { config | label = value })


{-| Whether the wait is on, from your model. The default is `True`. With `False`
nothing is drawn, but a labelled spinner (and a `panel`) keeps its empty live
region in the page, so the next `True` is announced. Render the spinner all the
time with `loading` rather than adding it with an `if`.

    Spinner.view [ Spinner.label "Saving order", Spinner.loading model.saving ]

-}
loading : Bool -> Attribute
loading value =
    Attribute (\config -> { config | loading = value })


{-| Less vertical space around a `panel`, for tables and small panels. It is the
space of a compact [Klar.EmptyState](Klar-EmptyState), and a panel follows a
compact density of the application (`Klar.Settings`) without it. It has no
effect on `view`.
-}
compact : Attribute
compact =
    Attribute (\config -> { config | compact = True })


{-| An inline spinner, small enough to sit next to text or inside a button.
With a `label` it is a status message for screen readers; without one it is only
decoration (the text next to it, or `aria-busy` on the button, says what is
going on).

    Spinner.view [ Spinner.label "Saving", Spinner.loading model.saving ]

-}
view : List Attribute -> Html msg
view attributes =
    let
        config =
            configure attributes

        spinner =
            Internal.cls [ "klar-spinner", "klar-spinner--" ++ Internal.sizeSuffix (Maybe.withDefault Medium config.size) ]
    in
    if String.isEmpty config.label then
        if config.loading then
            Html.span [ spinner, Attr.attribute "aria-hidden" "true" ] []

        else
            Html.text ""

    else
        -- The region is the same element whether the spinner turns or not, so
        -- that its text, and not the region, is what comes and goes.
        Html.span
            [ if config.loading then
                spinner

              else
                Internal.cls [ "klar-spinner-idle" ]
            , Attr.attribute "role" "status"
            , Attr.attribute "aria-live" "polite"
            ]
            [ Internal.viewIf config.loading
                (Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text config.label ])
            ]


{-| A large spinner with a text below it, centered in the space around it, to
fill a panel or a table body while it loads. It has the height of an
[Klar.EmptyState](Klar-EmptyState) or an [Klar.ErrorState](Klar-ErrorState), so
a region that goes from loading to empty or failed keeps its place. The text is
visible and is a polite status message.

A wait that ends within 400ms shows no spinner at all: the panel fades in after
that, so a fast answer does not flash. Its status text is there from the start.

    Spinner.panel [] "Loading orders ..."

    Spinner.panel [ Spinner.compact, Spinner.loading model.exporting ] "Preparing the export ..."

-}
panel : List Attribute -> String -> Html msg
panel attributes text =
    let
        config =
            configure attributes
    in
    Html.div
        [ Internal.cls
            (if config.loading then
                [ "klar-spinner-panel"
                , "klar-spinner-panel--delayed"
                , if config.compact then
                    "klar-spinner-panel--compact"

                  else
                    ""
                ]

             else
                [ "klar-spinner-idle" ]
            )
        , Attr.attribute "role" "status"
        , Attr.attribute "aria-live" "polite"
        ]
        (if config.loading then
            [ view [ size (Maybe.withDefault Large config.size) ]
            , Html.span [ Internal.cls [ "klar-spinner-panel__text" ] ] [ Html.text text ]
            ]

         else
            []
        )
