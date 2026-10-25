module FileDropTest exposing (suite)

{-| The file field beyond its rules: the reasons as values with predicates, the
announcement of a choice, rows that keep their identity, a disabled zone that
still cancels a drop, pasting, a single-file field that keeps its good file, and
the `accept` patterns that are easy to get wrong.
-}

import Expect
import Html.Attributes as Attr
import Json.Encode as Encode exposing (Value)
import Klar.FileDrop as FileDrop
import Klar.Format as Format
import Klar.Locale as Locale
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector exposing (Selector)


type Msg
    = Files FileDrop.Msg


type alias Step =
    FileDrop.State -> Result String FileDrop.State


empty : FileDrop.State
empty =
    FileDrop.init "attachments"


file : String -> Int -> String -> FileDrop.FileInfo
file name size mime =
    { name = name, size = size, mime = mime }


fileJson : FileDrop.FileInfo -> Value
fileJson info =
    Encode.object
        [ ( "name", Encode.string info.name )
        , ( "size", Encode.int info.size )
        , ( "type", Encode.string info.mime )
        ]


on : List (FileDrop.Attribute Msg) -> List Selector -> ( String, Value ) -> Step
on attributes selectors event state =
    FileDrop.view Files attributes state
        |> Query.fromHtml
        |> Query.find selectors
        |> Event.simulate event
        |> Event.toResult
        |> Result.map (\(Files inner) -> Tuple.first (FileDrop.update inner state))


zone : List Selector
zone =
    [ Selector.class "klar-filedrop__zone" ]


choose : List (FileDrop.Attribute Msg) -> List FileDrop.FileInfo -> Step
choose attributes list =
    on attributes
        [ Selector.tag "input", Selector.attribute (Attr.type_ "file") ]
        (Event.custom "change" (Encode.object [ ( "target", Encode.object [ ( "files", Encode.list fileJson list ) ] ) ]))


drop : List FileDrop.FileInfo -> ( String, Value )
drop list =
    Event.custom "drop" (Encode.object [ ( "dataTransfer", Encode.object [ ( "files", Encode.list fileJson list ) ] ) ])


paste : List FileDrop.FileInfo -> ( String, Value )
paste list =
    Event.custom "paste" (Encode.object [ ( "clipboardData", Encode.object [ ( "files", Encode.list fileJson list ) ] ) ])


steps : List Step -> FileDrop.State -> Result String FileDrop.State
steps list state =
    List.foldl (\step result -> Result.andThen step result) (Ok state) list


names : Result String FileDrop.State -> Result String (List String)
names =
    Result.map (FileDrop.values >> List.map .name)


refusals : Locale.Locale -> Result String FileDrop.State -> Result String (List String)
refusals lang =
    Result.map (FileDrop.rejected >> List.map (\( info, problem ) -> info.name ++ ": " ++ FileDrop.problemText lang problem))


announcement : List (FileDrop.Attribute Msg) -> Result String FileDrop.State -> Expect.Expectation
announcement attributes result =
    case result of
        Ok state ->
            FileDrop.view Files attributes state
                |> Query.fromHtml
                |> Query.find [ Selector.attribute (Attr.attribute "role" "status") ]
                |> Query.children []
                |> Query.count (Expect.equal 1)

        Err problem ->
            Expect.fail problem


announced : String -> List (FileDrop.Attribute Msg) -> Result String FileDrop.State -> Expect.Expectation
announced text attributes result =
    case result of
        Ok state ->
            FileDrop.view Files attributes state
                |> Query.fromHtml
                |> Query.find [ Selector.attribute (Attr.attribute "role" "status") ]
                |> Query.has [ Selector.exactText text ]

        Err problem ->
            Expect.fail problem


pdfOnly : List (FileDrop.Attribute Msg)
pdfOnly =
    [ FileDrop.accept [ ".pdf" ], FileDrop.maxSize 1000, FileDrop.maxFiles 2 ]


