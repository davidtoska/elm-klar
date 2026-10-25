module Page.Gallery.Actions.Split exposing
    ( Model
    , Msg
    , init
    , section
    , update
    )

{-| The split button of the gallery page "Actions and links": a main action with
a menu of alternatives. The main action pretends to save for a moment, so the
loading state can be seen.
-}

import Dict exposing (Dict)
import Html exposing (Html)
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.SplitButton as SplitButton
import Process
import Showcase.Doc as Doc
import Task



-- MODEL


type alias Model =
    { splits : Dict String SplitButton.State
    , saving : Bool
    , last : Maybe String
    }


init : Model
init =
    { splits = Dict.empty
    , saving = False
    , last = Nothing
    }


type Msg
    = SplitMsg String SplitButton.Msg
    | Did String
    | Save
    | Saved


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SplitMsg id inner ->
            SplitButton.update inner (stateOf id model)
                |> Tuple.mapBoth
                    (\split -> { model | splits = Dict.insert id split model.splits })
                    (Cmd.map (SplitMsg id))

        Did what ->
            ( { model | last = Just what }, Cmd.none )

        Save ->
            ( { model | saving = True, last = Just "Save (pretending for a moment)" }
            , Process.sleep 1500 |> Task.perform (\_ -> Saved)
            )

        Saved ->
            ( { model | saving = False, last = Just "Saved" }, Cmd.none )


stateOf : String -> Model -> SplitButton.State
stateOf id model =
    Dict.get id model.splits
        |> Maybe.withDefault (SplitButton.init id)



-- VIEW


section : Locale -> Model -> Html Msg
section locale model =
    let
        split id attributes content =
            SplitButton.view (SplitMsg id) (SplitButton.locale locale :: attributes) content (stateOf id model)
    in
    Doc.section "Split button"
        "A main action with a few alternatives behind a small arrow: Save with Save and close and Save as draft. The menu is the one of Klar.Menu, so it opens below the button with its right edge level with the button's, flips above when there is no room, and is never cut off by a card or a table."
        [ Doc.example
            { title = "A main action and its alternatives"
            , description = Just (lastText model.last ++ " Keyboard: Enter or Space on the main part saves; Enter, Space or ArrowDown on the arrow (and ArrowDown or Alt+ArrowDown on either part) opens the menu with the first item highlighted, ArrowUp on the arrow with the last, a letter jumps to an item, Escape closes it and gives focus back to the arrow, Tab leaves it. A dialog opened from the main part or an item names SplitButton.mainId or SplitButton.triggerId as its opener. Save pretends to work for a moment and shows the loading state.")
            , code = Just saveCode
            }
            (split "actions-split-save"
                [ SplitButton.primary, SplitButton.icon Icon.save, SplitButton.loading model.saving ]
                { label = "Save"
                , onClick = Save
                , items =
                    [ Menu.item "Save and close" (Did "Save and close") |> Menu.withIcon Icon.check
                    , Menu.item "Save as draft" (Did "Save as draft") |> Menu.withIcon Icon.fileText
                    , Menu.separator
                    , Menu.item "Discard changes" (Did "Discard changes") |> Menu.withIcon Icon.trash |> Menu.danger
                    ]
                }
            )
        , Doc.example
            { title = "Looks"
            , description = Just "The look is the look of a Button, and the same for both parts: secondary (the default), ghost, danger, and the sizes. A disabled item is skipped by the arrow keys."
            , code = Just looksCode
            }
            (Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                [ split "actions-split-export"
                    [ SplitButton.icon Icon.download ]
                    { label = "Export"
                    , onClick = Did "Export as CSV"
                    , items =
                        [ Menu.item "Export as Excel" (Did "Export as Excel")
                        , Menu.item "Export as PDF" (Did "Export as PDF")
                        , Menu.item "Export as JSON" (Did "Export as JSON") |> Menu.disabledItem
                        ]
                    }
                , split "actions-split-ghost"
                    [ SplitButton.ghost, SplitButton.small ]
                    { label = "Reload"
                    , onClick = Did "Reload"
                    , items =
                        [ Menu.item "Reload every minute" (Did "Reload every minute")
                        , Menu.item "Stop reloading" (Did "Stop reloading")
                        ]
                    }
                , split "actions-split-danger"
                    [ SplitButton.danger ]
                    { label = "Delete"
                    , onClick = Did "Delete"
                    , items =
                        [ Menu.item "Delete permanently" (Did "Delete permanently") |> Menu.danger
                        , Menu.item "Move to archive" (Did "Move to archive")
                        ]
                    }
                , split "actions-split-large"
                    [ SplitButton.primary, SplitButton.large ]
                    { label = "New order"
                    , onClick = Did "New order"
                    , items =
                        [ Menu.item "From a template" (Did "New order from a template")
                        , Menu.item "By copying an order" (Did "New order by copying")
                        ]
                    }
                ]
            )
        , Doc.example
            { title = "Disabled, and without alternatives"
            , description = Just "A disabled split button is off in both parts, which stay in the tab order (aria-disabled), so the focus is kept. A split button with no items is drawn as an ordinary button."
            , code = Nothing
            }
            (Layout.row [ Layout.gap 4, Layout.alignCenter, Layout.wrap ]
                [ split "actions-split-disabled"
                    [ SplitButton.disabled True ]
                    { label = "Approve"
                    , onClick = Did "Approve"
                    , items = [ Menu.item "Approve and notify" (Did "Approve and notify") ]
                    }
                , split "actions-split-none"
                    []
                    { label = "Approve"
                    , onClick = Did "Approve"
                    , items = []
                    }
                ]
            )
        , Doc.example
            { title = "At the end of a row"
            , description = Just "The menu ends where the button ends, so near the right edge it extends to the left. It also flips above the button near the bottom of the window."
            , code = Nothing
            }
            (Layout.row [ Layout.justifyEnd ]
                [ split "actions-split-end"
                    [ SplitButton.primary ]
                    { label = "Ship order"
                    , onClick = Did "Ship order"
                    , items =
                        [ Menu.item "Ship and print the label" (Did "Ship and print the label")
                        , Menu.item "Ship and notify the customer" (Did "Ship and notify the customer")
                        ]
                    }
                ]
            )
        ]


