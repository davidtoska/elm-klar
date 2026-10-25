module Klar.Tag exposing
    ( view
    , Attribute, tone, color, outline, size, icon
    , onRemove, removeId, removeLabel, nextFocus, locale
    )

{-| A chip: a short label for a value, a filter or a selection, optionally
with a remove button.

Use when: a chip shows a value, filter or selection that the user chose and can take away.
Do not use when: the label is a read-only state (as `Klar.Badge`).

    import Klar.Tag as Tag
    import Klar.Theme exposing (Tone(..))

    Tag.view [] "Warehouse A"

    Tag.view [ Tag.tone Primary, Tag.onRemove (TagRemoved "a") ] "Warehouse A"

Unlike [Klar.Badge](Klar-Badge) (state, read-only) a tag represents something
the user chose and can take away. The tag does not remove itself: `onRemove`
sends your message, and you take the value out of your model.

The remove button is a real button with a 24px target whose accessible name is
"Remove" followed by the label ("Remove Warehouse A"); `removeLabel` names it
yourself ("Remove filter Amount > 100"). A tag that is removed with the keyboard
takes the focus with it, and the focus is lost. Give every button an id with
`removeId`, and when your message arrives focus the tag that took its place:
`nextFocus` picks it (see the example there). A label that does not fit its
container is cut with an ellipsis; a label longer than 12 characters carries the
whole text as a tooltip.


# View

@docs view


# Attributes

@docs Attribute, tone, color, outline, size, icon


# Removing

@docs onRemove, removeId, removeLabel, nextFocus, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Color exposing (Color)
import Klar.Icon as Icon exposing (Icon)
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme as Theme exposing (Size(..), Tone(..))


{-| A setting of a tag. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { tone : Tone
    , icon : Maybe Icon
    , color : Maybe Color
    , onRemove : Maybe msg
    , removeId : Maybe String
    , removeLabel : Maybe String
    , outline : Bool
    , size : Size
    , locale : Locale
    }


configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { tone = Neutral
        , icon = Nothing
        , color = Nothing
        , onRemove = Nothing
        , removeId = Nothing
        , removeLabel = Nothing
        , outline = False
        , size = Medium
        , locale = Locale.default
        }
        attributes


{-| The color of the tag: `Neutral` (gray, the default), `Primary` or `Info`
(blue), `Success`, `Warning` or `Danger`.
-}
tone : Tone -> Attribute msg
tone value =
    Attribute (\config -> { config | tone = value })


{-| A small dot in a color from your data before the label, for a tag that stands
for a row with a color (a status, a team). The tag keeps its tone; the label must
say what the color says.
-}
color : Color -> Attribute msg
color value =
    Attribute (\config -> { config | color = Just value })


{-| A small icon before the label.
-}
icon : Icon -> Attribute msg
icon value =
    Attribute (\config -> { config | icon = Just value })


{-| Shows a small × button after the label that sends this message when it is
pressed: a click, `Enter` or `Space`, or `Delete` or `Backspace` while the button
has the focus. The tag does not remove itself: take the value out of your model
when the message arrives.
-}
onRemove : msg -> Attribute msg
onRemove msg =
    Attribute (\config -> { config | onRemove = Just msg })


{-| The DOM id of the remove button, for moving the focus to it from your
application (`Klar.focus`), for example to the next tag after one was
removed, so that keyboard users do not lose their place (see `nextFocus`).
-}
removeId : String -> Attribute msg
removeId id =
    Attribute (\config -> { config | removeId = Just id })


{-| The accessible name and the tooltip of the remove button, instead of
"Remove" followed by the label. Use it when the label alone does not say what
goes away, such as a filter chip whose label is a value:

    Tag.view
        [ Tag.onRemove (FilterRemoved "amount")
        , Tag.removeLabel "Remove filter Amount > 100"
        ]
        "Amount > 100"

-}
removeLabel : String -> Attribute msg
removeLabel text =
    Attribute (\config -> { config | removeLabel = Just text })


{-| The id to focus after a tag was removed with its button, so that keyboard
users keep their place: the remove button of the tag after it, else of the tag
before it, else `otherwise` (the control that adds tags, or a heading). Give it
the tags as they were before the removal, and the same id function as
`removeId`.

    viewTag : Warehouse -> Html Msg
    viewTag warehouse =
        Tag.view
            [ Tag.onRemove (WarehouseRemoved warehouse)
            , Tag.removeId (removeIdOf warehouse)
            ]
            warehouse.name

    removeIdOf : Warehouse -> String
    removeIdOf warehouse =
        "remove-" ++ warehouse.code

    -- in update
    WarehouseRemoved warehouse ->
        ( { model | warehouses = List.filter (\w -> w /= warehouse) model.warehouses }
        , Klar.focus
            (Tag.nextFocus
                { removed = warehouse
                , tags = model.warehouses
                , toId = removeIdOf
                , otherwise = "add-warehouse"
                }
            )
            NoOp
        )

-}
nextFocus : { removed : a, tags : List a, toId : a -> String, otherwise : String } -> String
nextFocus { removed, tags, toId, otherwise } =
    let
        ( before, after ) =
            splitAt removed tags
    in
    case ( after, List.reverse before ) of
        ( next :: _, _ ) ->
            toId next

        ( [], previous :: _ ) ->
            toId previous

        ( [], [] ) ->
            otherwise


{-| The tags before the first that equals `removed`, and the ones after it
(without it).
-}
splitAt : a -> List a -> ( List a, List a )
splitAt removed tags =
    case tags of
        [] ->
            ( [], [] )

        first :: rest ->
            if first == removed then
                ( [], rest )

            else
                Tuple.mapFirst ((::) first) (splitAt removed rest)


{-| No fill: the tag keeps its border and text color but gets a transparent
background.
-}
outline : Attribute msg
outline =
    Attribute (\config -> { config | outline = True })


{-| The size of the tag: `Small` (18px high), `Medium` (22px, the default) or
`Large` (26px).
-}
size : Size -> Attribute msg
size value =
    Attribute (\config -> { config | size = value })


{-| The language of the built-in text, which is the accessible name and the
tooltip of the remove button ("Remove Warehouse A" in English). The default is
`Locale.default`, which is English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| A tag with the given label. Add `onRemove` to make it removable.

    Tag.view [ Tag.outline, Tag.icon Icon.mapPin ] "Oslo warehouse"

-}
view : List (Attribute msg) -> String -> Html msg
view attributes label =
    let
        config =
            configure attributes

        buttonLabel =
            case config.removeLabel of
                Just text ->
                    text

                Nothing ->
                    Locale.pick config.locale { nb = "Fjern ", en = "Remove " } ++ label
    in
    Html.span
        [ Internal.cls
            [ "klar-tag"
            , "klar-tag--" ++ Internal.toneSuffix config.tone
            , "klar-tag--" ++ Internal.sizeSuffix config.size
            , if config.outline then
                "klar-tag--outline"

              else
                ""
            ]
        ]
        [ Internal.viewMaybe (\value -> Internal.markDot Nothing (Just value)) config.color
        , Internal.viewMaybe Icon.view config.icon
        , Html.span [ Internal.cls [ "klar-tag__label" ], Internal.attrIf (String.length label > 12) (Attr.title label) ] [ Html.text label ]
        , case config.onRemove of
            Just msg ->
                Html.button
                    [ Internal.cls [ "klar-tag__remove" ]
                    , Attr.type_ "button"
                    , Internal.attrMaybe Attr.id config.removeId
                    , Attr.attribute "aria-label" buttonLabel
                    , Attr.title buttonLabel
                    , Events.onClick msg
                    , Internal.onKeys [ ( "Delete", msg ), ( "Backspace", msg ) ]
                    ]
                    [ Icon.sized Icon.ExtraSmall Icon.close ]

            Nothing ->
                Html.text ""
        ]