suite : Test
suite =
    describe "FileDrop"
        [ problemTests
        , announcementTests
        , rowTests
        , disabledTests
        , pasteTests
        , singleTests
        , acceptTests
        , chosenTests
        , dragTests
        ]


problemTests : Test
problemTests =
    describe "the reasons a file was refused"
        [ test "each reason has its predicate" <|
            \_ ->
                steps [ choose pdfOnly [ file "a.pdf" 10 "application/pdf", file "a.pdf" 10 "application/pdf", file "x.exe" 10 "", file "big.pdf" 5000 "application/pdf", file "b.pdf" 10 "application/pdf", file "c.pdf" 10 "application/pdf" ] ] empty
                    |> Result.map
                        (FileDrop.rejected
                            >> List.map
                                (\( info, problem ) ->
                                    ( info.name
                                    , [ FileDrop.isDuplicate problem, FileDrop.isWrongType problem, FileDrop.isTooLarge problem, FileDrop.isTooMany problem ]
                                    )
                                )
                        )
                    |> Expect.equal
                        (Ok
                            [ ( "a.pdf", [ True, False, False, False ] )
                            , ( "x.exe", [ False, True, False, False ] )
                            , ( "big.pdf", [ False, False, True, False ] )
                            , ( "c.pdf", [ False, False, False, True ] )
                            ]
                        )
        , test "the text names the limit that refused the file" <|
            \_ ->
                steps [ choose pdfOnly [ file "big.pdf" 5000 "application/pdf", file "a.pdf" 10 "application/pdf", file "b.pdf" 10 "application/pdf", file "c.pdf" 10 "application/pdf" ] ] empty
                    |> refusals Locale.en
                    |> Expect.equal (Ok [ "big.pdf: File is too large (max " ++ Format.bytes Locale.en 1000 ++ ")", "c.pdf: Too many files (max 2)" ])
        , test "in Norwegian" <|
            \_ ->
                steps [ choose pdfOnly [ file "x.exe" 10 "" ] ] empty
                    |> refusals Locale.nb
                    |> Expect.equal (Ok [ "x.exe: Filtypen er ikke tillatt" ])
        ]


announcementTests : Test
announcementTests =
    describe "what a choice did is said once"
        [ test "the live region is there before anything happens" <|
            \_ -> announcement [] (Ok empty)
        , test "files that were added" <|
            \_ ->
                steps [ choose [ FileDrop.multiple ] [ file "a.pdf" 10 "application/pdf", file "b.pdf" 20 "application/pdf" ] ] empty
                    |> announced "2 files added" []
        , test "one refused file is named with its reason" <|
            \_ ->
                steps [ choose pdfOnly [ file "a.pdf" 10 "application/pdf", file "x.exe" 10 "" ] ] empty
                    |> announced "1 file added. Refused: x.exe, File type not allowed" pdfOnly
        , test "several refused files are counted" <|
            \_ ->
                steps [ choose pdfOnly [ file "x.exe" 10 "", file "y.exe" 10 "" ] ] empty
                    |> announced "2 files refused" pdfOnly
        , test "a removal" <|
            \_ ->
                steps [ choose [ FileDrop.multiple ] [ file "a.pdf" 10 "application/pdf" ], on [ FileDrop.multiple ] [ Selector.attribute (Attr.attribute "aria-label" "Remove a.pdf") ] Event.click ] empty
                    |> announced "Removed a.pdf" [ FileDrop.multiple ]
        , test "a refused file is not an alert of its own" <|
            \_ ->
                steps [ choose pdfOnly [ file "x.exe" 10 "" ] ] empty
                    |> Result.map (FileDrop.view Files pdfOnly >> Query.fromHtml >> Query.findAll [ Selector.attribute (Attr.attribute "role" "alert") ] >> Query.count (Expect.equal 0))
                    |> Result.withDefault (Expect.fail "the files were not taken")
        ]


