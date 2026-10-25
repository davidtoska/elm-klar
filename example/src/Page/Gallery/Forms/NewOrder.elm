module Page.Gallery.Forms.NewOrder exposing (Model, Msg, init, sections, update)

{-| The complete example of the forms page: a "new order" form that uses the
controls, the validators and the form layout together.
-}

import Api.Types exposing (allPriorities, priorityLabel)
import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.Card as Card
import Klar.Checkbox as Checkbox
import Klar.FileDrop as FileDrop
import Klar.Form.Layout as FormLayout
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.NumberInput as NumberInput
import Klar.Radio as Radio
import Klar.Remote as Remote
import Klar.SegmentedControl as SegmentedControl
import Klar.Slider as Slider
import Klar.Switch as Switch
import Klar.TagInput as TagInput
import Klar.Text as Text
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Klar.Theme exposing (Size(..))
import Klar.Validate as Validate
import Process
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options
import Showcase.Sample as Sample
import Task



-- MODEL


type alias Model =
    { customer : String
    , contact : String
    , email : String
    , phone : String
    , orderDate : String
    , method : Maybe String
    , priority : Maybe String
    , discount : Float
    , deposit : NumberInput.State
    , notifyEmail : Bool
    , notifySms : Bool
    , labels : TagInput.State
    , note : String
    , attachments : FileDrop.State
    , accepted : Bool

    -- where the user has been and what the submit is doing
    , touched : List String
    , submitted : Bool
    , status : FormLayout.Status
    , simulateFailure : Bool
    , baseline : Snapshot
    }


{-| The values of the form without the state of the controls, to tell whether
anything has changed since the form was loaded or saved.
-}
type alias Snapshot =
    { customer : String
    , contact : String
    , email : String
    , phone : String
    , orderDate : String
    , method : Maybe String
    , priority : Maybe String
    , discount : Float
    , deposit : Maybe Float
    , notifyEmail : Bool
    , notifySms : Bool
    , labels : List String
    , note : String
    , attachments : List FileDrop.FileInfo
    , accepted : Bool
    }


emptySnapshot : Snapshot
emptySnapshot =
    { customer = ""
    , contact = ""
    , email = ""
    , phone = ""
    , orderDate = ""
    , method = Nothing
    , priority = Just "normal"
    , discount = 10
    , deposit = Nothing
    , notifyEmail = True
    , notifySms = False
    , labels = []
    , note = ""
    , attachments = []
    , accepted = False
    }


snapshot : Model -> Snapshot
snapshot order =
    { customer = order.customer
    , contact = order.contact
    , email = order.email
    , phone = order.phone
    , orderDate = order.orderDate
    , method = order.method
    , priority = order.priority
    , discount = order.discount
    , deposit = NumberInput.value order.deposit
    , notifyEmail = order.notifyEmail
    , notifySms = order.notifySms
    , labels = TagInput.values order.labels
    , note = order.note
    , attachments = FileDrop.values order.attachments
    , accepted = order.accepted
    }


fromSnapshot : Snapshot -> Model
fromSnapshot saved =
    { customer = saved.customer
    , contact = saved.contact
    , email = saved.email
    , phone = saved.phone
    , orderDate = saved.orderDate
    , method = saved.method
    , priority = saved.priority
    , discount = saved.discount
    , deposit = NumberInput.setValue saved.deposit (NumberInput.init depositId)
    , notifyEmail = saved.notifyEmail
    , notifySms = saved.notifySms
    , labels = TagInput.setValues saved.labels (TagInput.init labelsId)
    , note = saved.note
    , attachments = FileDrop.setValues saved.attachments (FileDrop.init attachmentsId)
    , accepted = saved.accepted
    , touched = []
    , submitted = False
    , status = FormLayout.Idle
    , simulateFailure = False
    , baseline = saved
    }


init : Model
init =
    fromSnapshot emptySnapshot



-- FIELD IDS


formId : String
formId =
    "new-order-form"


customerId : String
customerId =
    "new-order-customer"


contactId : String
contactId =
    "new-order-contact"


emailId : String
emailId =
    "new-order-email"


phoneId : String
phoneId =
    "new-order-phone"


dateId : String
dateId =
    "new-order-date"


