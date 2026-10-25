module Page.Gallery.NextComponents.Comments exposing (Model, Msg, init, subscriptions, update, view)

{-| A discussion that simulates delayed posting, failure and late acknowledgements.
-}

import Html exposing (Html)
import Klar
import Klar.Button as Button
import Klar.CommentThread as Thread
import Klar.Ids as Ids
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Remote as Remote
import Klar.Settings exposing (Settings)
import Klar.Text as Text
import Process
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options
import Task
import Time


type alias Entry =
    { id : Int, author : String, body : String, parent : Maybe Int, resolved : Bool, at : Time.Posix }


type DataState
    = Ready
    | Loading
    | Failed
    | Empty
    | Refreshing
    | Stale


type alias Model =
    { thread : Thread.State
    , entries : List Entry
    , pending : Bool
    , failed : Maybe (Thread.Submission Int)
    , failNext : Bool
    , error : Maybe String
    , ticket : Int
    , nextId : Int
    , dataState : DataState
    }


type Msg
    = ThreadMsg Thread.Msg
    | Post (Thread.Submission Int)
    | Posted Int (Thread.Submission Int) Bool Time.Posix
    | FailNext
    | Resolve Int Bool
    | DataState DataState
    | Retry
    | Reset
    | NoOp


init : ( Model, Cmd Msg )
init =
    ( { thread = Thread.init "dispatch-discussion"
      , entries =
            [ { id = 1, author = "Ada", body = "The warehouse changed. Please verify **the delivery address** before dispatch.", parent = Nothing, resolved = False, at = Time.millisToPosix 1792886400000 }
            , { id = 2, author = "Grace", body = "Confirmed with the customer: use the Oslo warehouse.\n\n- Address checked\n- Contact updated", parent = Just 1, resolved = False, at = Time.millisToPosix 1792886460000 }
            ]
      , pending = False
      , failed = Nothing
      , failNext = False
      , error = Nothing
      , ticket = 0
      , nextId = 3
      , dataState = Ready
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ThreadMsg inner ->
            let
                ( thread, cmd ) =
                    Thread.update inner model.thread
            in
            ( { model | thread = thread }, Cmd.map ThreadMsg cmd )

        Post sent ->
            if model.pending then
                ( model, Cmd.none )

            else
                ( { model | pending = True, error = Nothing, failNext = False, ticket = model.ticket + 1 }
                , Process.sleep 1500 |> Task.andThen (always Time.now) |> Task.perform (Posted (model.ticket + 1) sent model.failNext)
                )

        Posted ticket sent fails at ->
            if ticket /= model.ticket then
                ( model, Cmd.none )

            else if fails then
                ( { model | pending = False, failed = Just sent, error = Just "The previous post failed. Its exact content is retained for retry; your current draft is unchanged." }, Cmd.none )

            else
                ( { model
                    | pending = False
                    , failed = Nothing
                    , error = Nothing
                    , thread = Thread.acknowledge sent model.thread
                    , entries = model.entries ++ [ { id = model.nextId, author = "You", body = Thread.submissionBody sent, parent = Thread.submissionParent sent, resolved = False, at = at } ]
                    , nextId = model.nextId + 1
                  }
                , Cmd.none
                )

        FailNext ->
            ( { model | failNext = not model.failNext }, Cmd.none )

        Resolve id value ->
            ( { model
                | entries =
                    List.map
                        (\entry ->
                            if entry.id == id then
                                { entry | resolved = value }

                            else
                                entry
                        )
                        model.entries
              }
            , Cmd.none
            )

        DataState value ->
            ( { model | dataState = value }, Cmd.none )

        Retry ->
            ( { model | dataState = Ready }, Klar.focus "dispatch-discussion" NoOp )

        Reset ->
            let
                ( fresh, cmd ) =
                    init
            in
            ( { fresh | ticket = model.ticket + 1, thread = Thread.reset model.thread }, cmd )

        NoOp ->
            ( model, Cmd.none )


view : Config.Config -> Settings -> Locale -> Model -> Html Msg
view playground settings locale model =
    let
        comments =
            List.map
                (\entry ->
                    let
                        value =
                            Thread.comment { id = entry.id, author = entry.author, body = entry.body, at = entry.at } |> Thread.resolved entry.resolved
                    in
                    Maybe.map (\parent -> Thread.replyTo parent value) entry.parent |> Maybe.withDefault value
                )
                model.entries

        remote =
            case model.dataState of
                Ready ->
                    Remote.Loaded comments

                Loading ->
                    Remote.Loading

                Failed ->
                    Remote.Failed (Remote.problem Remote.network)

                Empty ->
                    Remote.Loaded []

                Refreshing ->
                    Remote.refresh (Remote.Loaded comments)

                Stale ->
                    Remote.refreshWith (Remote.Loaded comments) (Err (Remote.problem Remote.network)) (Time.millisToPosix 0)
    in
    Doc.configuredSection playground
        [ "CommentThread" ]
        "CommentThread"
        "Replies, safe Markdown, explicit resolution and a draft that survives late server answers. Posting is simulated locally; no request is sent."
        [ Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
            [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "wrap" Layout.wrap ]))
                (List.map (\( label, value ) -> Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "pressed" (Button.pressed (value == model.dataState)), Config.keep playground "Button" "onClick" (Button.onClick (DataState value)) ])) label)
                    [ ( "Data", Ready ), ( "Loading", Loading ), ( "Failure", Failed ), ( "Empty", Empty ), ( "Refreshing", Refreshing ), ( "Old data", Stale ) ]
                    ++ [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "pressed" (Button.pressed model.failNext), Config.keep playground "Button" "onClick" (Button.onClick FailNext) ])) "Fail next post", Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "onClick" (Button.onClick Reset) ])) "Reset discussion" ]
                )
            , Text.secondary "Post a comment, then keep typing during the 1.5 second delay. The acknowledgement only clears the sent draft. A failed snapshot can be retried separately below."
            , Thread.view ThreadMsg
                (Options.klarCommentThread playground (List.concat [ Config.keep playground "CommentThread" "onSubmit" (Thread.onSubmit Post), Config.keep playground "CommentThread" "sending" (Thread.sending model.pending), Config.keep playground "CommentThread" "errorMaybe" (Thread.errorMaybe model.error), Config.keep playground "CommentThread" "onResolve" (Thread.onResolve Resolve), Config.keep playground "CommentThread" "onRetry" (Thread.onRetry Retry), Config.keep playground "CommentThread" "locale" (Thread.locale locale), Config.keep playground "CommentThread" "settings" (Thread.settings settings), Config.keep playground "CommentThread" "maxLength" (Thread.maxLength 2000) ]))
                { label = "Dispatch discussion", ids = Ids.int, comments = remote }
                model.thread
            , case model.failed of
                Just sent ->
                    Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2) ])) [ Text.strong "Retained failed post", Text.codeBlock (Thread.submissionBody sent), Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "disabled" (Button.disabled model.pending), Config.keep playground "Button" "onClick" (Button.onClick (Post sent)) ])) "Retry this exact post" ]

                Nothing ->
                    Html.text ""
            ]
        ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
