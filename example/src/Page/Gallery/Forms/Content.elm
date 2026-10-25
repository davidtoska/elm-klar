module Page.Gallery.Forms.Content exposing (Model, Msg, init, sections, update)

{-| The sections of the forms page for content with a state of its own: tags,
file choices and text that is edited in place.
-}

import Dict exposing (Dict)
import Html exposing (Html)
import Klar.FileDrop as FileDrop
import Klar.InlineEdit as InlineEdit
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote
import Klar.Switch as Switch
import Klar.TagInput as TagInput
import Klar.Text as Text
import Klar.Validate as Validate
import Page.Gallery.Forms.Common exposing (grid, narrow, readout, stack)
import Process
import Showcase.Doc as Doc
import Task



-- MODEL


{-| The state of each control is stored under the DOM id of the control.
-}
type alias Model =
    { tags : Dict String TagInput.State
    , files : Dict String FileDrop.State
    , inlines : Dict String InlineEdit.State
    , inlineFails : Bool
    }


init : Model
init =
    { tags =
        Dict.fromList
            [ ( "tags-labels", TagInput.setValues [ "Fragile", "Gift" ] (TagInput.init "tags-labels") )
            , ( "tags-notes", TagInput.setValues handlingNotes (TagInput.init "tags-notes") )
            ]
    , files =
        Dict.fromList
            [ ( "files-attachments"
              , FileDrop.setFiles
                    [ { name = "purchase-order-10412.pdf", size = 245760, mime = "application/pdf" }
                    , { name = "damaged-goods-2026-10-02.jpg", size = 1843200, mime = "image/jpeg" }
                    ]
                    (FileDrop.init "files-attachments")
              )
            , ( "files-photo"
              , FileDrop.setFiles
                    [ { name = "product-photo-warehouse-hamburg-aisle-14-shelf-3-final-version-cropped-2026-10-20.png"
                      , size = 524288
                      , mime = "image/png"
                      }
                    ]
                    (FileDrop.init "files-photo")
              )
            ]
    , inlines =
        Dict.fromList
            [ ( contactKey, InlineEdit.init contactKey "Ada Lovelace" )
            , ( "inline-long", InlineEdit.init "inline-long" longReference )
            ]
    , inlineFails = False
    }


handlingNotes : List String
handlingNotes =
    [ "Fragile: handle with care"
    , "Keep upright"
    , "Temperature controlled between 2 and 8 degrees"
    , "Hazardous goods class 3"
    , "Do not stack more than two high"
    , "Signature required on delivery"
    , "Heavy: use a pallet truck"
    , "Customs documents attached"
    , "Deliver before 10 am"
    , "Back order allowed"
    ]


{-| The long value of the "long text in a narrow place" example.
-}
longReference : String
longReference =
    "The customer wants to be called between nine and eleven, never by email. Reference number: 2026-10-20-001-NORTHWIND-ABCDEFGHIJKLMNOPQRSTUVWXYZ-0123456789"


{-| The field whose save takes time and can fail.
-}
contactKey : String
contactKey =
    "inline-contact"


tagsOf : String -> Model -> TagInput.State
tagsOf key model =
    Dict.get key model.tags |> Maybe.withDefault (TagInput.init key)


filesOf : String -> Model -> FileDrop.State
filesOf key model =
    Dict.get key model.files |> Maybe.withDefault (FileDrop.init key)


inlineOf : String -> Model -> InlineEdit.State
inlineOf key model =
    Dict.get key model.inlines |> Maybe.withDefault (InlineEdit.init key "")


{-| A failed save with its problem written in the language of the page: the
problem was made when the save failed, and is made again here so that it follows
the language switch like everything else.
-}
localizeInline : Locale -> InlineEdit.State -> InlineEdit.State
localizeInline lang state =
    if InlineEdit.isFailed state then
        InlineEdit.failed (Remote.problem Remote.network) state

    else
        state



-- UPDATE


