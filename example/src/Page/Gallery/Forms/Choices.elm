module Page.Gallery.Forms.Choices exposing (Model, Msg, init, sections, update)

{-| The sections of the forms page for choosing: radio buttons and checkbox
groups, switches, segmented controls and sliders.
-}

import Dict exposing (Dict)
import Html exposing (Html)
import Klar.Card as Card
import Klar.Checkbox as Checkbox
import Klar.CheckboxGroup as CheckboxGroup
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Radio as Radio
import Klar.SegmentedControl as SegmentedControl
import Klar.Slider as Slider
import Klar.Switch as Switch
import Klar.Theme exposing (Size(..))
import Page.Gallery.Forms.Common exposing (grid, narrow, readout, stack)
import Process
import Showcase.Doc as Doc
import Task



-- MODEL


{-| The values of the main examples are types of their own, as in an
application: the options carry them and the messages give them back.
-}
type Shipping
    = Standard
    | Express
    | Freight
    | Pickup


type Layout
    = ListLayout
    | GridLayout
    | ColumnsLayout


type Extra
    = GiftWrap
    | PaperInvoice
    | Insurance
    | SameDay


{-| The small examples only need to keep what the user does, so each of their
choices is stored under the DOM id of its control.
-}
type alias Model =
    { shipping : Maybe Shipping
    , layout : Layout
    , extras : List Extra
    , picks : Dict String String
    , checks : Dict String (List String)
    , flags : Dict String Bool
    , levels : Dict String Float
    , committed : Maybe Float
    , ranges : Dict String ( Float, Float )
    , saving : Bool
    , readOnly : Bool
    }


init : Model
init =
    { shipping = Just Standard
    , layout = ListLayout
    , extras = [ GiftWrap ]
    , picks =
        Dict.fromList
            [ ( "radio-long", "a" )
            , ( "seg-period", "week" )
            , ( "seg-owner", "all" )
            , ( "seg-small", "b" )
            , ( "seg-large", "b" )
            , ( "seg-icons", "list" )
            , ( "seg-error", "third" )
            , ( "seg-long", "all" )
            , ( "radio-readonly", "express" )
            , ( "seg-readonly", "month" )
            ]
    , checks =
        Dict.fromList
            [ ( "checks-days", [ "mon", "tue" ] )
            , ( "checks-long", [ "manager" ] )
            , ( "checks-readonly", [ "invoice" ] )
            ]
    , flags =
        Dict.fromList
            [ ( "sw-email", True )
            , ( "sw-large", True )
            , ( "sw-long", True )
            , ( "sw-setting-a", True )
            , ( "sw-setting-c", True )
            , ( "check-readonly", True )
            , ( "sw-readonly", True )
            ]
    , levels =
        Dict.fromList
            [ ( "slider-discount", 35 )
            , ( "slider-urgency", 50 )
            , ( "slider-service", 20 )
            , ( "slider-price", 400 )
            ]
    , committed = Nothing
    , ranges = Dict.fromList [ ( "range-quantity", ( 100, 350 ) ) ]
    , saving = False
    , readOnly = True
    }


pickOf : String -> Model -> Maybe String
pickOf key model =
    Dict.get key model.picks


{-| The choice of a segmented control, which always has one.
-}
segmentOf : String -> Model -> String
segmentOf key model =
    Dict.get key model.picks |> Maybe.withDefault ""


checksOf : String -> Model -> List String
checksOf key model =
    Dict.get key model.checks |> Maybe.withDefault []


flagOf : String -> Model -> Bool
flagOf key model =
    Dict.get key model.flags |> Maybe.withDefault False


levelOf : String -> Model -> Float
levelOf key model =
    Dict.get key model.levels |> Maybe.withDefault 0


rangeOf : String -> Model -> ( Float, Float )
rangeOf key model =
    Dict.get key model.ranges |> Maybe.withDefault ( 0, 100 )



-- UPDATE


