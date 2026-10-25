module UploadQueueTest exposing (suite)

import Expect
import File exposing (File)
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.FileDrop as FileDrop
import Klar.Ids as Ids
import Klar.Locale as Locale
import Klar.Remote as Remote
import Klar.UploadQueue as Upload
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as S


type UploadId
    = UploadId Int


ids : Ids.Ids UploadId
ids =
    Ids.make { toKey = \(UploadId value) -> String.fromInt value, fromKey = String.toInt >> Maybe.map UploadId }


type Msg
    = Picker Upload.Msg
    | Add (List File)
    | Start UploadId
    | StartAll (List UploadId)
    | Retry UploadId
    | Cancel UploadId
    | Remove UploadId


sample : Upload.FileInfo
sample =
    { name = "order.pdf", size = 1200, mime = "application/pdf" }


entry : Upload.Status -> Upload.Upload UploadId
entry status =
    Upload.upload { id = UploadId 7, file = sample } |> Upload.withStatus status


view : List (Upload.Attribute UploadId Msg) -> List (Upload.Upload UploadId) -> Upload.State -> Html Msg
view attributes uploads state =
    Upload.view Picker attributes { label = "Order uploads", ids = ids, uploads = uploads, onAdd = Add } state


shown : List (Upload.Attribute UploadId Msg) -> Upload.Status -> Query.Single Msg
shown attributes status =
    view attributes [ entry status ] (Upload.init "uploads") |> Query.fromHtml


button : String -> Query.Single msg -> Query.Single msg
button label =
    Query.find [ S.tag "button", S.containing [ S.text label ] ]


pick : List (Upload.Attribute UploadId Msg) -> List Upload.FileInfo -> Upload.State -> Result String Upload.State
pick attributes incoming state =
    view attributes [] state
        |> Query.fromHtml
        |> Query.find [ S.tag "input", S.attribute (Attr.type_ "file") ]
        |> Event.simulate
            (Event.custom "change"
                (Encode.object
                    [ ( "target"
                      , Encode.object
                            [ ( "files"
                              , Encode.list
                                    (\file ->
                                        Encode.object
                                            [ ( "name", Encode.string file.name ), ( "size", Encode.int file.size ), ( "type", Encode.string file.mime ) ]
                                    )
                                    incoming
                              )
                            ]
                      )
                    ]
                )
            )
        |> Event.toResult
        |> Result.andThen
            (\msg ->
                case msg of
                    Picker inner ->
                        Ok (Upload.update inner state |> Tuple.first)

                    _ ->
                        Err "Expected a picker message"
            )


