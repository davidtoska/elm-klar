module Page.Gallery.Forms.Choices exposing (Model, Msg, init, sections, update)

{-| The sections of the forms page for choosing: radio buttons and checkbox
groups, switches, segmented controls and sliders.
-}

import Dict exposing (Dict)
import Html exposing (Html)
import Klar.Card as Card
import Klar.CheckboxGroup as CheckboxGroup
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


{-| The small examples only need to keep what the user does, so each choice is
stored under the DOM id of its control.
-}
type alias Model =
    { picks : Dict String String
    , checks : Dict String (List String)
    , flags : Dict String Bool
    , levels : Dict String Float
    , ranges : Dict String ( Float, Float )
    , saving : Bool
    }


init : Model
init =
    { picks =
        Dict.fromList
            [ ( "radio-method", "standard" )
            , ( "radio-long", "a" )
            , ( "seg-view", "list" )
            , ( "seg-period", "week" )
            , ( "seg-owner", "all" )
            , ( "seg-small", "b" )
            , ( "seg-large", "b" )
            , ( "seg-icons", "list" )
            , ( "seg-long", "all" )
            ]
    , checks =
        Dict.fromList
            [ ( "checks-extras", [ "gift-wrap" ] )
            , ( "checks-days", [ "mon", "tue" ] )
            , ( "checks-long", [ "manager" ] )
            ]
    , flags =
        Dict.fromList
            [ ( "sw-email", True )
            , ( "sw-large", True )
            , ( "sw-long", True )
            , ( "sw-setting-a", True )
            , ( "sw-setting-c", True )
            ]
    , levels =
        Dict.fromList
            [ ( "slider-discount", 35 )
            , ( "slider-urgency", 50 )
            , ( "slider-service", 20 )
            ]
    , ranges = Dict.fromList [ ( "range-quantity", ( 100, 350 ) ) ]
    , saving = False
    }


pickOf : String -> Model -> Maybe String
pickOf key model =
    Dict.get key model.picks


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
    = PickChanged String String
    | ChecksChanged String (List String)
    | FlagChanged String Bool
    | SavingToggled Bool
    | SavingDone
    | LevelChanged String Float
    | RangeChanged String Float Float


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PickChanged key value ->
            ( { model | picks = Dict.insert key value model.picks }, Cmd.none )

        ChecksChanged key values ->
            ( { model | checks = Dict.insert key values model.checks }, Cmd.none )

        FlagChanged key value ->
            ( { model | flags = Dict.insert key value model.flags }, Cmd.none )

        SavingToggled value ->
            -- the "server" answers after a second
            ( { model | flags = Dict.insert "sw-saving" value model.flags, saving = True }
            , Process.sleep 1200 |> Task.perform (\_ -> SavingDone)
            )

        SavingDone ->
            ( { model | saving = False }, Cmd.none )

        LevelChanged key value ->
            ( { model | levels = Dict.insert key value model.levels }, Cmd.none )

        RangeChanged key low high ->
            ( { model | ranges = Dict.insert key ( low, high ) model.ranges }, Cmd.none )



-- VIEW


sections : Locale -> Model -> List (Html Msg)
sections lang model =
    [ choices lang model
    , switches lang model
    , segments model
    , sliders lang model
    ]



-- RADIO AND CHECKBOX GROUPS


