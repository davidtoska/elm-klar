module Page.Gallery.DataDisplay.Json exposing (Model, Msg, init, update, view)

{-| The JSON viewer section: a response from a service, large and deep data, a
response of thousands of records, and simple values.
-}

import Api.Types as Types exposing (Order, OrderStatus(..))
import Html exposing (Html)
import Html.Lazy
import Json.Encode as Encode
import Klar.Date as Date
import Klar.JsonViewer as JsonViewer
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Showcase.Doc as Doc
import Showcase.Sample as Sample



-- MODEL


type alias Model =
    { response : JsonViewer.State
    , big : JsonViewer.State
    , huge : JsonViewer.State
    }


type Msg
    = ResponseMsg JsonViewer.Msg
    | BigMsg JsonViewer.Msg
    | HugeMsg JsonViewer.Msg
    | RootMsg JsonViewer.Msg


init : Model
init =
    { response = JsonViewer.init "json-response"
    , big = JsonViewer.init "json-big" |> JsonViewer.collapseAll
    , huge = JsonViewer.init "json-huge" |> JsonViewer.collapseAll
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ResponseMsg inner ->
            let
                ( state, cmd ) =
                    JsonViewer.update inner model.response
            in
            ( { model | response = state }, Cmd.map ResponseMsg cmd )

        BigMsg inner ->
            let
                ( state, cmd ) =
                    JsonViewer.update inner model.big
            in
            ( { model | big = state }, Cmd.map BigMsg cmd )

        HugeMsg inner ->
            let
                ( state, cmd ) =
                    JsonViewer.update inner model.huge
            in
            ( { model | huge = state }, Cmd.map HugeMsg cmd )

        RootMsg _ ->
            ( model, Cmd.none )



-- VIEW


view : Locale -> Model -> Html Msg
view locale model =
    let
        root id value =
            JsonViewer.view RootMsg [ JsonViewer.locale locale ] (JsonViewer.init id) value
    in
    Doc.section "JSON viewer"
        "For looking at the response of a service. The values have muted colors (text green, numbers blue, booleans brown, null gray), the keys are blue, and thin gray lines follow the indentation. Every node is a button with aria-expanded: Tab moves between the nodes, Enter or Space opens and closes. Long texts are cut, with the start of the whole text in a tooltip. There is no copy button, but the text can be selected."
        [ Doc.example
            { title = "Response from a service"
            , description = Just "The two top levels are open from the start. Empty objects and lists are shown on one line."
            , code = Just """JsonViewer.view JsonMsg
    [ JsonViewer.toolbar, JsonViewer.rootLabel "response" ]
    model.viewer
    model.response

JsonMsg m ->
    let
        ( viewer, cmd ) =
            JsonViewer.update m model.viewer
    in
    ( { model | viewer = viewer }, Cmd.map JsonMsg cmd )"""
            }
            (JsonViewer.view ResponseMsg
                [ JsonViewer.toolbar
                , JsonViewer.rootLabel "response"
                , JsonViewer.ariaLabel "Response from the order service"
                , JsonViewer.locale locale
                ]
                model.response
                apiResponse
            )
        , Doc.example
            { title = "Large and deep data"
            , description = Just "450 numbers and 150 objects are shown 20 at a time with “Show more”. The object “deep” is nested 16 levels and stops at level 12 with “...”. Everything below the top level is collapsed to start with; open it with “Expand all”."
            , code = Just "JsonViewer.view BigMsg [ JsonViewer.maxItems 20, JsonViewer.maxDepth 12, JsonViewer.maxHeight 360 ] model.state value"
            }
            (Html.Lazy.lazy2 bigViewer locale model.big)
        , Doc.example
            { title = "A response with three thousand records"
            , description = Just "About thirty thousand values. Only what is open is drawn, and a list shows 50 records at a time: open “orders” and page through with “Show more”. The keyboard and scrolling should still feel immediate."
            , code = Just "JsonViewer.view HugeMsg [ JsonViewer.maxItems 50, JsonViewer.maxHeight 380 ] model.state response"
            }
            (Html.Lazy.lazy2 hugeViewer locale model.huge)
        , Doc.example
            { title = "Simple values and empty responses"
            , description = Just "The root can be anything: a text, a number, null, an empty object or an empty list."
            , code = Nothing
            }
            (Layout.grid [ Layout.minColumn 220, Layout.gap 3 ]
                [ root "json-root-string" (Encode.string "Just a text at the root")
                , root "json-root-number" (Encode.float 3.14159)
                , root "json-root-null" Encode.null
                , root "json-root-object" (Encode.object [])
                , root "json-root-list" (Encode.list identity [])
                ]
            )
        ]


{-| The viewers with big values are built only when their state or the language
changes: decoding thousands of values on every key press would be a waste.
-}
bigViewer : Locale -> JsonViewer.State -> Html Msg
bigViewer locale state =
    JsonViewer.view BigMsg
        [ JsonViewer.toolbar
        , JsonViewer.maxItems 20
        , JsonViewer.maxDepth 12
        , JsonViewer.maxHeight 380
        , JsonViewer.ariaLabel "Large response"
        , JsonViewer.locale locale
        ]
        state
        bigResponse


hugeViewer : Locale -> JsonViewer.State -> Html Msg
hugeViewer locale state =
    JsonViewer.view HugeMsg
        [ JsonViewer.toolbar
        , JsonViewer.maxItems 50
        , JsonViewer.maxHeight 380
        , JsonViewer.ariaLabel "Three thousand orders"
        , JsonViewer.locale locale
        ]
        state
        hugeResponse



-- DATA


longText : String
longText =
    "The customer asked for one delivery of all lines on a single pallet that is no taller than 1.8 m. The goods are fragile and must be handled with care. Call the contact person an hour before arrival, and leave the pallet at reception if nobody is there. "
        ++ "The invoice goes to the head office, and a copy of the delivery note must be signed and sent back."


maybe : (a -> Encode.Value) -> Maybe a -> Encode.Value
maybe encode value =
    case value of
        Just present ->
            encode present

        Nothing ->
            Encode.null


orderJson : Order -> Encode.Value
orderJson order =
    Encode.object
        [ ( "id", Encode.string order.id )
        , ( "customer", Encode.string order.customer )
        , ( "status", Encode.string (Types.orderStatusLabel order.status) )
        , ( "priority", Encode.string (Types.priorityLabel order.priority) )
        , ( "owner", maybe Encode.string order.owner )
        , ( "created", Encode.string (Date.toIso order.created) )
        , ( "due", Encode.string (Date.toIso order.due) )
        , ( "delivered", maybe (Date.toIso >> Encode.string) order.delivered )
        , ( "paid", Encode.bool True )
        , ( "cancelled", Encode.bool (order.status == Cancelled) )
        , ( "discount", Encode.float 0.0375 )
        , ( "lines", Encode.int order.lines )
        , ( "total", Encode.float order.total )
        , ( "shipping"
          , Encode.object
                [ ( "street", Encode.string "Main Street 12" )
                , ( "postalCode", Encode.string "1000" )
                , ( "city", Encode.string order.city )
                , ( "country", Encode.string order.country )
                , ( "coordinates", Encode.list Encode.float [ 50.8503, 4.3517 ] )
                ]
          )
        , ( "contacts"
          , Encode.list identity
                [ Encode.object [ ( "type", Encode.string "phone" ), ( "value", Encode.string "+32 2 123 45 67" ), ( "primary", Encode.bool True ) ]
                , Encode.object [ ( "type", Encode.string "email" ), ( "value", Encode.string order.email ), ( "primary", Encode.bool False ) ]
                ]
          )
        , ( "attachments", Encode.list Encode.string [] )
        , ( "tags", Encode.list Encode.string [ "fragile", "repeat-order", "ünïcödé-test" ] )
        , ( "note", Encode.string longText )
        , ( "signature", Encode.null )
        ]


shipmentJson : Int -> Encode.Value
shipmentJson i =
    Encode.object
        [ ( "id", Encode.string ("SHP-" ++ String.fromInt (9000 + i)) )
        , ( "warehouse", Encode.string (List.drop (i - 1) [ "RTM", "HAM", "GOT" ] |> List.head |> Maybe.withDefault "RTM") )
        , ( "dispatched", Encode.string ("2026-09-1" ++ String.fromInt i) )
        , ( "delivered", Encode.null )
        , ( "items", Encode.list Encode.string [ "SKU-0000" ++ String.fromInt i, "SKU-0001" ++ String.fromInt i ] )
        ]


apiResponse : Encode.Value
apiResponse =
    Encode.object
        [ ( "status", Encode.string "ok" )
        , ( "requestId", Encode.string "7f3c2d1e-9b1a-4c55-8d0e-2a6b1e4f9c10" )
        , ( "elapsedMs", Encode.float 42.7 )
        , ( "data"
          , Encode.object
                [ ( "order", List.head Sample.orders |> maybe orderJson )
                , ( "shipments", Encode.list shipmentJson (List.range 1 3) )
                ]
          )
        , ( "warnings", Encode.list Encode.string [ "Delivery address needs confirmation", "Customs number is missing" ] )
        , ( "meta"
          , Encode.object
                [ ( "page", Encode.int 1 )
                , ( "pageSize", Encode.int 25 )
                , ( "total", Encode.int (List.length Sample.orders) )
                , ( "nextCursor", Encode.null )
                , ( "empty", Encode.object [] )
                , ( "emptyList", Encode.list identity [] )
                ]
          )
        ]


{-| Objects nested far deeper than the viewer will open.
-}
deepValue : Int -> Encode.Value
deepValue depth =
    if depth <= 0 then
        Encode.string "the bottom"

    else
        Encode.object [ ( "level " ++ String.fromInt depth, deepValue (depth - 1) ) ]


bigResponse : Encode.Value
bigResponse =
    Encode.object
        [ ( "readings", Encode.list Encode.int (List.range 1 450) )
        , ( "customers"
          , Encode.list
                (\order -> Encode.object [ ( "id", Encode.string order.id ), ( "name", Encode.string order.customer ), ( "city", Encode.string order.city ) ])
                (List.take 150 Sample.orders)
          )
        , ( "deep", deepValue 16 )
        , ( "numbers"
          , Encode.object
                [ ( "huge", Encode.float 1.2345678901234567e19 )
                , ( "tiny", Encode.float 1.0e-10 )
                , ( "negative", Encode.float -0.5 )
                , ( "integer", Encode.int 42 )
                , ( "zero", Encode.int 0 )
                ]
          )
        , ( "specialCharacters"
          , Encode.object
                [ ( "a/b", Encode.string "slash in the key" )
                , ( "a~b", Encode.string "tilde in the key" )
                , ( "quote", Encode.string "he said \"hello\"\nand left" )
                ]
          )
        ]


{-| Three thousand records with eight fields each: about thirty thousand values.
-}
hugeResponse : Encode.Value
hugeResponse =
    Encode.object
        [ ( "total", Encode.int (List.length Sample.orders) )
        , ( "orders"
          , Encode.list
                (\order ->
                    Encode.object
                        [ ( "id", Encode.string order.id )
                        , ( "customer", Encode.string order.customer )
                        , ( "email", Encode.string order.email )
                        , ( "city", Encode.string order.city )
                        , ( "status", Encode.string (Types.orderStatusLabel order.status) )
                        , ( "owner", maybe Encode.string order.owner )
                        , ( "total", Encode.float order.total )
                        , ( "note", Encode.string order.note )
                        ]
                )
                Sample.orders
          )
        ]
