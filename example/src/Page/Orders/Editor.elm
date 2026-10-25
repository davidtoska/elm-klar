module Page.Orders.Editor exposing
    ( Config
    , Editor
    , Msg
    , Target(..)
    , firstFieldId
    , formId
    , init
    , isDirty
    , isEditable
    , isNew
    , localProblems
    , settle
    , subtitle
    , title
    , toInput
    , update
    , view
    )

{-| The form of the order editor: the values the user is working on, how they
change, and how they look. `Page.Orders` owns the drawer around the form and the
requests it makes; this module owns the fields.

Every control keeps its own state (`Select.State`, `DatePicker.State` ...), so the
editor is a record of those and of the plain text fields. Nothing is stored
twice: what the user typed lives in the controls, and `toInput` reads it into the
`OrderInput` that the API takes. The editor also remembers the input it was
opened with (`saved`), and "has unsaved changes" simply means that the two
differ. That is truer than a flag that is set by the first keystroke: typing a
letter and deleting it again leaves the form clean.

The DOM ids of the controls (`order-customer`, `order-email` ...) are the field
names the server uses in its validation messages, so a server error finds its
control, and the links of the error summary find the control to focus.

-}

import Api.Types as Types exposing (CountryCode, FieldError, Lookups, Order, OrderInput, OwnerId, Priority(..), WarehouseId)
import Html exposing (Html)
import Klar.Alert as Alert
import Klar.Autocomplete as Autocomplete
import Klar.DatePicker as DatePicker
import Klar.DescriptionList as DescriptionList
import Klar.Form.Layout as FormLayout
import Klar.Form.Submission as Submission
import Klar.Format as Format
import Klar.Layout as Layout
import Klar.NumberInput as NumberInput
import Klar.Remote as Remote exposing (Remote)
import Klar.SegmentedControl as SegmentedControl
import Klar.Select as Select
import Klar.TextArea as TextArea
import Klar.TextInput as TextInput
import Klar.Theme as Theme exposing (Tone(..))
import Page.Effect exposing (Context)
import View.Labels as Labels



-- MODEL


{-| What the editor works on: a new order, or one that exists (as the server last
told us).
-}
type Target
    = NewOrder
    | ExistingOrder Order


type alias Editor =
    { target : Target

    -- The input the form was opened with. The form has unsaved changes when
    -- `toInput` is no longer equal to it.
    , saved : OrderInput
    , customer : Autocomplete.State String
    , email : String
    , country : Select.State CountryCode
    , city : String
    , warehouse : Select.State WarehouseId
    , owner : Select.State OwnerId
    , priority : Priority
    , due : DatePicker.State
    , lines : NumberInput.State
    , total : NumberInput.State
    , note : String

    -- Shared save status, field problems and request tickets.
    , submission : Submission.State
    }


{-| The id of the form. The error summary and the status line are found by it
(`FormLayout.focusSummary`, `FormLayout.focusStatus`).
-}
formId : String
formId =
    "order-form"


{-| The control to put the cursor in when the editor opens.
-}
firstFieldId : String
firstFieldId =
    "order-customer"


{-| An order has between one and this many lines. The server checks the same.
-}
maxLines : Int
maxLines =
    500


init : Target -> Editor
init target =
    let
        values =
            case target of
                NewOrder ->
                    blank

                ExistingOrder order ->
                    fromOrder order
    in
    { target = target
    , saved = values
    , customer = Autocomplete.init "order-customer" |> Autocomplete.setText values.customer
    , email = values.email
    , country = selectOf "order-country" values.country
    , city = values.city
    , warehouse = selectOf "order-warehouse" values.warehouse
    , owner = selectOf "order-owner" values.owner
    , priority = values.priority
    , due = DatePicker.init "order-due" |> DatePicker.setValue values.due
    , lines = NumberInput.init "order-lines" |> NumberInput.setValue (Maybe.map toFloat values.lines)
    , total = NumberInput.init "order-total" |> NumberInput.setValue values.total
    , note = values.note
    , submission = Submission.init formId
    }


blank : OrderInput
blank =
    { customer = ""
    , email = ""
    , country = Nothing
    , city = ""
    , priority = Normal
    , owner = Nothing
    , warehouse = Nothing
    , due = Nothing
    , lines = Nothing
    , total = Nothing
    , note = ""
    }


fromOrder : Order -> OrderInput
fromOrder order =
    { customer = order.customer
    , email = order.email
    , country = Just order.country
    , city = order.city
    , priority = order.priority
    , owner = order.owner
    , warehouse = Just order.warehouse
    , due = Just order.due
    , lines = Just order.lines
    , total = Just order.total
    , note = order.note
    }


