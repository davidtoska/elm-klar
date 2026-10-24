module Examples.CommandPalette exposing (main)

{-| A command palette with a section that searches the backend while the user types
("Go to order ...") next to a static section of actions.

The pattern for the backend section:

1.  Open: `CommandPalette.open openerId`, and set the section to `NotAsked`, so the answers of
    the last opening do not show under the new, empty query.
2.  After `CommandPalette.update`, compare `CommandPalette.query` before and after. The query
    waits for a pause of 300 ms in the typing by itself, so there is no debounce and no ticket to
    write: when it changed, ask the backend at once (`Loading`), or go back to `NotAsked` for an
    empty query.
3.  The item "Go to order ..." declares its words with `CommandPalette.withCommand`, and
    `CommandPalette.argument` gives the text after them ("go to order Fjord" asks for "Fjord").
4.  The answer carries the query it answers. `GotHits asked result` is dropped when `asked` is
    no longer `CommandPalette.query model.palette`: the user typed on, or closed the palette.
5.  `CommandPalette.onRetry` sends `RetryHits`, which asks again for the same query.

The palette is an overlay, so it goes in the list of `Overlay.host` (or `AppShell.overlays`).
Press Ctrl K (or the button). Type `fail` to see the failure and the retry button.

-}

import Browser
import Html exposing (Html)
import Klar
import Klar.Alert as Alert
import Klar.Button as Button
import Klar.CommandPalette as CommandPalette
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Overlay as Overlay
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote(..))
import Klar.Shortcut as Shortcut
import Klar.Text as Text
import Process
import Task



-- MODEL


type alias Hit =
    { id : String
    , customer : String
    }


type alias Model =
    { palette : CommandPalette.State
    , shortcuts : Shortcut.State
    , hits : Remote (List Hit)
    , done : String
    }


type Msg
    = OpenPalette
    | PaletteMsg CommandPalette.Msg
    | ShortcutMsg Shortcut.Msg
    | GotHits String (Result Remote.Problem (List Hit))
    | RetryHits
    | GoToOrder Hit
    | ShowOrders
    | NewOrder
    | Reload


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( init, Cmd.none )
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


init : Model
init =
    { palette = CommandPalette.init "palette"
    , shortcuts = Shortcut.init
    , hits = NotAsked
    , done = "Nothing yet."
    }


openButtonId : String
openButtonId =
    "open-palette"



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OpenPalette ->
            let
                ( palette, cmd ) =
                    CommandPalette.open openButtonId model.palette
            in
            ( { model | palette = palette, hits = NotAsked }, Cmd.map PaletteMsg cmd )

        PaletteMsg m ->
            let
                ( palette, cmd ) =
                    CommandPalette.update m model.palette
            in
            if CommandPalette.query palette /= CommandPalette.query model.palette then
                search { model | palette = palette } (Cmd.map PaletteMsg cmd)

            else
                ( { model | palette = palette }, Cmd.map PaletteMsg cmd )

        ShortcutMsg m ->
            let
                ( shortcuts, triggered ) =
                    Shortcut.update shortcutList m model.shortcuts
            in
            case triggered of
                Just next ->
                    update next { model | shortcuts = shortcuts }

                Nothing ->
                    ( { model | shortcuts = shortcuts }, Cmd.none )

        GotHits asked result ->
            -- an answer to a query that is no longer the palette's comes too late
            if asked == CommandPalette.query model.palette then
                ( { model | hits = Remote.fromResult result }, Cmd.none )

            else
                ( model, Cmd.none )

        RetryHits ->
            search model Cmd.none

        GoToOrder hit ->
            ( { model | done = "Opened order " ++ hit.id ++ " (" ++ hit.customer ++ ")." }, Cmd.none )

        ShowOrders ->
            ( { model | done = "Showed all orders." }, Cmd.none )

        NewOrder ->
            ( { model | done = "New order started." }, Cmd.none )

        Reload ->
            ( { model | done = "Reloaded." }, Cmd.none )


