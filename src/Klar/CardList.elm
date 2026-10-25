module Klar.CardList exposing
    ( view
    , Field, field
    , Attribute, id, selection, onOpen, actions, onLoadMore, onRetry, locale, settings
    )

{-| A responsive collection of records as compact cards, with labelled fields,
selection and actions that remain ordinary keyboard controls.

Use when: a product catalogue or overview needs cards that fit a narrow screen.
Do not use when: rows must be sorted, filtered or edited in columns; use `Klar.Table`.

    import Html
    import Klar.CardList as CardList
    import Klar.Ids as Ids
    import Klar.Remote as Remote

    CardList.view []
        { label = "Products"
        , items = Remote.Loaded [ { id = 1, name = "Steel bracket", sku = "BR-01" } ]
        , ids = Ids.int
        , id = .id
        , title = .name
        , fields = [ CardList.field "SKU" (Html.text << .sku) ]
        }

`selection` is controlled by the application. Selecting or clearing the loaded
cards preserves selections on other pages. A card's title is a button only when
`onOpen` is supplied; actions and checkboxes are never nested in that button.
Records and ids must be unique within the list. Ordering and paging belong to the
application; this component never truncates the supplied records.

Every remote state is drawn, including empty retained data, refresh and failed
refresh with retry. Give the region a surrounding focus target and use
`Klar.focus` in its retry handler when the retry button would disappear.

@docs view


# Fields

@docs Field, field


# Attributes

@docs Attribute, id, selection, onOpen, actions, onLoadMore, onRetry, locale, settings

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Json.Encode as Encode
import Klar.Format as Format
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Collection as Collection
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote exposing (Remote)
import Klar.Settings as Settings exposing (Settings)
import Set


{-| A labelled value in a card. The record type is your application's own type.
-}
type Field record msg
    = Field String (record -> Html msg)


{-| A field rendered as a description-list pair. Values may be text, badges or links.
-}
field : String -> (record -> Html msg) -> Field record msg
field =
    Field


{-| Optional card behaviour; later attributes win. By default cards are read only.
-}
type Attribute record id msg
    = Attribute (Config record id msg -> Config record id msg)


type alias Config record id msg =
    { domId : Maybe String
    , selection : Maybe ( List id, List id -> msg )
    , onOpen : Maybe (id -> msg)
    , actions : record -> List (Html msg)
    , onLoadMore : Maybe msg
    , onRetry : Maybe msg
    , locale : Locale
    , settings : Settings
    }


{-| A DOM id unique on the page and a stable focus target after retry or removal.
Absent by default. Use `Klar.focus` in the handler when its control disappears.
-}
id : String -> Attribute record id msg
id value =
    Attribute (\config -> { config | domId = Just value })


{-| Enables selection, with the selected ids and the callback receiving the new
complete selection. Clearing loaded cards keeps ids from other pages.
-}
selection : List id -> (List id -> msg) -> Attribute record id msg
selection ids toMsg =
    Attribute (\config -> { config | selection = Just ( ids, toMsg ) })


{-| Turns each title into a button that sends its record's id. Absent by default.
-}
onOpen : (id -> msg) -> Attribute record id msg
onOpen toMsg =
    Attribute (\config -> { config | onOpen = Just toMsg })


{-| Additional controls below each card's fields. Empty by default.
-}
actions : (record -> List (Html msg)) -> Attribute record id msg
actions render =
    Attribute (\config -> { config | actions = render })


{-| Shows a load-more button after the loaded cards. The application appends data.
-}
onLoadMore : msg -> Attribute record id msg
onLoadMore msg =
    Attribute (\config -> { config | onLoadMore = Just msg })


{-| Retry message for initial failures and failed refreshes. Absent by default.
-}
onRetry : msg -> Attribute record id msg
onRetry msg =
    Attribute (\config -> { config | onRetry = Just msg })


{-| Built-in text language. Defaults to English.
-}
locale : Locale -> Attribute record id msg
locale value =
    Attribute (\config -> { config | locale = value })


{-| Settings used to format the time of retained data. Defaults to `Settings.default`.
-}
settings : Settings -> Attribute record id msg
settings value =
    Attribute (\config -> { config | settings = value })


{-| Draws every supplied record, keyed by its unique application id. `label`
names the region; `title` is plain text and `fields` are shown in order.
-}
view :
    List (Attribute record id msg)
    -> { label : String, items : Remote (List record), ids : Ids id, id : record -> id, title : record -> String, fields : List (Field record msg) }
    -> Html msg
view attributes data =
    let
        config =
            List.foldl (\(Attribute change) acc -> change acc)
                { domId = Nothing, selection = Nothing, onOpen = Nothing, actions = always [], onLoadMore = Nothing, onRetry = Nothing, locale = Locale.default, settings = Settings.default }
                attributes

        pick en nb =
            Locale.pick config.locale { en = en, nb = nb }

        key =
            Ids.toKey data.ids

        render records =
            let
                selected =
                    config.selection |> Maybe.map (Tuple.first >> List.map key >> Set.fromList) |> Maybe.withDefault Set.empty

                loadedKeys =
                    List.map (data.id >> key) records |> Set.fromList

                allSelected =
                    Set.isEmpty (Set.diff loadedKeys selected)

                selectControl =
                    case config.selection of
                        Just ( chosen, toMsg ) ->
                            [ Html.label [ Internal.cls [ "klar-workbench__check" ] ]
                                [ Html.input
                                    [ Attr.type_ "checkbox"
                                    , Attr.checked allSelected
                                    , Attr.property "indeterminate" (Encode.bool (not allSelected && not (Set.isEmpty (Set.intersect loadedKeys selected))))
                                    , Attr.attribute "aria-checked"
                                        (if allSelected then
                                            "true"

                                         else if Set.isEmpty (Set.intersect loadedKeys selected) then
                                            "false"

                                         else
                                            "mixed"
                                        )
                                    , Events.onCheck
                                        (\checked ->
                                            toMsg
                                                (if checked then
                                                    chosen ++ (records |> List.map data.id |> List.filter (key >> (\k -> not (Set.member k selected))))

                                                 else
                                                    List.filter (key >> (\k -> not (Set.member k loadedKeys))) chosen
                                                )
                                        )
                                    ]
                                    []
                                , Html.text (pick "Select loaded cards" "Velg innlastede kort")
                                ]
                            ]

                        Nothing ->
                            []

                card record =
                    let
                        recordId =
                            data.id record

                        isSelected =
                            Set.member (key recordId) selected
                    in
                    ( key recordId
                    , Html.li [ Internal.classes [ ( "klar-card-list__card", True ), ( "klar-card-list__card--selected", isSelected ) ] ]
                        [ Html.div [ Internal.cls [ "klar-card-list__head" ] ]
                            [ case config.selection of
                                Just ( chosen, toMsg ) ->
                                    Html.label [ Internal.cls [ "klar-workbench__check" ] ]
                                        [ Html.input
                                            [ Attr.type_ "checkbox"
                                            , Attr.checked isSelected
                                            , Events.onCheck
                                                (\checked ->
                                                    toMsg
                                                        (if checked then
                                                            chosen ++ [ recordId ]

                                                         else
                                                            List.filter (key >> (/=) (key recordId)) chosen
                                                        )
                                                )
                                            ]
                                            []
                                        , Html.span [ Internal.cls [ "klar-sr-only" ] ] [ Html.text (pick "Select " "Velg " ++ data.title record) ]
                                        ]

                                Nothing ->
                                    Html.text ""
                            , case config.onOpen of
                                Just toMsg ->
                                    Html.button [ Attr.type_ "button", Internal.cls [ "klar-workbench__title-button" ], Events.onClick (toMsg recordId) ] [ Html.text (data.title record) ]

                                Nothing ->
                                    Html.strong [] [ Html.text (data.title record) ]
                            ]
                        , Html.dl [ Internal.cls [ "klar-card-list__fields" ] ]
                            (List.concatMap (\(Field label show) -> [ Html.dt [] [ Html.text label ], Html.dd [] [ show record ] ]) data.fields)
                        , Html.div [ Internal.cls [ "klar-workbench__actions" ] ] (config.actions record)
                        ]
                    )
            in
            Html.div []
                [ Html.div [ Internal.cls [ "klar-workbench__bar" ] ]
                    (Html.span [ Attr.attribute "role" "status" ] [ Html.text (Format.int config.locale (List.length records) ++ pick " loaded" " innlastet") ] :: selectControl)
                , Keyed.ul [ Internal.cls [ "klar-card-list__grid" ] ] (List.map card records)
                , Collection.more config.locale config.onLoadMore
                ]
    in
    Html.section [ Internal.cls [ "klar-card-list" ], Attr.attribute "aria-label" data.label, Attr.tabindex -1, Internal.attrMaybe Attr.id config.domId ]
        (Collection.view { locale = config.locale, settings = config.settings, onRetry = config.onRetry, onLoadMore = config.onLoadMore }
            (pick "No records" "Ingen poster")
            data.items
            render
        )
