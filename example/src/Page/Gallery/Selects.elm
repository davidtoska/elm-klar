module Page.Gallery.Selects exposing (Model, Msg, init, subscriptions, update, view)

{-| Gallery page: choosing. Select, MultiSelect and Autocomplete with large
lists, server search and the awkward places a popup has to work in.
-}

import Api.Types exposing (countryCodeText, orderIdText, orderStatusLabel)
import Dict exposing (Dict)
import Html exposing (Html)
import Klar.Autocomplete as Autocomplete
import Klar.Button as Button
import Klar.Card as Card
import Klar.Color as Color
import Klar.Format as Format
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.MultiSelect as MultiSelect
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Select as Select exposing (Option)
import Klar.Text as Text
import Klar.Theme exposing (Size(..), Tone(..))
import Process
import Showcase.Doc as Doc
import Showcase.Sample as Sample
import Task



-- DATA


countryOptions : List (Option String)
countryOptions =
    Sample.countries
        |> List.sortBy .name
        |> List.map (\country -> Select.option (countryCodeText country.code) country.name |> Select.withDescription (countryCodeText country.code))


countryGroupedOptions : List (Option String)
countryGroupedOptions =
    Sample.countries
        |> List.sortBy (\country -> ( country.region, country.name ))
        |> List.map
            (\country ->
                Select.option (countryCodeText country.code) country.name
                    |> Select.withDescription (countryCodeText country.code)
                    |> Select.withGroup country.region
            )


deliveryOptions : List (Option String)
deliveryOptions =
    [ Select.option "home" "Home delivery"
        |> Select.withIcon Icon.home
        |> Select.withDescription "2 to 4 working days"
        |> Select.withKeywords [ "parcel", "doorstep" ]
    , Select.option "express" "Express courier"
        |> Select.withIcon Icon.zap
        |> Select.withDescription "Next working day"
        |> Select.withKeywords [ "overnight", "urgent" ]
    , Select.option "same-day" "Same-day courier"
        |> Select.withIcon Icon.clock
        |> Select.withDescription "Order before 11:00"
        |> Select.withKeywords [ "urgent", "rush" ]
    , Select.option "pickup" "Warehouse pickup"
        |> Select.withIcon Icon.building
        |> Select.withDescription "Collect at the counter"
        |> Select.withKeywords [ "collect" ]
    , Select.option "locker" "Parcel locker"
        |> Select.withIcon Icon.mapPin
        |> Select.withDescription "Self-service pickup point"
    , Select.option "pallet" "Pallet freight"
        |> Select.withIcon Icon.layers
        |> Select.withDescription "Heavy and bulky goods"
        |> Select.withKeywords [ "lorry", "truck" ]
    , Select.option "international" "International freight"
        |> Select.withIcon Icon.globe
        |> Select.withDescription "Customs papers included"
        |> Select.withKeywords [ "export", "customs" ]
    , Select.option "hazmat" "Hazardous goods"
        |> Select.withIcon Icon.warning
        |> Select.withDescription "Temporarily unavailable"
        |> Select.disabledOption
    , Select.option "groupage" "Groupage freight with a very long name that does not fit in the field"
        |> Select.withIcon Icon.archive
        |> Select.withDescription "Transit of several weeks"
    ]


{-| Top-level, so the list is built once and the selects can compare it cheaply.
-}
orderOptions : List (Option String)
orderOptions =
    Sample.orders
        |> List.map
            (\order ->
                Select.option (orderIdText order.id) (orderIdText order.id ++ " · " ++ order.customer)
                    |> Select.withDescription (order.city ++ " · " ++ orderStatusLabel order.status)
            )


customerOptions : List (Option String)
customerOptions =
    List.map (\name -> Select.option name name) Sample.customers


cityOptions : List (Option String)
cityOptions =
    List.map (\name -> Select.option name name) Sample.cities


{-| The product categories (the last step of each category path) with the path
above them.
-}
knownCategories : List ( String, String )
knownCategories =
    Sample.categoryPaths
        |> List.filterMap
            (\path ->
                case List.reverse path of
                    name :: parents ->
                        Just ( name, String.join " / " (List.reverse parents) )

                    [] ->
                        Nothing
            )
        |> List.sortBy Tuple.first


categoryOptions : List String -> List (Option String)
categoryOptions created =
    List.map (\( name, parent ) -> Select.option name name |> Select.withDescription parent) knownCategories
        ++ List.map (\name -> Select.option name name) created


isKnownCategory : String -> Bool
isKnownCategory name =
    List.any (\( known, _ ) -> known == name) knownCategories


labelOf : List (Option String) -> String -> String
labelOf options value =
    options
        |> List.filter (\opt -> opt.value == value)
        |> List.head
        |> Maybe.map .label
        |> Maybe.withDefault value


{-| An order as the application would store it: its id, and its label from the
last time the server returned it.
-}
savedOrder : String -> Option String
savedOrder id =
    Select.option id (labelOf orderOptions id)


{-| What a failed request looks like in the demos that show a value whose
options never arrived.
-}
unreachable : Remote (List (Option String))
unreachable =
    Failed (Remote.problem Remote.network)



-- MODEL


type Target
    = OrderSearch
    | OrderMultiSearch
    | CustomerSearch


{-| What the simulated server last did for one field: the answer, the number of
the request it belongs to (older answers are ignored) and the text searched for.
-}
type alias Backend =
    { results : Remote (List (Option String))
    , request : Int
    , text : String
    }


type alias Model =
    { selects : Dict String (Select.State String)
    , multis : Dict String (MultiSelect.State String)
    , autos : Dict String (Autocomplete.State String)
    , owner : Select.State OwnerId
    , assignees : MultiSelect.State OwnerId
    , createdCategories : List String
    , orderSearch : Backend
    , orderMultiSearch : Backend
    , customerSearch : Backend
    , serverFails : Bool
    , customerFails : Bool
    , lastEnter : Maybe String
    }


type Msg
    = SelectMsg String (Select.Msg String)
    | MultiMsg String (MultiSelect.Msg String)
    | AutoMsg String (Autocomplete.Msg String)
    | OwnerMsg (Select.Msg OwnerId)
    | AssigneesMsg (MultiSelect.Msg OwnerId)
    | Responded Target Int String
    | Retry Target
    | ToggleServerFailure
    | ToggleCustomerFailure
    | LoadSaved
    | LoadSavedCustomer
    | CityEntered