rowTests : Test
rowTests =
    describe "the rows"
        [ test "each remove button has an id of its own, for the focus after a removal" <|
            \_ ->
                steps [ choose [ FileDrop.multiple ] [ file "a.pdf" 10 "application/pdf", file "b.pdf" 20 "application/pdf" ] ] empty
                    |> Result.map
                        (FileDrop.view Files [ FileDrop.multiple ]
                            >> Query.fromHtml
                            >> Expect.all
                                [ Query.has [ Selector.id "attachments-remove-0" ]
                                , Query.has [ Selector.id "attachments-remove-1" ]
                                ]
                        )
                    |> Result.withDefault (Expect.fail "the files were not taken")
        , test "the remove button of a refused file says why it was refused" <|
            \_ ->
                steps [ choose pdfOnly [ file "x.exe" 10 "" ] ] empty
                    |> Result.map
                        (FileDrop.view Files pdfOnly
                            >> Query.fromHtml
                            >> Expect.all
                                [ Query.find [ Selector.id "attachments-remove-0" ]
                                    >> Query.has [ Selector.attribute (Attr.attribute "aria-describedby" "attachments-problem-0") ]
                                , Query.find [ Selector.id "attachments-problem-0" ]
                                    >> Query.has [ Selector.text "File type not allowed" ]
                                ]
                        )
                    |> Result.withDefault (Expect.fail "the files were not taken")
        , test "a second click on the remove button of a file that is gone removes nothing else" <|
            \_ ->
                let
                    two =
                        steps [ choose [ FileDrop.multiple ] [ file "a.pdf" 10 "application/pdf", file "b.pdf" 20 "application/pdf" ] ] empty
                            |> Result.withDefault empty

                    click state =
                        FileDrop.view Files [ FileDrop.multiple ] two
                            |> Query.fromHtml
                            |> Query.find [ Selector.id "attachments-remove-0" ]
                            |> Event.simulate Event.click
                            |> Event.toResult
                            |> Result.map (\(Files inner) -> Tuple.first (FileDrop.update inner state))
                in
                -- both clicks come from the same render, before the next one
                click two
                    |> Result.andThen click
                    |> names
                    |> Expect.equal (Ok [ "b.pdf" ])
        , test "a file keeps its id when the one before it is removed" <|
            \_ ->
                steps
                    [ choose [ FileDrop.multiple ] [ file "a.pdf" 10 "application/pdf", file "b.pdf" 20 "application/pdf" ]
                    , on [ FileDrop.multiple ] [ Selector.id "attachments-remove-0" ] Event.click
                    ]
                    empty
                    |> Result.map
                        (FileDrop.view Files [ FileDrop.multiple ]
                            >> Query.fromHtml
                            >> Query.find [ Selector.id "attachments-remove-1" ]
                            >> Query.has [ Selector.attribute (Attr.attribute "aria-label" "Remove b.pdf") ]
                        )
                    |> Result.withDefault (Expect.fail "the files were not taken")
        ]


