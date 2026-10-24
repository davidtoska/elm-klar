module Klar.DescriptionList exposing
    ( view
    , Item, text, maybe, html, values, fullWidth
    , Attribute, columns, labelBeside, labelWidth, bordered, density, locale
    )

{-| Label and value pairs for detail views, rendered as a semantic `dl`.

Use when: the application shows the facts about one thing, such as an order, a customer or a shipment.
Do not use when: there are many things of the same kind to compare or sort (use `Klar.Table`), or two or more versions of one thing are compared side by side (use `Klar.Compare`).

    import Klar.Badge as Badge
    import Klar.DescriptionList as DescriptionList
    import Klar.Theme exposing (Tone(..))

    DescriptionList.view [ DescriptionList.columns 2 ]
        [ DescriptionList.text "Customer number" "100482"
        , DescriptionList.maybe "Phone" model.phone
        , DescriptionList.html "Status" (Badge.view [ Badge.tone Success ] "Active")
        , DescriptionList.values "Sales channels"
            [ Badge.view [] "Web shop", Badge.view [] "Wholesale" ]
        , DescriptionList.text "Delivery note" model.note
            |> DescriptionList.fullWidth
        ]

Use it for the facts about one thing, such as an order, a customer or a
shipment. For many things of the same kind use [Klar.Table](Klar-Table).

A value that is missing (an empty or blank string, `Nothing` or an empty list) is
shown as a muted dash, with a hidden "Not provided" for screen readers, so a row
never silently disappears and a label never sits beside nothing. The hidden text
follows `locale` (English by default).

The label sits above the value by default. `labelBeside` puts it in a column to
the left, which reads like a table and works well with `bordered`. The number of
`columns` is a maximum: the grid drops to fewer columns when there is no room
(a column is never narrower than 200px, and with `labelBeside` never narrower than
the label column and 160px for the value). Rows keep the order they are given in.
The list has no state and sends no messages.

While the data is on its way, show the same labels with `Skeleton.line` values in
the place of [Klar.RemoteView](Klar-RemoteView), so that nothing jumps when the
data arrives:

    RemoteView.view
        [ RemoteView.skeleton
            (DescriptionList.view [ DescriptionList.columns 2 ]
                [ DescriptionList.html "Customer number" (Skeleton.line 40)
                , DescriptionList.html "Phone" (Skeleton.line 60)
                ]
            )
        ]
        model.customer
        (\customer -> [ customerFacts customer ])


# View

@docs view


# Items

@docs Item, text, maybe, html, values, fullWidth


# Attributes

@docs Attribute, columns, labelBeside, labelWidth, bordered, density, locale

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)
import Klar.Theme exposing (Density(..))


{-| A setting of the list. Make them with the functions below and pass a list to
`view`; later attributes win over earlier ones. The list sends no messages, so
the type has no `msg` parameter.
-}
type Attribute
    = Attribute (Config -> Config)


type alias Config =
    { columns : Int
    , beside : Bool
    , labelWidth : Int
    , bordered : Bool
    , density : Maybe Density
    , locale : Locale
    }


configure : List Attribute -> Config
configure attributes =
    List.foldl (\(Attribute change) config -> change config)
        { columns = 1
        , beside = False
        , labelWidth = 160
        , bordered = False
        , density = Nothing
        , locale = Locale.default
        }
        attributes



-- ITEMS


{-| One label with its value. Make an item with `text`, `maybe`, `html` or
`values` and give a list of them to `view`. The `msg` is the message type of the
Html you pass to `html` and `values`.
-}
type Item msg
    = Item
        { label : String
        , values : List (Html msg)
        , fullWidth : Bool
        }


{-| A plain text value: the label first, then the value. An empty or blank
string (nothing but spaces) counts as no value and is shown as a dash.

    DescriptionList.text "Customer number" "100482"

-}
text : String -> String -> Item msg
text label value =
    Item
        { label = label
        , values =
            if String.isEmpty (String.trim value) then
                []

            else
                [ Html.text value ]
        , fullWidth = False
        }


{-| A text value that may be missing. `Nothing` and `Just ""` (or any blank
string) are shown as a dash, like in `text`.

    DescriptionList.maybe "Phone" model.phone

-}
maybe : String -> Maybe String -> Item msg
maybe label value =
    text label (Maybe.withDefault "" value)