init : ( Model, Cmd Msg )
init =
    ( { selects =
            Dict.fromList
                (List.map (\( id, setup ) -> ( id, setup (Select.init id) ))
                    [ ( "sel-basic", identity )
                    , ( "sel-grouped", Select.setValue (Just "NO") )
                    , ( "sel-rich", Select.setValue (Just "express") )
                    , ( "sel-required", identity )
                    , ( "sel-invalid", Select.setValue (Just "AD") )
                    , ( "sel-disabled", Select.setValue (Just "DK") )
                    , ( "sel-readonly", Select.setValue (Just "SE") )
                    , ( "sel-small", identity )
                    , ( "sel-medium", Select.setValue (Just "NO") )
                    , ( "sel-traffic", Select.setValue (Just "amber") )
                    , ( "sel-teams", Select.setValue (Just "sales") )
                    , ( "sel-large", identity )
                    , ( "sel-empty", identity )
                    , ( "sel-creatable", identity )
                    , ( "sel-orders", Select.setValue (Just "ORD-11234") )
                    , ( "sel-server", identity )
                    , ( "sel-loading", Select.setValue (Just "ORD-11234") )
                    , ( "sel-failed", Select.setValue (Just "ORD-11234") )
                    , ( "sel-scroll", identity )
                    , ( "sel-bottom", identity )
                    ]
                )
      , multis =
            Dict.fromList
                (List.map (\( id, setup ) -> ( id, setup (MultiSelect.init id) ))
                    [ ( "multi-orders", identity )
                    , ( "multi-cities", MultiSelect.setValues [ "Rotterdam", "Hamburg", "Gothenburg", "Chicago", "Singapore", "Sydney", "London" ] )
                    , ( "multi-limited", MultiSelect.setValues [ "NO" ] )
                    , ( "multi-teams", MultiSelect.setValues [ "ops", "sales", "misc" ] )
                    , ( "multi-invalid", identity )
                    , ( "multi-disabled", MultiSelect.setValues [ "SE", "DK", "FI" ] )
                    , ( "multi-readonly", MultiSelect.setValues [ "NO", "IS" ] )
                    , ( "multi-server", identity )
                    , ( "multi-loading", MultiSelect.setValues [ "ORD-10012", "ORD-10047", "ORD-10203" ] )
                    , ( "multi-failed", MultiSelect.setValues [ "ORD-10012", "ORD-10047" ] )
                    ]
                )
      , autos =
            Dict.fromList
                (List.map (\( id, setup ) -> ( id, setup (Autocomplete.init id) ))
                    [ ( "auto-city", identity )
                    , ( "auto-customer", identity )
                    , ( "auto-required", identity )
                    , ( "auto-disabled", Autocomplete.setText "Rotterdam" )
                    , ( "auto-readonly", Autocomplete.setText "Hamburg" )
                    , ( "auto-small", identity )
                    , ( "auto-large", identity )
                    ]
                )
      , owner = Select.init "typed-owner" |> Select.setValue (Just (OwnerId 2))
      , assignees = MultiSelect.init "typed-assignees" |> MultiSelect.setValues [ OwnerId 1, OwnerId 3 ]
      , createdCategories = []
      , orderSearch = idle
      , orderMultiSearch = idle
      , customerSearch = idle
      , serverFails = False
      , customerFails = False
      , lastEnter = Nothing
      }
    , Cmd.none
    )


idle : Backend
idle =
    { results = NotAsked, request = 0, text = "" }


selectState : String -> Model -> Select.State String
selectState id model =
    Dict.get id model.selects |> Maybe.withDefault (Select.init id)


multiState : String -> Model -> MultiSelect.State String
multiState id model =
    Dict.get id model.multis |> Maybe.withDefault (MultiSelect.init id)