methodId : String
methodId =
    "new-order-method"


depositId : String
depositId =
    "new-order-deposit"


labelsId : String
labelsId =
    "new-order-labels"


attachmentsId : String
attachmentsId =
    "new-order-attachments"


termsId : String
termsId =
    "new-order-terms"


submitId : String
submitId =
    "new-order-submit"


{-| The order of the fields in the form, to list the problems in that order.
-}
fieldOrder : List String
fieldOrder =
    [ customerId
    , contactId
    , emailId
    , phoneId
    , dateId
    , methodId
    , depositId
    , attachmentsId
    , termsId
    ]


fieldLabels : List ( String, String )
fieldLabels =
    [ ( customerId, "Customer" )
    , ( contactId, "Contact name" )
    , ( emailId, "Email" )
    , ( phoneId, "Phone" )
    , ( dateId, "Order date" )
    , ( methodId, "Shipping method" )
    , ( depositId, "Deposit" )
    , ( attachmentsId, "Attachments" )
    , ( termsId, "Terms" )
    ]


{-| Every problem in the form right now, in the order of the fields. The text
fields are checked with validators; the other controls know their own rules.
-}
errorsOf : Locale -> Model -> List Validate.Problem
errorsOf lang order =
    let
        fromText =
            Validate.collect lang
                [ ( customerId, [ Validate.required, Validate.maxLength 60 ], order.customer )
                , ( contactId, [ Validate.required, Validate.maxLength 40 ], order.contact )
                , ( emailId, [ Validate.required, Validate.email, Validate.maxLength 80 ], order.email )
                , ( phoneId, [ Validate.when order.notifySms Validate.required, Validate.phone ], order.phone )
                , ( dateId, [ Validate.required, Validate.date, Validate.notInFuture Sample.today ], order.orderDate )
                ]

        fromControls =
            List.filterMap identity
                [ if order.method == Nothing then
                    Just { field = methodId, message = "Choose a shipping method" }

                  else
                    Nothing
                , if NumberInput.isValid order.deposit then
                    Nothing

                  else
                    Just { field = depositId, message = "The deposit must be a number between 0 and 100\u{00A0}000" }
                , if FileDrop.hasProblems order.attachments then
                    Just { field = attachmentsId, message = "Remove the files that cannot be used" }

                  else
                    Nothing
                , if order.accepted then
                    Nothing

                  else
                    Just { field = termsId, message = "You must accept the terms of sale" }
                ]
    in
    (fromText ++ fromControls)
        |> List.sortBy (\error -> indexOf error.field fieldOrder)


indexOf : String -> List String -> Int
indexOf needle haystack =
    haystack
        |> List.indexedMap Tuple.pair
        |> List.filter (\( _, item ) -> item == needle)
        |> List.head
        |> Maybe.map Tuple.first
        |> Maybe.withDefault 999


touch : String -> Model -> Model
touch fieldId order =
    if List.member fieldId order.touched then
        order

    else
        { order | touched = fieldId :: order.touched }



-- UPDATE


