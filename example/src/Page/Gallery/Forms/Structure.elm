module Page.Gallery.Forms.Structure exposing (Model, Msg, init, sections, update)

{-| The form layout section of the forms page: sections and columns, the error
summary, the status of a submit and the reminder of unsaved changes.
-}

import Dict exposing (Dict)
import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.Form.Layout as FormLayout
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote
import Klar.SegmentedControl as SegmentedControl
import Klar.Switch as Switch
import Klar.Text as Text
import Klar.TextInput as TextInput
import Klar.Theme exposing (Size(..))
import Klar.Validate as Validate
import Page.Gallery.Forms.Common exposing (stack)
import Process
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options
import Task



-- MODEL


type alias Model =
    { stacked : Bool
    , texts : Dict String String
    , mini : Mini
    , statusKind : Maybe String
    , status : FormLayout.Status
    , unsavedText : String
    , unsavedBaseline : String
    }


{-| The values of the small form with the error summary.
-}
type alias Mini =
    { name : String
    , email : String
    , phone : String
    , submitted : Bool
    }


init : Model
init =
    { stacked = False
    , texts =
        Dict.fromList
            [ ( "lay-first", "Ada" )
            , ( "lay-last", "Lovelace" )
            , ( "lay-email", "ada@example.com" )
            , ( "lay-street", "12 Harbour Road" )
            , ( "lay-zip", "3011 AB" )
            , ( "lay-city", "Rotterdam" )
            ]
    , mini = { name = "", email = "ada@", phone = "123", submitted = False }
    , statusKind = Just "failed"
    , status = failedStatus
    , unsavedText = "Original title"
    , unsavedBaseline = "Original title"
    }


textOf : String -> Model -> String
textOf key model =
    Dict.get key model.texts |> Maybe.withDefault ""


failedStatus : FormLayout.Status
failedStatus =
    FormLayout.Failed (Remote.problem Remote.server |> Remote.withCode "HTTP 503")


statusFor : String -> FormLayout.Status
statusFor kind =
    case kind of
        "submitting" ->
            FormLayout.Submitting

        "succeeded" ->
            FormLayout.Succeeded "The order was saved."

        "failed" ->
            failedStatus

        _ ->
            FormLayout.Idle


{-| The id of the form that owns the status line of the example.
-}
statusDemoId : String
statusDemoId =
    "status-demo"


{-| The problems of the small form, one per field.
-}
miniErrors : Locale -> Mini -> List Validate.Problem
miniErrors lang mini =
    Validate.collect lang
        [ ( "mini-name", [ Validate.required ], mini.name )
        , ( "mini-email", [ Validate.required, Validate.email ], mini.email )
        , ( "mini-phone", [ Validate.phone ], mini.phone )
        ]



-- UPDATE


type Msg
    = NoOp
    | StackedToggled Bool
    | TextChanged String String
    | MiniName String
    | MiniEmail String
    | MiniPhone String
    | MiniSubmit
    | FocusField String
    | StatusKindSelected String
    | StatusRetry
    | StatusRetried
    | StatusDismiss
    | UnsavedChanged String
    | UnsavedSave
    | UnsavedDiscard


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        StackedToggled value ->
            ( { model | stacked = value }, Cmd.none )

        TextChanged key value ->
            ( { model | texts = Dict.insert key value model.texts }, Cmd.none )

        MiniName value ->
            ( mapMini (\mini -> { mini | name = value }) model, Cmd.none )

        MiniEmail value ->
            ( mapMini (\mini -> { mini | email = value }) model, Cmd.none )

        MiniPhone value ->
            ( mapMini (\mini -> { mini | phone = value }) model, Cmd.none )

        MiniSubmit ->
            let
                mini =
                    model.mini
            in
            ( { model | mini = { mini | submitted = True } }
            , if List.isEmpty (miniErrors Locale.default mini) then
                Cmd.none

              else
                FormLayout.focusSummary "mini-form" NoOp
            )

        FocusField fieldId ->
            ( model, Klar.focus fieldId NoOp )

        StatusKindSelected kind ->
            ( { model | statusKind = Just kind, status = statusFor kind }, Cmd.none )

        StatusRetry ->
            -- "Try again" is replaced by "Saving ...": focus follows to the
            -- status region instead of falling back to the page
            ( { model | statusKind = Just "submitting", status = FormLayout.Submitting }
            , Cmd.batch
                [ Process.sleep 1100 |> Task.perform (\_ -> StatusRetried)
                , FormLayout.focusStatus statusDemoId NoOp
                ]
            )

        StatusRetried ->
            -- the answer is ignored when the example was switched to another status meanwhile
            if model.status == FormLayout.Submitting then
                ( { model | statusKind = Just "succeeded", status = statusFor "succeeded" }, Cmd.none )

            else
                ( model, Cmd.none )

        StatusDismiss ->
            -- the close button goes with the message: focus moves to the control
            -- that drives this example instead of falling back to the page
            ( { model | statusKind = Just "idle", status = FormLayout.Idle }
            , Klar.focus "status-kind" NoOp
            )

        UnsavedChanged value ->
            ( { model | unsavedText = value }, Cmd.none )

        UnsavedSave ->
            ( { model | unsavedBaseline = model.unsavedText }, Cmd.none )

        UnsavedDiscard ->
            ( { model | unsavedText = model.unsavedBaseline }, Cmd.none )


