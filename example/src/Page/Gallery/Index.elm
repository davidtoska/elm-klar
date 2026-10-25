module Page.Gallery.Index exposing (Model, Msg, init, update, view)

{-| The front page of the component gallery: what is in it, one card per page,
and a search box over every component name.
-}

import Html exposing (Html)
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.EmptyState as EmptyState
import Klar.Icon as Icon
import Klar.Icon.Library as Library
import Klar.Layout as Layout
import Klar.Link as Link
import Klar.Locale exposing (Locale)
import Klar.Search as Search
import Klar.Stat as Stat
import Klar.Tag as Tag
import Klar.TextInput as TextInput
import Klar.Theme exposing (Tone(..))
import Page.Gallery.Catalog as Catalog exposing (Section)
import Route
import Showcase.Doc as Doc


type alias Model =
    { query : String
    }


type Msg
    = QueryChanged String


init : Model
init =
    { query = "" }


update : Msg -> Model -> Model
update msg model =
    case msg of
        QueryChanged query ->
            { model | query = query }


view : Locale -> Model -> Html Msg
view locale model =
    let
        matching =
            Catalog.all
                |> List.filterMap
                    (\section ->
                        let
                            hits =
                                if String.trim model.query == "" then
                                    Catalog.components section

                                else
                                    Search.filter identity model.query (Catalog.components section)
                        in
                        if List.isEmpty hits then
                            Nothing

                        else
                            Just ( section, hits )
                    )
    in
    Doc.page
        { title = "Component gallery"
        , description = "Reusable interface components in plain Elm and plain CSS for data-intensive applications: tables, searchable selects, filters, rules, dialogs and more. Everything the showcase application displays comes from here."
        }
        [ Layout.grid [ Layout.minColumn 150, Layout.gap 4 ]
            [ Stat.view [ Stat.label "Components", Stat.int Catalog.componentCount, Stat.caption "in the library", Stat.locale locale ]
            , Stat.view [ Stat.label "Pages", Stat.int (List.length Catalog.all), Stat.caption "with live examples", Stat.locale locale ]
            , Stat.view [ Stat.label "Icons", Stat.int Library.count, Stat.caption "one style, all Elm", Stat.locale locale ]
            , Stat.view [ Stat.label "Packages", Stat.int 0, Stat.caption "besides the official elm/*", Stat.locale locale ]
            ]
        , Layout.stack [ Layout.gap 4 ]
            [ TextInput.view
                [ TextInput.id "component-search"
                , TextInput.label "Search components"
                , TextInput.labelHidden
                , TextInput.search
                , TextInput.clearable
                , TextInput.locale locale
                , TextInput.placeholder "Search components, for example \"table\" ..."
                , TextInput.value model.query
                , TextInput.onInput QueryChanged
                ]
            , if List.isEmpty matching then
                EmptyState.view
                    [ EmptyState.icon Icon.search
                    , EmptyState.title "No components found"
                    , EmptyState.description "Try another word, or clear the search."
                    , EmptyState.actions [ Button.view [ Button.onClick (QueryChanged "") ] "Clear search" ]
                    ]

              else
                Layout.grid [ Layout.minColumn 320, Layout.gap 4 ]
                    (List.map viewSection matching)
            ]
        ]


viewSection : ( Section, List String ) -> Html Msg
viewSection ( section, hits ) =
    Card.view
        [ Card.headingLevel 2
        , Card.title (Catalog.title section)
        , Card.subtitle (Catalog.description section)
        , Card.actions
            [ Badge.view [ Badge.tone Primary ]
                (String.fromInt (List.length (Catalog.components section)))
            ]
        , Card.footer
            [ Button.view
                [ Button.href (Link.internal (Route.path (Route.Components (Just (Catalog.slug section)))))
                , Button.iconRight Icon.arrowRight
                , Button.small
                ]
                "Open page"
            ]
        ]
        [ Layout.row [ Layout.gap 2, Layout.wrap ]
            (List.map (\name -> Tag.view [] name) hits)
        ]