type Msg
    = NoOp
    | CustomerChanged String
    | ContactChanged String
    | EmailChanged String
    | PhoneChanged String
    | DateChanged String
    | Touched String
    | MethodSelected String
    | PrioritySelected String
    | DiscountChanged Float
    | DepositMsg NumberInput.Msg
    | NotifyEmailToggled Bool
    | NotifySmsToggled Bool
    | LabelsMsg TagInput.Msg
    | NoteChanged String
    | AttachmentsMsg FileDrop.Msg
    | AcceptedToggled Bool
    | Submit
    | SubmitFinished
    | Discard
    | DismissStatus
    | SimulateFailureToggled Bool
    | FocusField String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg order =
    case msg of
        NoOp ->
            ( order, Cmd.none )

        CustomerChanged value ->
            ( { order | customer = value }, Cmd.none )

        ContactChanged value ->
            ( { order | contact = value }, Cmd.none )

        EmailChanged value ->
            ( { order | email = value }, Cmd.none )

        PhoneChanged value ->
            ( { order | phone = value }, Cmd.none )

        DateChanged value ->
            ( { order | orderDate = value }, Cmd.none )

        Touched fieldId ->
            ( touch fieldId order, Cmd.none )

        MethodSelected value ->
            ( touch methodId { order | method = Just value }, Cmd.none )

        PrioritySelected value ->
            ( { order | priority = Just value }, Cmd.none )

        DiscountChanged value ->
            ( { order | discount = value }, Cmd.none )

        DepositMsg inner ->
            let
                ( state, cmd ) =
                    NumberInput.update inner order.deposit
            in
            ( { order | deposit = state }, Cmd.map DepositMsg cmd )

        NotifyEmailToggled value ->
            ( { order | notifyEmail = value }, Cmd.none )

        NotifySmsToggled value ->
            ( { order | notifySms = value }, Cmd.none )

        LabelsMsg inner ->
            let
                ( state, cmd ) =
                    TagInput.update inner order.labels
            in
            ( { order | labels = state }, Cmd.map LabelsMsg cmd )

        NoteChanged value ->
            ( { order | note = value }, Cmd.none )

        AttachmentsMsg inner ->
            let
                ( state, cmd ) =
                    FileDrop.update inner order.attachments
            in
            ( { order | attachments = state }, Cmd.map AttachmentsMsg cmd )

        AcceptedToggled value ->
            ( touch termsId { order | accepted = value }, Cmd.none )

        Submit ->
            if order.status == FormLayout.Submitting then
                ( order, Cmd.none )

            else if List.isEmpty (errorsOf Locale.default order) then
                ( { order | submitted = True, status = FormLayout.Submitting }
                , Cmd.batch
                    [ Process.sleep 1400 |> Task.perform (\_ -> SubmitFinished)
                    , case order.status of
                        -- "Try again" is about to be replaced by "Saving ...":
                        -- focus follows to the status region
                        FormLayout.Failed _ ->
                            FormLayout.focusStatus formId NoOp

                        _ ->
                            Cmd.none
                    ]
                )

            else
                ( { order | submitted = True, status = FormLayout.Idle }
                , FormLayout.focusSummary formId NoOp
                )

        SubmitFinished ->
            if order.simulateFailure then
                ( { order | status = FormLayout.Failed (Remote.problem Remote.server |> Remote.withCode "HTTP 503") }
                , Cmd.none
                )

            else
                ( { order
                    | status = FormLayout.Succeeded "The order was placed."
                    , baseline = snapshot order
                    , submitted = False
                    , touched = []
                  }
                , Cmd.none
                )

        Discard ->
            let
                restored =
                    fromSnapshot order.baseline
            in
            ( { restored | simulateFailure = order.simulateFailure }, Cmd.none )

        DismissStatus ->
            -- the close button goes with the message: focus moves to the button
            -- that sent the form
            ( { order | status = FormLayout.Idle }, Klar.focus submitId NoOp )

        SimulateFailureToggled value ->
            ( { order | simulateFailure = value }, Cmd.none )

        FocusField fieldId ->
            ( order, Klar.focus fieldId NoOp )



-- VIEW


sections : Config.Config -> Locale -> Model -> List (Html Msg)
sections playground lang order =
    [ newOrder playground lang order ]


priorityKey : Api.Types.Priority -> String
priorityKey priority =
    String.toLower (priorityLabel priority)