type Msg
    = ShippingChanged Shipping
    | LayoutChanged Layout
    | ExtrasChanged (List Extra)
    | PickChanged String String
    | ChecksChanged String (List String)
    | FlagChanged String Bool
    | SavingChecked Bool
    | SavingDone
    | LevelChanged String Float
    | PriceChosen Float
    | RangeChanged String Float Float
    | ReadOnlyChecked Bool


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ShippingChanged shipping ->
            ( { model | shipping = Just shipping }, Cmd.none )

        LayoutChanged layout ->
            ( { model | layout = layout }, Cmd.none )

        ExtrasChanged extras ->
            ( { model | extras = extras }, Cmd.none )

        PickChanged key value ->
            ( { model | picks = Dict.insert key value model.picks }, Cmd.none )

        ChecksChanged key values ->
            ( { model | checks = Dict.insert key values model.checks }, Cmd.none )

        FlagChanged key value ->
            ( { model | flags = Dict.insert key value model.flags }, Cmd.none )

        SavingChecked value ->
            if value == flagOf "sw-saving" model then
                -- pressed again while the last change is being saved
                ( model, Cmd.none )

            else
                -- the "server" answers after a second
                ( { model | flags = Dict.insert "sw-saving" value model.flags, saving = True }
                , Process.sleep 1200 |> Task.perform (\_ -> SavingDone)
                )

        SavingDone ->
            ( { model | saving = False }, Cmd.none )

        LevelChanged key value ->
            ( { model | levels = Dict.insert key value model.levels }, Cmd.none )

        PriceChosen value ->
            ( { model | levels = Dict.insert "slider-price" value model.levels, committed = Just value }, Cmd.none )

        RangeChanged key low high ->
            ( { model | ranges = Dict.insert key ( low, high ) model.ranges }, Cmd.none )

        ReadOnlyChecked value ->
            ( { model | readOnly = value }, Cmd.none )



-- VIEW


sections : Locale -> Model -> List (Html Msg)
sections lang model =
    [ choices lang model
    , switches lang model
    , segments model
    , sliders lang model
    ]



-- RADIO AND CHECKBOX GROUPS


shippingName : Shipping -> String
shippingName shipping =
    case shipping of
        Standard ->
            "Standard"

        Express ->
            "Express"

        Freight ->
            "Freight"

        Pickup ->
            "Pick up in store"


extraName : Extra -> String
extraName extra =
    case extra of
        GiftWrap ->
            "Gift wrap"

        PaperInvoice ->
            "Paper invoice"

        Insurance ->
            "Shipping insurance"

        SameDay ->
            "Same-day dispatch"