selectOf : String -> Maybe id -> Select.State id
selectOf id maybeValue =
    Select.init id |> Select.setValue maybeValue


{-| The values in the form, as the API takes them. What is missing or cannot be
read stays missing (`Nothing`, `""`): the server decides what that means.
-}
toInput : Editor -> OrderInput
toInput editor =
    { customer = Autocomplete.text editor.customer
    , email = editor.email
    , country = Select.value editor.country
    , city = editor.city
    , priority = editor.priority
    , owner = Select.value editor.owner
    , warehouse = Select.value editor.warehouse
    , due = DatePicker.value editor.due
    , lines = Maybe.map round (NumberInput.value editor.lines)
    , total = NumberInput.value editor.total
    , note = editor.note
    }


{-| Does the form hold something that has not been saved? Text in the date and
number fields that is not a date or a number (yet) counts too: `toInput` leaves it
out, but the user has typed it.
-}
isDirty : Editor -> Bool
isDirty editor =
    let
        changed =
            toInput editor /= editor.saved

        unread =
            DatePicker.text editor.due
                /= ""
                || not (NumberInput.isValid editor.lines)
                || not (NumberInput.isValid editor.total)
    in
    changed || unread


isNew : Editor -> Bool
isNew editor =
    editor.target == NewOrder


{-| Can the order be changed? A new one can; an existing one until it has shipped.
-}
isEditable : Editor -> Bool
isEditable editor =
    case editor.target of
        NewOrder ->
            True

        ExistingOrder order ->
            Types.isEditable order.status


title : Editor -> String
title editor =
    case editor.target of
        NewOrder ->
            "New order"

        ExistingOrder order ->
            if Types.isEditable order.status then
                "Edit order"

            else
                "Order details"


subtitle : Editor -> String
subtitle editor =
    case editor.target of
        NewOrder ->
            "The order is created as a draft."

        ExistingOrder order ->
            Types.orderIdText order.id ++ " · " ++ order.customer



-- CHECKS BEFORE SENDING


{-| The due date field accepts today and later. `view` and `settle` use the same
rules: the picker needs them to read what was typed.

The saved date of an order that is already late is kept as it is until the user
types another one, and the server accepts it too (it only refuses a past date
for a new order).

-}
dueRules : Context -> List (DatePicker.Attribute msg)
dueRules context =
    [ DatePicker.today context.today
    , DatePicker.min context.today
    , DatePicker.locale context.locale
    ]


{-| Reads text in the date field that was never confirmed (no blur, no Enter),
with the rules of the field. Call it before checking or sending the form.
-}
settle : Context -> Editor -> Editor
settle context editor =
    { editor | due = DatePicker.setLimits (dueRules context) editor.due }


{-| What the controls themselves object to: a date that is not a date, a number
that is not a number or outside its limits. Their messages are on the fields
already; this is the same list for the error summary, and a reason not to send
the form to the server.

Everything else (missing values, a bad email address ...) is checked by the
server.

-}
localProblems : Editor -> List FieldError
localProblems editor =
    List.filterMap identity
        [ if not (DatePicker.isValid editor.due) then
            Just { field = "order-due", message = "Enter a valid due date, today or later." }

          else
            Nothing
        , numberProblem "order-lines"
            ("Enter a whole number of lines from 1 to " ++ String.fromInt maxLines ++ ".")
            (\n -> n >= 1 && n <= toFloat maxLines)
            editor.lines
        , numberProblem "order-total" "Enter a total of more than zero." (\n -> n > 0) editor.total
        ]


{-| A number field is wrong when its text is not a number, or when it holds a
number the rules do not accept. An empty field is not this function's business:
the server asks for the value.
-}
numberProblem : String -> String -> (Float -> Bool) -> NumberInput.State -> Maybe FieldError
numberProblem field message accepts state =
    let
        outside =
            case NumberInput.value state of
                Just n ->
                    not (accepts n)

                Nothing ->
                    False
    in
    if not (NumberInput.isValid state) || outside then
        Just { field = field, message = message }

    else
        Nothing



-- UPDATE


type Msg
    = CustomerMsg (Autocomplete.Msg String)
    | EmailChanged String
    | CountryMsg (Select.Msg CountryCode)
    | CityChanged String
    | WarehouseMsg (Select.Msg WarehouseId)
    | OwnerMsg (Select.Msg OwnerId)
    | PriorityChosen String
    | DueMsg DatePicker.Msg
    | LinesMsg NumberInput.Msg
    | TotalMsg NumberInput.Msg
    | NoteChanged String


