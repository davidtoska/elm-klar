module Examples.CommandPalette exposing (main)

{-| A command palette with a section that searches the backend while the user types
("Go to order ...") next to a static section of actions.

The pattern for the backend section:

  - `CommandPalette.query` before and after `update` tells that the text changed;
  - a ticket counter, a short pause (debounce) and a check of the ticket on the answer, so a slow
    answer to an old text never replaces a newer one;
  - the words of the command ("go to order") are taken off the text before it is sent;
  - the section is reset when the palette opens, and `onRetry` asks again.

Press Ctrl K (or the button). Type `fail` to see the failure and the retry button.

The pattern:

1.  Open: `CommandPalette.open openerId`, set the section to `NotAsked` and bump the ticket, so answers on their way are dropped.
2.  After `CommandPalette.update`, compare `CommandPalette.query` before and after. If it changed: `NotAsked`, bump the ticket, `Process.sleep 250` then `Debounced ticket`.
3.  `Debounced ticket` asks the backend only when the ticket is the latest and the text is not empty (`Loading`).
4.  `GotHits ticket result` is dropped when the ticket is old; otherwise `Remote.fromResult`.
5.  `CommandPalette.onRetry` sends `RetryHits`, which repeats step 3.
6.  The words of the command ("go to order") are stripped from the query before it is sent (`searchText`).

The palette is an overlay, so it goes in the list of `Overlay.host` (or `AppShell.overlays`). Type `fail` to see the failure and the retry button.

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
    , ticket : Int
    , done : String
    }


type Msg
    = OpenPalette
    | PaletteMsg CommandPalette.Msg
    | ShortcutMsg Shortcut.Msg
    | Debounced Int
    | GotHits Int (Result Remote.Problem (List Hit))
    | RetryHits
    | GoToOrder Hit
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
    , ticket = 0
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
            -- a new opening starts with an empty section and invalidates every answer on its way
            ( { model | palette = palette, hits = NotAsked, ticket = model.ticket + 1 }
            , Cmd.map PaletteMsg cmd
            )

        PaletteMsg m ->
            let
                ( palette, cmd ) =
                    CommandPalette.update m model.palette

                textChanged =
                    CommandPalette.query palette /= CommandPalette.query model.palette
            in
            if textChanged then
                let
                    ticket =
                        model.ticket + 1
                in
                ( { model | palette = palette, hits = NotAsked, ticket = ticket }
                , Cmd.batch
                    [ Cmd.map PaletteMsg cmd
                    , Process.sleep 250 |> Task.perform (\_ -> Debounced ticket)
                    ]
                )

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

        Debounced ticket ->
            let
                text =
                    searchText model.palette
            in
            if ticket == model.ticket && text /= "" then
                ( { model | hits = Loading }
                , lookup text |> Task.perform (GotHits ticket)
                )

            else
                ( model, Cmd.none )

        GotHits ticket result ->
            if ticket == model.ticket then
                ( { model | hits = Remote.fromResult result }, Cmd.none )

            else
                ( model, Cmd.none )

        RetryHits ->
            update (Debounced model.ticket) model

        GoToOrder hit ->
            ( { model | done = "Opened order " ++ hit.id ++ " (" ++ hit.customer ++ ")." }, Cmd.none )

        NewOrder ->
            ( { model | done = "New order started." }, Cmd.none )

        Reload ->
            ( { model | done = "Reloaded." }, Cmd.none )


shortcutList : List (Shortcut.Shortcut Msg)
shortcutList =
    [ Shortcut.shortcut (Shortcut.mod (Shortcut.char 'k')) "Navigation" "Open the command palette" OpenPalette
        |> Shortcut.inInputs
    ]


{-| The words of the command are not part of the search: "go to order 10" looks for "10".
-}
searchText : CommandPalette.State -> String
searchText palette =
    -- KLAR GAP: no way to give an item a prefix ("go to order") that the palette removes from the query; the application strips the words.
    let
        query =
            String.trim (CommandPalette.query palette)

        prefixes =
            [ "go to order", "open order", "go to", "order" ]

        strip prefix rest =
            if String.startsWith prefix (String.toLower rest) then
                String.trim (String.dropLeft (String.length prefix) rest)

            else
                rest
    in
    List.foldl strip query prefixes



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


viewPalette : Model -> Overlay.Overlay Msg
viewPalette model =
    CommandPalette.view PaletteMsg
        [ CommandPalette.sections
            [ CommandPalette.section "Actions"
                [ CommandPalette.item "New order" NewOrder
                    |> CommandPalette.withIcon Icon.plus
                    |> CommandPalette.withKeywords [ "create", "add" ]
                , CommandPalette.item "Reload" Reload
                    |> CommandPalette.withIcon Icon.refresh
                ]
            , CommandPalette.remote "Go to order ..." (Remote.map (List.map hitItem) model.hits)
                |> CommandPalette.onRetry RetryHits
                |> CommandPalette.emptyText "No order matches"
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
