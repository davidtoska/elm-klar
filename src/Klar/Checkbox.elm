module Klar.Checkbox exposing
    ( view, Attribute
    , checked, indeterminate, onCheck
    , label, hint, error, ariaLabel
    , size, disabled, tabIndex, id
    )

{-| A checkbox, with a label or bare.

Use when: a yes or no choice that is saved together with the rest of a form, or a bare box in a table row.
Do not use when: the setting takes effect at once (`Klar.Switch`) or several related choices share one label (`Klar.CheckboxGroup`).

    import Klar.Checkbox as Checkbox

    Checkbox.view
        [ Checkbox.label "Send me the monthly newsletter"
        , Checkbox.hint "At most one email a month."
        , Checkbox.checked model.newsletter
        , Checkbox.onCheck NewsletterChanged
        ]

The application owns the value: `checked` says whether the box is checked, and
`onCheck` gets the new value when the user clicks the box or its label, or
presses Space on it. Keep it in the model, like the text of an input. It is a
native checkbox, so Tab reaches it and Space toggles it.

Use a checkbox for a choice that is saved together with the rest of a form. A
setting that takes effect at once is a [Klar.Switch](Klar-Switch), and several
related choices that share one label and one error message are a
[Klar.CheckboxGroup](Klar-CheckboxGroup).

A checkbox without a label is "bare", as in the rows of [Klar.Table](Klar-Table)
or a "select all" header, and needs `ariaLabel` for its accessible name.
`indeterminate` shows a dash instead of a check for "some selected"; a click on
such a box sends `True`, because that is what "select all" is expected to do.

    Checkbox.view
        [ Checkbox.ariaLabel "Select all orders"
        , Checkbox.checked allSelected
        , Checkbox.indeterminate (someSelected && not allSelected)
        , Checkbox.onCheck AllOrdersToggled
        ]

The hint and the error message are drawn under the label, or beside the box when
there is no label (then the checkbox needs `ariaLabel`). Both are joined to the
checkbox with `aria-describedby`, the error is read out when it appears, and the
accessible name stays the label alone. A checkbox draws these itself and does not
use [Klar.Field](Klar-Field), so it has no `errorMaybe`, `required` or
`labelHidden`.


# View

@docs view, Attribute


# Value

@docs checked, indeterminate, onCheck


# Label, hint and error

@docs label, hint, error, ariaLabel


# Look and behavior

@docs size, disabled, tabIndex, id

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Encode as Encode
import Klar.Internal as Internal
import Klar.Theme as Theme exposing (Size(..))


{-| A setting of a checkbox. Make them with the functions below and pass a list
to `view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { label : Maybe String
    , hint : Maybe String
    , error : Maybe String
    , checked : Bool
    , indeterminate : Bool
    , disabled : Bool
    , onCheck : Maybe (Bool -> msg)
    , id : Maybe String
    , ariaLabel : Maybe String
    , size : Size
    , tabIndex : Maybe Int
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { label = Nothing
        , hint = Nothing
        , error = Nothing
        , checked = False
        , indeterminate = False
        , disabled = False
        , onCheck = Nothing
        , id = Nothing
        , ariaLabel = Nothing
        , size = Medium
        , tabIndex = Nothing
        }
        attributes


{-| The text next to the box; a click on it toggles the checkbox. Without a
label the checkbox is bare: give it an `ariaLabel`.
-}
label : String -> Attribute msg
label text =
    Attribute (\config -> { config | label = Just text })


{-| A line of gray explanation under the label (beside the box when there is no
label), joined to the checkbox with `aria-describedby`. An empty text counts as
none.
-}
hint : String -> Attribute msg
hint text =
    Attribute (\config -> { config | hint = Just text })


{-| Marks the checkbox invalid (a red box and `aria-invalid`) and shows the
message in red under the label (beside the box when there is no label). The
message is joined to the checkbox with `aria-describedby`, and screen readers
read it when it appears. An empty text counts as no error, so there is never a
red box without a message. There is no `errorMaybe`: add `error` to the list only
while there is a problem.
-}
error : String -> Attribute msg
error text =
    Attribute (\config -> { config | error = Just text })


{-| Whether the box is checked. The default is `False`. While the box is
`indeterminate` it shows a dash, whatever this says.
-}
checked : Bool -> Attribute msg
checked value =
    Attribute (\config -> { config | checked = value })


{-| Shows a dash instead of a check, for "some selected". The box is the native
"indeterminate" state of a checkbox, which assistive technology announces as
"mixed". A click on an indeterminate box sends `True` to `onCheck`, because that is
what "select all" is expected to do. The default is `False`.
-}
indeterminate : Bool -> Attribute msg
indeterminate value =
    Attribute (\config -> { config | indeterminate = value })


{-| Dims the checkbox and makes it unchangeable and unfocusable (the HTML
`disabled` attribute). The default is `False`.
-}
disabled : Bool -> Attribute msg
disabled value =
    Attribute (\config -> { config | disabled = value })


{-| The message sent when the user toggles the box. It gets the new value,
`True` for checked; store it and give it back with `checked`.

    Checkbox.onCheck NewsletterChanged

-}
onCheck : (Bool -> msg) -> Attribute msg
onCheck toMsg =
    Attribute (\config -> { config | onCheck = Just toMsg })


{-| The DOM id of the `input` element, for moving focus to it with
`Klar.focus`. No id is set by default. The hint and the error message get
the ids `<id>-description` and `<id>-error`, and the label text `<id>-label`
while there is a hint or an error to leave out of the name. Without an id they
are made from the label (or the `ariaLabel`), so give checkboxes that share a
text and show a hint or an error an id each.
-}
id : String -> Attribute msg
id value =
    Attribute (\config -> { config | id = Just value })


{-| The accessible name when there is no visible label, such as "Select all
orders" or "Select order 1042". It becomes the `aria-label` of the input.
-}
ariaLabel : String -> Attribute msg
ariaLabel value =
    Attribute (\config -> { config | ariaLabel = Just value })


{-| The size of the box and its label: `Small`, `Medium` or `Large` (see
[Klar.Theme](Klar-Theme)). The default is `Medium`.
-}
size : Size -> Attribute msg
size value =
    Attribute (\config -> { config | size = value })


{-| The `tabindex` of the input. `-1` takes the checkbox out of the tab order
(it can still be clicked and focused by script), for a list of checkboxes that
is reached some other way, like the rows of [Klar.Table](Klar-Table), where the
arrow keys move between rows. Without it the browser decides: a checkbox is
reached with Tab.
-}
tabIndex : Int -> Attribute msg
tabIndex value =
    Attribute (\config -> { config | tabIndex = Just value })


{-| A single checkbox. The box, its label, hint and error message are one
`label` element, so clicking the text toggles the box. Without any of that text
the checkbox is bare.

    Checkbox.view
        [ Checkbox.label "I accept the terms of delivery"
        , Checkbox.checked model.accepted
        , Checkbox.onCheck TermsAccepted
        ]

-}
view : List (Attribute msg) -> Html msg
view attributes =
    let
        config =
            configure attributes

        isChecked =
            config.checked && not config.indeterminate

        -- A blank text is no text: there is nothing to show or to refer to.
        shownHint =
            Maybe.andThen Internal.nonEmpty config.hint

        shownError =
            Maybe.andThen Internal.nonEmpty config.error

        hasText =
            config.label /= Nothing || shownHint /= Nothing || shownError /= Nothing

        -- The ids of the parts: from the id of the input, else from the label.
        partId =
            case config.id of
                Just given ->
                    given

                Nothing ->
                    "klar-check-"
                        ++ Internal.sanitizeId
                            (String.toLower (Maybe.withDefault (Maybe.withDefault "checkbox" config.ariaLabel) config.label))

        labelId =
            partId ++ "-label"

        hintId =
            partId ++ "-description"

        errorId =
            partId ++ "-error"

        -- aria-describedby only names elements that are drawn below.
        described =
            List.filterMap identity
                [ Maybe.map (\_ -> hintId) shownHint
                , Maybe.map (\_ -> errorId) shownError
                ]

        -- The hint and the error message sit inside the label element. When there
        -- are some, the label text has an id and names the input on its own
        -- (aria-labelledby), so they are described but not part of the name.
        nameFromLabelText =
            config.label /= Nothing && not (List.isEmpty described)

        ariaAttributes =
            (if nameFromLabelText then
                [ Attr.attribute "aria-labelledby" labelId ]

             else
                []
            )
                ++ (if List.isEmpty described then
                        []

                    else
                        [ Attr.attribute "aria-describedby" (String.join " " described) ]
                   )
    in
    Html.label
        [ Internal.cls
            [ "klar-check"
            , "klar-check--" ++ Internal.sizeSuffix config.size
            , if config.disabled then
                "klar-check--disabled"

              else
                ""
            , if config.indeterminate then
                "klar-check--indeterminate"

              else
                ""
            , if shownError /= Nothing then
                "klar-check--invalid"

              else
                ""
            , if hasText then
                ""

              else
                "klar-check--bare"
            ]
        ]
        [ Html.input
            ([ Internal.cls [ "klar-check__input" ]
             , Attr.type_ "checkbox"
             , Attr.checked isChecked
             , Attr.disabled config.disabled
             , Internal.attrMaybe Attr.id config.id
             , Internal.attrMaybe Attr.tabindex config.tabIndex
             , Internal.attrMaybe (Attr.attribute "aria-label") config.ariaLabel
             , Attr.property "indeterminate" (Encode.bool config.indeterminate)
             , Internal.attrIf (shownError /= Nothing) (Attr.attribute "aria-invalid" "true")
             , Internal.attrMaybe Events.onCheck (config.onCheck |> Maybe.map (indeterminateAware config.indeterminate))
             ]
                ++ ariaAttributes
            )
            []
        , Html.span [ Internal.cls [ "klar-check__box" ], Attr.attribute "aria-hidden" "true" ] []
        , if hasText then
            Html.span [ Internal.cls [ "klar-check__text" ] ]
                [ Internal.viewMaybe
                    (\text ->
                        Html.span
                            (if nameFromLabelText then
                                [ Internal.cls [ "klar-check__label" ], Attr.id labelId ]

                             else
                                [ Internal.cls [ "klar-check__label" ] ]
                            )
                            [ Html.text text ]
                    )
                    config.label
                , Internal.viewMaybe
                    (\text -> Html.span [ Internal.cls [ "klar-check__hint" ], Attr.id hintId ] [ Html.text text ])
                    shownHint
                , Internal.viewMaybe
                    (\message ->
                        Html.span
                            [ Internal.cls [ "klar-check__error" ]
                            , Attr.id errorId
                            , Attr.attribute "role" "alert"
                            ]
                            [ Html.text message ]
                    )
                    shownError
                ]

          else
            Html.text ""
        ]


{-| Clicking an indeterminate box selects everything, which is the common
expectation for "select all".
-}
indeterminateAware : Bool -> (Bool -> msg) -> Bool -> msg
indeterminateAware isIndeterminate toMsg newValue =
    if isIndeterminate then
        toMsg True

    else
        toMsg newValue