disabledTests : Test
disabledTests =
    describe "a disabled zone"
        [ test "cancels a drop, so the browser does not open the file in place of the page" <|
            \_ ->
                FileDrop.view Files [ FileDrop.disabled True ] empty
                    |> Query.fromHtml
                    |> Query.find zone
                    |> Event.simulate (drop [ file "a.pdf" 10 "application/pdf" ])
                    |> Event.expectPreventDefault
        , test "adds nothing" <|
            \_ ->
                on [ FileDrop.disabled True ] zone (drop [ file "a.pdf" 10 "application/pdf" ]) empty
                    |> names
                    |> Expect.equal (Ok [])
        , test "keeps its file input focusable: aria-disabled, not the disabled attribute that drops the focus" <|
            \_ ->
                FileDrop.view Files [ FileDrop.disabled True ] empty
                    |> Query.fromHtml
                    |> Query.find fileInput
                    |> Expect.all
                        [ Query.has [ Selector.attribute (Attr.attribute "aria-disabled" "true") ]
                        , Query.hasNot [ Selector.attribute (Attr.disabled True) ]
                        ]
        , test "cancels the click that would open the file dialog" <|
            \_ ->
                FileDrop.view Files [ FileDrop.disabled True ] empty
                    |> Query.fromHtml
                    |> Query.find fileInput
                    |> Event.simulate Event.click
                    |> Event.expectPreventDefault
        , test "cancels Space on the file input, which opens the dialog too" <|
            \_ ->
                FileDrop.view Files [ FileDrop.disabled True ] empty
                    |> Query.fromHtml
                    |> Query.find fileInput
                    |> Event.simulate (Event.custom "keydown" (Encode.object [ ( "key", Encode.string " " ) ]))
                    |> Event.expectPreventDefault
        , test "leaves Tab alone, so the user can move on" <|
            \_ ->
                FileDrop.view Files [ FileDrop.disabled True ] empty
                    |> Query.fromHtml
                    |> Query.find fileInput
                    |> Event.simulate (Event.custom "keydown" (Encode.object [ ( "key", Encode.string "Tab" ) ]))
                    |> Event.toResult
                    |> Expect.err
        , test "a choice that arrives after it was disabled adds nothing" <|
            \_ ->
                choose [ FileDrop.disabled True ] [ file "a.pdf" 10 "application/pdf" ] empty
                    |> Expect.err
        , test "an enabled file input has no aria-disabled" <|
            \_ ->
                FileDrop.view Files [] empty
                    |> Query.fromHtml
                    |> Query.find fileInput
                    |> Query.hasNot [ Selector.attribute (Attr.attribute "aria-disabled" "true") ]
        ]


fileInput : List Selector
fileInput =
    [ Selector.tag "input", Selector.attribute (Attr.type_ "file") ]


pasteTests : Test
pasteTests =
    describe "pasting"
        [ test "files on the clipboard are added" <|
            \_ ->
                on [ FileDrop.multiple ] zone (paste [ file "screenshot.png" 3000 "image/png" ]) empty
                    |> names
                    |> Expect.equal (Ok [ "screenshot.png" ])
        , test "they are checked like the others" <|
            \_ ->
                on [ FileDrop.accept [ ".pdf" ] ] zone (paste [ file "screenshot.png" 3000 "image/png" ]) empty
                    |> refusals Locale.en
                    |> Expect.equal (Ok [ "screenshot.png: File type not allowed" ])
        , test "text on the clipboard is left alone" <|
            \_ -> on [] zone (paste []) empty |> Expect.err
        ]


singleTests : Test
singleTests =
    describe "a single-file field"
        [ test "a refused file does not throw the good one away" <|
            \_ ->
                steps [ choose [ FileDrop.accept [ ".pdf" ] ] [ file "a.pdf" 10 "application/pdf" ], choose [ FileDrop.accept [ ".pdf" ] ] [ file "x.exe" 10 "" ] ] empty
                    |> Result.map (\state -> ( FileDrop.values state |> List.map .name, FileDrop.rejected state |> List.map (Tuple.first >> .name) ))
                    |> Expect.equal (Ok ( [ "a.pdf" ], [ "x.exe" ] ))
        , test "the next good file replaces both" <|
            \_ ->
                steps
                    [ choose [ FileDrop.accept [ ".pdf" ] ] [ file "a.pdf" 10 "application/pdf" ]
                    , choose [ FileDrop.accept [ ".pdf" ] ] [ file "x.exe" 10 "" ]
                    , choose [ FileDrop.accept [ ".pdf" ] ] [ file "b.pdf" 10 "application/pdf" ]
                    ]
                    empty
                    |> Result.map (\state -> ( FileDrop.values state |> List.map .name, FileDrop.hasProblems state ))
                    |> Expect.equal (Ok ( [ "b.pdf" ], False ))
        ]