autoState : String -> Model -> Autocomplete.State String
autoState id model =
    Dict.get id model.autos |> Maybe.withDefault (Autocomplete.init id)



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OwnerMsg inner ->
            let
                ( owner, cmd ) =
                    Select.update inner model.owner
            in
            ( { model | owner = owner }, Cmd.map OwnerMsg cmd )

        AssigneesMsg inner ->
            let
                ( assignees, cmd ) =
                    MultiSelect.update inner model.assignees
            in
            ( { model | assignees = assignees }, Cmd.map AssigneesMsg cmd )

        SelectMsg id inner ->
            let
                old =
                    selectState id model

                ( new, cmd ) =
                    Select.update inner old

                updated =
                    { model | selects = Dict.insert id new model.selects }

                ( final, extra ) =
                    if id == "sel-server" && Select.isOpen new && (Select.query new /= Select.query old || not (Select.isOpen old)) then
                        search OrderSearch (Select.query new) updated

                    else if id == "sel-creatable" then
                        ( rememberCreated (Select.value new) updated, Cmd.none )

                    else
                        ( updated, Cmd.none )
            in
            ( final, Cmd.batch [ Cmd.map (SelectMsg id) cmd, extra ] )

        MultiMsg id inner ->
            let
                old =
                    multiState id model

                ( new, cmd ) =
                    MultiSelect.update inner old

                updated =
                    { model | multis = Dict.insert id new model.multis }

                ( final, extra ) =
                    if id == "multi-server" && MultiSelect.isOpen new && (MultiSelect.query new /= MultiSelect.query old || not (MultiSelect.isOpen old)) then
                        search OrderMultiSearch (MultiSelect.query new) updated

                    else
                        ( updated, Cmd.none )
            in
            ( final, Cmd.batch [ Cmd.map (MultiMsg id) cmd, extra ] )

        AutoMsg id inner ->
            let
                old =
                    autoState id model

                ( new, cmd ) =
                    Autocomplete.update inner old

                updated =
                    { model | autos = Dict.insert id new model.autos }

                ( final, extra ) =
                    if id == "auto-customer" && Autocomplete.query new /= Autocomplete.query old then
                        search CustomerSearch (Autocomplete.query new) updated

                    else
                        ( updated, Cmd.none )
            in
            ( final, Cmd.batch [ Cmd.map (AutoMsg id) cmd, extra ] )

        Responded target request text ->
            let
                backend =
                    backendOf target model
            in
            if request == backend.request then
                ( setBackend target { backend | results = respond target text model } model, Cmd.none )

            else
                ( model, Cmd.none )

        Retry target ->
            let
                text =
                    case target of
                        OrderSearch ->
                            Select.query (selectState "sel-server" model)

                        OrderMultiSearch ->
                            MultiSelect.query (multiState "multi-server" model)

                        CustomerSearch ->
                            Autocomplete.query (autoState "auto-customer" model)
            in
            search target text model

        ToggleServerFailure ->
            ( { model | serverFails = not model.serverFails }, Cmd.none )

        ToggleCustomerFailure ->
            ( { model | customerFails = not model.customerFails }, Cmd.none )

        LoadSaved ->
            ( { model
                | selects = Dict.update "sel-server" (Maybe.map (Select.setOption (savedOrder "ORD-10042"))) model.selects
                , multis =
                    Dict.update "multi-server"
                        (Maybe.map (MultiSelect.setOptions (List.map savedOrder [ "ORD-10042", "ORD-10107", "ORD-10215" ])))
                        model.multis
              }
            , Cmd.none
            )

        LoadSavedCustomer ->
            -- an order being edited: its customer's id and name, as saved
            case List.head customerOptions of
                Just saved ->
                    ( { model | autos = Dict.update "auto-customer" (Maybe.map (Autocomplete.setOption saved)) model.autos }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        CityEntered ->
            ( { model | lastEnter = Just (Autocomplete.text (autoState "auto-city" model)) }, Cmd.none )


rememberCreated : Maybe String -> Model -> Model
rememberCreated value model =
    case value of
        Just text ->
            if isKnownCategory text || List.member text model.createdCategories then
                model

            else
                { model | createdCategories = model.createdCategories ++ [ text ] }

        Nothing ->
            model


backendOf : Target -> Model -> Backend
backendOf target model =
    case target of
        OrderSearch ->
            model.orderSearch

        OrderMultiSearch ->
            model.orderMultiSearch

        CustomerSearch ->
            model.customerSearch


setBackend : Target -> Backend -> Model -> Model
setBackend target backend model =
    case target of
        OrderSearch ->
            { model | orderSearch = backend }

        OrderMultiSearch ->
            { model | orderMultiSearch = backend }

        CustomerSearch ->
            { model | customerSearch = backend }


{-| The simulated backend: start a request (or none for too short a search).
The answer comes after a delay; older answers are ignored.
-}
search : Target -> String -> Model -> ( Model, Cmd Msg )
search target text model =
    let
        backend =
            backendOf target model

        request =
            backend.request + 1

        minimum =
            case target of
                CustomerSearch ->
                    1

                _ ->
                    2
    in
    if String.length (String.trim text) < minimum then
        ( setBackend target { results = NotAsked, request = request, text = text } model, Cmd.none )

    else
        ( setBackend target { results = Loading, request = request, text = text } model
        , Process.sleep 700 |> Task.perform (\_ -> Responded target request text)
        )


respond : Target -> String -> Model -> Remote (List (Option String))
respond target text model =
    let
        fails =
            case target of
                CustomerSearch ->
                    model.customerFails

                _ ->
                    model.serverFails
    in
    if fails then
        Failed (Remote.problem Remote.server |> Remote.withCode "HTTP 503")

    else
        case target of
            CustomerSearch ->
                Loaded (Select.filter text customerOptions |> List.take 30)

            _ ->
                Loaded (Select.filter text orderOptions |> List.take 50)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    Doc.page
        { title = "Choosing"
        , description = "Select, MultiSelect and Autocomplete share one option model, one search and one set of keyboard rules. Every list can be searched, and only the rows that are visible are drawn, so thousands of options are as fast as ten."
        }
        [ basics locale model
        , states locale model
        , colors locale model
        , creating locale model
        , typedIds locale model
        , largeLists locale model
        , multiSelects locale model
        , serverSearch locale model
        , autocompletes locale model
        , containers locale model
        , bottom locale model
        ]


selectView : String -> Locale -> Model -> List (Select.Attribute String Msg) -> Html Msg
selectView id locale model attributes =
    Select.view (SelectMsg id) (Select.locale locale :: attributes) (selectState id model)


multiView : String -> Locale -> Model -> List (MultiSelect.Attribute String Msg) -> Html Msg
multiView id locale model attributes =
    MultiSelect.view (MultiMsg id) (MultiSelect.locale locale :: attributes) (multiState id model)


autoView : String -> Locale -> Model -> List (Autocomplete.Attribute String Msg) -> Html Msg
autoView id locale model attributes =
    Autocomplete.view (AutoMsg id) (Autocomplete.locale locale :: attributes) (autoState id model)


valueCaption : List (Option String) -> Maybe String -> Html msg
valueCaption options value =
    case value of
        Just v ->
            Text.caption ("Selected value: " ++ v ++ " (" ++ labelOf options v ++ ")")

        Nothing ->
            Text.caption "No value selected"


{-| What the simulated server did, in a sentence.
-}
remoteDescription : Locale -> Remote (List a) -> String
remoteDescription locale remote =
    case remote of
        NotAsked ->
            "No request."

        Loading ->
            "Fetching ..."

        Failed _ ->
            "The request failed."

        Loaded found ->
            "Answer received: " ++ countOf locale (List.length found) "option" "options" ++ "."

        Kept _ ->
            case Remote.toMaybe remote of
                Just found ->
                    "Answer kept: " ++ countOf locale (List.length found) "option" "options" ++ "."

                Nothing ->
                    ""


countOf : Locale -> Int -> String -> String -> String
countOf locale n one other =
    Format.int locale n ++ " " ++ Format.plural locale n { one = one, other = other }


failureButton : Bool -> Msg -> Html Msg
failureButton on toggle =
    Button.view
        [ Button.pressed on
        , Button.icon Icon.warning
        , Button.onClick toggle
        ]
        (if on then
            "Simulate failure: on"

         else
            "Simulate failure: off"
        )


basics : Locale -> Model -> Html Msg
basics locale model =
    Doc.section "Searchable select"
        "Click the field, press Enter, Space, ArrowDown or ArrowUp, or just start typing to open it. In the list ArrowUp and ArrowDown, and PageUp and PageDown move the highlight; Home and End go to the first and last option while the search box is empty and move the caret once you have typed (Ctrl+Home and Ctrl+End always go to the ends). Enter chooses, Escape closes the list and returns to the field, and Tab closes it and moves on. The Enter that confirms an input method composition (Japanese, Chinese, Korean) never chooses. The search ignores case and accents (é, ü, ñ), accepts several words and shows the best match first. The chosen option has a check mark and is centered in the list when it opens."
        [ Doc.example
            { title = "Basic"
            , description = Just "Countries from the sample data. Try “south af” or “nz”: every word has to match, and the grey codes are searched too."
            , code = Just basicCode
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
                [ Layout.stack [ Layout.gap 2 ]
                    [ selectView "sel-basic"
                        locale
                        model
                        [ Select.label "Country"
                        , Select.options countryOptions
                        , Select.hint "The country the order is delivered to"
                        ]
                    , valueCaption countryOptions (Select.value (selectState "sel-basic" model))
                    ]
                ]
            )
        , Doc.example
            { title = "Grouped by region"
            , description = Just "The group headings are rows of the same height as the options. The heading of the group at the top stays in place while the list scrolls. While you search, the groups are ordered by best match."
            , code = Just groupedCode
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
                [ selectView "sel-grouped"
                    locale
                    model
                    [ Select.label "Country (grouped)"
                    , Select.options countryGroupedOptions
                    ]
                ]
            )
        , Doc.example
            { title = "Descriptions, icons and disabled options"
            , description = Just "The description and the keywords are searched too: try “overnight” or “lorry”, which are keywords that are never shown. “Hazardous goods” is disabled. Long names are cut with an ellipsis and shown in full as a tooltip."
            , code = Just richCode
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
                [ selectView "sel-rich"
                    locale
                    model
                    [ Select.label "Delivery method"
                    , Select.options deliveryOptions
                    , Select.clearable
                    ]
                ]
            )
        ]


colors : Locale -> Model -> Html Msg
colors locale model =
    Doc.section "Colors"
        "An option can carry a small colored dot, in the list, in the closed field and in the chips. A tone (Select.withTone) is a status color that follows the theme and the dark mode: green, amber, red. A color (Select.withColor) is a value of your data, for example the color of a row in a database; Color.hex checks the code, so a bad code is a Nothing you decide about. The label always says the same as the color, because color alone is not read by everyone."
        [ Doc.example
            { title = "Traffic light"
            , description = Just "Three tones for a status. The dot follows the theme and the dark mode."
            , code = Just trafficCode
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
                [ selectView "sel-traffic"
                    locale
                    model
                    [ Select.label "Delivery status"
                    , Select.options trafficOptions
                    ]
                ]
            )
        , Doc.example
            { title = "Colors from the data"
            , description = Just "The options are built from rows, as a database returns them, each with a color code that someone typed. The last row has a code that is not a color: it gets no dot, and the application is the one that knows."
            , code = Just teamCode
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
                [ selectView "sel-teams"
                    locale
                    model
                    [ Select.label "Team"
                    , Select.options teamOptions
                    , Select.clearable
                    ]
                , multiView "multi-teams"
                    locale
                    model
                    [ MultiSelect.label "Teams (chips keep the color)"
                    , MultiSelect.options teamOptions
                    ]
                ]
            )
        ]


trafficOptions : List (Option String)
trafficOptions =
    [ Select.option "green" "On time" |> Select.withTone Success
    , Select.option "amber" "At risk" |> Select.withTone Warning
    , Select.option "red" "Delayed" |> Select.withTone Danger
    , Select.option "none" "Not started" |> Select.withTone Neutral
    ]


{-| Rows as a database returns them: an id, a name and a color code.
-}
teamRows : List ( String, String, String )
teamRows =
    [ ( "ops", "Operations", "#2a9461" )
    , ( "sales", "Sales", "#D6453A" )
    , ( "people", "People", "#e0a31a" )
    , ( "it", "IT", "#5f95d3" )
    , ( "misc", "Miscellaneous", "not a color" )
    ]


teamOptions : List (Option String)
teamOptions =
    List.map teamOption teamRows


teamOption : ( String, String, String ) -> Option String
teamOption ( id, name, code ) =
    case Color.hex code of
        Just color ->
            Select.option id name |> Select.withColor color

        Nothing ->
            Select.option id name


trafficCode : String
trafficCode =
    """Select.option "green" "On time" |> Select.withTone Success
Select.option "amber" "At risk" |> Select.withTone Warning
Select.option "red" "Delayed" |> Select.withTone Danger"""


teamCode : String
teamCode =
    """-- a row from the database: { id, name, color : String }
teamOption row =
    case Color.hex row.color of
        Just color ->
            Select.option row.id row.name |> Select.withColor color

        Nothing ->
            Select.option row.id row.name"""


states : Locale -> Model -> Html Msg
states locale model =
    let
        required =
            selectState "sel-required" model
    in
    Doc.section "States and sizes"
        "Label, hint, error message and the required mark go through the same field wrapper as the text inputs. A disabled field cannot be focused; a read-only field can be focused but not opened. A field that can be cleared has a small cross, and Backspace or Delete on the closed field clears it too."
        [ Doc.example
            { title = "Required, invalid, disabled and read-only"
            , description = Nothing
            , code = Just statesCode
            }
            (Layout.grid [ Layout.minColumn 240, Layout.gap 5 ]
                [ selectView "sel-required"
                    locale
                    model
                    [ Select.label "Billing country"
                    , Select.required
                    , Select.options countryOptions
                    , Select.errorMaybe
                        (if Select.value required == Nothing then
                            Just "Choose a country"

                         else
                            Nothing
                        )
                    ]
                , selectView "sel-invalid"
                    locale
                    model
                    [ Select.label "Delivery country"
                    , Select.options countryOptions
                    , Select.error "We cannot deliver to this country yet"
                    ]
                , selectView "sel-disabled"
                    locale
                    model
                    [ Select.label "Disabled"
                    , Select.options countryOptions
                    , Select.disabled True
                    ]
                , selectView "sel-readonly"
                    locale
                    model
                    [ Select.label "Read-only"
                    , Select.options countryOptions
                    , Select.readOnly True
                    , Select.hint "Copied from the customer record"
                    ]
                ]
            )
        , Doc.example
            { title = "Sizes and clearing"
            , description = Just "Small, Medium and Large, like the text inputs. All three can be cleared."
            , code = Just sizesCode
            }
            (Layout.grid [ Layout.minColumn 220, Layout.gap 5, Layout.alignStart ]
                [ selectView "sel-small" locale model [ Select.label "Small", Select.size Small, Select.clearable, Select.options countryOptions ]
                , selectView "sel-medium" locale model [ Select.label "Medium", Select.clearable, Select.options countryOptions ]
                , selectView "sel-large" locale model [ Select.label "Large", Select.size Large, Select.clearable, Select.options countryOptions ]
                ]
            )
        , Doc.example
            { title = "A chosen value before the options have arrived"
            , description = Just "The value is chosen, but its name is not known yet. While the options load, and when they could not be fetched, the field says so in muted text instead of showing the id (ORD-11234, ORD-10012, ORD-10047). Select.value and MultiSelect.values return the values all the time."
            , code = Just remoteCode
            }
            (Layout.grid [ Layout.minColumn 240, Layout.gap 5 ]
                [ selectView "sel-loading"
                    locale
                    model
                    [ Select.label "Options are loading"
                    , Select.remote Loading
                    , Select.hint "Value: ORD-11234"
                    ]
                , selectView "sel-failed"
                    locale
                    model
                    [ Select.label "Options could not be fetched"
                    , Select.remote unreachable
                    , Select.clearable
                    , Select.hint "Value: ORD-11234"
                    ]
                , multiView "multi-loading"
                    locale
                    model
                    [ MultiSelect.label "Multiple choice, options are loading"
                    , MultiSelect.remote Loading
                    ]
                , multiView "multi-failed"
                    locale
                    model
                    [ MultiSelect.label "Multiple choice, options could not be fetched"
                    , MultiSelect.remote unreachable
                    ]
                ]
            )
        , Doc.example
            { title = "No options"
            , description = Just "A list without options says so when it is opened."
            , code = Just emptyCode
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
                [ selectView "sel-empty"
                    locale
                    model
                    [ Select.label "Carrier"
                    , Select.options []
                    , Select.placeholder "No carriers available"
                    ]
                ]
            )
        ]


creating : Locale -> Model -> Html Msg
creating locale model =
    Doc.section "New values"
        "With creatable the list offers a first row such as Create “Adhesives” when the search does not match an option exactly. The value becomes the text that was typed; the application adds it to its options if it should stay."
        [ Doc.example
            { title = "A category that can be created"
            , description =
                Just
                    (if List.isEmpty model.createdCategories then
                        "Type a category that does not exist, for example “Adhesives”, and press Enter."

                     else
                        "Created: " ++ String.join ", " model.createdCategories
                    )
            , code = Just creatableCode
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
                [ selectView "sel-creatable"
                    locale
                    model
                    [ Select.label "Category"
                    , Select.options (categoryOptions model.createdCategories)
                    , Select.creatable identity
                    , Select.clearable
                    , Select.placeholder "Choose or type a category"
                    ]
                ]
            )
        ]


{-| An id that belongs to the application: the options carry `OwnerId`s, and the
select hands back an `OwnerId`, not a `String` to be parsed.
-}
type OwnerId
    = OwnerId Int


type alias Owner =
    { id : OwnerId
    , name : String
    }


owners : List Owner
owners =
    List.indexedMap (\i name -> { id = OwnerId (i + 1), name = name }) Sample.owners


ownerOptions : List (Option OwnerId)
ownerOptions =
    List.map (\owner -> Select.option owner.id owner.name) owners


ownerName : OwnerId -> String
ownerName id =
    owners |> List.filter (\owner -> owner.id == id) |> List.head |> Maybe.map .name |> Maybe.withDefault "unknown"


ownerNumber : OwnerId -> String
ownerNumber (OwnerId n) =
    String.fromInt n


typedIds : Locale -> Model -> Html Msg
typedIds locale model =
    Doc.section "Your own id type"
        "The value of an option can be any plain data: an id type of your own, an Int, a record. The select gives the same value back, so a database id needs no String in between and no parsing on the way out. Values are compared with ==."
        [ Doc.example
            { title = "A select of OwnerId"
            , description =
                Just
                    (case Select.value model.owner of
                        Just id ->
                            "Select.value is Just (OwnerId " ++ ownerNumber id ++ "), the id of " ++ ownerName id ++ "."

                        Nothing ->
                            "Select.value is Nothing."
                    )
            , code = Just typedIdCode
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
                [ Select.view OwnerMsg
                    [ Select.label "Owner"
                    , Select.options ownerOptions
                    , Select.valueText (\id -> "Owner #" ++ ownerNumber id)
                    , Select.clearable
                    , Select.locale locale
                    ]
                    model.owner
                ]
            )
        , Doc.example
            { title = "A multiple choice of OwnerId"
            , description =
                Just
                    ("MultiSelect.values is a List OwnerId: "
                        ++ (case MultiSelect.values model.assignees of
                                [] ->
                                    "empty."

                                ids ->
                                    String.join ", " (List.map ownerNumber ids) ++ "."
                           )
                    )
            , code = Just typedMultiCode
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
                [ MultiSelect.view AssigneesMsg
                    [ MultiSelect.label "Assignees"
                    , MultiSelect.options ownerOptions
                    , MultiSelect.clearable
                    , MultiSelect.locale locale
                    ]
                    model.assignees
                ]
            )
        ]


largeLists : Locale -> Model -> Html Msg
largeLists locale model =
    let
        count =
            List.length (MultiSelect.values (multiState "multi-orders" model))
    in
    Doc.section "Large lists"
        "3,000 orders. The list draws only the rows that are visible, plus a few above and below (Klar.VirtualList does this for all three components), so it opens, filters on every keystroke and moves with the keyboard without delay. The line under the list says how many options matched. Try “ord-1250”, “pinnacle” or “shipped”, or hold PageDown."
        [ Doc.example
            { title = "3,000 options"
            , description = Just "The label is the order number and the customer, the description the city and the status. Both are searched."
            , code = Just manyCode
            }
            (Layout.grid [ Layout.minColumn 320, Layout.gap 5 ]
                [ Layout.stack [ Layout.gap 2 ]
                    [ selectView "sel-orders"
                        locale
                        model
                        [ Select.label "Order"
                        , Select.options orderOptions
                        , Select.clearable
                        ]
                    , valueCaption orderOptions (Select.value (selectState "sel-orders" model))
                    ]
                ]
            )
        , Doc.example
            { title = "3,000 options, multiple choice"
            , description = Just "“Select all filtered” chooses every match of the search. The field shows three chips and “+N” for the rest."
            , code = Just manyMultiCode
            }
            (Layout.grid [ Layout.minColumn 320, Layout.gap 5 ]
                [ Layout.stack [ Layout.gap 2 ]
                    [ multiView "multi-orders"
                        locale
                        model
                        [ MultiSelect.label "Orders"
                        , MultiSelect.options orderOptions
                        , MultiSelect.maxVisibleChips 3
                        , MultiSelect.clearable
                        ]
                    , Text.caption
                        (if count == 0 then
                            "No orders selected"

                         else
                            countOf locale count "order" "orders" ++ " selected"
                        )
                    ]
                ]
            )
        ]


multiSelects : Locale -> Model -> Html Msg
multiSelects locale model =
    let
        invalid =
            multiState "multi-invalid" model
    in
    Doc.section "Multiple choice"
        "The chosen values are shown as chips in the field, wrapping onto several lines. The list has check boxes and stays open while you choose. Enter checks and unchecks, Backspace in an empty search box removes the last chip, and Tab moves on to “Select all” and “Clear all”. On the closed field Backspace removes the last chip, and every chip has its own remove button."
        [ Doc.example
            { title = "Cities with chips"
            , description = Just "The field shows five chips and “+N” for the rest, so it does not grow when many are chosen. Point at “+N” to read which ones are hidden. Try “Select all”."
            , code = Just citiesCode
            }
            (Layout.grid [ Layout.minColumn 320, Layout.gap 5 ]
                [ multiView "multi-cities"
                    locale
                    model
                    [ MultiSelect.label "Cities"
                    , MultiSelect.options cityOptions
                    , MultiSelect.clearable
                    , MultiSelect.hint "The cities this route serves"
                    ]
                ]
            )
        , Doc.example
            { title = "Limit, required, disabled and read-only"
            , description = Just "With maxSelected the rest of the list is dimmed once the limit is reached."
            , code = Just limitCode
            }
            (Layout.grid [ Layout.minColumn 240, Layout.gap 5 ]
                [ multiView "multi-limited"
                    locale
                    model
                    [ MultiSelect.label "Up to three countries"
                    , MultiSelect.options countryGroupedOptions
                    , MultiSelect.maxSelected 3
                    , MultiSelect.required
                    ]
                , multiView "multi-invalid"
                    locale
                    model
                    [ MultiSelect.label "Countries served"
                    , MultiSelect.options countryOptions
                    , MultiSelect.required
                    , MultiSelect.errorMaybe
                        (if List.isEmpty (MultiSelect.values invalid) then
                            Just "Choose at least one country"

                         else
                            Nothing
                        )
                    ]
                , multiView "multi-disabled"
                    locale
                    model
                    [ MultiSelect.label "Disabled"
                    , MultiSelect.options countryOptions
                    , MultiSelect.disabled True
                    ]
                , multiView "multi-readonly"
                    locale
                    model
                    [ MultiSelect.label "Read-only"
                    , MultiSelect.options countryOptions
                    , MultiSelect.readOnly True
                    ]
                ]
            )
        ]


serverSearch : Locale -> Model -> Html Msg
serverSearch locale model =
    let
        server =
            selectState "sel-server" model
    in
    Doc.section "Server search"
        "With serverSearch the component does not filter. The application compares Select.query before and after in update and fetches when the search changes; the answer is given as a Remote. Here a simulated server answers after 0.7 seconds with the 50 best matches. Under two characters the list says “Type to search”, a search for “zzz” gives the empty list, and “Simulate failure” gives the failed state with “Try again”."
        [ Doc.example
            { title = "Order search"
            , description =
                Just
                    ((if model.orderSearch.text == "" then
                        "No search yet. "

                      else
                        "Last search: “" ++ model.orderSearch.text ++ "”. "
                     )
                        ++ remoteDescription locale model.orderSearch.results
                        ++ " “Load saved values” shows saved orders by name although the server has not returned them (setOption and setOptions)."
                    )
            , code = Just serverCode
            }
            (Layout.stack [ Layout.gap 4 ]
                [ Layout.row [ Layout.gap 2, Layout.wrap ]
                    [ failureButton model.serverFails ToggleServerFailure
                    , Button.view [ Button.icon Icon.bookmark, Button.onClick LoadSaved ] "Load saved values"
                    ]
                , Layout.grid [ Layout.minColumn 300, Layout.gap 5 ]
                    [ Layout.stack [ Layout.gap 2 ]
                        [ selectView "sel-server"
                            locale
                            model
                            [ Select.label "Order (server search)"
                            , Select.serverSearch
                            , Select.remote model.orderSearch.results
                            , Select.onRetry (Retry OrderSearch)
                            , Select.clearable
                            , Select.searchPlaceholder "Search the orders ..."
                            ]
                        , valueCaption orderOptions (Select.value server)
                        ]
                    , Layout.stack [ Layout.gap 2 ]
                        [ multiView "multi-server"
                            locale
                            model
                            [ MultiSelect.label "Orders (server search, multiple choice)"
                            , MultiSelect.serverSearch
                            , MultiSelect.remote model.orderMultiSearch.results
                            , MultiSelect.onRetry (Retry OrderMultiSearch)
                            , MultiSelect.maxVisibleChips 2
                            , MultiSelect.clearable
                            ]
                        , Text.caption "The chips keep their names even when the server no longer returns the option."
                        ]
                    ]
                ]
            )
        ]


autocompletes : Locale -> Model -> Html Msg
autocompletes locale model =
    let
        city =
            autoState "auto-city" model

        requiredCity =
            autoState "auto-required" model
    in
    Doc.section "Autocomplete"
        "A free text field with suggestions: the user may type anything, the suggestions only help. Typing shows the suggestions with none highlighted, so Enter keeps the typed text. ArrowDown and ArrowUp move through the suggestions (ArrowUp on the first one goes back to the typed text), Enter chooses the highlighted one, Escape closes the list and Tab moves on. The field keeps focus when a suggestion is clicked, and the list closes when the field loses focus. A typed text that is exactly a suggestion is picked however the field is left (Enter, Tab, Escape or a click elsewhere), and the values are of your own type, as in Select."
        [ Doc.example
            { title = "City with local suggestions"
            , description =
                Just
                    ("Try “zürich”: accents are ignored. Text: “"
                        ++ Autocomplete.text city
                        ++ "” · Picked suggestion: "
                        ++ Maybe.withDefault "none" (Autocomplete.picked city)
                        ++ (case model.lastEnter of
                                Just entered ->
                                    " · Enter pressed with the text “" ++ entered ++ "”"

                                Nothing ->
                                    ""
                           )
                    )
            , code = Just autoCityCode
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
                [ autoView "auto-city"
                    locale
                    model
                    [ Autocomplete.label "City"
                    , Autocomplete.options cityOptions
                    , Autocomplete.prefixIcon Icon.mapPin
                    , Autocomplete.clearable
                    , Autocomplete.onEnter CityEntered
                    , Autocomplete.placeholder "For example Rotterdam"
                    ]
                ]
            )
        , Doc.example
            { title = "Suggestions from a server"
            , description =
                Just
                    ("Customer names from a simulated server. "
                        ++ remoteDescription locale model.customerSearch.results
                        ++ " Picked: "
                        ++ Maybe.withDefault "none" (Autocomplete.picked (autoState "auto-customer" model))
                        ++ ". “Load saved customer” puts a saved name and id back with setOption."
                    )
            , code = Just autoServerCode
            }
            (Layout.stack [ Layout.gap 4 ]
                [ Layout.row [ Layout.gap 2 ]
                    [ failureButton model.customerFails ToggleCustomerFailure
                    , Button.view [ Button.icon Icon.bookmark, Button.onClick LoadSavedCustomer ] "Load saved customer"
                    ]
                , Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
                    [ autoView "auto-customer"
                        locale
                        model
                        [ Autocomplete.label "Customer"
                        , Autocomplete.remote model.customerSearch.results
                        , Autocomplete.onRetry (Retry CustomerSearch)
                        , Autocomplete.clearable
                        , Autocomplete.hint "Type at least one letter"
                        ]
                    ]
                ]
            )
        , Doc.example
            { title = "States and sizes"
            , description = Just "Required with an error, disabled, read-only, and the two other sizes."
            , code = Just autoStatesCode
            }
            (Layout.grid [ Layout.minColumn 220, Layout.gap 5, Layout.alignStart ]
                [ autoView "auto-required"
                    locale
                    model
                    [ Autocomplete.label "Delivery city"
                    , Autocomplete.options cityOptions
                    , Autocomplete.required
                    , Autocomplete.errorMaybe
                        (if String.isEmpty (String.trim (Autocomplete.text requiredCity)) then
                            Just "Enter a city"

                         else
                            Nothing
                        )
                    ]
                , autoView "auto-disabled"
                    locale
                    model
                    [ Autocomplete.label "Disabled"
                    , Autocomplete.options cityOptions
                    , Autocomplete.disabled True
                    ]
                , autoView "auto-readonly"
                    locale
                    model
                    [ Autocomplete.label "Read-only"
                    , Autocomplete.options cityOptions
                    , Autocomplete.readOnly True
                    ]
                , autoView "auto-small"
                    locale
                    model
                    [ Autocomplete.label "Small"
                    , Autocomplete.options cityOptions
                    , Autocomplete.size Small
                    ]
                , autoView "auto-large"
                    locale
                    model
                    [ Autocomplete.label "Large"
                    , Autocomplete.options cityOptions
                    , Autocomplete.size Large
                    ]
                ]
            )
        ]


containers : Locale -> Model -> Html Msg
containers locale model =
    Doc.section "In a scrolling container"
        "The list sits above everything else and is not cut off by the overflow of a card, a table or a dialog. Scroll the area in the card and open the field: the list follows the field."
        [ Doc.example
            { title = "A field in a card with a scrolling area"
            , description = Nothing
            , code = Just containerCode
            }
            (Layout.grid [ Layout.minColumn 320, Layout.gap 5 ]
                [ Card.view [ Card.title "Dispatch", Card.subtitle "The content scrolls" ]
                    [ Layout.stack [ Layout.gap 3, Layout.padding 1, Layout.maxHeight 180 ]
                        [ Text.paragraph "The order is ready for dispatch. Choose how it leaves the warehouse."
                        , Text.paragraph "This area has a fixed height and scrolls. Scroll down to the field and open it: the list is shown in full, also outside the area, and follows the field when the area scrolls."
                        , selectView "sel-scroll"
                            locale
                            model
                            [ Select.label "Delivery method"
                            , Select.options deliveryOptions
                            ]
                        , Text.paragraph "More text below the field, so that the area has to scroll."
                        , Text.paragraph "The carrier is notified as soon as the order is approved."
                        , Text.paragraph "The last paragraph in the area."
                        ]
                    ]
                ]
            )
        ]


bottom : Locale -> Model -> Html Msg
bottom locale model =
    Doc.section "At the bottom of the page"
        "When there is no room below the field, the list opens above it."
        [ Doc.example
            { title = "A field at the very bottom"
            , description = Just "Scroll all the way down and open the field."
            , code = Nothing
            }
            (Layout.grid [ Layout.minColumn 280, Layout.gap 5 ]
                [ selectView "sel-bottom"
                    locale
                    model
                    [ Select.label "Country"
                    , Select.options countryGroupedOptions
                    ]
                ]
            )
        ]



-- CODE SNIPPETS


basicCode : String
basicCode =
    """-- model
{ country = Select.init "country" }

-- update
CountryMsg inner ->
    let
        ( country, cmd ) =
            Select.update inner model.country
    in
    ( { model | country = country }, Cmd.map CountryMsg cmd )

-- view
Select.view CountryMsg
    [ Select.label "Country"
    , Select.options (List.map (\\c -> Select.option c.code c.name |> Select.withDescription c.code) countries)
    , Select.hint "The country the order is delivered to"
    ]
    model.country

-- reading the value; react to a change by comparing before and after in update
Select.value model.country --> Maybe String"""


groupedCode : String
groupedCode =
    """Select.option c.code c.name
    |> Select.withDescription c.code
    |> Select.withGroup c.region"""


richCode : String
richCode =
    """Select.option "express" "Express courier"
    |> Select.withIcon Icon.zap
    |> Select.withDescription "Next working day"
    |> Select.withKeywords [ "overnight", "urgent" ]

Select.option "hazmat" "Hazardous goods"
    |> Select.disabledOption"""


statesCode : String
statesCode =
    """Select.view CountryMsg
    [ Select.label "Billing country"
    , Select.required
    , Select.errorMaybe
        (if Select.value model.country == Nothing then
            Just "Choose a country"

         else
            Nothing
        )
    , Select.options countryOptions
    ]
    model.country

Select.view CountryMsg [ Select.disabled True, ... ] model.country

Select.view CountryMsg [ Select.readOnly True, ... ] model.country"""


sizesCode : String
sizesCode =
    """-- Small, Medium and Large come from Klar.Theme
Select.view CountryMsg [ Select.size Small, Select.clearable, ... ] model.country"""


remoteCode : String
remoteCode =
    """Select.view OrderMsg
    [ Select.label "Order"
    , Select.remote model.orders -- Loading: "Loading ...", Failed: "Could not be loaded"
    ]
    (Select.setValue (Just "ORD-11234") model.order)

Select.value model.order -- Just "ORD-11234", also while the options load"""


emptyCode : String
emptyCode =
    """Select.view CarrierMsg
    [ Select.label "Carrier"
    , Select.options []
    , Select.placeholder "No carriers available"
    ]
    model.carrier"""


typedIdCode : String
typedIdCode =
    """type OwnerId
    = OwnerId Int

-- model
{ owner : Select.State OwnerId }

-- the options carry the ids
Select.options (List.map (\\o -> Select.option o.id o.name) owners)

-- reading it back: Maybe OwnerId, nothing to parse
Select.value model.owner

-- an id that is in none of the options (a saved value, a server search)
Select.valueText (\\(OwnerId n) -> "Owner #" ++ String.fromInt n)"""


typedMultiCode : String
typedMultiCode =
    """-- model
{ assignees : MultiSelect.State OwnerId }

MultiSelect.options (List.map (\\o -> Select.option o.id o.name) owners)

-- reading it back: List OwnerId
MultiSelect.values model.assignees"""


creatableCode : String
creatableCode =
    """Select.view CategoryMsg
    [ Select.label "Category"
    , Select.options (categoryOptions model.created)
    , Select.creatable identity
    ]
    model.category

-- in update: add new values to the options
case Select.value category of
    Just v ->
        if List.member v (model.known ++ model.created) then
            model

        else
            { model | created = model.created ++ [ v ] }

    Nothing ->
        model"""


manyCode : String
manyCode =
    """-- build the options once, at the top level or in the model, not in view
orderOptions =
    List.map
        (\\order ->
            Select.option (orderIdText order.id) (orderIdText order.id ++ " · " ++ order.customer)
                |> Select.withDescription order.city
        )
        orders

Select.view OrderMsg
    [ Select.label "Order", Select.options orderOptions, Select.clearable ]
    model.order"""


manyMultiCode : String
manyMultiCode =
    """MultiSelect.view OrdersMsg
    [ MultiSelect.label "Orders"
    , MultiSelect.options orderOptions
    , MultiSelect.maxVisibleChips 3
    , MultiSelect.clearable
    ]
    model.orders"""


citiesCode : String
citiesCode =
    """MultiSelect.view CitiesMsg
    [ MultiSelect.label "Cities"
    , MultiSelect.options cityOptions
    , MultiSelect.clearable
    ]
    model.cities

MultiSelect.values model.cities -- [ "Rotterdam", "Hamburg", ... ]"""


limitCode : String
limitCode =
    """MultiSelect.view CountriesMsg [ MultiSelect.maxSelected 3, ... ] model.countries

MultiSelect.view CountriesMsg
    [ MultiSelect.required
    , MultiSelect.errorMaybe
        (if List.isEmpty (MultiSelect.values model.countries) then
            Just "Choose at least one country"

         else
            Nothing
        )
    , ...
    ]
    model.countries"""


serverCode : String
serverCode =
    """Select.view OrderMsg
    [ Select.label "Order"
    , Select.serverSearch
    , Select.remote model.found -- Remote (List (Option String))
    , Select.onRetry RetrySearch
    ]
    model.order

-- update: fetch when the search text changes
OrderMsg inner ->
    let
        ( order, cmd ) =
            Select.update inner model.order
    in
    if Select.query order /= Select.query model.order then
        ( { model | order = order, found = Loading }
        , Cmd.batch [ Cmd.map OrderMsg cmd, fetchOrders (Select.query order) ]
        )

    else
        ( { model | order = order }, Cmd.map OrderMsg cmd )

-- a saved value whose option the server may not return again
Select.setOption (Select.option "ORD-10042" "ORD-10042 · Beacon Foods BV") model.order
MultiSelect.setOptions savedOptions model.orders"""


autoCityCode : String
autoCityCode =
    """Autocomplete.view CityMsg
    [ Autocomplete.label "City"
    , Autocomplete.options (List.map (\\c -> Select.option c c) cities)
    , Autocomplete.prefixIcon Icon.mapPin
    , Autocomplete.onEnter CityEntered
    ]
    model.city

Autocomplete.text model.city -- what is in the field
Autocomplete.picked model.city -- Just value when the text came from a suggestion"""


autoServerCode : String
autoServerCode =
    """Autocomplete.view CustomerMsg
    [ Autocomplete.label "Customer"
    , Autocomplete.remote model.found -- Remote (List (Option String))
    , Autocomplete.onRetry RetrySuggestions
    ]
    model.customer

-- update: fetch when the query changes (it waits for a pause in the typing)
if Autocomplete.query new /= Autocomplete.query old then
    fetchCustomers (Autocomplete.query new)

else
    Cmd.none"""


autoStatesCode : String
autoStatesCode =
    """Autocomplete.view CityMsg [ Autocomplete.required, Autocomplete.error "Enter a city", ... ] model.city

Autocomplete.view CityMsg [ Autocomplete.disabled True, ... ] model.city

Autocomplete.view CityMsg [ Autocomplete.readOnly True, ... ] model.city

Autocomplete.view CityMsg [ Autocomplete.size Large, ... ] model.city"""


containerCode : String
containerCode =
    """Card.view [ Card.title "Dispatch" ]
    [ Layout.stack [ Layout.padding 1, Layout.maxHeight 180 ] -- this area scrolls
        [ ... Select.view ... ]
    ]"""