type Msg
    = NoOp
    | TagsMsg String TagInput.Msg
    | FilesMsg String FileDrop.Msg
    | InlineMsg String InlineEdit.Msg
    | InlineSaved String (Result Remote.Problem String)
    | InlineFailsToggled Bool


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        TagsMsg key inner ->
            let
                ( state, cmd ) =
                    TagInput.update inner (tagsOf key model)
            in
            ( { model | tags = Dict.insert key state model.tags }, Cmd.map (TagsMsg key) cmd )

        FilesMsg key inner ->
            let
                ( state, cmd ) =
                    FileDrop.update inner (filesOf key model)
            in
            ( { model | files = Dict.insert key state model.files }, Cmd.map (FilesMsg key) cmd )

        InlineMsg key inner ->
            let
                before =
                    inlineOf key model

                ( state, cmd ) =
                    InlineEdit.update inner before

                startsSaving =
                    InlineEdit.isSaving state && not (InlineEdit.isSaving before)
            in
            if key == contactKey then
                ( { model | inlines = Dict.insert key state model.inlines }
                , Cmd.batch
                    [ Cmd.map (InlineMsg key) cmd
                    , if startsSaving then
                        fakeSave key model.inlineFails (InlineEdit.pending state |> Maybe.withDefault "")

                      else
                        Cmd.none
                    ]
                )

            else
                -- the other fields are saved at once
                ( { model
                    | inlines =
                        Dict.insert key
                            (if InlineEdit.isSaving state then
                                InlineEdit.saved state

                             else
                                state
                            )
                            model.inlines
                  }
                , Cmd.map (InlineMsg key) cmd
                )

        InlineSaved key (Ok _) ->
            ( { model | inlines = Dict.insert key (InlineEdit.saved (inlineOf key model)) model.inlines }, Cmd.none )

        InlineSaved key (Err problem) ->
            ( { model | inlines = Dict.insert key (InlineEdit.failed problem (inlineOf key model)) model.inlines }, Cmd.none )

        InlineFailsToggled value ->
            ( { model | inlineFails = value }, Cmd.none )


{-| The "backend" of the inline edit: it answers after a short while, and fails
when the switch of the example says so.
-}
fakeSave : String -> Bool -> String -> Cmd Msg
fakeSave key fails saved =
    Process.sleep 900
        |> Task.perform
            (\_ ->
                if fails then
                    InlineSaved key (Err (Remote.problem Remote.network))

                else
                    InlineSaved key (Ok saved)
            )



-- VIEW


sections : Locale -> Model -> List (Html Msg)
sections lang model =
    [ tagInputs lang model
    , fileDrops lang model
    , inlineEdits lang model
    ]



-- TAGS