choices : Locale -> Model -> Html Msg
choices lang model =
    Doc.section "Radio buttons and checkbox groups"
        "The radio group is a fieldset with the label as its legend. Tab enters the group, the arrow keys move and choose (the browser's own behavior) and Space chooses the focused option. The checkbox group has Tab between the boxes and Space toggles; \"Select all\" shows a dash when only some are chosen."
        [ Doc.example
            { title = "Radio group"
            , description = Just "With a description, a disabled option, a horizontal layout and an error."
            , code = Just """Radio.view
    [ Radio.label "Shipping method"
    , Radio.id "shipping-method"
    , Radio.options
        [ Radio.option "standard" "Standard"
        , Radio.option "express" "Express" |> Radio.withDescription "Delivered the next working day."
        , Radio.option "pickup" "Pick up in store" |> Radio.disabledOption
        ]
    , Radio.selected model.method
    , Radio.onSelect MethodSelected
    ]"""
            }
            (grid 280
                [ Radio.view
                    [ Radio.label "Shipping method"
                    , Radio.id "radio-method"
                    , Radio.options
                        [ Radio.option "standard" "Standard"
                            |> Radio.withDescription "Three to five working days."
                        , Radio.option "express" "Express"
                            |> Radio.withDescription "Delivered the next working day if ordered before 2 pm."
                        , Radio.option "freight" "Freight"
                        , Radio.option "pickup" "Pick up in store" |> Radio.disabledOption
                        ]
                    , Radio.selected (pickOf "radio-method" model)
                    , Radio.onSelect (PickChanged "radio-method")
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
                    , Radio.onSelect (PickChanged "radio-contact")
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
                    , Radio.onSelect (PickChanged "radio-partial")
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
            , description = Just "Two groups have the same label and no id. The name of a group is made from the label and the values of its options, so they are two groups: choosing in one does not change the other. (Two groups with the same label and the same values need an id each.)"
            , code = Just """Radio.view
    [ Radio.label "Notification"
    , Radio.options [ Radio.option "sms" "SMS", Radio.option "email" "Email" ]
    , Radio.selected model.first
    , Radio.onSelect FirstSelected
    ]

Radio.view
    [ Radio.label "Notification"
    , Radio.options [ Radio.option "call" "Phone call", Radio.option "letter" "Letter" ]
    , Radio.selected model.second
    , Radio.onSelect SecondSelected
    ]"""
            }
            (grid 280
                [ Radio.view
                    [ Radio.label "Notification"
                    , Radio.options [ Radio.option "sms" "SMS", Radio.option "email" "Email" ]
                    , Radio.selected (pickOf "radio-noid-a" model)
                    , Radio.onSelect (PickChanged "radio-noid-a")
                    ]
                , Radio.view
                    [ Radio.label "Notification"
                    , Radio.options [ Radio.option "call" "Phone call", Radio.option "letter" "Letter" ]
                    , Radio.selected (pickOf "radio-noid-b" model)
                    , Radio.onSelect (PickChanged "radio-noid-b")
                    ]
                ]
            )
        , Doc.example
            { title = "Checkbox group"
            , description = Just "\"Select all\" is tri-state, and its text can be changed with selectAllLabel. The selection comes back in the same order as the options."
            , code = Just """CheckboxGroup.view
    [ CheckboxGroup.label "Extras"
    , CheckboxGroup.options
        [ CheckboxGroup.option "gift-wrap" "Gift wrap"
        , CheckboxGroup.option "paper-invoice" "Paper invoice"
        ]
    , CheckboxGroup.selected model.extras
    , CheckboxGroup.onChange ExtrasChanged
    , CheckboxGroup.selectAll
    ]"""
            }
            (grid 280
                [ CheckboxGroup.view
                    [ CheckboxGroup.label "Extras"
                    , CheckboxGroup.id "checks-extras"
                    , CheckboxGroup.options
                        [ CheckboxGroup.option "gift-wrap" "Gift wrap"
                        , CheckboxGroup.option "paper-invoice" "Paper invoice"
                        , CheckboxGroup.option "insurance" "Shipping insurance"
                            |> CheckboxGroup.withDescription "Covers loss and damage up to $500."
                        , CheckboxGroup.option "same-day" "Same-day dispatch" |> CheckboxGroup.disabledOption
                        ]
                    , CheckboxGroup.selected (checksOf "checks-extras" model)
                    , CheckboxGroup.onChange (ChecksChanged "checks-extras")
                    , CheckboxGroup.selectAll
                    , CheckboxGroup.locale lang
                    ]
                , stack
                    [ CheckboxGroup.view
                        [ CheckboxGroup.label "Delivery days"
                        , CheckboxGroup.id "checks-days"
                        , CheckboxGroup.hint "Horizontal layout."
                        , CheckboxGroup.horizontal
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
                        , Radio.onSelect (PickChanged "radio-long")
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
                        , Switch.description "The invoice is sent through the e-invoicing network and cannot be recalled once it has been delivered."
                        , Switch.checked (flagOf "sw-long" model)
                        , Switch.onToggle (FlagChanged "sw-long")
                        ]
                    ]
                ]
            )
        ]



-- SWITCH


switches : Locale -> Model -> Html Msg
switches lang model =
    Doc.section "Switch"
        "A switch (role=switch) for settings that take effect at once. Space toggles it. While the application is saving, the knob shows a spinner and clicks are ignored."
        [ Doc.example
            { title = "Switch with a description"
            , description = Just "Sizes, disabled, error, and a save that takes time (click the last one)."
            , code = Just """Switch.view
    [ Switch.label "Email updates"
    , Switch.description "You get an email when an order changes status."
    , Switch.checked model.notify
    , Switch.onToggle NotifyToggled
    , Switch.loading model.saving
    ]"""
            }
            (grid 300
                [ stack
                    [ Switch.view
                        [ Switch.label "Email updates"
                        , Switch.id "sw-email"
                        , Switch.description "You get an email when an order changes status."
                        , Switch.checked (flagOf "sw-email" model)
                        , Switch.onToggle (FlagChanged "sw-email")
                        , Switch.locale lang
                        ]
                    , Switch.view
                        [ Switch.label "SMS updates"
                        , Switch.id "sw-sms"
                        , Switch.checked (flagOf "sw-sms" model)
                        , Switch.onToggle (FlagChanged "sw-sms")
                        , Switch.size Small
                        , Switch.locale lang
                        ]
                    , Switch.view
                        [ Switch.label "Large switch"
                        , Switch.id "sw-large"
                        , Switch.checked (flagOf "sw-large" model)
                        , Switch.onToggle (FlagChanged "sw-large")
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
                        ([ Switch.label "Accept the terms"
                         , Switch.id "sw-error"
                         , Switch.checked (flagOf "sw-error" model)
                         , Switch.onToggle (FlagChanged "sw-error")
                         , Switch.locale lang
                         ]
                            ++ (if flagOf "sw-error" model then
                                    []

                                else
                                    [ Switch.error "You must accept the terms" ]
                               )
                        )
                    , Switch.view
                        [ Switch.label "Saving to the server"
                        , Switch.id "sw-saving"
                        , Switch.description "The switch shows a spinner for a second and ignores clicks meanwhile."
                        , Switch.checked (flagOf "sw-saving" model)
                        , Switch.loading model.saving
                        , Switch.onToggle SavingToggled
                        , Switch.locale lang
                        ]
                    ]
                ]
            )
        , Doc.example
            { title = "List of settings"
            , description = Just "With controlAtEnd the switch sits at the far end of the line, as in a list of settings."
            , code = Just """Switch.view [ Switch.label "Daily report", Switch.controlAtEnd, Switch.checked model.dailyReport, Switch.onToggle DailyReportToggled ]"""
            }
            (Card.view [ Card.title "Notifications" ]
                [ Layout.stack [ Layout.gap 4 ]
                    [ Switch.view
                        [ Switch.label "Daily report by email"
                        , Switch.id "sw-setting-a"
                        , Switch.description "Sent at 07:00 every day."
                        , Switch.controlAtEnd
                        , Switch.checked (flagOf "sw-setting-a" model)
                        , Switch.onToggle (FlagChanged "sw-setting-a")
                        ]
                    , Layout.divider
                    , Switch.view
                        [ Switch.label "Tell me about new orders"
                        , Switch.id "sw-setting-b"
                        , Switch.controlAtEnd
                        , Switch.checked (flagOf "sw-setting-b" model)
                        , Switch.onToggle (FlagChanged "sw-setting-b")
                        ]
                    , Layout.divider
                    , Switch.view
                        [ Switch.label "Show the unread counter in the menu"
                        , Switch.id "sw-setting-c"
                        , Switch.controlAtEnd
                        , Switch.checked (flagOf "sw-setting-c" model)
                        , Switch.onToggle (FlagChanged "sw-setting-c")
                        ]
                    ]
                ]
            )
        ]



-- SEGMENTED CONTROL


segments : Model -> Html Msg
segments model =
    Doc.section "Segmented control"
        "A choice between a few options that look like joined buttons, for views, periods and modes. They are radio buttons underneath: Tab goes to the chosen option, the arrow keys move and choose."
        [ Doc.example
            { title = "With icons, periods and full width"
            , description = Just "On the left icons with text, in the middle a period picker, and on the right full width."
            , code = Just """SegmentedControl.view
    [ SegmentedControl.ariaLabel "View"
    , SegmentedControl.options
        [ SegmentedControl.option "list" "List" |> SegmentedControl.withIcon Icon.list
        , SegmentedControl.option "grid" "Grid" |> SegmentedControl.withIcon Icon.grid
        ]
    , SegmentedControl.selected model.layout
    , SegmentedControl.onSelect LayoutSelected
    ]"""
            }
            (grid 300
                [ SegmentedControl.view
                    [ SegmentedControl.label "View"
                    , SegmentedControl.id "seg-view"
                    , SegmentedControl.options
                        [ SegmentedControl.option "list" "List" |> SegmentedControl.withIcon Icon.list
                        , SegmentedControl.option "grid" "Grid" |> SegmentedControl.withIcon Icon.grid
                        , SegmentedControl.option "columns" "Columns" |> SegmentedControl.withIcon Icon.columns
                        ]
                    , SegmentedControl.selected (pickOf "seg-view" model)
                    , SegmentedControl.onSelect (PickChanged "seg-view")
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
                    , SegmentedControl.selected (pickOf "seg-period" model)
                    , SegmentedControl.onSelect (PickChanged "seg-period")
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
                    , SegmentedControl.selected (pickOf "seg-owner" model)
                    , SegmentedControl.onSelect (PickChanged "seg-owner")
                    ]
                ]
            )
        , Doc.example
            { title = "Sizes, icon only, error and disabled"
            , description = Just "A segment with only an icon uses its text as the accessible name and as a tooltip."
            , code = Just """SegmentedControl.option "grid" "Grid" |> SegmentedControl.withIcon Icon.grid |> SegmentedControl.iconOnly"""
            }
            (grid 260
                [ SegmentedControl.view
                    [ SegmentedControl.ariaLabel "Small"
                    , SegmentedControl.id "seg-small"
                    , SegmentedControl.size Small
                    , SegmentedControl.options (letters "A" "B" "C")
                    , SegmentedControl.selected (pickOf "seg-small" model)
                    , SegmentedControl.onSelect (PickChanged "seg-small")
                    ]
                , SegmentedControl.view
                    [ SegmentedControl.ariaLabel "Large"
                    , SegmentedControl.id "seg-large"
                    , SegmentedControl.size Large
                    , SegmentedControl.options (letters "A" "B" "C")
                    , SegmentedControl.selected (pickOf "seg-large" model)
                    , SegmentedControl.onSelect (PickChanged "seg-large")
                    ]
                , SegmentedControl.view
                    [ SegmentedControl.ariaLabel "Icons only"
                    , SegmentedControl.id "seg-icons"
                    , SegmentedControl.options
                        [ SegmentedControl.option "list" "List" |> SegmentedControl.withIcon Icon.list |> SegmentedControl.iconOnly
                        , SegmentedControl.option "grid" "Grid" |> SegmentedControl.withIcon Icon.grid |> SegmentedControl.iconOnly
                        ]
                    , SegmentedControl.selected (pickOf "seg-icons" model)
                    , SegmentedControl.onSelect (PickChanged "seg-icons")
                    ]
                , SegmentedControl.view
                    [ SegmentedControl.label "Required choice"
                    , SegmentedControl.id "seg-error"
                    , SegmentedControl.required
                    , SegmentedControl.errorMaybe
                        (if pickOf "seg-error" model == Nothing then
                            Just "Choose an option"

                         else
                            Nothing
                        )
                    , SegmentedControl.options (letters "First" "Second" "Third")
                    , SegmentedControl.selected (pickOf "seg-error" model)
                    , SegmentedControl.onSelect (PickChanged "seg-error")
                    ]
                , SegmentedControl.view
                    [ SegmentedControl.label "Disabled"
                    , SegmentedControl.id "seg-disabled"
                    , SegmentedControl.disabled True
                    , SegmentedControl.options (letters "Off" "On" "Auto")
                    , SegmentedControl.selected (Just "on")
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
                    , SegmentedControl.selected (pickOf "seg-long" model)
                    , SegmentedControl.onSelect (PickChanged "seg-long")
                    ]
                ]
            )
        ]


{-| Three options whose value is their text.
-}
letters : String -> String -> String -> List SegmentedControl.Option
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
            { title = "Range"
            , description = Just "Two thumbs that cannot pass each other. Keep at least 10 pieces between them."
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
