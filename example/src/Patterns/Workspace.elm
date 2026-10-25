module Patterns.Workspace exposing (connectionCard, demoNotice, flow, header, link, permission, result, section)

{-| Larger, copyable view compositions built only from public Klar components.
The application owns messages, transport and credentials. No CSS is needed.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Alert as Alert
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.Checkbox as Checkbox
import Klar.Icon as Icon exposing (Icon)
import Klar.Layout as Layout
import Klar.Link as Link
import Klar.PageHeader as PageHeader
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))


header : String -> String -> List (Html msg) -> Html msg
header title description actions =
    PageHeader.view [ PageHeader.title title, PageHeader.subtitle description, PageHeader.actions actions ]


demoNotice : Html msg
demoNotice =
    Alert.view [ Alert.tone Info, Alert.compact ] "Interactive demo · Responses are simulated. Use made-up credentials; nothing is sent or saved."


section : String -> String -> List (Html msg) -> Html msg
section title subtitle children =
    Card.view [ Card.title title, Card.subtitle subtitle ] [ Layout.stack [ Layout.gap 4 ] children ]


link : String -> String -> Html msg
link label slug =
    Button.view [ Button.ghost, Button.small, Button.href (Link.internal ("#/applications/" ++ slug)), Button.iconRight Icon.arrowRight ] label


connectionCard : { name : String, description : String, icon : Icon, state : String, tone : Tone, action : Html msg } -> Html msg
connectionCard config =
    Card.view []
        [ Layout.stack [ Layout.gap 4 ]
            [ Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.wrap ]
                [ Icon.sized Icon.Large config.icon, Text.subheading config.name, Layout.spacer, Badge.view [ Badge.tone config.tone, Badge.dot ] config.state ]
            , Text.paragraph config.description
            , config.action
            ]
        ]


permission : { label : String, reason : String, selected : Bool, onChange : Bool -> msg, disabled : Bool } -> Html msg
permission config =
    Checkbox.view [ Checkbox.label config.label, Checkbox.hint config.reason, Checkbox.checked config.selected, Checkbox.onCheck config.onChange, Checkbox.disabled config.disabled ]


flow : List String -> Int -> Html msg
flow labels active =
    Layout.row [ Layout.gap 2, Layout.wrap ]
        (List.indexedMap
            (\index label ->
                Badge.view
                    [ Badge.tone
                        (if index < active then
                            Success

                         else if index == active then
                            Info

                         else
                            Neutral
                        )
                    ]
                    (String.fromInt (index + 1) ++ " · " ++ label)
            )
            labels
        )


result : String -> Tone -> String -> Html msg
result id tone message =
    Html.div [ Attr.id id, Attr.tabindex -1, Attr.attribute "role" "status", Attr.attribute "aria-live" "polite" ]
        [ if String.isEmpty message then
            Html.text ""

          else
            Alert.view [ Alert.tone tone ] message
        ]