{-| Asks the backend for the palette's query, without the words of the command.
-}
search : Model -> Cmd Msg -> ( Model, Cmd Msg )
search model cmd =
    let
        asked =
            CommandPalette.query model.palette

        text =
            CommandPalette.argument [ goToOrder ] model.palette
    in
    if text == "" then
        ( { model | hits = NotAsked }, cmd )

    else
        ( { model | hits = Loading }
        , Cmd.batch [ cmd, lookup text |> Task.perform (GotHits asked) ]
        )


shortcutList : List (Shortcut.Shortcut Msg)
shortcutList =
    [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette
        |> Shortcut.inInputs
    ]



-- VIEW


view : Model -> Html Msg
view model =
    Overlay.host
        { attributes = [ Shortcut.listen ShortcutMsg shortcutList model.shortcuts ]
        , page =
            [ Klar.stylesheet
            , Layout.stack [ Layout.gap 3, Layout.padding 4 ]
                [ PageHeader.view [ PageHeader.title "Command palette" ]
                , Layout.row [ Layout.gap 2 ]
                    [ Button.view [ Button.id openButtonId, Button.icon Icon.search, Button.onClick OpenPalette ] "Search or run a command" ]
                , Text.paragraph "Press Ctrl K, then type \"go to order Fjord\" or \"Cedar\"."
                , Alert.view [ Alert.polite ] model.done
                ]
            ]
        , overlays = [ viewPalette model ]
        }


{-| The item that "go to order ..." calls. The same value goes to the view and to
`CommandPalette.argument`.
-}
goToOrder : CommandPalette.Item Msg
goToOrder =
    CommandPalette.item "Go to order ..." ShowOrders
        |> CommandPalette.withIcon Icon.clipboard
        |> CommandPalette.withCommand "go to order"
        |> CommandPalette.withCommand "open order"


viewPalette : Model -> Overlay.Overlay Msg
viewPalette model =
    CommandPalette.view PaletteMsg
        [ CommandPalette.sections
            [ CommandPalette.section "Actions"
                [ goToOrder
                , CommandPalette.item "New order" NewOrder
                    |> CommandPalette.withIcon Icon.plus
                    |> CommandPalette.withKeywords [ "create", "add" ]
                , CommandPalette.item "Reload" Reload
                    |> CommandPalette.withIcon Icon.refresh
                ]
            , CommandPalette.remote "Orders" (Remote.map (List.map hitItem) model.hits)
                |> CommandPalette.onRetry RetryHits
                |> CommandPalette.withEmptyText "No order matches"
            ]
        , CommandPalette.placeholder "Type a command, or an order number or customer"
        ]
        model.palette


hitItem : Hit -> CommandPalette.Item Msg
hitItem hit =
    CommandPalette.item (hit.id ++ "  " ++ hit.customer) (GoToOrder hit)
        |> CommandPalette.withId hit.id



-- THE BACKEND (a stand-in: replace `lookup` with a request)


lookup : String -> Task.Task Never (Result Remote.Problem (List Hit))
lookup text =
    Process.sleep 350
        |> Task.map
            (\_ ->
                if String.toLower text == "fail" then
                    Err (Remote.problem Remote.network)

                else
                    Ok (List.filter (matches (String.toLower text)) orders |> List.take 8)
            )


matches : String -> Hit -> Bool
matches needle hit =
    String.contains needle (String.toLower (hit.id ++ " " ++ hit.customer))


orders : List Hit
orders =
    List.range 1 60
        |> List.map
            (\n ->
                { id = "SO-" ++ String.fromInt (1000 + n)
                , customer = customerAt n
                }
            )


customerAt : Int -> String
customerAt n =
    [ "Aurora Logistics", "Fjord Foods", "Birch Hardware", "Cedar Supplies" ]
        |> List.drop (modBy 4 n)
        |> List.head
        |> Maybe.withDefault ""