{-| The controls report what the user does; the editor keeps the result. A control
keeps no out-messages: the value before and after its own `update` tells whether
the user changed it, and only then is the server's complaint about that field
dropped (opening a list is not a change).
-}
update : Msg -> Editor -> ( Editor, Cmd Msg )
update msg editor =
    if Submission.status editor.submission == FormLayout.Submitting then
        ( editor, Cmd.none )

    else
        updateReady msg editor


updateReady : Msg -> Editor -> ( Editor, Cmd Msg )
updateReady msg editor =
    case msg of
        CustomerMsg inner ->
            let
                ( customer, cmd ) =
                    Autocomplete.update inner editor.customer
            in
            ( { editor | customer = customer }
                |> forgetErrorIf (Autocomplete.text customer /= Autocomplete.text editor.customer) "order-customer"
            , Cmd.map CustomerMsg cmd
            )

        EmailChanged value ->
            ( { editor | email = value } |> forgetError "order-email", Cmd.none )

        CountryMsg inner ->
            let
                ( country, cmd ) =
                    Select.update inner editor.country
            in
            ( { editor | country = country }
                |> forgetErrorIf (Select.value country /= Select.value editor.country) "order-country"
            , Cmd.map CountryMsg cmd
            )

        CityChanged value ->
            ( { editor | city = value } |> forgetError "order-city", Cmd.none )

        WarehouseMsg inner ->
            let
                ( warehouse, cmd ) =
                    Select.update inner editor.warehouse
            in
            ( { editor | warehouse = warehouse }
                |> forgetErrorIf (Select.value warehouse /= Select.value editor.warehouse) "order-warehouse"
            , Cmd.map WarehouseMsg cmd
            )

        OwnerMsg inner ->
            let
                ( owner, cmd ) =
                    Select.update inner editor.owner
            in
            ( { editor | owner = owner }, Cmd.map OwnerMsg cmd )

        PriorityChosen label ->
            case List.filter (\priority -> Types.priorityLabel priority == label) Types.allPriorities of
                priority :: _ ->
                    ( { editor | priority = priority }, Cmd.none )

                [] ->
                    ( editor, Cmd.none )

        DueMsg inner ->
            let
                ( due, cmd ) =
                    DatePicker.update inner editor.due
            in
            ( { editor | due = due }
                |> forgetErrorIf (DatePicker.value due /= DatePicker.value editor.due) "order-due"
            , Cmd.map DueMsg cmd
            )

        LinesMsg inner ->
            let
                ( lines, cmd ) =
                    NumberInput.update inner editor.lines
            in
            ( { editor | lines = lines }
                |> forgetErrorIf (NumberInput.value lines /= NumberInput.value editor.lines) "order-lines"
            , Cmd.map LinesMsg cmd
            )

        TotalMsg inner ->
            let
                ( total, cmd ) =
                    NumberInput.update inner editor.total
            in
            ( { editor | total = total }
                |> forgetErrorIf (NumberInput.value total /= NumberInput.value editor.total) "order-total"
            , Cmd.map TotalMsg cmd
            )

        NoteChanged value ->
            ( { editor | note = value } |> forgetError "order-note", Cmd.none )


{-| The user changed a field, so what the server said about it no longer applies.
-}
forgetError : String -> Editor -> Editor
forgetError field editor =
    { editor | submission = Submission.edited field editor.submission }


forgetErrorIf : Bool -> String -> Editor -> Editor
forgetErrorIf changed field editor =
    if changed then
        forgetError field editor

    else
        editor



-- VIEW


{-| What the form needs from the page around it. `toMsg` wraps the form's own
messages; the others are messages of the page.
-}
type alias Config msg =
    { context : Context
    , lookups : Remote Lookups
    , toMsg : Msg -> msg
    , onSubmit : msg
    , onFocusField : String -> msg
    , onRetryLookups : msg
    }


