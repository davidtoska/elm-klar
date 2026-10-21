module Page.Gallery.DataDisplay exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: data display. Every section is a module of its own in
`Page.Gallery.DataDisplay.*`; this one puts them on the page and owns the
switch that makes the pretend backend fail.
-}

import Html exposing (Html)
import Html.Lazy
import Klar.Checkbox as Checkbox
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Page.Gallery.DataDisplay.Avatars as Avatars
import Page.Gallery.DataDisplay.Charts as Charts
import Page.Gallery.DataDisplay.Json as Json
import Page.Gallery.DataDisplay.Lists as Lists
import Page.Gallery.DataDisplay.Progress as Progress
import Page.Gallery.DataDisplay.Stats as Stats
import Page.Gallery.DataDisplay.Timelines as Timelines
import Page.Gallery.DataDisplay.Trees as Trees
import Showcase.Doc as Doc



-- MODEL


type alias Model =
    { failing : Bool
    , trees : Trees.Model
    , timelines : Timelines.Model
    , stats : Stats.Model
    , charts : Charts.Model
    , progress : Progress.Model
    , lists : Lists.Model
    , json : Json.Model
    }


type Msg
    = SetFailing Bool
    | TreesMsg Trees.Msg
    | TimelinesMsg Timelines.Msg
    | StatsMsg Stats.Msg
    | ChartsMsg Charts.Msg
    | ProgressMsg Progress.Msg
    | ListsMsg Lists.Msg
    | JsonMsg Json.Msg


init : ( Model, Cmd Msg )
init =
    ( { failing = False
      , trees = Trees.init
      , timelines = Timelines.init
      , stats = Stats.init
      , charts = Charts.init
      , progress = Progress.init
      , lists = Lists.init
      , json = Json.init
      }
    , Cmd.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SetFailing value ->
            ( { model | failing = value }, Cmd.none )

        TreesMsg inner ->
            let
                ( trees, cmd ) =
                    Trees.update model.failing inner model.trees
            in
            ( { model | trees = trees }, Cmd.map TreesMsg cmd )

        TimelinesMsg inner ->
            let
                ( timelines, cmd ) =
                    Timelines.update model.failing inner model.timelines
            in
            ( { model | timelines = timelines }, Cmd.map TimelinesMsg cmd )

        StatsMsg inner ->
            let
                ( stats, cmd ) =
                    Stats.update model.failing inner model.stats
            in
            ( { model | stats = stats }, Cmd.map StatsMsg cmd )

        ChartsMsg inner ->
            let
                ( charts, cmd ) =
                    Charts.update inner model.charts
            in
            ( { model | charts = charts }, Cmd.map ChartsMsg cmd )

        ProgressMsg inner ->
            ( { model | progress = Progress.update inner model.progress }, Cmd.none )

        ListsMsg inner ->
            let
                ( lists, cmd ) =
                    Lists.update inner model.lists
            in
            ( { model | lists = lists }, Cmd.map ListsMsg cmd )

        JsonMsg inner ->
            let
                ( json, cmd ) =
                    Json.update inner model.json
            in
            ( { model | json = json }, Cmd.map JsonMsg cmd )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Doc.page
        { title = "Data display"
        , description = "Components that show data: trees, timelines, key figures, charts, avatars, progress, list items and a JSON viewer. Each of them has loading, failed and empty states where that makes sense. The built-in texts follow the language switch in the top bar."
        }
        [ Layout.row [ Layout.justifyEnd ]
            [ Checkbox.view
                [ Checkbox.label "Simulate failures in the backend"
                , Checkbox.hint "Applies to the branches loaded in the tree, to “Load more” in the timeline, and to the first key figure."
                , Checkbox.checked model.failing
                , Checkbox.onCheck SetFailing
                ]
            ]
        , Html.map TreesMsg (Trees.view locale model.trees)
        , Html.map TimelinesMsg (Timelines.view locale model.timelines)
        , Html.map StatsMsg (Stats.view locale model.stats)

        -- Sections that only depend on the language and on a few flags are not
        -- built and compared again on every key press elsewhere on the page.
        , Html.map ChartsMsg (Html.Lazy.lazy2 Charts.view locale model.charts)
        , Html.Lazy.lazy Avatars.view locale
        , Html.map ProgressMsg (Progress.view locale model.progress)
        , Html.map ListsMsg (Html.Lazy.lazy2 Lists.view locale model.lists)
        , Html.map JsonMsg (Json.view locale model.json)
        ]