mapMini : (Mini -> Mini) -> Model -> Model
mapMini change model =
    { model | mini = change model.mini }



-- VIEW


sections : Config.Config -> Locale -> Model -> List (Html Msg)
sections playground lang model =
    [ formLayout playground lang model ]


{-| A text field of the layout example. It keeps what is typed.
-}
layoutField : Config.Config -> Model -> String -> String -> List (TextInput.Attribute Msg) -> Html Msg
layoutField playground model key label extra =
    TextInput.view
        (Options.klarTextInput playground
            (List.concat
                [ Config.keep playground "TextInput" "label" (TextInput.label label)
                , Config.keep playground "TextInput" "id" (TextInput.id key)
                , Config.keep playground "TextInput" "value" (TextInput.value (textOf key model))
                , Config.keep playground "TextInput" "onInput" (TextInput.onInput (TextChanged key))
                ]
            )
            ++ extra
        )


formLayout : Config.Config -> Locale -> Model -> Html Msg
formLayout playground lang model =
    let
        mini =
            model.mini

        errors =
            miniErrors lang mini

        shown fieldId =
            if mini.submitted then
                Validate.errorFor fieldId errors

            else
                Nothing

        dirty =
            model.unsavedText /= model.unsavedBaseline
    in
    Doc.configuredSection playground
        [ "Form.Layout" ]
        "Form layout"
        "FormLayout.view makes a form without the browser's own validation. Sections have a title and an explanation on the left and the fields on the right (above each other on a narrow screen, or with \"stacked\"). FormLayout.grid puts fields in columns. The error summary links to each field, and the link moves keyboard focus there."
        [ Doc.configuredExample playground
            [ "Form.Layout" ]
            { title = "Sections and columns"
            , description = Just "Turn on \"Stacked layout\" to see the version for narrow places such as dialogs. Below 880 pixels of width everything stacks by itself."
            , code = Just """FormLayout.view [ FormLayout.onSubmit Submit ]
    [ FormLayout.section "Contact" "Used for order confirmations."
        [ FormLayout.grid 2
            [ TextInput.view [ TextInput.label "First name" ]
            , TextInput.view [ TextInput.label "Last name" ]
            , FormLayout.fullRow (TextInput.view [ TextInput.label "Email" ])
            ]
        ]
    , FormLayout.actions [ Button.view [] "Cancel", Button.view [ Button.primary, Button.submit ] "Save" ]
    ]"""
            }
            (stack playground
                [ Switch.view
                    (Options.klarSwitch playground
                        (List.concat
                            [ Config.keep playground "Switch" "label" (Switch.label "Stacked layout")
                            , Config.keep playground "Switch" "id" (Switch.id "layout-stacked")
                            , Config.keep playground "Switch" "checked" (Switch.checked model.stacked)
                            , Config.keep playground "Switch" "onCheck" (Switch.onCheck StackedToggled)
                            ]
                        )
                    )
                , FormLayout.view
                    (Options.klarFormLayout playground (List.concat [ Config.keep playground "Form.Layout" "onSubmit" (FormLayout.onSubmit NoOp), Config.keep playground "Form.Layout" "ariaLabel" (FormLayout.ariaLabel "Example form"), Config.keep playground "Form.Layout" "locale" (FormLayout.locale lang) ])
                        ++ (if model.stacked then
                                Options.klarFormLayout playground (List.concat [ Config.keep playground "Form.Layout" "stacked" FormLayout.stacked ])

                            else
                                []
                           )
                    )
                    [ FormLayout.section "Contact"
                        "Used for order confirmations and invoices. We never share the address."
                        [ FormLayout.grid 2
                            [ layoutField playground model "lay-first" "First name" (Options.klarTextInput playground (List.concat [ Config.keep playground "TextInput" "required" TextInput.required ]))
                            , layoutField playground model "lay-last" "Last name" (Options.klarTextInput playground (List.concat [ Config.keep playground "TextInput" "required" TextInput.required ]))
                            , FormLayout.fullRow (layoutField playground model "lay-email" "Email" (Options.klarTextInput playground (List.concat [ Config.keep playground "TextInput" "email" TextInput.email ])))
                            ]
                        ]
                    , FormLayout.section "Address"
                        "Where the goods are delivered."
                        [ layoutField playground model "lay-street" "Street" []
                        , FormLayout.grid 3
                            [ layoutField playground model "lay-zip" "Postcode" []
                            , layoutField playground model "lay-city" "City" []
                            , TextInput.view (Options.klarTextInput playground (List.concat [ Config.keep playground "TextInput" "label" (TextInput.label "Country"), Config.keep playground "TextInput" "id" (TextInput.id "lay-country"), Config.keep playground "TextInput" "value" (TextInput.value "Netherlands"), Config.keep playground "TextInput" "disabled" (TextInput.disabled True) ]))
                            ]
                        ]
                    , FormLayout.actions
                        [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "ghost" Button.ghost, Config.keep playground "Button" "danger" Button.danger ])) "Delete"
                        , Layout.spacer
                        , Options.buttonView playground (Options.klarButton playground []) "Cancel"
                        , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "submit" Button.submit ])) "Save"
                        ]
                    ]
                ]
            )
        , Doc.configuredExample playground
            [ "Form.Layout" ]
            { title = "Error summary"
            , description = Just "Press \"Create\" with errors in the fields. The summary gets focus; each link moves focus to its field."
            , code = Just """FormLayout.errorSummary
    [ FormLayout.id "mini-form"
    , FormLayout.labels [ ( "mini-name", "Name" ) ]
    , FormLayout.onFocusField FocusField
    ]
    (Validate.collect Locale.en [ ( "mini-name", [ Validate.required ], model.name ) ])

-- update
FocusField fieldId ->
    ( model, Klar.focus fieldId NoOp )"""
            }
            (FormLayout.view (Options.klarFormLayout playground (List.concat [ Config.keep playground "Form.Layout" "id" (FormLayout.id "mini-form"), Config.keep playground "Form.Layout" "onSubmit" (FormLayout.onSubmit MiniSubmit), Config.keep playground "Form.Layout" "ariaLabel" (FormLayout.ariaLabel "Small form"), Config.keep playground "Form.Layout" "stacked" FormLayout.stacked ]))
                [ if mini.submitted then
                    FormLayout.errorSummary
                        (Options.klarFormLayout playground
                            (List.concat
                                [ Config.keep playground "Form.Layout" "id" (FormLayout.id "mini-form")
                                , Config.keep playground "Form.Layout" "locale" (FormLayout.locale lang)
                                , Config.keep playground "Form.Layout" "onFocusField" (FormLayout.onFocusField FocusField)
                                , Config.keep playground "Form.Layout" "labels" (FormLayout.labels [ ( "mini-name", "Name" ), ( "mini-email", "Email" ), ( "mini-phone", "Phone" ) ])
                                ]
                            )
                        )
                        errors

                  else
                    Text.text ""
                , FormLayout.grid 3
                    [ TextInput.view
                        (Options.klarTextInput playground
                            (List.concat
                                [ Config.keep playground "TextInput" "label" (TextInput.label "Name")
                                , Config.keep playground "TextInput" "id" (TextInput.id "mini-name")
                                , Config.keep playground "TextInput" "required" TextInput.required
                                , Config.keep playground "TextInput" "value" (TextInput.value mini.name)
                                , Config.keep playground "TextInput" "onInput" (TextInput.onInput MiniName)
                                , Config.keep playground "TextInput" "errorMaybe" (TextInput.errorMaybe (shown "mini-name"))
                                ]
                            )
                        )
                    , TextInput.view
                        (Options.klarTextInput playground
                            (List.concat
                                [ Config.keep playground "TextInput" "label" (TextInput.label "Email")
                                , Config.keep playground "TextInput" "id" (TextInput.id "mini-email")
                                , Config.keep playground "TextInput" "email" TextInput.email
                                , Config.keep playground "TextInput" "required" TextInput.required
                                , Config.keep playground "TextInput" "value" (TextInput.value mini.email)
                                , Config.keep playground "TextInput" "onInput" (TextInput.onInput MiniEmail)
                                , Config.keep playground "TextInput" "errorMaybe" (TextInput.errorMaybe (shown "mini-email"))
                                ]
                            )
                        )
                    , TextInput.view
                        (Options.klarTextInput playground
                            (List.concat
                                [ Config.keep playground "TextInput" "label" (TextInput.label "Phone")
                                , Config.keep playground "TextInput" "id" (TextInput.id "mini-phone")
                                , Config.keep playground "TextInput" "tel" TextInput.tel
                                , Config.keep playground "TextInput" "value" (TextInput.value mini.phone)
                                , Config.keep playground "TextInput" "onInput" (TextInput.onInput MiniPhone)
                                , Config.keep playground "TextInput" "errorMaybe" (TextInput.errorMaybe (shown "mini-phone"))
                                ]
                            )
                        )
                    ]
                , FormLayout.actions [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "submit" Button.submit ])) "Create" ]
                ]
            )
        , Doc.configuredExample playground
            [ "Form.Layout" ]
            { title = "Status of the submit"
            , description = Just "Where the submit is: nothing, saving, saved or failed. A failure is shown with an explanation, and with \"Try again\" when that can help."
            , code = Just """-- model.status : FormLayout.Status
--     = Idle | Submitting | Succeeded String | Failed Remote.Problem
FormLayout.status [ FormLayout.id "order-form", FormLayout.onRetry Retry, FormLayout.onDismiss Dismiss ] model.status"""
            }
            (stack playground
                [ SegmentedControl.view
                    (Options.klarSegmentedControl playground
                        (List.concat
                            [ Config.keep playground "SegmentedControl" "label" (SegmentedControl.label "Status")
                            , Config.keep playground "SegmentedControl" "labelHidden" SegmentedControl.labelHidden
                            , Config.keep playground "SegmentedControl" "id" (SegmentedControl.id "status-kind")
                            , Config.keep playground "SegmentedControl" "size" (SegmentedControl.size Small)
                            , Config.keep playground
                                "SegmentedControl"
                                "options"
                                (SegmentedControl.options
                                    [ SegmentedControl.option "idle" "Nothing"
                                    , SegmentedControl.option "submitting" "Saving"
                                    , SegmentedControl.option "succeeded" "Saved"
                                    , SegmentedControl.option "failed" "Failed"
                                    ]
                                )
                            , Config.keep playground "SegmentedControl" "selected" (SegmentedControl.selected (Maybe.withDefault "idle" model.statusKind))
                            , Config.keep playground "SegmentedControl" "onChange" (SegmentedControl.onChange StatusKindSelected)
                            ]
                        )
                    )
                , FormLayout.status
                    (Options.klarFormLayout playground
                        (List.concat
                            [ Config.keep playground "Form.Layout" "id" (FormLayout.id statusDemoId)
                            , Config.keep playground "Form.Layout" "onRetry" (FormLayout.onRetry StatusRetry)
                            , Config.keep playground "Form.Layout" "onDismiss" (FormLayout.onDismiss StatusDismiss)
                            , Config.keep playground "Form.Layout" "locale" (FormLayout.locale lang)
                            ]
                        )
                    )
                    model.status
                ]
            )
        , Doc.configuredExample playground
            [ "Form.Layout" ]
            { title = "Unsaved changes"
            , description = Just "The banner is shown for as long as the form differs from what is saved, and it can stick to the top while the page scrolls. The small flag takes no room while the form is clean: it fits the footer of a dialog or a drawer."
            , code = Just """FormLayout.unsavedChanges [ FormLayout.onSave Save, FormLayout.onDiscard Discard ] (model.draft /= model.saved)

FormLayout.unsavedFlag [] (model.draft /= model.saved)"""
            }
            (stack playground
                [ FormLayout.unsavedChanges
                    (Options.klarFormLayout playground
                        (List.concat
                            [ Config.keep playground "Form.Layout" "onSave" (FormLayout.onSave UnsavedSave)
                            , Config.keep playground "Form.Layout" "onDiscard" (FormLayout.onDiscard UnsavedDiscard)
                            , Config.keep playground "Form.Layout" "locale" (FormLayout.locale lang)
                            ]
                        )
                    )
                    dirty
                , TextInput.view
                    (Options.klarTextInput playground
                        (List.concat
                            [ Config.keep playground "TextInput" "label" (TextInput.label "Title")
                            , Config.keep playground "TextInput" "id" (TextInput.id "unsaved-text")
                            , Config.keep playground "TextInput" "hint" (TextInput.hint ("Saved: \"" ++ model.unsavedBaseline ++ "\""))
                            , Config.keep playground "TextInput" "value" (TextInput.value model.unsavedText)
                            , Config.keep playground "TextInput" "onInput" (TextInput.onInput UnsavedChanged)
                            ]
                        )
                    )
                , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
                    [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "primary" Button.primary, Config.keep playground "Button" "disabled" (Button.disabled (not dirty)), Config.keep playground "Button" "onClick" (Button.onClick UnsavedSave) ])) "Save"
                    , FormLayout.unsavedFlag (Options.klarFormLayout playground (List.concat [ Config.keep playground "Form.Layout" "locale" (FormLayout.locale lang) ])) dirty
                    ]
                ]
            )
        ]