{-| Any content as the value: a badge, a link, a formatted number. It always
counts as a value, even if the Html you pass shows nothing.

    DescriptionList.html "Status" (Badge.view [ Badge.tone Success ] "Active")

-}
html : String -> Html msg -> Item msg
html label value =
    Item { label = label, values = [ value ], fullWidth = False }


{-| Several values for one label, side by side and wrapping onto more lines when
needed (tags, sales channels, phone numbers). An empty list counts as no value
and is shown as a dash.
-}
values : String -> List (Html msg) -> Item msg
values label contents =
    Item
        { label = label
        , values =
            if List.isEmpty contents then
                []

            else
                [ Html.div [ Internal.cls [ "klar-description-list__values" ] ] contents ]
        , fullWidth = False
        }


{-| Lets the item use the whole row, whatever the number of `columns`. For long
text such as notes.
-}
fullWidth : Item msg -> Item msg
fullWidth (Item item) =
    Item { item | fullWidth = True }



-- ATTRIBUTES


{-| The largest number of columns, from 1 to 3 (other numbers are moved into that
range). Default 1. It is a maximum: the grid uses fewer columns when there is no
room for them, because a column is never narrower than 200px.
-}
columns : Int -> Attribute
columns n =
    Attribute (\config -> { config | columns = clamp 1 3 n })


{-| Puts the label in a column to the left of the value instead of above it. The
column is 160px wide; change it with `labelWidth`.
-}
labelBeside : Attribute
labelBeside =
    Attribute (\config -> { config | beside = True })


{-| The width in pixels of the label column when the label is beside the value.
Default 160. Without `labelBeside` it has no effect.
-}
labelWidth : Int -> Attribute
labelWidth px =
    Attribute (\config -> { config | labelWidth = px })


{-| A thin line under every row.
-}
bordered : Attribute
bordered =
    Attribute (\config -> { config | bordered = True })


{-| How tightly the rows are packed: `Compact` (less space between the rows, for
dense detail views), `Normal` or `Comfortable` (more space). Without it the list
follows the density of the application (`Klar.Settings`), so give it only to a
list that must differ from the rest.

    DescriptionList.density Compact

-}
density : Density -> Attribute
density value =
    Attribute (\config -> { config | density = Just value })


{-| The language of the hidden text that stands for a missing value: "Not
provided" in English, which is the default (`Locale.en`). The visible dash is the
same in every language.
-}
locale : Locale -> Attribute
locale value =
    Attribute (\config -> { config | locale = value })



-- VIEW


{-| The list. Rows keep the order they are given in. Each row is a `div` with a
`dt` for the label and a `dd` for the value inside a `dl`.
-}
view : List Attribute -> List (Item msg) -> Html msg
view attributes items =
    let
        config =
            configure attributes
    in
    Html.dl
        [ Internal.cls
            [ "klar-description-list"
            , if config.beside then
                "klar-description-list--beside"

              else
                ""
            , if config.bordered then
                "klar-description-list--bordered"

              else
                ""
            , case config.density of
                Just Compact ->
                    "klar-description-list--compact"

                Just Normal ->
                    "klar-description-list--normal"

                Just Comfortable ->
                    "klar-description-list--comfortable"

                Nothing ->
                    ""
            ]
        , Internal.styleVars
            [ ( "--klar-dl-cols", String.fromInt config.columns )
            , ( "--klar-dl-label-w", String.fromInt config.labelWidth ++ "px" )
            ]
        ]
        (List.map (viewItem config) items)


viewItem : Config -> Item msg -> Html msg
viewItem config (Item item) =
    Html.div
        [ Internal.cls
            [ "klar-description-list__item"
            , if item.fullWidth then
                "klar-description-list__item--full"

              else
                ""
            ]
        ]
        (Html.dt [ Internal.cls [ "klar-description-list__label" ] ] [ Html.text item.label ]
            :: (case item.values of
                    [] ->
                        [ Html.dd [ Internal.cls [ "klar-description-list__value", "klar-description-list__value--empty" ] ]
                            [ Html.span [ Internal.cls [ "klar-description-list__dash" ], ariaHidden ] [ Html.text "-" ]
                            , Html.span [ Internal.cls [ "klar-sr-only" ] ]
                                [ Html.text (Locale.pick config.locale { nb = "Ikke oppgitt", en = "Not provided" }) ]
                            ]
                        ]

                    present ->
                        List.map (\content -> Html.dd [ Internal.cls [ "klar-description-list__value" ] ] [ content ]) present
               )
        )


ariaHidden : Html.Attribute msg
ariaHidden =
    Attr.attribute "aria-hidden" "true"