suite : Test
suite =
    describe "Klar.UploadQueue"
        [ describe "Staging reuses the file picker rules"
            [ test "empty staging and queue have explicit names and empty state" <|
                \_ ->
                    view [] [] (Upload.init "uploads")
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.has [ S.id "uploads", S.attribute (Attr.tabindex -1) ]
                            , Query.has [ S.text "No files in the queue" ]
                            , Query.has [ S.tag "input", S.id "uploads-choose", S.attribute (Attr.type_ "file") ]
                            ]
            , test "a file exactly at max size is accepted" <|
                \_ ->
                    pick [ Upload.maxSize 1200 ] [ sample ] (Upload.init "uploads") |> Result.map Upload.files |> Expect.equal (Ok [ sample ])
            , test "a file one byte too large remains rejected" <|
                \_ ->
                    pick [ Upload.maxSize 1199 ] [ sample ] (Upload.init "uploads") |> Result.map (Upload.rejected >> List.map (Tuple.mapSecond FileDrop.isTooLarge)) |> Expect.equal (Ok [ ( sample, True ) ])
            , test "an uppercase extension matches without changing the filename" <|
                \_ ->
                    let
                        file =
                            { sample | name = "ORDER.PDF", mime = "" }
                    in
                    pick [ Upload.accept [ ".pdf" ] ] [ file ] (Upload.init "uploads") |> Result.map Upload.files |> Expect.equal (Ok [ file ])
            , test "MIME groups are validated for dropped or chosen files" <|
                \_ ->
                    pick [ Upload.accept [ "image/*" ] ] [ sample ] (Upload.init "uploads") |> Result.map (Upload.rejected >> List.map (Tuple.mapSecond FileDrop.isWrongType)) |> Expect.equal (Ok [ ( sample, True ) ])
            , test "files beyond the staged-batch count remain visibly rejected" <|
                \_ ->
                    let
                        second =
                            { sample | name = "second.pdf" }

                        third =
                            { sample | name = "third.pdf" }
                    in
                    pick [ Upload.maxFiles 2 ] [ sample, second, third ] (Upload.init "uploads") |> Result.map (Upload.rejected >> List.map (Tuple.mapSecond FileDrop.isTooMany)) |> Expect.equal (Ok [ ( third, True ) ])
            , test "duplicate selections are not uploaded twice" <|
                \_ ->
                    pick [] [ sample, sample ] (Upload.init "uploads") |> Result.map (Upload.rejected >> List.map (Tuple.mapSecond FileDrop.isDuplicate)) |> Expect.equal (Ok [ ( sample, True ) ])
            , test "metadata-only test events never invent a browser File" <|
                \_ ->
                    pick [] [ sample ] (Upload.init "uploads") |> Result.map (Upload.rawFiles >> List.length) |> Expect.equal (Ok 0)
            , test "clearing staging removes accepted and rejected files" <|
                \_ ->
                    pick [] [ sample, sample ] (Upload.init "uploads") |> Result.map (Upload.clear >> (\state -> ( Upload.files state, Upload.rejected state ))) |> Expect.equal (Ok ( [], [] ))
            , test "add is disabled without actual browser files" <|
                \_ ->
                    shown [] Upload.pending |> button "Add files to queue" |> Query.has [ S.disabled True ]
            , test "a stricter size rule invalidates existing staging without discarding it" <|
                \_ ->
                    case pick [ Upload.maxSize 1200 ] [ sample ] (Upload.init "uploads") of
                        Err message ->
                            Expect.fail message

                        Ok state ->
                            Expect.all
                                [ Upload.files >> Expect.equal [ sample ]
                                , \staging -> view [ Upload.maxSize 1199 ] [] staging |> Query.fromHtml |> Query.findAll [ S.attribute (Attr.attribute "role" "alert") ] |> Query.count (Expect.equal 1)
                                , \staging -> view [ Upload.maxSize 1199 ] [] staging |> Query.fromHtml |> button "Add files to queue" |> Query.has [ S.disabled True ]
                                ]
                                state
            , test "changing rules presents an explicit choose-again explanation" <|
                \_ ->
                    case pick [ Upload.accept [ ".pdf" ] ] [ sample ] (Upload.init "uploads") of
                        Err message ->
                            Expect.fail message

                        Ok state ->
                            view [ Upload.accept [ "image/*" ] ] [] state |> Query.fromHtml |> Query.has [ S.text "File rules changed. Clear the selection and choose files again before adding them." ]
            , test "switching rules back cannot admit files selected under a broader intervening policy" <|
                \_ ->
                    let
                        script =
                            { sample | name = "script.js", mime = "text/javascript" }

                        staged =
                            pick [ Upload.accept [ ".pdf" ] ] [ sample ] (Upload.init "uploads") |> Result.andThen (pick [] [ script ])
                    in
                    case staged of
                        Err message ->
                            Expect.fail message

                        Ok state ->
                            view [ Upload.accept [ ".pdf" ] ] [] state |> Query.fromHtml |> Query.has [ S.text "File rules changed. Clear the selection and choose files again before adding them." ]
            , test "semantically equivalent accept lists do not invalidate staging" <|
                \_ ->
                    case pick [ Upload.accept [ " .PDF ", "image/*" ] ] [ sample ] (Upload.init "uploads") of
                        Err message ->
                            Expect.fail message

                        Ok state ->
                            view [ Upload.accept [ "image/*", ".pdf", ".pdf" ] ] [] state |> Query.fromHtml |> Query.findAll [ S.attribute (Attr.attribute "role" "alert") ] |> Query.count (Expect.equal 0)
            , test "clearing staging allows a fresh batch under the new rules" <|
                \_ ->
                    let
                        image =
                            { sample | name = "photo.png", mime = "image/png" }

                        staged =
                            pick [ Upload.accept [ ".pdf" ] ] [ sample ] (Upload.init "uploads") |> Result.map Upload.clear |> Result.andThen (pick [ Upload.accept [ "image/*" ] ] [ image ])
                    in
                    case staged of
                        Err message ->
                            Expect.fail message

                        Ok state ->
                            view [ Upload.accept [ "image/*" ] ] [] state |> Query.fromHtml |> Query.findAll [ S.attribute (Attr.attribute "role" "alert") ] |> Query.count (Expect.equal 0)
            ]
        , describe "Transport actions carry application ids"
            [ test "pending start carries a custom id" <|
                \_ ->
                    shown [ Upload.onStart Start ] Upload.pending |> button "Start" |> Event.simulate Event.click |> Event.expect (Start (UploadId 7))
            , test "start-all contains pending ids only, preserving queue order" <|
                \_ ->
                    view [ Upload.onStartAll StartAll ]
                        [ entry Upload.pending, Upload.upload { id = UploadId 8, file = sample } |> Upload.withStatus Upload.completed, Upload.upload { id = UploadId 9, file = sample } ]
                        (Upload.init "uploads")
                        |> Query.fromHtml
                        |> button "Start pending files"
                        |> Event.simulate Event.click
                        |> Event.expect (StartAll [ UploadId 7, UploadId 9 ])
            , test "active cancel is an explicit callback" <|
                \_ ->
                    shown [ Upload.onCancel Cancel ] (Upload.transferring { sent = 10, total = Just 1200 }) |> button "Cancel" |> Event.simulate Event.click |> Event.expect (Cancel (UploadId 7))
            , test "an active transfer cannot be removed" <|
                \_ ->
                    shown [ Upload.onRemove Remove ] (Upload.transferring { sent = 10, total = Nothing }) |> Query.findAll [ S.tag "button", S.containing [ S.text "Remove" ] ] |> Query.count (Expect.equal 0)
            , test "retryable failures offer retry" <|
                \_ ->
                    shown [ Upload.onRetry Retry ] (Upload.failed (Remote.problem Remote.network)) |> button "Retry" |> Event.simulate Event.click |> Event.expect (Retry (UploadId 7))
            , test "forbidden failures do not imply that retry can help" <|
                \_ ->
                    shown [ Upload.onRetry Retry ] (Upload.failed (Remote.problem Remote.forbidden)) |> Query.findAll [ S.tag "button", S.containing [ S.text "Retry" ] ] |> Query.count (Expect.equal 0)
            , test "confirmed cancellation can be retried explicitly" <|
                \_ ->
                    shown [ Upload.onRetry Retry ] Upload.cancelled |> button "Retry" |> Event.simulate Event.click |> Event.expect (Retry (UploadId 7))
            , test "completed transfers can be removed" <|
                \_ ->
                    shown [ Upload.onRemove Remove ] Upload.completed |> button "Remove" |> Event.simulate Event.click |> Event.expect (Remove (UploadId 7))
            , test "disabled controls do not allow accidental restart" <|
                \_ ->
                    shown [ Upload.onStart Start, Upload.disabled True ] Upload.pending |> button "Start" |> Query.has [ S.disabled True ]
            , test "duplicate ids preserve every row and disable ambiguous actions" <|
                \_ ->
                    view [ Upload.onStart Start, Upload.onStartAll StartAll ] [ entry Upload.pending, entry Upload.pending ] (Upload.init "uploads")
                        |> Query.fromHtml
                        |> Expect.all
                            [ Query.findAll [ S.class "klar-upload-queue__item" ] >> Query.count (Expect.equal 2)
                            , Query.findAll [ S.tag "button", S.containing [ S.text "Start" ], S.disabled True ] >> Query.count (Expect.equal 3)
                            , Query.has [ S.text "Duplicate upload ids: transfer actions are unavailable. Every upload needs a unique id." ]
                            ]
            ]
        , describe "Progress is exact and does not manufacture completion"
            [ test "near-complete bytes retain the real denominator" <|
                \_ ->
                    shown [] (Upload.transferring { sent = 1199, total = Just 1200 })
                        |> Query.find [ S.tag "progress" ]
                        |> Expect.all
                            [ Query.has [ S.attribute (Attr.attribute "aria-valuenow" "1199") ]
                            , Query.has [ S.attribute (Attr.attribute "aria-valuemax" "1200") ]
                            ]
            , test "all bytes sent still waits for server confirmation" <|
                \_ ->
                    shown [] (Upload.transferring { sent = 1200, total = Just 1200 })
                        |> Expect.all
                            [ Query.has [ S.text "Waiting for confirmation" ], Query.hasNot [ S.text "Completed" ] ]
            , test "unknown totals are indeterminate" <|
                \_ ->
                    shown [] (Upload.transferring { sent = 12, total = Nothing }) |> Query.find [ S.tag "progress" ] |> Query.hasNot [ S.attribute (Attr.attribute "aria-valuenow" "12") ]
            , test "zero-byte files wait for confirmation without a false percentage" <|
                \_ ->
                    shown [] (Upload.transferring { sent = 0, total = Just 0 })
                        |> Expect.all
                            [ Query.has [ S.text "Waiting for confirmation" ]
                            , Query.find [ S.tag "progress" ] >> Query.hasNot [ S.attribute (Attr.attribute "aria-valuenow" "0") ]
                            ]
            , test "negative sent bytes are reported, not clamped" <|
                \_ ->
                    shown [] (Upload.transferring { sent = -1, total = Just 1200 })
                        |> Expect.all
                            [ Query.has [ S.text "Invalid progress report" ], Query.findAll [ S.tag "progress" ] >> Query.count (Expect.equal 0) ]
            , test "sent bytes exceeding total remain an error" <|
                \_ ->
                    shown [] (Upload.transferring { sent = 1201, total = Just 1200 }) |> Query.has [ S.text "Invalid progress report" ]
            , test "negative totals remain an error" <|
                \_ ->
                    shown [] (Upload.transferring { sent = 0, total = Just -1 }) |> Query.has [ S.text "Invalid progress report" ]
            , test "the progressbar has a file-specific name" <|
                \_ ->
                    shown [] (Upload.transferring { sent = 1, total = Just 3 }) |> Query.find [ S.tag "progress" ] |> Query.has [ S.attribute (Attr.attribute "aria-label" "Bytes sent: order.pdf") ]
            , test "Norwegian status and control text is built in" <|
                \_ ->
                    shown [ Upload.locale Locale.nb, Upload.onCancel Cancel ] (Upload.transferring { sent = 1200, total = Just 1200 })
                        |> Expect.all
                            [ Query.has [ S.text "Venter på bekreftelse" ], Query.has [ S.tag "button", S.containing [ S.text "Avbryt" ] ] ]
            ]
        ]