tagInputs : Locale -> Model -> Html Msg
tagInputs lang model =
    Doc.section "Tags"
        "Free text that becomes small chips. Enter or comma adds a tag, Backspace in the empty field removes the last one, the crosses remove single tags, and pasting \"a, b, c\" gives three tags. Duplicates (ignoring case) and invalid tags are refused with a message, and their text stays in the field to be corrected. The chips are no Tab stops: arrow left at the start of the text moves to them, arrow left and right move between them, Backspace or Delete removes one, and arrow right past the last one or Escape goes back to the text."
        [ Doc.example
            { title = "Labels"
            , description = Just "At most six tags, at least two characters each. Try adding \"fragile\" twice."
            , code = Just """TagInput.view LabelsMsg
    [ TagInput.label "Labels"
    , TagInput.placeholder "Type and press Enter"
    , TagInput.maxTags 6
    , TagInput.validate (Validate.run Locale.en (Validate.minLength 2))
    ]
    model.labels

TagInput.values model.labels -- List String"""
            }
            (stack
                [ TagInput.view (TagsMsg "tags-labels")
                    [ TagInput.label "Labels"
                    , TagInput.hint "Enter or comma adds a tag. Backspace removes the last one."
                    , TagInput.placeholder "Type and press Enter"
                    , TagInput.maxTags 6
                    , TagInput.validate (Validate.run lang (Validate.minLength 2))
                    , TagInput.locale lang
                    ]
                    (tagsOf "tags-labels" model)
                , readout ("Tags: " ++ String.join " | " (TagInput.values (tagsOf "tags-labels" model)))
                ]
            )
        , Doc.example
            { title = "States"
            , description = Just "Many long tags wrap over several lines. Disabled, read-only, and with an error from the application."
            , code = Just """TagInput.view TagsMsg [ TagInput.label "Handling notes", TagInput.error "Add at least one note" ] state"""
            }
            (grid 300
                [ TagInput.view (TagsMsg "tags-notes")
                    [ TagInput.label "Handling notes"
                    , TagInput.hint "Long tags fit by wrapping to the next line."
                    , TagInput.locale lang
                    ]
                    (tagsOf "tags-notes" model)
                , TagInput.view (always NoOp)
                    [ TagInput.label "Disabled"
                    , TagInput.disabled True
                    , TagInput.locale lang
                    ]
                    (TagInput.setValues [ "Fragile", "Gift" ] (TagInput.init "tags-disabled"))
                , TagInput.view (always NoOp)
                    [ TagInput.label "Read-only"
                    , TagInput.readOnly True
                    , TagInput.locale lang
                    ]
                    (TagInput.setValues [ "Wholesale", "Spring sale" ] (TagInput.init "tags-readonly"))
                , TagInput.view (TagsMsg "tags-error")
                    [ TagInput.label "Delivery tags"
                    , TagInput.required
                    , TagInput.errorMaybe
                        (if List.isEmpty (TagInput.values (tagsOf "tags-error" model)) then
                            Just "Add at least one tag"

                         else
                            Nothing
                        )
                    , TagInput.locale lang
                    ]
                    (tagsOf "tags-error" model)
                ]
            )
        , Doc.example
            { title = "Delimiters and leaving the field"
            , description = Just "A semicolon ends a tag as well as a comma, and text that is still being typed when you leave the field is not added."
            , code = Just """TagInput.view CodesMsg
    [ TagInput.label "Product codes"
    , TagInput.delimiters [ ',', ';' ]
    , TagInput.keepDraftOnBlur
    ]
    model.codes"""
            }
            (TagInput.view (TagsMsg "tags-codes")
                [ TagInput.label "Product codes"
                , TagInput.hint "Comma or semicolon ends a code. Enter adds it too."
                , TagInput.delimiters [ ',', ';' ]
                , TagInput.keepDraftOnBlur
                , TagInput.locale lang
                ]
                (tagsOf "tags-codes" model)
            )
        ]



-- FILE DROP


fileDrops : Locale -> Model -> Html Msg
fileDrops lang model =
    let
        attachments =
            filesOf "files-attachments" model
    in
    Doc.section "File drop"
        "Drop files on the field, or use \"Choose files\" (Tab to the button, Enter or Space opens the file dialog). The files are checked against the allowed types, the largest size, the number of files and duplicates. The contents of the files are not read or sent by the library: it hands the application the name, size and type (FileDrop.files) and the browser's own File values (FileDrop.rawFiles) for a request the application makes."
        [ Doc.example
            { title = "Several files"
            , description = Just "PDF or images, at most 5 MB, up to three files. Try an .exe file or a large file to see the refusals. Refused files stay in the list with a message until you remove them."
            , code = Just """FileDrop.view AttachmentsMsg
    [ FileDrop.label "Attachments"
    , FileDrop.accept [ ".pdf", "image/*" ]
    , FileDrop.maxSize 5000000
    , FileDrop.maxFiles 3
    ]
    model.attachments

FileDrop.files model.attachments -- List FileInfo, only the accepted ones"""
            }
            (stack
                [ FileDrop.view (FilesMsg "files-attachments")
                    [ FileDrop.label "Attachments"
                    , FileDrop.accept [ ".pdf", "image/*" ]
                    , FileDrop.maxSize 5000000
                    , FileDrop.maxFiles 3
                    , FileDrop.locale lang
                    ]
                    attachments
                , readout
                    ("Accepted files: "
                        ++ String.fromInt (List.length (FileDrop.files attachments))
                        ++ ", refused: "
                        ++ String.fromInt (List.length (FileDrop.rejected attachments))
                    )
                ]
            )
        , Doc.example
            { title = "One file, compact and disabled"
            , description = Just "Without multiple a new choice replaces the old one."
            , code = Just """FileDrop.view PhotoMsg [ FileDrop.label "Photo", FileDrop.accept [ "image/*" ], FileDrop.compact ] state"""
            }
            (grid 300
                [ FileDrop.view (FilesMsg "files-photo")
                    [ FileDrop.label "Product photo"
                    , FileDrop.accept [ "image/*" ]
                    , FileDrop.maxSize 2000000
                    , FileDrop.compact
                    , FileDrop.locale lang
                    ]
                    (filesOf "files-photo" model)
                , FileDrop.view (FilesMsg "files-disabled")
                    [ FileDrop.label "Disabled"
                    , FileDrop.disabled True
                    , FileDrop.locale lang
                    ]
                    (filesOf "files-disabled" model)
                , FileDrop.view (FilesMsg "files-error")
                    [ FileDrop.label "Documentation"
                    , FileDrop.required
                    , FileDrop.errorMaybe
                        (if List.isEmpty (FileDrop.files (filesOf "files-error" model)) then
                            Just "Attach at least one document"

                         else
                            Nothing
                        )
                    , FileDrop.accept [ ".pdf" ]
                    , FileDrop.locale lang
                    ]
                    (filesOf "files-error" model)
                ]
            )
        ]