lastText : Maybe String -> String
lastText last =
    case last of
        Just what ->
            "Last action: " ++ what ++ "."

        Nothing ->
            "No action yet."



-- CODE


saveCode : String
saveCode =
    """-- model:   saveSplit : SplitButton.State   (SplitButton.init "order-save")

-- update
SaveSplitMsg inner ->
    let
        ( split, cmd ) =
            SplitButton.update inner model.saveSplit
    in
    ( { model | saveSplit = split }, Cmd.map SaveSplitMsg cmd )

-- view
SplitButton.view SaveSplitMsg
    [ SplitButton.primary
    , SplitButton.icon Icon.save
    , SplitButton.loading model.saving
    ]
    { label = "Save"
    , onClick = Save
    , items =
        [ Menu.item "Save and close" SaveAndClose |> Menu.withIcon Icon.check
        , Menu.item "Save as draft" SaveDraft |> Menu.withIcon Icon.fileText
        , Menu.separator
        , Menu.item "Discard changes" Discard |> Menu.withIcon Icon.trash |> Menu.danger
        ]
    }
    model.saveSplit
"""


looksCode : String
looksCode =
    """SplitButton.view ExportMsg
    [ SplitButton.icon Icon.download ]
    { label = "Export"
    , onClick = ExportCsv
    , items =
        [ Menu.item "Export as Excel" ExportExcel
        , Menu.item "Export as JSON" ExportJson |> Menu.disabledItem
        ]
    }
    model.export

SplitButton.view ReloadMsg [ SplitButton.ghost, SplitButton.small ] { ... } model.reload

SplitButton.view DeleteMsg [ SplitButton.danger ] { ... } model.delete
"""