view : Config msg -> Editor -> Html msg
view config editor =
    let
        context =
            config.context

        toMsg =
            config.toMsg

        -- Read-only while the order cannot be changed, and while it is being
        -- saved. Read-only, not disabled: a control that is disabled while it
        -- has the cursor drops the keyboard focus out of the drawer.
        locked =
            not (isEditable editor) || Submission.status editor.submission == FormLayout.Submitting

        errorOf field =
            Submission.problems editor.submission
                |> List.filter (\error -> error.field == field)
                |> List.head
                |> Maybe.map .message

        formAttributes =
            [ FormLayout.id formId
            , FormLayout.onSubmit config.onSubmit
            , FormLayout.onFocusField config.onFocusField
            , FormLayout.labels fieldLabels
            , FormLayout.stacked
            , FormLayout.locale context.locale
            , FormLayout.saving (Submission.status editor.submission == FormLayout.Submitting)
            ]
    in
    Layout.stack [ Layout.gap 5 ]
        [ viewOrderFacts context editor
        , FormLayout.view formAttributes
            [ FormLayout.errorSummary formAttributes
                (Submission.problems editor.submission
                    |> List.map
                        (\p ->
                            if List.any (\( key, _ ) -> key == p.field) fieldLabels then
                                p

                            else
                                { p | field = "" }
                        )
                    |> List.sortBy (\error -> formOrder error.field)
                )
            , FormLayout.section "Customer"
                "Who placed the order and how to reach them."
                [ FormLayout.grid 2
                    [ Autocomplete.view (CustomerMsg >> toMsg)
                        [ Autocomplete.label "Customer"
                        , Autocomplete.required
                        , Autocomplete.remote (Remote.map (.customers >> List.map customerOption) config.lookups)
                        , Autocomplete.minChars 2
                        , Autocomplete.hint "Choose a known customer or type a new name."
                        , Autocomplete.errorMaybe (errorOf "order-customer")
                        , Autocomplete.readOnly locked
                        , Autocomplete.locale context.locale
                        ]
                        editor.customer
                    , TextInput.view
                        [ TextInput.id "order-email"
                        , TextInput.label "Email"
                        , TextInput.email
                        , TextInput.required
                        , TextInput.autocomplete "off"
                        , TextInput.hint "Where the order confirmation goes."
                        , TextInput.value editor.email
                        , TextInput.onInput (EmailChanged >> toMsg)
                        , TextInput.errorMaybe (errorOf "order-email")
                        , TextInput.readOnly locked
                        , TextInput.locale context.locale
                        ]
                    ]
                ]
            , FormLayout.section "Delivery"
                "Where the goods are sent from and to, and when they are due."
                [ FormLayout.grid 2
                    [ Select.view (CountryMsg >> toMsg)
                        [ Select.label "Country"
                        , Select.required
                        , Select.remote (Remote.map (.countries >> List.map countryOption) config.lookups)
                        , Select.onRetry config.onRetryLookups
                        , Select.placeholder "Choose a country"
                        , Select.searchPlaceholder "Search countries"
                        , Select.errorMaybe (errorOf "order-country")
                        , Select.readOnly locked
                        , Select.locale context.locale
                        ]
                        editor.country
                    , TextInput.view
                        [ TextInput.id "order-city"
                        , TextInput.label "City"
                        , TextInput.required
                        , TextInput.autocomplete "off"
                        , TextInput.value editor.city
                        , TextInput.onInput (CityChanged >> toMsg)
                        , TextInput.errorMaybe (errorOf "order-city")
                        , TextInput.readOnly locked
                        , TextInput.locale context.locale
                        ]
                    , Select.view (WarehouseMsg >> toMsg)
                        [ Select.label "Warehouse"
                        , Select.required
                        , Select.remote (Remote.map (.warehouses >> List.map warehouseOption) config.lookups)
                        , Select.onRetry config.onRetryLookups
                        , Select.placeholder "Choose a warehouse"
                        , Select.errorMaybe (errorOf "order-warehouse")
                        , Select.readOnly locked
                        , Select.locale context.locale
                        ]
                        editor.warehouse
                    , DatePicker.view (DueMsg >> toMsg)
                        (dueRules context
                            ++ [ DatePicker.label "Due date"
                               , DatePicker.required
                               , DatePicker.errorMaybe (errorOf "order-due")
                               , DatePicker.readOnly locked
                               ]
                        )
                        editor.due
                    ]
                ]
            , FormLayout.section "Order"
                "How many lines the order has and what it comes to."
                [ FormLayout.grid 2
                    [ NumberInput.view (LinesMsg >> toMsg)
                        [ NumberInput.label "Lines"
                        , NumberInput.required
                        , NumberInput.min 1
                        , NumberInput.max (toFloat maxLines)
                        , NumberInput.decimals 0
                        , NumberInput.suffixText "lines"
                        , NumberInput.errorMaybe (errorOf "order-lines")
                        , NumberInput.readOnly locked
                        , NumberInput.locale context.locale
                        ]
                        editor.lines
                    , NumberInput.view (TotalMsg >> toMsg)
                        [ NumberInput.label "Total"
                        , NumberInput.required
                        , NumberInput.min 0.01
                        , NumberInput.decimals 2
                        , NumberInput.grouped
                        , NumberInput.suffixText "USD"
                        , NumberInput.errorMaybe (errorOf "order-total")
                        , NumberInput.readOnly locked
                        , NumberInput.locale context.locale
                        ]
                        editor.total
                    ]
                ]
            , FormLayout.section "Handling"
                "How urgent the order is and who looks after it."
                [ FormLayout.grid 2
                    [ SegmentedControl.view
                        [ SegmentedControl.id "order-priority"
                        , SegmentedControl.label "Priority"
                        , SegmentedControl.options
                            (List.map
                                (\priority -> SegmentedControl.option (Types.priorityLabel priority) (Types.priorityLabel priority))
                                Types.allPriorities
                            )
                        , SegmentedControl.selected (Types.priorityLabel editor.priority)
                        , SegmentedControl.onChange (PriorityChosen >> toMsg)
                        , SegmentedControl.disabled (not (isEditable editor))
                        , SegmentedControl.readOnly locked
                        ]
                    , Select.view (OwnerMsg >> toMsg)
                        [ Select.label "Owner"
                        , Select.optionalText "(optional)"
                        , Select.remote (Remote.map (.owners >> List.map ownerOption) config.lookups)
                        , Select.onRetry config.onRetryLookups
                        , Select.placeholder "Unassigned"
                        , Select.clearable
                        , Select.readOnly locked
                        , Select.locale context.locale
                        ]
                        editor.owner
                    , FormLayout.fullRow
                        (TextArea.view
                            [ TextArea.id "order-note"
                            , TextArea.label "Note"
                            , TextArea.optionalText "(optional)"
                            , TextArea.hint "Anything the warehouse or the owner should know."
                            , TextArea.value editor.note
                            , TextArea.onInput (NoteChanged >> toMsg)
                            , TextArea.minRows 3
                            , TextArea.maxRows 8
                            , TextArea.maxLength 200
                            , TextArea.errorMaybe (errorOf "order-note")
                            , TextArea.readOnly locked
                            , TextArea.locale context.locale
                            ]
                        )
                    ]
                ]
            ]
        ]