choices : Locale -> Model -> Html Msg
choices lang model =
    Doc.section "Radio buttons and checkbox groups"
        "The radio group is a fieldset with the label as its legend. Tab enters the group, the arrow keys move and choose (the browser's own behavior) and Space chooses the focused option. The checkbox group has Tab between the boxes and Space toggles; \"Select all\" shows a dash when only some are chosen. The values are the application's own types, compared with ==."
        [ Doc.example
            { title = "Radio group"
            , description = Just "The values are a type of the application (Standard, Express ...). With a description, a disabled option, a horizontal layout and an error."
            , code = Just """type Shipping = Standard | Express | Freight | Pickup

Radio.view
    [ Radio.label "Shipping method"
    , Radio.id "shipping-method"
    , Radio.options
        [ Radio.option Standard "Standard"
        , Radio.option Express "Express" |> Radio.withDescription "Delivered the next working day."
        , Radio.option Pickup "Pick up in store" |> Radio.disabledOption
        ]
    , Radio.selected model.shipping -- Maybe Shipping
    , Radio.onChange ShippingChanged -- Shipping -> Msg
    ]"""
            }
            (grid 280
                [ stack
                    [ Radio.view
                        [ Radio.label "Shipping method"
                        , Radio.id "radio-method"
                        , Radio.options
                            [ Radio.option Standard "Standard"
                                |> Radio.withDescription "Three to five working days."
                            , Radio.option Express "Express"
                                |> Radio.withDescription "Delivered the next working day if ordered before 2 pm."
                            , Radio.option Freight "Freight"
                            , Radio.option Pickup "Pick up in store" |> Radio.disabledOption
                            ]
                        , Radio.selected model.shipping
                        , Radio.onChange ShippingChanged
                        ]
                    , readout ("Chosen: " ++ (model.shipping |> Maybe.map shippingName |> Maybe.withDefault "nothing"))
                    ]
                , Radio.view
                    [ Radio.label "Preferred contact"
                    , Radio.id "radio-contact"
                    , Radio.hint "Horizontal layout, nothing chosen yet."
                    , Radio.horizontal
                    , Radio.options
                        [ Radio.option "email" "Email"
                        , Radio.option "phone" "Phone"
                        , Radio.option "post" "Post"
                        ]
                    , Radio.selected (pickOf "radio-contact" model)
                    , Radio.onChange (PickChanged "radio-contact")
                    ]
                , Radio.view
                    [ Radio.label "Partial delivery"
                    , Radio.id "radio-partial"
                    , Radio.required
                    , Radio.errorMaybe
                        (if pickOf "radio-partial" model == Nothing then
                            Just "Choose one option"

                         else
                            Nothing
                        )
                    , Radio.options
                        [ Radio.option "yes" "Allowed"
                        , Radio.option "no" "Not allowed"
                        ]
                    , Radio.selected (pickOf "radio-partial" model)
                    , Radio.onChange (PickChanged "radio-partial")
                    ]
                , Radio.view
                    [ Radio.label "Disabled group"
                    , Radio.id "radio-disabled"
                    , Radio.disabled True
                    , Radio.options [ Radio.option "a" "Option A", Radio.option "b" "Option B" ]
                    , Radio.selected (Just "b")
                    ]
                ]
            )
        , Doc.example
            { title = "Groups without an id"
            , description = Just "Two groups have the same label and no id. The name of a group is made from the label and the texts of its options, so they are two groups: choosing in one does not change the other. (Two groups with the same label and the same texts need an id each.)"
            , code = Just """Radio.view
    [ Radio.label "Notification"
    , Radio.options [ Radio.option Sms "SMS", Radio.option Email "Email" ]
    , Radio.selected model.first
    , Radio.onChange FirstChanged
    ]

Radio.view
    [ Radio.label "Notification"
    , Radio.options [ Radio.option Call "Phone call", Radio.option Letter "Letter" ]
    , Radio.selected model.second
    , Radio.onChange SecondChanged
    ]"""
            }
            (grid 280
                [ Radio.view
                    [ Radio.label "Notification"
                    , Radio.options [ Radio.option "sms" "SMS", Radio.option "email" "Email" ]
                    , Radio.selected (pickOf "radio-noid-a" model)
                    , Radio.onChange (PickChanged "radio-noid-a")
                    ]
                , Radio.view
                    [ Radio.label "Notification"
                    , Radio.options [ Radio.option "call" "Phone call", Radio.option "letter" "Letter" ]
                    , Radio.selected (pickOf "radio-noid-b" model)
                    , Radio.onChange (PickChanged "radio-noid-b")
                    ]
                ]
            )
        , Doc.example
            { title = "Checkbox group"
            , description = Just "\"Select all\" is tri-state, and its text can be changed with selectAllLabel. The selection is a list of the application's own values, in the same order as the options."
            , code = Just """type Extra = GiftWrap | PaperInvoice | Insurance | SameDay

CheckboxGroup.view
    [ CheckboxGroup.label "Extras"
    , CheckboxGroup.options
        [ CheckboxGroup.option GiftWrap "Gift wrap"
        , CheckboxGroup.option PaperInvoice "Paper invoice"
        ]
    , CheckboxGroup.selected model.extras -- List Extra
    , CheckboxGroup.onChange ExtrasChanged -- List Extra -> Msg
    , CheckboxGroup.selectAll
    ]"""
            }
            (grid 280
                [ stack
                    [ CheckboxGroup.view
                        [ CheckboxGroup.label "Extras"
                        , CheckboxGroup.id "checks-extras"
                        , CheckboxGroup.options
                            [ CheckboxGroup.option GiftWrap (extraName GiftWrap)
                            , CheckboxGroup.option PaperInvoice (extraName PaperInvoice)
                            , CheckboxGroup.option Insurance (extraName Insurance)
                                |> CheckboxGroup.withDescription "Covers loss and damage up to $500."
                            , CheckboxGroup.option SameDay (extraName SameDay) |> CheckboxGroup.disabledOption
                            ]
                        , CheckboxGroup.selected model.extras
                        , CheckboxGroup.onChange ExtrasChanged
                        , CheckboxGroup.selectAll
                        , CheckboxGroup.locale lang
                        ]
                    , readout ("Chosen: " ++ String.join ", " (List.map extraName model.extras))
                    ]
                , stack
                    [ CheckboxGroup.view
                        [ CheckboxGroup.label "Delivery days"
                        , CheckboxGroup.id "checks-days"
                        , CheckboxGroup.hint "Horizontal layout, small boxes."
                        , CheckboxGroup.horizontal
                        , CheckboxGroup.size Small
                        , CheckboxGroup.options
                            [ CheckboxGroup.option "mon" "Mon"
                            , CheckboxGroup.option "tue" "Tue"
                            , CheckboxGroup.option "wed" "Wed"
                            , CheckboxGroup.option "thu" "Thu"
                            , CheckboxGroup.option "fri" "Fri"
                            ]
                        , CheckboxGroup.selected (checksOf "checks-days" model)
                        , CheckboxGroup.onChange (ChecksChanged "checks-days")
                        ]
                    , readout ("Chosen: " ++ String.join ", " (checksOf "checks-days" model))
                    ]
                , CheckboxGroup.view
                    [ CheckboxGroup.label "Documents"
                    , CheckboxGroup.id "checks-documents"
                    , CheckboxGroup.required
                    , CheckboxGroup.errorMaybe
                        (if List.isEmpty (checksOf "checks-documents" model) then
                            Just "Choose at least one document"

                         else
                            Nothing
                        )
                    , CheckboxGroup.options
                        [ CheckboxGroup.option "invoice" "Invoice"
                        , CheckboxGroup.option "packing-list" "Packing list"
                        , CheckboxGroup.option "customs" "Customs declaration"
                        ]
                    , CheckboxGroup.selected (checksOf "checks-documents" model)
                    , CheckboxGroup.onChange (ChecksChanged "checks-documents")
                    , CheckboxGroup.selectAllLabel "All documents"
                    , CheckboxGroup.locale lang
                    ]
                , CheckboxGroup.view
                    [ CheckboxGroup.label "Disabled group"
                    , CheckboxGroup.id "checks-disabled"
                    , CheckboxGroup.disabled True
                    , CheckboxGroup.options [ CheckboxGroup.option "a" "Option A", CheckboxGroup.option "b" "Option B" ]
                    , CheckboxGroup.selected [ "a" ]
                    ]
                ]
            )
        , Doc.example
            { title = "Read only"
            , description = Just "For a record the user may read but not change. Unlike disabled, nothing is dimmed and Tab still reaches the controls (the chosen option of a group), so a screen reader reads the value with \"read only\"; a click, Space or an arrow key changes nothing. Turn it off to edit."
            , code = Just """Radio.view [ Radio.label "Delivery", Radio.readOnly model.locked, ... ]
CheckboxGroup.view [ CheckboxGroup.label "Documents", CheckboxGroup.readOnly model.locked, ... ]
Checkbox.view [ Checkbox.label "Newsletter", Checkbox.readOnly model.locked, ... ]
Switch.view [ Switch.label "Active", Switch.readOnly model.locked, ... ]
SegmentedControl.view [ SegmentedControl.label "Period", SegmentedControl.readOnly model.locked, ... ]"""
            }
            (stack
                [ Switch.view
                    [ Switch.label "Read only"
                    , Switch.id "readonly-toggle"
                    , Switch.checked model.readOnly
                    , Switch.onCheck ReadOnlyChecked
                    , Switch.locale lang
                    ]
                , grid 240
                    [ Radio.view
                        [ Radio.label "Delivery"
                        , Radio.id "radio-readonly"
                        , Radio.readOnly model.readOnly
                        , Radio.options
                            [ Radio.option "standard" "Standard"
                            , Radio.option "express" "Express"
                            , Radio.option "pickup" "Pick up in store"
                            ]
                        , Radio.selected (pickOf "radio-readonly" model)
                        , Radio.onChange (PickChanged "radio-readonly")
                        ]
                    , CheckboxGroup.view
                        [ CheckboxGroup.label "Documents"
                        , CheckboxGroup.id "checks-readonly"
                        , CheckboxGroup.readOnly model.readOnly
                        , CheckboxGroup.options
                            [ CheckboxGroup.option "invoice" "Invoice"
                            , CheckboxGroup.option "packing-list" "Packing list"
                            ]
                        , CheckboxGroup.selected (checksOf "checks-readonly" model)
                        , CheckboxGroup.onChange (ChecksChanged "checks-readonly")
                        , CheckboxGroup.locale lang
                        ]
                    , stack
                        [ Checkbox.view
                            [ Checkbox.label "Newsletter"
                            , Checkbox.id "check-readonly"
                            , Checkbox.readOnly model.readOnly
                            , Checkbox.checked (flagOf "check-readonly" model)
                            , Checkbox.onCheck (FlagChanged "check-readonly")
                            ]
                        , Switch.view
                            [ Switch.label "Active customer"
                            , Switch.id "sw-readonly"
                            , Switch.readOnly model.readOnly
                            , Switch.checked (flagOf "sw-readonly" model)
                            , Switch.onCheck (FlagChanged "sw-readonly")
                            , Switch.locale lang
                            ]
                        , SegmentedControl.view
                            [ SegmentedControl.label "Period"
                            , SegmentedControl.id "seg-readonly"
                            , SegmentedControl.readOnly model.readOnly
                            , SegmentedControl.options (letters "Day" "Week" "Month")
                            , SegmentedControl.selected (segmentOf "seg-readonly" model)
                            , SegmentedControl.onChange (PickChanged "seg-readonly")
                            ]
                        ]
                    ]
                ]
            )
        , Doc.example
            { title = "Long texts in a narrow place"
            , description = Just "Labels and descriptions wrap over several lines without moving the control itself."
            , code = Nothing
            }
            (narrow 340
                [ stack
                    [ Radio.view
                        [ Radio.label "What should the carrier do when nobody is at the delivery address at the agreed time?"
                        , Radio.id "radio-long"
                        , Radio.options
                            [ Radio.option "a" "Leave the parcel with a neighbour or at the nearest pick-up point and send a notification by email"
                                |> Radio.withDescription "The carrier keeps the parcel for up to seven days before it goes back to the warehouse."
                            , Radio.option "b" "Try again the next working day"
                            ]
                        , Radio.selected (pickOf "radio-long" model)
                        , Radio.onChange (PickChanged "radio-long")
                        ]
                    , CheckboxGroup.view
                        [ CheckboxGroup.label "Send a copy of the delivery confirmation to these recipients"
                        , CheckboxGroup.id "checks-long"
                        , CheckboxGroup.options
                            [ CheckboxGroup.option "manager" "The account manager and the responsible warehouse supervisor"
                            , CheckboxGroup.option "accounts" "Accounts payable"
                                |> CheckboxGroup.withDescription "Only the addresses registered as invoice recipients on the customer record."
                            ]
                        , CheckboxGroup.selected (checksOf "checks-long" model)
                        , CheckboxGroup.onChange (ChecksChanged "checks-long")
                        ]
                    , Switch.view
                        [ Switch.label "Send the invoice to the accounting system of the customer when the order is delivered"
                        , Switch.id "sw-long"
                        , Switch.hint "The invoice is sent through the e-invoicing network and cannot be recalled once it has been delivered."
                        , Switch.checked (flagOf "sw-long" model)
                        , Switch.onCheck (FlagChanged "sw-long")
                        ]
                    ]
                ]
            )
        ]



