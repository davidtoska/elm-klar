module Page.Gallery.NextComponents.Uploads exposing (Model, Msg, init, subscriptions, update, view)

{-| An explicit simulation of a transport-neutral upload workbench. Actual chosen
files are retained by the example; no file is read or transmitted.
-}

import File exposing (File)
import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.Ids as Ids
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Remote as Remote
import Klar.Settings exposing (Settings)
import Klar.Text as Text
import Klar.UploadQueue as Upload
import Showcase.Doc as Doc


type alias Entry =
    { id : Int, file : Upload.FileInfo, source : Maybe File, status : Upload.Status, sent : Int, active : Bool }


type alias Model =
    { staging : Upload.State, entries : List Entry, nextId : Int }


type Msg
    = Picker Upload.Msg
    | Add (List File)
    | Start Int
    | StartAll (List Int)
    | Retry Int
    | Cancel Int
    | Remove Int
    | Advance
    | InvalidProgress
    | Reset
    | NoOp


init : ( Model, Cmd Msg )
init =
    ( { staging = Upload.init "transfer-workbench"
      , entries =
            [ { id = 1, file = { name = "warehouse-orders.csv", size = 1200000, mime = "text/csv" }, source = Nothing, status = Upload.pending, sent = 0, active = False }
            , { id = 2, file = { name = "product-images.zip", size = 1000000, mime = "application/zip" }, source = Nothing, status = Upload.transferring { sent = 999999, total = Just 1000000 }, sent = 999999, active = True }
            , { id = 3, file = { name = "delivery-note.pdf", size = 40000, mime = "application/pdf" }, source = Nothing, status = Upload.failed (Remote.problem Remote.network), sent = 0, active = False }
            , { id = 4, file = { name = "supplier-catalogue.pdf", size = 250000, mime = "application/pdf" }, source = Nothing, status = Upload.completed, sent = 250000, active = False }
            , { id = 5, file = { name = "customer-attachments.zip", size = 340000, mime = "application/zip" }, source = Nothing, status = Upload.cancelled, sent = 0, active = False }
            ]
      , nextId = 6
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        focus next =
            ( next, Klar.focus "transfer-workbench" NoOp )

        start ids =
            focus
                { model
                    | entries =
                        List.map
                            (\entry ->
                                if List.member entry.id ids then
                                    { entry | status = Upload.transferring { sent = 0, total = Just entry.file.size }, active = True, sent = 0 }

                                else
                                    entry
                            )
                            model.entries
                }
    in
    case msg of
        Picker inner ->
            let
                ( staging, cmd ) =
                    Upload.update inner model.staging
            in
            ( { model | staging = staging }, Cmd.map Picker cmd )

        Add files ->
            let
                new =
                    List.indexedMap (\index file -> { id = model.nextId + index, file = { name = File.name file, size = File.size file, mime = File.mime file }, source = Just file, status = Upload.pending, sent = 0, active = False }) files
            in
            focus { model | entries = model.entries ++ new, nextId = model.nextId + List.length new, staging = Upload.clear model.staging }

        Start id ->
            start [ id ]

        StartAll ids ->
            start ids

        Retry id ->
            start [ id ]

        Cancel id ->
            focus
                { model
                    | entries =
                        List.map
                            (\entry ->
                                if entry.id == id then
                                    { entry | status = Upload.cancelled, active = False }

                                else
                                    entry
                            )
                            model.entries
                }

        Remove id ->
            focus { model | entries = List.filter (\entry -> entry.id /= id) model.entries }

        Advance ->
            ( { model
                | entries =
                    List.map
                        (\entry ->
                            if not entry.active then
                                entry

                            else if entry.sent >= entry.file.size then
                                { entry | status = Upload.completed, active = False }

                            else
                                let
                                    sent =
                                        min entry.file.size (entry.sent + 250000)
                                in
                                { entry | sent = sent, status = Upload.transferring { sent = sent, total = Just entry.file.size } }
                        )
                        model.entries
              }
            , Cmd.none
            )

        InvalidProgress ->
            ( { model
                | entries =
                    List.map
                        (\entry ->
                            if entry.id == 2 then
                                { entry | status = Upload.transferring { sent = entry.file.size + 1, total = Just entry.file.size }, active = False }

                            else
                                entry
                        )
                        model.entries
              }
            , Cmd.none
            )

        Reset ->
            init

        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


view : Settings -> Locale -> Model -> Html Msg
view _ locale model =
    Doc.section "Upload queue"
        "Choose files, inspect validation and control every transfer. The example simulates transport; no file is read or sent."
        [ Doc.example
            { title = "Validated staging and exact byte progress", description = Just "Advance the simulation once to send remaining bytes, and again to acknowledge completion. The nearly finished sample never rounds into a false completion.", code = Nothing }
            (Layout.stack [ Layout.gap 4 ]
                [ Layout.row [ Layout.gap 2, Layout.wrap ]
                    [ Button.view [ Button.small, Button.onClick Advance ] "Advance simulation"
                    , Button.view [ Button.small, Button.onClick InvalidProgress ] "Show inconsistent report"
                    , Button.view [ Button.small, Button.onClick Reset ] "Reset transfers"
                    ]
                , Text.secondary "Selection rules: PDF, CSV, ZIP or images; up to three files per staged batch; 10 MB per file. Remove rejected selections before adding accepted browser files."
                , Upload.view Picker
                    [ Upload.locale locale
                    , Upload.accept [ ".pdf", ".csv", ".zip", "image/*" ]
                    , Upload.maxSize 10000000
                    , Upload.maxFiles 3
                    , Upload.onStart Start
                    , Upload.onStartAll StartAll
                    , Upload.onRetry Retry
                    , Upload.onCancel Cancel
                    , Upload.onRemove Remove
                    ]
                    { label = "Order and product uploads"
                    , ids = Ids.int
                    , uploads = List.map (\entry -> Upload.upload { id = entry.id, file = entry.file } |> Upload.withStatus entry.status) model.entries
                    , onAdd = Add
                    }
                    model.staging
                ]
            )
        ]