newOrder : Config.Config -> Locale -> Model -> Html Msg
newOrder playground lang order =
    let
        errors =
            errorsOf lang order

        isShown fieldId =
            order.submitted || List.member fieldId order.touched

        shown fieldId =
            if isShown fieldId then
                Validate.errorFor fieldId errors

            else
                Nothing

        dirty =
            snapshot order /= order.baseline

        submitting =
            order.status == FormLayout.Submitting

        text fieldId label toMsg value extra =
            TextInput.view
                (Options.klarTextInput playground
                    (List.concat
                        [ Config.keep playground "TextInput" "label" (TextInput.label label)
                        , Config.keep playground "TextInput" "id" (TextInput.id fieldId)
                        , Config.keep playground "TextInput" "value" (TextInput.value value)
                        , Config.keep playground "TextInput" "onInput" (TextInput.onInput toMsg)
                        , Config.keep playground "TextInput" "onBlur" (TextInput.onBlur (Touched fieldId))
                        , Config.keep playground "TextInput" "errorMaybe" (TextInput.errorMaybe (shown fieldId))
                        ]
                    )
                    ++ extra
                )

        formAttributes =
            Options.klarFormLayout playground (List.concat [ Config.keep playground "Form.Layout" "id" (FormLayout.id formId), Config.keep playground "Form.Layout" "locale" (FormLayout.locale lang) ])
    in
    Doc.configuredSection playground
        [ "Form.Layout" ]
        "Complete example: new order"
        "All the controls in one form. The fields are checked when you leave them and when you submit. Problems give a summary at the top with links to the fields. The submit is a fake request (1.4 seconds) that can succeed or fail. When you change something, the banner about unsaved changes appears."
        [ Doc.configuredExample playground
            [ "Form.Layout" ]
            { title = "New order"
            , description = Just "Try to submit the empty form. Fill it in, turn on \"Simulate a failure\" and submit to see the error and \"Try again\"."
            , code = Just """-- customerFields, deliveryFields ... are functions of your own: each returns
-- the controls of one section (TextInput, Radio, Slider, NumberInput, Switch,
-- TagInput, TextArea, FileDrop, Checkbox)
FormLayout.view [ FormLayout.id "new-order-form", FormLayout.onSubmit Submit ]
    [ FormLayout.unsavedChanges [ FormLayout.onSave Submit, FormLayout.onDiscard Discard, FormLayout.sticky ] dirty
    , FormLayout.errorSummary [ FormLayout.id "new-order-form", FormLayout.onFocusField FocusField, FormLayout.labels labels ] errors
    , FormLayout.section "Customer" "Who orders." [ customerFields model errors ]
    , FormLayout.section "Delivery" "How the goods are shipped." [ deliveryFields model errors ]
    , FormLayout.section "Notifications and notes" "Updates and a note." [ notificationFields model ]
    , FormLayout.section "Attachments and terms" "Documents and consent." [ attachmentFields model errors ]
    , FormLayout.stickyActions
        [ FormLayout.status [ FormLayout.id "new-order-form", FormLayout.onRetry Submit ] model.status
        , Layout.spacer
        , Button.view [ Button.primary, Button.submit ] "Place order"
        ]
    ]"""
            }
            (FormLayout.view
                (formAttributes ++ Options.klarFormLayout playground (List.concat [ Config.keep playground "Form.Layout" "onSubmit" (FormLayout.onSubmit Submit), Config.keep playground "Form.Layout" "ariaLabel" (FormLayout.ariaLabel "New order") ]))
                [ FormLayout.unsavedChanges
                    (formAttributes
                        ++ Options.klarFormLayout playground
                            (List.concat
                                [ Config.keep playground "Form.Layout" "onSave" (FormLayout.onSave Submit)
                                , Config.keep playground "Form.Layout" "onDiscard" (FormLayout.onDiscard Discard)
                                , Config.keep playground "Form.Layout" "saving" (FormLayout.saving submitting)
                                , Config.keep playground "Form.Layout" "sticky" FormLayout.sticky
                                ]
                            )
                    )
                    dirty
                , if order.submitted then
                    FormLayout.errorSummary
                        (formAttributes ++ Options.klarFormLayout playground (List.concat [ Config.keep playground "Form.Layout" "labels" (FormLayout.labels fieldLabels), Config.keep playground "Form.Layout" "onFocusField" (FormLayout.onFocusField FocusField) ]))
                        errors

                  else
                    Text.text ""
                , FormLayout.section "Customer"
                    "Who orders and how to reach them. A phone number is required when SMS updates are on."
                    [ FormLayout.grid 2
                        [ text customerId "Customer" CustomerChanged order.customer (Options.klarTextInput playground (List.concat [ Config.keep playground "TextInput" "required" TextInput.required, Config.keep playground "TextInput" "autocomplete" (TextInput.autocomplete "organization") ]))
                        , text contactId "Contact name" ContactChanged order.contact (Options.klarTextInput playground (List.concat [ Config.keep playground "TextInput" "required" TextInput.required, Config.keep playground "TextInput" "autocomplete" (TextInput.autocomplete "name") ]))
                        , FormLayout.fullRow
                            (text emailId "Email" EmailChanged order.email (Options.klarTextInput playground (List.concat [ Config.keep playground "TextInput" "email" TextInput.email, Config.keep playground "TextInput" "required" TextInput.required, Config.keep playground "TextInput" "placeholder" (TextInput.placeholder "name@example.com"), Config.keep playground "TextInput" "autocomplete" (TextInput.autocomplete "email") ])))
                        , text phoneId
                            "Phone"
                            PhoneChanged
                            order.phone
                            (Options.klarTextInput playground
                                (List.concat
                                    [ Config.keep playground "TextInput" "tel" TextInput.tel
                                    , Config.keep playground "TextInput" "hint" (TextInput.hint "With country code, for example +44 20 7946 0958")
                                    , [ if order.notifySms then
                                            TextInput.required

                                        else
                                            TextInput.optionalText "(optional)"
                                      ]
                                    ]
                                )
                            )
                        , text dateId "Order date" DateChanged order.orderDate (Options.klarTextInput playground (List.concat [ Config.keep playground "TextInput" "required" TextInput.required, Config.keep playground "TextInput" "placeholder" (TextInput.placeholder "dd.mm.yyyy"), Config.keep playground "TextInput" "hint" (TextInput.hint "For example 14.10.2026, not later than today") ]))
                        ]
                    ]
                , FormLayout.section "Delivery"
                    "How the goods are shipped, how urgent the order is and what is paid up front."
                    [ Radio.view
                        (Options.klarRadio playground
                            (List.concat
                                [ Config.keep playground "Radio" "label" (Radio.label "Shipping method")
                                , Config.keep playground "Radio" "id" (Radio.id methodId)
                                , Config.keep playground "Radio" "required" Radio.required
                                , Config.keep playground
                                    "Radio"
                                    "options"
                                    (Radio.options
                                        [ Radio.option "standard" "Standard" |> Radio.withDescription "Three to five working days."
                                        , Radio.option "express" "Express" |> Radio.withDescription "The next working day, for orders before 2 pm."
                                        , Radio.option "pickup" "Pick up" |> Radio.withDescription "The customer collects the goods at the warehouse."
                                        ]
                                    )
                                , Config.keep playground "Radio" "selected" (Radio.selected order.method)
                                , Config.keep playground "Radio" "onChange" (Radio.onChange MethodSelected)
                                , Config.keep playground "Radio" "errorMaybe" (Radio.errorMaybe (shown methodId))
                                ]
                            )
                        )
                    , SegmentedControl.view
                        (Options.klarSegmentedControl playground
                            (List.concat
                                [ Config.keep playground "SegmentedControl" "label" (SegmentedControl.label "Priority")
                                , Config.keep playground "SegmentedControl" "id" (SegmentedControl.id "new-order-priority")
                                , Config.keep playground
                                    "SegmentedControl"
                                    "options"
                                    (SegmentedControl.options
                                        (List.map (\priority -> SegmentedControl.option (priorityKey priority) (priorityLabel priority)) allPriorities)
                                    )
                                , Config.keep playground "SegmentedControl" "selected" (SegmentedControl.selected (Maybe.withDefault "normal" order.priority))
                                , Config.keep playground "SegmentedControl" "onChange" (SegmentedControl.onChange PrioritySelected)
                                ]
                            )
                        )
                    , Slider.view
                        (Options.klarSlider playground
                            (List.concat
                                [ Config.keep playground "Slider" "label" (Slider.label "Discount")
                                , Config.keep playground "Slider" "id" (Slider.id "new-order-discount")
                                , Config.keep playground "Slider" "hint" (Slider.hint "Approved by the account owner. Steps of 5 points.")
                                , Config.keep playground "Slider" "min" (Slider.min 0)
                                , Config.keep playground "Slider" "max" (Slider.max 50)
                                , Config.keep playground "Slider" "step" (Slider.step 5)
                                , Config.keep playground "Slider" "value" (Slider.value order.discount)
                                , Config.keep playground "Slider" "onInput" (Slider.onInput DiscountChanged)
                                , Config.keep playground "Slider" "unit" (Slider.unit "%")
                                , Config.keep playground "Slider" "marks" (Slider.marks [ ( 0, "None" ), ( 25, "25 %" ), ( 50, "Maximum" ) ])
                                , Config.keep playground "Slider" "locale" (Slider.locale lang)
                                ]
                            )
                        )
                    , NumberInput.view DepositMsg
                        (Options.klarNumberInput playground
                            (List.concat
                                [ Config.keep playground "NumberInput" "label" (NumberInput.label "Deposit")
                                , Config.keep playground "NumberInput" "hint" (NumberInput.hint "Between 0 and 100\u{00A0}000.")
                                , Config.keep playground "NumberInput" "min" (NumberInput.min 0)
                                , Config.keep playground "NumberInput" "max" (NumberInput.max 100000)
                                , Config.keep playground "NumberInput" "step" (NumberInput.step 50)
                                , Config.keep playground "NumberInput" "decimals" (NumberInput.decimals 2)
                                , Config.keep playground "NumberInput" "grouped" NumberInput.grouped
                                , Config.keep playground "NumberInput" "prefixText" (NumberInput.prefixText "$")
                                , Config.keep playground "NumberInput" "optionalText" (NumberInput.optionalText "(optional)")
                                , Config.keep playground
                                    "NumberInput"
                                    "errorMaybe"
                                    (NumberInput.errorMaybe
                                        (if NumberInput.isTouched order.deposit || order.submitted then
                                            Validate.errorFor depositId errors

                                         else
                                            Nothing
                                        )
                                    )
                                , Config.keep playground "NumberInput" "locale" (NumberInput.locale lang)
                                ]
                            )
                        )
                        order.deposit
                    ]
                , FormLayout.section "Notifications and notes"
                    "Updates about the order, labels and a free note."
                    [ Card.view (Options.klarCard playground (List.concat [ Config.keep playground "Card" "title" (Card.title "Updates") ]))
                        [ Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 4) ]))
                            [ Switch.view
                                (Options.klarSwitch playground
                                    (List.concat
                                        [ Config.keep playground "Switch" "label" (Switch.label "Email updates")
                                        , Config.keep playground "Switch" "id" (Switch.id "new-order-notify-email")
                                        , Config.keep playground "Switch" "hint" (Switch.hint "Status changes and reminders.")
                                        , Config.keep playground "Switch" "controlAtEnd" Switch.controlAtEnd
                                        , Config.keep playground "Switch" "checked" (Switch.checked order.notifyEmail)
                                        , Config.keep playground "Switch" "onCheck" (Switch.onCheck NotifyEmailToggled)
                                        ]
                                    )
                                )
                            , Layout.divider
                            , Switch.view
                                (Options.klarSwitch playground
                                    (List.concat
                                        [ Config.keep playground "Switch" "label" (Switch.label "SMS updates")
                                        , Config.keep playground "Switch" "id" (Switch.id "new-order-notify-sms")
                                        , Config.keep playground "Switch" "hint" (Switch.hint "Needs a phone number.")
                                        , Config.keep playground "Switch" "controlAtEnd" Switch.controlAtEnd
                                        , Config.keep playground "Switch" "checked" (Switch.checked order.notifySms)
                                        , Config.keep playground "Switch" "onCheck" (Switch.onCheck NotifySmsToggled)
                                        ]
                                    )
                                )
                            ]
                        ]
                    , TagInput.view LabelsMsg
                        (Options.klarTagInput playground
                            (List.concat
                                [ Config.keep playground "TagInput" "label" (TagInput.label "Labels")
                                , Config.keep playground "TagInput" "hint" (TagInput.hint "Enter or comma adds a tag.")
                                , Config.keep playground "TagInput" "placeholder" (TagInput.placeholder "Type and press Enter")
                                , Config.keep playground "TagInput" "maxTags" (TagInput.maxTags 8)
                                , Config.keep playground "TagInput" "validate" (TagInput.validate (Validate.run lang (Validate.minLength 2)))
                                , Config.keep playground "TagInput" "optionalText" (TagInput.optionalText "(optional)")
                                , Config.keep playground "TagInput" "locale" (TagInput.locale lang)
                                ]
                            )
                        )
                        order.labels
                    , TextArea.view
                        (Options.klarTextArea playground
                            (List.concat
                                [ Config.keep playground "TextArea" "label" (TextArea.label "Note")
                                , Config.keep playground "TextArea" "id" (TextArea.id "new-order-note")
                                , Config.keep playground "TextArea" "optionalText" (TextArea.optionalText "(optional)")
                                , Config.keep playground "TextArea" "minRows" (TextArea.minRows 3)
                                , Config.keep playground "TextArea" "maxRows" (TextArea.maxRows 8)
                                , Config.keep playground "TextArea" "maxLength" (TextArea.maxLength 500)
                                , Config.keep playground "TextArea" "value" (TextArea.value order.note)
                                , Config.keep playground "TextArea" "onInput" (TextArea.onInput NoteChanged)
                                , Config.keep playground "TextArea" "locale" (TextArea.locale lang)
                                ]
                            )
                        )
                    ]
                , FormLayout.section "Attachments and terms"
                    "The purchase order and other documents. The files are not uploaded in this example."
                    [ FileDrop.view AttachmentsMsg
                        (Options.klarFileDrop playground
                            (List.concat
                                [ Config.keep playground "FileDrop" "label" (FileDrop.label "Attachments")
                                , Config.keep playground "FileDrop" "accept" (FileDrop.accept [ ".pdf", "image/*" ])
                                , Config.keep playground "FileDrop" "maxSize" (FileDrop.maxSize 5000000)
                                , Config.keep playground "FileDrop" "maxFiles" (FileDrop.maxFiles 3)
                                , Config.keep playground "FileDrop" "optionalText" (FileDrop.optionalText "(optional)")
                                , Config.keep playground "FileDrop" "errorMaybe" (FileDrop.errorMaybe (shown attachmentsId))
                                , Config.keep playground "FileDrop" "locale" (FileDrop.locale lang)
                                ]
                            )
                        )
                        order.attachments
                    , Checkbox.view
                        (Options.klarCheckbox playground
                            (List.concat
                                [ Config.keep playground "Checkbox" "label" (Checkbox.label "I accept the terms of sale")
                                , Config.keep playground "Checkbox" "id" (Checkbox.id termsId)
                                , Config.keep playground "Checkbox" "checked" (Checkbox.checked order.accepted)
                                , Config.keep playground "Checkbox" "onCheck" (Checkbox.onCheck AcceptedToggled)
                                , [ case shown termsId of
                                        Just message ->
                                            Checkbox.error message

                                        Nothing ->
                                            Checkbox.hint "Required to place the order."
                                  ]
                                ]
                            )
                        )
                    ]
                , FormLayout.stickyActions
                    [ Switch.view
                        (Options.klarSwitch playground
                            (List.concat
                                [ Config.keep playground "Switch" "label" (Switch.label "Simulate a failure")
                                , Config.keep playground "Switch" "id" (Switch.id "new-order-simulate-failure")
                                , Config.keep playground "Switch" "checked" (Switch.checked order.simulateFailure)
                                , Config.keep playground "Switch" "onCheck" (Switch.onCheck SimulateFailureToggled)
                                , Config.keep playground "Switch" "size" (Switch.size Small)
                                ]
                            )
                        )
                    , Layout.spacer
                    , FormLayout.status
                        (formAttributes
                            ++ Options.klarFormLayout playground (List.concat [ Config.keep playground "Form.Layout" "onRetry" (FormLayout.onRetry Submit), Config.keep playground "Form.Layout" "onDismiss" (FormLayout.onDismiss DismissStatus) ])
                        )
                        order.status
                    , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "disabled" (Button.disabled submitting), Config.keep playground "Button" "onClick" (Button.onClick Discard) ])) "Reset"
                    , Options.buttonView playground
                        (Options.klarButton playground
                            (List.concat
                                [ Config.keep playground "Button" "primary" Button.primary
                                , Config.keep playground "Button" "submit" Button.submit
                                , Config.keep playground "Button" "id" (Button.id submitId)
                                , Config.keep playground "Button" "loading" (Button.loading submitting)
                                , Config.keep playground "Button" "icon" (Button.icon Icon.send)
                                ]
                            )
                        )
                        (if submitting then
                            "Placing order ..."

                         else
                            "Place order"
                        )
                    ]
                ]
            )
        ]