acceptTests : Test
acceptTests =
    describe "accept"
        [ test "a bare word is an extension" <|
            \_ ->
                steps [ choose [ FileDrop.accept [ "pdf" ], FileDrop.multiple ] [ file "a.PDF" 10 "application/pdf", file "b.txt" 10 "text/plain" ] ] empty
                    |> names
                    |> Expect.equal (Ok [ "a.PDF" ])
        , test "the file dialog gets it with its point" <|
            \_ ->
                FileDrop.view Files [ FileDrop.accept [ "pdf", "image/*" ] ] empty
                    |> Query.fromHtml
                    |> Query.find [ Selector.tag "input" ]
                    |> Query.has [ Selector.attribute (Attr.accept ".pdf,image/*") ]
        , test "the rules write it in capitals" <|
            \_ ->
                FileDrop.view Files [ FileDrop.accept [ "pdf" ] ] empty
                    |> Query.fromHtml
                    |> Query.has [ Selector.text "Allowed types: PDF" ]
        , test "a photo without a media type is still an image" <|
            \_ ->
                steps [ choose [ FileDrop.accept [ "image/*" ] ] [ file "IMG_0042.HEIC" 10 "" ] ] empty
                    |> names
                    |> Expect.equal (Ok [ "IMG_0042.HEIC" ])
        , test "a PDF without a media type still matches application/pdf" <|
            \_ ->
                steps [ choose [ FileDrop.accept [ "application/pdf" ] ] [ file "scan.pdf" 10 "" ] ] empty
                    |> names
                    |> Expect.equal (Ok [ "scan.pdf" ])
        , test "a file without an extension or a type is not an image" <|
            \_ ->
                steps [ choose [ FileDrop.accept [ "image/*" ] ] [ file "README" 10 "" ] ] empty
                    |> names
                    |> Expect.equal (Ok [])
        ]


chosenTests : Test
chosenTests =
    describe "chosen"
        [ test "leaves out the files that came from the application, which have no File" <|
            \_ ->
                empty
                    |> FileDrop.setValues [ file "server.pdf" 10 "application/pdf" ]
                    |> FileDrop.chosen
                    |> List.length
                    |> Expect.equal 0
        ]


dragTests : Test
dragTests =
    let
        drag name types =
            Event.custom name (Encode.object [ ( "dataTransfer", Encode.object [ ( "types", Encode.list Encode.string types ) ] ) ])

        lit result =
            case result of
                Ok state ->
                    FileDrop.view Files [] state
                        |> Query.fromHtml
                        |> Query.has [ Selector.class "klar-filedrop--over" ]

                Err problem ->
                    Expect.fail problem
    in
    describe "dragging over the zone"
        [ test "files being dragged light it up" <|
            \_ -> on [] zone (drag "dragenter" [ "Files" ]) empty |> lit
        , test "text being dragged does not" <|
            \_ -> on [] zone (drag "dragenter" [ "text/plain" ]) empty |> Expect.err
        , test "leaving the zone puts the light out" <|
            \_ ->
                steps [ on [] zone (drag "dragenter" [ "Files" ]), on [] zone (drag "dragleave" []) ] empty
                    |> Result.map (FileDrop.view Files [] >> Query.fromHtml >> Query.hasNot [ Selector.class "klar-filedrop--over" ])
                    |> Result.withDefault (Expect.fail "the zone did not take the drag")
        , test "leaving a child of the zone does not, while the zone itself is still entered" <|
            \_ ->
                steps [ on [] zone (drag "dragenter" [ "Files" ]), on [] zone (drag "dragenter" [ "Files" ]), on [] zone (drag "dragleave" []) ] empty
                    |> lit
        , test "a drop puts the light out" <|
            \_ ->
                steps [ on [] zone (drag "dragenter" [ "Files" ]), on [] zone (drop [ file "a.pdf" 10 "application/pdf" ]) ] empty
                    |> Result.map (FileDrop.view Files [] >> Query.fromHtml >> Query.hasNot [ Selector.class "klar-filedrop--over" ])
                    |> Result.withDefault (Expect.fail "the zone did not take the drop")
        ]
