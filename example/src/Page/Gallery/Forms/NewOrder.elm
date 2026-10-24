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
import Showcase.Doc as Doc
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
    , labels = TagInput.tags order.labels
    , note = order.note
    , attachments = FileDrop.files order.attachments
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
    , labels = TagInput.setTags saved.labels (TagInput.init labelsId)
    , note = saved.note
    , attachments = FileDrop.setFiles saved.attachments (FileDrop.init attachmentsId)
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


sections : Locale -> Model -> List (Html Msg)
sections lang order =
    [ newOrder lang order ]


priorityKey : Api.Types.Priority -> String
priorityKey priority =
    String.toLower (priorityLabel priority)


newOrder : Locale -> Model -> Html Msg
newOrder lang order =
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
                ([ TextInput.label label
                 , TextInput.id fieldId
                 , TextInput.value value
                 , TextInput.onInput toMsg
                 , TextInput.onBlur (Touched fieldId)
                 , TextInput.errorMaybe (shown fieldId)
                 ]
                    ++ extra
                )

        formAttributes =
            [ FormLayout.id formId, FormLayout.locale lang ]
    in
    Doc.section "Complete example: new order"
        "All the controls in one form. The fields are checked when you leave them and when you submit. Problems give a summary at the top with links to the fields. The submit is a fake request (1.4 seconds) that can succeed or fail. When you change something, the banner about unsaved changes appears."
        [ Doc.example
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
                (formAttributes ++ [ FormLayout.onSubmit Submit, FormLayout.ariaLabel "New order" ])
                [ FormLayout.unsavedChanges
                    (formAttributes
                        ++ [ FormLayout.onSave Submit
                           , FormLayout.onDiscard Discard
                           , FormLayout.saving submitting
                           , FormLayout.sticky
                           ]
                    )
                    dirty
                , if order.submitted then
                    FormLayout.errorSummary
                        (formAttributes ++ [ FormLayout.labels fieldLabels, FormLayout.onFocusField FocusField ])
                        errors

                  else
                    Text.text ""
                , FormLayout.section "Customer"
                    "Who orders and how to reach them. A phone number is required when SMS updates are on."
                    [ FormLayout.grid 2
                        [ text customerId "Customer" CustomerChanged order.customer [ TextInput.required, TextInput.autocomplete "organization" ]
                        , text contactId "Contact name" ContactChanged order.contact [ TextInput.required, TextInput.autocomplete "name" ]
                        , FormLayout.fullRow
                            (text emailId "Email" EmailChanged order.email [ TextInput.email, TextInput.required, TextInput.placeholder "name@example.com", TextInput.autocomplete "email" ])
                        , text phoneId
                            "Phone"
                            PhoneChanged
                            order.phone
                            [ TextInput.tel
                            , TextInput.hint "With country code, for example +44 20 7946 0958"
                            , if order.notifySms then
                                TextInput.required

                              else
                                TextInput.optionalText "(optional)"
                            ]
                        , text dateId "Order date" DateChanged order.orderDate [ TextInput.required, TextInput.placeholder "dd.mm.yyyy", TextInput.hint "For example 14.10.2026, not later than today" ]
                        ]
                    ]
                , FormLayout.section "Delivery"
                    "How the goods are shipped, how urgent the order is and what is paid up front."
                    [ Radio.view
                        [ Radio.label "Shipping method"
                        , Radio.id methodId
                        , Radio.required
                        , Radio.options
                            [ Radio.option "standard" "Standard" |> Radio.withDescription "Three to five working days."
                            , Radio.option "express" "Express" |> Radio.withDescription "The next working day, for orders before 2 pm."
                            , Radio.option "pickup" "Pick up" |> Radio.withDescription "The customer collects the goods at the warehouse."
                            ]
                        , Radio.selected order.method
                        , Radio.onSelect MethodSelected
                        , Radio.errorMaybe (shown methodId)
                        ]
                    , SegmentedControl.view
                        [ SegmentedControl.label "Priority"
                        , SegmentedControl.id "new-order-priority"
                        , SegmentedControl.options
                            (List.map (\priority -> SegmentedControl.option (priorityKey priority) (priorityLabel priority)) allPriorities)
                        , SegmentedControl.selected order.priority
                        , SegmentedControl.onSelect PrioritySelected
                        ]
                    , Slider.view
                        [ Slider.label "Discount"
                        , Slider.id "new-order-discount"
                        , Slider.hint "Approved by the account owner. Steps of 5 points."
                        , Slider.min 0
                        , Slider.max 50
                        , Slider.step 5
                        , Slider.value order.discount
                        , Slider.onInput DiscountChanged
                        , Slider.unit "%"
                        , Slider.marks [ ( 0, "None" ), ( 25, "25 %" ), ( 50, "Maximum" ) ]
                        , Slider.locale lang
                        ]
                    , NumberInput.view DepositMsg
                        [ NumberInput.label "Deposit"
                        , NumberInput.hint "Between 0 and 100\u{00A0}000."
                        , NumberInput.min 0
                        , NumberInput.max 100000
                        , NumberInput.step 50
                        , NumberInput.decimals 2
                        , NumberInput.grouped
                        , NumberInput.prefixText "$"
                        , NumberInput.optionalText "(optional)"
                        , NumberInput.errorMaybe
                            (if NumberInput.isTouched order.deposit || order.submitted then
                                Validate.errorFor depositId errors

                             else
                                Nothing
                            )
                        , NumberInput.locale lang
                        ]
                        order.deposit
                    ]
                , FormLayout.section "Notifications and notes"
                    "Updates about the order, labels and a free note."
                    [ Card.view [ Card.title "Updates" ]
                        [ Layout.stack [ Layout.gap 4 ]
                            [ Switch.view
                                [ Switch.label "Email updates"
                                , Switch.id "new-order-notify-email"
                                , Switch.description "Status changes and reminders."
                                , Switch.controlAtEnd
                                , Switch.checked order.notifyEmail
                                , Switch.onToggle NotifyEmailToggled
                                ]
                            , Layout.divider
                            , Switch.view
                                [ Switch.label "SMS updates"
                                , Switch.id "new-order-notify-sms"
                                , Switch.description "Needs a phone number."
                                , Switch.controlAtEnd
                                , Switch.checked order.notifySms
                                , Switch.onToggle NotifySmsToggled
                                ]
                            ]
                        ]
                    , TagInput.view LabelsMsg
                        [ TagInput.label "Labels"
                        , TagInput.hint "Enter or comma adds a tag."
                        , TagInput.placeholder "Type and press Enter"
                        , TagInput.maxTags 8
                        , TagInput.validate (Validate.run lang (Validate.minLength 2))
                        , TagInput.optionalText "(optional)"
                        , TagInput.locale lang
                        ]
                        order.labels
                    , TextArea.view
                        [ TextArea.label "Note"
                        , TextArea.id "new-order-note"
                        , TextArea.optionalText "(optional)"
                        , TextArea.minRows 3
                        , TextArea.maxRows 8
                        , TextArea.maxLength 500
                        , TextArea.value order.note
                        , TextArea.onInput NoteChanged
                        , TextArea.locale lang
                        ]
                    ]
                , FormLayout.section "Attachments and terms"
                    "The purchase order and other documents. The files are not uploaded in this example."
                    [ FileDrop.view AttachmentsMsg
                        [ FileDrop.label "Attachments"
                        , FileDrop.accept [ ".pdf", "image/*" ]
                        , FileDrop.maxSize 5000000
                        , FileDrop.maxFiles 3
                        , FileDrop.optionalText "(optional)"
                        , FileDrop.errorMaybe (shown attachmentsId)
                        , FileDrop.locale lang
                        ]
                        order.attachments
                    , Checkbox.view
                        [ Checkbox.label "I accept the terms of sale"
                        , Checkbox.id termsId
                        , Checkbox.checked order.accepted
                        , Checkbox.onCheck AcceptedToggled
                        , case shown termsId of
                            Just message ->
                                Checkbox.error message

                            Nothing ->
                                Checkbox.hint "Required to place the order."
                        ]
                    ]
                , FormLayout.stickyActions
                    [ Switch.view
                        [ Switch.label "Simulate a failure"
                        , Switch.id "new-order-simulate-failure"
                        , Switch.checked order.simulateFailure
                        , Switch.onToggle SimulateFailureToggled
                        , Switch.size Small
                        ]
                    , Layout.spacer
                    , FormLayout.status
                        (formAttributes
                            ++ [ FormLayout.onRetry Submit, FormLayout.onDismiss DismissStatus ]
                        )
                        order.status
                    , Button.view [ Button.disabled submitting, Button.onClick Discard ] "Reset"
                    , Button.view
                        [ Button.primary
                        , Button.submit
                        , Button.id submitId
                        , Button.loading submitting
                        , Button.icon Icon.send
                        ]
                        (if submitting then
                            "Placing order ..."

                         else
                            "Place order"
                        )
                    ]
                ]
            )
        ]