-- SWITCH


switches : Locale -> Model -> Html Msg
switches lang model =
    Doc.section "Switch"
        "A switch (role=switch) for settings that take effect at once. Space toggles it. While the application is saving, the knob shows a spinner, clicks and Space change nothing, and the switch keeps the keyboard focus."
        [ Doc.example
            { title = "Switch with a hint"
            , description = Just "Sizes, disabled, error, and a save that takes time (click the last one, then press Space again while it saves: the focus stays)."
            , code = Just """Switch.view
    [ Switch.label "Email updates"
    , Switch.hint "You get an email when an order changes status."
    , Switch.checked model.notify
    , Switch.onCheck NotifyChecked
    , Switch.loading model.saving
    ]

-- update: a press while saving sends the value the switch already has
NotifyChecked value ->
    if value == model.notify then
        ( model, Cmd.none )

    else
        ( { model | notify = value, saving = True }, saveNotify value )"""
            }
            (grid 300
                [ stack
                    [ Switch.view
                        [ Switch.label "Email updates"
                        , Switch.id "sw-email"
                        , Switch.hint "You get an email when an order changes status."
                        , Switch.checked (flagOf "sw-email" model)
                        , Switch.onCheck (FlagChanged "sw-email")
                        , Switch.locale lang
                        ]
                    , Switch.view
                        [ Switch.label "SMS updates"
                        , Switch.id "sw-sms"
                        , Switch.checked (flagOf "sw-sms" model)
                        , Switch.onCheck (FlagChanged "sw-sms")
                        , Switch.size Small
                        , Switch.locale lang
                        ]
                    , Switch.view
                        [ Switch.label "Large switch"
                        , Switch.id "sw-large"
                        , Switch.checked (flagOf "sw-large" model)
                        , Switch.onCheck (FlagChanged "sw-large")
                        , Switch.size Large
                        , Switch.locale lang
                        ]
                    ]
                , stack
                    [ Switch.view
                        [ Switch.label "Disabled (off)"
                        , Switch.id "sw-disabled-off"
                        , Switch.disabled True
                        ]
                    , Switch.view
                        [ Switch.label "Disabled (on)"
                        , Switch.id "sw-disabled-on"
                        , Switch.disabled True
                        , Switch.checked True
                        ]
                    , Switch.view
                        [ Switch.label "Show prices with tax"
                        , Switch.id "sw-error"
                        , Switch.checked (flagOf "sw-error" model)
                        , Switch.onCheck (FlagChanged "sw-error")
                        , Switch.errorMaybe
                            (if flagOf "sw-error" model then
                                Nothing

                             else
                                Just "Prices for consumers must include tax"
                            )
                        , Switch.locale lang
                        ]
                    , Switch.view
                        [ Switch.label "Saving to the server"
                        , Switch.id "sw-saving"
                        , Switch.hint "The switch shows a spinner for a second and ignores clicks meanwhile."
                        , Switch.checked (flagOf "sw-saving" model)
                        , Switch.loading model.saving
                        , Switch.onCheck SavingChecked
                        , Switch.locale lang
                        ]
                    ]
                ]
            )
        , Doc.example
            { title = "List of settings"
            , description = Just "With controlAtEnd the switch sits at the far end of the line, as in a list of settings."
            , code = Just """Switch.view [ Switch.label "Daily report", Switch.controlAtEnd, Switch.checked model.dailyReport, Switch.onCheck DailyReportChecked ]"""
            }
            (Card.view [ Card.title "Notifications" ]
                [ Layout.stack [ Layout.gap 4 ]
                    [ Switch.view
                        [ Switch.label "Daily report by email"
                        , Switch.id "sw-setting-a"
                        , Switch.hint "Sent at 07:00 every day."
                        , Switch.controlAtEnd
                        , Switch.checked (flagOf "sw-setting-a" model)
                        , Switch.onCheck (FlagChanged "sw-setting-a")
                        ]
                    , Layout.divider
                    , Switch.view
                        [ Switch.label "Tell me about new orders"
                        , Switch.id "sw-setting-b"
                        , Switch.controlAtEnd
                        , Switch.checked (flagOf "sw-setting-b" model)
                        , Switch.onCheck (FlagChanged "sw-setting-b")
                        ]
                    , Layout.divider
                    , Switch.view
                        [ Switch.label "Show the unread counter in the menu"
                        , Switch.id "sw-setting-c"
                        , Switch.controlAtEnd
                        , Switch.checked (flagOf "sw-setting-c" model)
                        , Switch.onCheck (FlagChanged "sw-setting-c")
                        ]
                    ]
                ]
            )
        ]