{-| What the form does not show: where the order is in its life, and why it
cannot be changed when it cannot. Nothing for a new order.
-}
viewOrderFacts : Context -> Editor -> Html msg
viewOrderFacts context editor =
    case editor.target of
        NewOrder ->
            Html.text ""

        ExistingOrder order ->
            Layout.stack [ Layout.gap 4 ]
                [ DescriptionList.view [ DescriptionList.columns 3, DescriptionList.density Theme.Compact, DescriptionList.locale context.locale ]
                    (List.filterMap identity
                        [ Just (DescriptionList.html "Status" (Labels.statusBadge order.status))
                        , Just (DescriptionList.text "Created" (Format.date context.locale order.created))
                        , order.delivered |> Maybe.map (\day -> DescriptionList.text "Delivered" (Format.date context.locale day))
                        ]
                    )
                , if Types.isEditable order.status then
                    Html.text ""

                  else
                    Alert.view
                        [ Alert.tone Info, Alert.title "This order can no longer be changed" ]
                        ("It is " ++ String.toLower (Types.orderStatusLabel order.status) ++ ". An order can be edited until it ships.")
                ]


customerOption : String -> Select.Option String
customerOption name =
    Select.option name name


countryOption : Types.Country -> Select.Option CountryCode
countryOption country =
    Select.option country.code country.name
        |> Select.withDescription (Types.countryCodeText country.code)


warehouseOption : Types.Warehouse -> Select.Option WarehouseId
warehouseOption warehouse =
    Select.option warehouse.id warehouse.name
        |> Select.withDescription warehouse.city


ownerOption : Types.Owner -> Select.Option OwnerId
ownerOption owner =
    Select.option owner.id owner.name


{-| The fields in the order of the form, with the names the error summary uses.
The summary lists the server's complaints in this order, whatever order the
server found them in.
-}
fieldLabels : List ( String, String )
fieldLabels =
    [ ( "order-customer", "Customer" )
    , ( "order-email", "Email" )
    , ( "order-country", "Country" )
    , ( "order-city", "City" )
    , ( "order-warehouse", "Warehouse" )
    , ( "order-due", "Due date" )
    , ( "order-lines", "Lines" )
    , ( "order-total", "Total" )
    , ( "order-priority", "Priority" )
    , ( "order-owner", "Owner" )
    , ( "order-note", "Note" )
    ]


{-| Where a field comes in the form; a field the form does not know comes last.
-}
formOrder : String -> Int
formOrder field =
    fieldLabels
        |> List.indexedMap (\index ( id, _ ) -> ( id, index ))
        |> List.filter (\( id, _ ) -> id == field)
        |> List.head
        |> Maybe.map Tuple.second
        |> Maybe.withDefault (List.length fieldLabels)