-- INLINE EDIT


inlineEdits : Locale -> Model -> Html Msg
inlineEdits lang model =
    Doc.section "Inline edit"
        "Text that can be clicked to edit (Tab to the text, Enter or Space starts editing). Enter saves, Escape cancels, and leaving the field saves. The save can take time or fail; then a spinner, a message and \"Try again\" are shown."
        [ Doc.example
            { title = "Contact with validation and saving"
            , description = Just "The name is required and at most 30 characters. Turn on \"Simulate a failure when saving\" to see the failed state with \"Try again\"."
            , code = Just """InlineEdit.view ContactMsg
    [ InlineEdit.label "Contact"
    , InlineEdit.validate (Validate.run Locale.en (Validate.all [ Validate.required, Validate.maxLength 30 ]))
    ]
    model.contact

-- update: start the save when InlineEdit.isSaving turns True,
-- then call InlineEdit.saved or InlineEdit.failed problem"""
            }
            (stack
                [ Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                    [ Text.strong "Contact:"
                    , InlineEdit.view (InlineMsg contactKey)
                        [ InlineEdit.label "Contact"
                        , InlineEdit.validate (Validate.run lang (Validate.all [ Validate.required, Validate.maxLength 30 ]))
                        , InlineEdit.maxLength 40
                        , InlineEdit.locale lang
                        ]
                        (localizeInline lang (inlineOf contactKey model))
                    ]
                , Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                    [ Text.strong "Reference:"
                    , InlineEdit.view (InlineMsg "inline-reference")
                        [ InlineEdit.label "Reference"
                        , InlineEdit.emptyText "Add reference"
                        , InlineEdit.placeholder "For example PO-2041"
                        , InlineEdit.locale lang
                        ]
                        (inlineOf "inline-reference" model)
                    ]
                , Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                    [ Text.strong "Locked:"
                    , InlineEdit.view (always NoOp)
                        [ InlineEdit.label "Warehouse"
                        , InlineEdit.disabled True
                        , InlineEdit.locale lang
                        ]
                        (InlineEdit.init "inline-disabled" "Rotterdam Hub")
                    ]
                , Switch.view
                    [ Switch.label "Simulate a failure when saving"
                    , Switch.id "inline-fails"
                    , Switch.checked model.inlineFails
                    , Switch.onToggle InlineFailsToggled
                    , Switch.locale lang
                    ]
                ]
            )
        , Doc.example
            { title = "Long text in a narrow place"
            , description = Just "Long values wrap over several lines, also without spaces."
            , code = Nothing
            }
            (narrow 340
                [ InlineEdit.view (InlineMsg "inline-long")
                    [ InlineEdit.label "Note"
                    , InlineEdit.locale lang
                    ]
                    (inlineOf "inline-long" model)
                ]
            )
        ]