-- SEGMENTED CONTROL


segments : Model -> Html Msg
segments model =
    Doc.section "Segmented control"
        "A choice between a few options that look like joined buttons, for views, periods and modes. They are radio buttons underneath: Tab goes to the chosen option, the arrow keys move and choose. One option is always chosen, so selected takes a value, not a Maybe."
        [ Doc.example
            { title = "With icons, periods and full width"
            , description = Just "On the left icons with text (the values are a type of the application), in the middle a period picker, and on the right full width."
            , code = Just """type Layout = ListLayout | GridLayout | ColumnsLayout

SegmentedControl.view
    [ SegmentedControl.label "View"
    , SegmentedControl.options
        [ SegmentedControl.option ListLayout "List" |> SegmentedControl.withIcon Icon.list
        , SegmentedControl.option GridLayout "Grid" |> SegmentedControl.withIcon Icon.grid
        ]
    , SegmentedControl.selected model.layout -- Layout
    , SegmentedControl.onChange LayoutChanged -- Layout -> Msg
    ]"""
            }
            (grid 300
                [ SegmentedControl.view
                    [ SegmentedControl.label "View"
                    , SegmentedControl.id "seg-view"
                    , SegmentedControl.options
                        [ SegmentedControl.option ListLayout "List" |> SegmentedControl.withIcon Icon.list
                        , SegmentedControl.option GridLayout "Grid" |> SegmentedControl.withIcon Icon.grid
                        , SegmentedControl.option ColumnsLayout "Columns" |> SegmentedControl.withIcon Icon.columns
                        ]
                    , SegmentedControl.selected model.layout
                    , SegmentedControl.onChange LayoutChanged
                    ]
                , SegmentedControl.view
                    [ SegmentedControl.label "Period"
                    , SegmentedControl.id "seg-period"
                    , SegmentedControl.options
                        [ SegmentedControl.option "day" "Day"
                        , SegmentedControl.option "week" "Week"
                        , SegmentedControl.option "month" "Month"
                        , SegmentedControl.option "year" "Year" |> SegmentedControl.disabledOption
                        ]
                    , SegmentedControl.selected (segmentOf "seg-period" model)
                    , SegmentedControl.onChange (PickChanged "seg-period")
                    ]
                , SegmentedControl.view
                    [ SegmentedControl.label "Owner (full width)"
                    , SegmentedControl.id "seg-owner"
                    , SegmentedControl.fullWidth
                    , SegmentedControl.options
                        [ SegmentedControl.option "all" "All"
                        , SegmentedControl.option "mine" "Mine"
                        , SegmentedControl.option "unassigned" "Unassigned"
                        ]
                    , SegmentedControl.selected (segmentOf "seg-owner" model)
                    , SegmentedControl.onChange (PickChanged "seg-owner")
                    ]
                ]
            )
        , Doc.example
            { title = "Sizes, icon only, error and disabled"
            , description = Just "A segment made with iconOption has only an icon; its text is the accessible name and the tooltip, so it cannot be forgotten. A label that the segments make clear is kept for screen readers with labelHidden."
            , code = Just """SegmentedControl.view
    [ SegmentedControl.label "Layout"
    , SegmentedControl.labelHidden
    , SegmentedControl.options
        [ SegmentedControl.iconOption ListLayout Icon.list "List"
        , SegmentedControl.iconOption GridLayout Icon.grid "Grid"
        ]
    , SegmentedControl.selected model.layout
    , SegmentedControl.onChange LayoutChanged
    ]"""
            }
            (grid 260
                [ SegmentedControl.view
                    [ SegmentedControl.label "Small"
                    , SegmentedControl.labelHidden
                    , SegmentedControl.id "seg-small"
                    , SegmentedControl.size Small
                    , SegmentedControl.options (letters "A" "B" "C")
                    , SegmentedControl.selected (segmentOf "seg-small" model)
                    , SegmentedControl.onChange (PickChanged "seg-small")
                    ]
                , SegmentedControl.view
                    [ SegmentedControl.label "Large"
                    , SegmentedControl.labelHidden
                    , SegmentedControl.id "seg-large"
                    , SegmentedControl.size Large
                    , SegmentedControl.options (letters "A" "B" "C")
                    , SegmentedControl.selected (segmentOf "seg-large" model)
                    , SegmentedControl.onChange (PickChanged "seg-large")
                    ]
                , SegmentedControl.view
                    [ SegmentedControl.label "Icons only"
                    , SegmentedControl.labelHidden
                    , SegmentedControl.id "seg-icons"
                    , SegmentedControl.options
                        [ SegmentedControl.iconOption "list" Icon.list "List"
                        , SegmentedControl.iconOption "grid" Icon.grid "Grid"
                        ]
                    , SegmentedControl.selected (segmentOf "seg-icons" model)
                    , SegmentedControl.onChange (PickChanged "seg-icons")
                    ]
                , SegmentedControl.view
                    [ SegmentedControl.label "Choice with an error"
                    , SegmentedControl.id "seg-error"
                    , SegmentedControl.required
                    , SegmentedControl.errorMaybe
                        (if segmentOf "seg-error" model == "third" then
                            Just "Third is not allowed for this report"

                         else
                            Nothing
                        )
                    , SegmentedControl.options (letters "First" "Second" "Third")
                    , SegmentedControl.selected (segmentOf "seg-error" model)
                    , SegmentedControl.onChange (PickChanged "seg-error")
                    ]
                , SegmentedControl.view
                    [ SegmentedControl.label "Disabled"
                    , SegmentedControl.id "seg-disabled"
                    , SegmentedControl.disabled True
                    , SegmentedControl.options (letters "Off" "On" "Auto")
                    , SegmentedControl.selected "on"
                    ]
                ]
            )
        , Doc.example
            { title = "Long texts in a narrow place"
            , description = Just "The text is cut with an ellipsis when the options do not fit."
            , code = Nothing
            }
            (narrow 340
                [ SegmentedControl.view
                    [ SegmentedControl.label "Who can see this report?"
                    , SegmentedControl.id "seg-long"
                    , SegmentedControl.fullWidth
                    , SegmentedControl.options
                        [ SegmentedControl.option "all" "Everyone in the whole company, across all warehouses and offices"
                        , SegmentedControl.option "unit" "Only my warehouse"
                        ]
                    , SegmentedControl.selected (segmentOf "seg-long" model)
                    , SegmentedControl.onChange (PickChanged "seg-long")
                    ]
                ]
            )
        ]


