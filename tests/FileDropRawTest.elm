module FileDropRawTest exposing (suite)

{-| `FileDrop.rawFiles` and `Form.rawFiles`: the browser's `File` values travel with
the accepted files. A test cannot make a real `File` (the events here are plain
JSON), so what is proved is the part around it: a value that is not a `File`
still gives the plain data, nothing is invented, and the real thing is walked in
a browser.
-}

import Expect
import Html.Attributes as Attr
import Json.Encode as Encode
import Klar.FileDrop as FileDrop
import Klar.Form as Form
import Klar.Form.Spec as Spec
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector


type Msg
    = Files FileDrop.Msg


contract : FileDrop.FileInfo
contract =
    { name = "contract.pdf", size = 1200, mime = "application/pdf" }


choose : FileDrop.State -> FileDrop.State
choose state =
    FileDrop.view Files [] state
        |> Query.fromHtml
        |> Query.find [ Selector.tag "input", Selector.attribute (Attr.type_ "file") ]
        |> Event.simulate
            (Event.custom "change"
                (Encode.object
                    [ ( "target"
                      , Encode.object
                            [ ( "files"
                              , Encode.list identity
                                    [ Encode.object
                                        [ ( "name", Encode.string contract.name )
                                        , ( "size", Encode.int contract.size )
                                        , ( "type", Encode.string contract.mime )
                                        ]
                                    ]
                              )
                            ]
                      )
                    ]
                )
            )
        |> Event.toResult
        |> Result.map (\(Files inner) -> FileDrop.update inner state |> Tuple.first)
        |> Result.withDefault state


suite : Test
suite =
    describe "the File values of a file field"
        [ test "a chosen file is in files, and rawFiles does not invent a File for a value that is none" <|
            \_ ->
                let
                    state =
                        choose (FileDrop.init "contract")
                in
                ( FileDrop.files state, List.length (FileDrop.rawFiles state) )
                    |> Expect.equal ( [ contract ], 0 )
        , test "a file put in with setFiles has no File" <|
            \_ ->
                FileDrop.init "contract"
                    |> FileDrop.setFiles [ contract ]
                    |> (\state -> ( FileDrop.files state, FileDrop.rawFiles state ))
                    |> Expect.equal ( [ contract ], [] )
        , test "Form.rawFiles reads the field of the form, and is empty for a field that holds none" <|
            \_ ->
                let
                    form : Form.Form () Fields Values
                    form =
                        Spec.define "s" Fields Values
                            |> Spec.with (Spec.files "Contract" |> Spec.one)
                            |> Spec.build

                    f =
                        Form.fields form
                in
                Form.init form
                    |> Form.set f.contract [ contract ]
                    |> Form.rawFiles f.contract
                    |> List.length
                    |> Expect.equal 0
        ]


type alias Fields =
    { contract : Form.Field (List FileDrop.FileInfo) }


type alias Values =
    { contract : Maybe FileDrop.FileInfo }
