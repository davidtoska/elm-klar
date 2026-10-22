module Main exposing (main)

{-| The application of the LeaveGuard browser test (`node scripts/test-leave-guard.mjs`).
It is the example at the top of `Klar.LeaveGuard`, with a few counters in the page so
that the test can read what happened. Routes live in the fragment, so that any static
server will do.
-}

import Browser
import Browser.Dom as Dom
import Browser.Navigation as Nav
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar
import Klar.LeaveGuard as LeaveGuard exposing (Answer(..))
import Klar.Overlay as Overlay
import Task
import Url exposing (Url)


type Route
    = Home
    | Orders
    | NewOrder


type Source
    = OrderForm


type alias Model =
    { key : Nav.Key
    , route : Route
    , draft : String
    , guard : LeaveGuard.Guard Source Route
    , urlChanges : Int
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | Typed String
    | Saved
    | OpenOrders
    | GuardMsg LeaveGuard.Msg
    | Focused


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( { key = key
      , route = fromUrl url
      , draft = ""
      , guard = LeaveGuard.initAt "leave-dialog" key url
      , urlChanges = 0
      }
    , Cmd.none
    )


fromUrl : Url -> Route
fromUrl url =
    case url.fragment of
        Just "/orders" ->
            Orders

        Just "/orders/new" ->
            NewOrder

        _ ->
            Home


toPath : Route -> String
toPath route =
    case route of
        Home ->
            "#/"

        Orders ->
            "#/orders"

        NewOrder ->
            "#/orders/new"


{-| Every route the user enters moves focus to the page: the guard restores focus
to the link that asked, and this is what the new page puts there afterwards.
-}
enter : Route -> Model -> ( Model, Cmd Msg )
enter route model =
    ( { model | route = route }, Task.attempt (\_ -> Focused) (Dom.focus "content") )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            go (fromUrl url) model

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            let
                counted =
                    { model | urlChanges = model.urlChanges + 1 }
            in
            case LeaveGuard.onUrlChange fromUrl url model.guard of
                ( guard, cmd, Just route ) ->
                    enter route { counted | guard = guard }
                        |> Tuple.mapSecond (\focus -> Cmd.batch [ Cmd.map GuardMsg cmd, focus ])

                ( guard, cmd, Nothing ) ->
                    ( { counted | guard = guard }, Cmd.map GuardMsg cmd )

        Typed text ->
            ( { model
                | draft = text
                , guard = LeaveGuard.setDirty OrderForm (text /= "") model.guard
              }
            , Cmd.none
            )

        Saved ->
            ( { model | draft = "", guard = LeaveGuard.setDirty OrderForm False model.guard }, Cmd.none )

        OpenOrders ->
            go Orders model

        GuardMsg inner ->
            let
                ( guard, cmd, decision ) =
                    LeaveGuard.update inner model.guard

                next =
                    { model | guard = guard }
            in
            case decision of
                Nothing ->
                    ( next, Cmd.map GuardMsg cmd )

                Just answer ->
                    ( next
                    , Cmd.batch
                        [ Cmd.map GuardMsg cmd
                        , Nav.pushUrl model.key (toPath (LeaveGuard.destination answer))
                        ]
                    )

        Focused ->
            ( model, Cmd.none )


go : Route -> Model -> ( Model, Cmd Msg )
go route model =
    case LeaveGuard.request route model.guard of
        Proceed _ ->
            ( model, Nav.pushUrl model.key (toPath route) )

        Hold guard cmd ->
            ( { model | guard = guard }, Cmd.map GuardMsg cmd )


view : Model -> Browser.Document Msg
view model =
    { title = "LeaveGuard browser test"
    , body =
        [ Klar.stylesheet
        , Overlay.host
            { attributes = []
            , page = [ page model ]
            , overlays =
                [ LeaveGuard.view GuardMsg
                    [ LeaveGuard.title "Leave without saving?" ]
                    model.guard
                ]
            }
        ]
    }


page : Model -> Html Msg
page model =
    Html.div []
        [ Html.nav []
            [ Html.a [ Attr.id "link-home", Attr.href "#/" ] [ Html.text "Home" ]
            , Html.text " "
            , Html.a [ Attr.id "link-orders", Attr.href "#/orders" ] [ Html.text "Orders" ]
            , Html.text " "
            , Html.a [ Attr.href "#/orders/new" ] [ Html.text "New order (a link without an id)" ]
            , Html.text " "
            , Html.button [ Attr.id "open-orders", Events.onClick OpenOrders ] [ Html.text "Open orders (code)" ]
            , Html.button [ Attr.id "make-dirty", Events.onClick (Typed "x") ] [ Html.text "Make dirty" ]
            ]
        , Html.main_ [ Attr.id "content", Attr.tabindex -1 ]
            [ Html.h1 [ Attr.id "route" ] [ Html.text (toPath model.route) ]
            , case model.route of
                NewOrder ->
                    Html.div []
                        [ Html.input [ Attr.id "draft", Attr.value model.draft, Events.onInput Typed ] []
                        , Html.button [ Attr.id "save", Events.onClick Saved ] [ Html.text "Save" ]
                        ]

                _ ->
                    Html.text ""
            ]
        , Html.p [] [ Html.text "onUrlChange calls: ", Html.span [ Attr.id "url-changes" ] [ Html.text (String.fromInt model.urlChanges) ] ]
        , Html.p [] [ Html.text "dirty: ", Html.span [ Attr.id "dirty" ] [ Html.text (if LeaveGuard.isDirty model.guard then "yes" else "no") ] ]
        ]