{-| Three options whose value is their text.
-}
letters : String -> String -> String -> List (SegmentedControl.Option String)
letters first second third =
    [ SegmentedControl.option (String.toLower first) first
    , SegmentedControl.option (String.toLower second) second
    , SegmentedControl.option (String.toLower third) third
    ]



-- SLIDER


sliders : Locale -> Model -> Html Msg
sliders lang model =
    let
        ( quantityLow, quantityHigh ) =
            rangeOf "range-quantity" model
    in
    Doc.section "Slider"
        "A slider for one number and for a range. The arrow keys change the value by one step, Page Up and Page Down by ten percent, Home and End jump to the ends. The colored part of the track follows the thumb without JavaScript. On the range slider the thumbs cannot pass each other."
        [ Doc.example
            { title = "Single slider"
            , description = Just "With a bubble over the thumb (on hover, focus and drag), tick marks and a unit. Below: marks with text and a value written in your own way."
            , code = Just """Slider.view
    [ Slider.label "Discount"
    , Slider.min 0
    , Slider.max 50
    , Slider.step 5
    , Slider.value model.discount
    , Slider.onInput DiscountChanged
    , Slider.unit "%"
    , Slider.bubble
    , Slider.ticks 10
    ]"""
            }
            (grid 340
                [ Slider.view
                    [ Slider.label "Discount"
                    , Slider.id "slider-discount"
                    , Slider.hint "Steps of 5 points."
                    , Slider.min 0
                    , Slider.max 50
                    , Slider.step 5
                    , Slider.value (levelOf "slider-discount" model)
                    , Slider.onInput (LevelChanged "slider-discount")
                    , Slider.unit "%"
                    , Slider.bubble
                    , Slider.ticks 10
                    , Slider.locale lang
                    ]
                , Slider.view
                    [ Slider.label "Urgency"
                    , Slider.id "slider-urgency"
                    , Slider.min 0
                    , Slider.max 100
                    , Slider.step 10
                    , Slider.value (levelOf "slider-urgency" model)
                    , Slider.onInput (LevelChanged "slider-urgency")
                    , Slider.marks [ ( 0, "Low" ), ( 50, "Normal" ), ( 100, "Urgent" ) ]
                    , Slider.valueFormat (\v -> String.fromInt (round (v / 10)) ++ " of 10")
                    , Slider.locale lang
                    ]
                ]
            )
        , Doc.example
            { title = "Fetch when the thumb is let go"
            , description = Just "onInput keeps the written value up to date while dragging; onCommit is sent once when the thumb is let go (and for every key press), the moment to ask the server for the filtered list."
            , code = Just """Slider.view
    [ Slider.label "Highest price"
    , Slider.max 1000
    , Slider.step 10
    , Slider.value model.maxPrice
    , Slider.onInput PriceMoved -- every step of the drag
    , Slider.onCommit PriceChosen -- once, when the thumb is let go
    ]"""
            }
            (narrow 340
                [ stack
                    [ Slider.view
                        [ Slider.label "Highest price"
                        , Slider.id "slider-price"
                        , Slider.max 1000
                        , Slider.step 10
                        , Slider.value (levelOf "slider-price" model)
                        , Slider.onInput (LevelChanged "slider-price")
                        , Slider.onCommit PriceChosen
                        , Slider.unit "USD"
                        , Slider.locale lang
                        ]
                    , readout
                        (case model.committed of
                            Just price ->
                                "Fetched the products up to " ++ Format.decimal lang 0 price ++ " USD"

                            Nothing ->
                                "Nothing fetched yet: drag the thumb and let go"
                        )
                    ]
                ]
            )
        , Doc.example
            { title = "Range"
            , description = Just "Two thumbs that cannot pass each other, named \"Order quantity, from\" and \"Order quantity, to\" for screen readers. Keep at least 10 pieces between them."
            , code = Just """Slider.viewRange
    [ Slider.label "Order quantity"
    , Slider.min 0
    , Slider.max 500
    , Slider.minGap 10
    , Slider.range model.from model.to
    , Slider.onRangeInput QuantityChanged
    , Slider.unit "pcs"
    ]"""
            }
            (grid 340
                [ Slider.viewRange
                    [ Slider.label "Order quantity"
                    , Slider.id "range-quantity"
                    , Slider.min 0
                    , Slider.max 500
                    , Slider.minGap 10
                    , Slider.range quantityLow quantityHigh
                    , Slider.onRangeInput (RangeChanged "range-quantity")
                    , Slider.unit "pcs"
                    , Slider.bubble
                    , Slider.ticks 50
                    , Slider.locale lang
                    ]
                , Slider.viewRange
                    [ Slider.label "Disabled range"
                    , Slider.id "range-disabled"
                    , Slider.disabled True
                    , Slider.range 30 70
                    , Slider.locale lang
                    ]
                ]
            )
        , Doc.example
            { title = "States"
            , description = Just "Disabled and with an error."
            , code = Just """Slider.view [ Slider.label "Threshold", Slider.disabled True, Slider.value 40 ]"""
            }
            (grid 340
                [ Slider.view
                    [ Slider.label "Reorder threshold (disabled)"
                    , Slider.id "slider-disabled"
                    , Slider.disabled True
                    , Slider.value 40
                    , Slider.unit "%"
                    , Slider.locale lang
                    ]
                , Slider.view
                    [ Slider.label "Service level"
                    , Slider.id "slider-service"
                    , Slider.required
                    , Slider.errorMaybe
                        (if levelOf "slider-service" model < 50 then
                            Just "The value must be at least 50"

                         else
                            Nothing
                        )
                    , Slider.value (levelOf "slider-service" model)
                    , Slider.onInput (LevelChanged "slider-service")
                    , Slider.unit "%"
                    , Slider.locale lang
                    ]
                ]
            )
        ]
