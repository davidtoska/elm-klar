module Page.Gallery.Examples exposing (view)

{-| Gallery page: the complete example programs in `example/src/Examples/`. Each is a
whole application of its own, built next to the showcase (`examples/<name>.html`), so
it opens in a tab of its own.
-}

import Html exposing (Html)
import Klar.Button as Button
import Klar.Card as Card
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Link as Link
import Klar.Text as Text
import Showcase.Doc as Doc


type alias Example =
    { file : String
    , page : String
    , title : String
    , task : String
    }


examples : List Example
examples =
    [ { file = "Inbox"
      , page = "inbox"
      , title = "Inbox: a list on the server"
      , task = "Orders that live on the server, with search, sorting, paging, a filter bar and saved views, all in one ServerList. Type \"fail\" in the search box to see the failure."
      }
    , { file = "EditForm"
      , page = "edit-form"
      , title = "Edit form with a save that can fail"
      , task = "A customer is loaded, edited, validated and saved with Klar.Form. The e-mail taken@example.com gives a field problem from the server, the name Crash a failure with a retry."
      }
    , { file = "ConfirmDelete"
      , page = "confirm-delete"
      , title = "Confirm before delete"
      , task = "A ConfirmDialog that is busy while it deletes and can fail, a toast with Undo, and the focus kept right, for one row and for a selection."
      }
    , { file = "Dashboard"
      , page = "dashboard"
      , title = "Dashboard"
      , task = "Every panel is its own Remote: it loads, fails, refreshes and shows old data on its own, and a period picker drops answers that come too late."
      }
    , { file = "MultiStep"
      , page = "multi-step"
      , title = "Multi-step flow with a leave guard"
      , task = "Three steps with a stepper, validation before Next, a submit that can fail, and a question before unsaved input is left, also with the browser's Back button."
      }
    , { file = "CommandPalette"
      , page = "command-palette"
      , title = "Command palette with a search as you type"
      , task = "Ctrl K opens a palette with fixed actions and a section that asks the backend while the user types, with a retry when the search fails."
      }
    , { file = "ReviewDesk"
      , page = "review-desk"
      , title = "Order review desk"
      , task = "Five components in one workflow: review orders with the keyboard, select cards, resolve concurrent edits, inspect audit diffs and manage persistent notifications. Includes every remote state."
      }
    ]


view : Html msg
view =
    Doc.page
        { title = "Examples"
        , description = "Seven complete applications for common screens. Each is one Elm file that uses only Klar, with no CSS and no class names, and it is the program an AI copies: example/src/Examples/<Name>.elm."
        }
        [ Doc.section "Programs" "Each one opens in a tab of its own, because it is an application of its own." (List.map viewExample examples) ]


viewExample : Example -> Html msg
viewExample example =
    Card.view [ Card.title example.title, Card.headingLevel 3 ]
        [ Layout.stack [ Layout.gap 3 ]
            [ Text.paragraph example.task
            , Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.wrap ]
                [ Button.view
                    [ Button.primary
                    , Button.href (Link.internal ("./examples/" ++ example.page ++ ".html"))
                    , Button.newTab
                    , Button.iconRight Icon.externalLink
                    ]
                    "Open"
                , Text.code ("example/src/Examples/" ++ example.file ++ ".elm")
                ]
            ]
        ]
