module Page.Gallery.Arranging.Sortables exposing (Model, Msg, init, update, view)

{-| The sortable section: a pick sequence with ids of its own type, a chip list, a
list with fixed items that can be locked or emptied, and a list whose whole items
can be dragged and that has move buttons.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Icon as Icon
import Klar.Ids as Ids exposing (Ids)
import Klar.Layout as Layout
import Klar.Locale exposing (Locale)
import Klar.Sortable as Sortable
import Klar.Switch as Switch
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Showcase.Config as Config
import Showcase.Doc as Doc
import Showcase.Options as Options



-- MODEL


{-| The number of a step. A type of its own: a step cannot be mixed up with a
warehouse or an order, and the list never sees a `String`.
-}
type StepId
    = StepId Int


stepIds : Ids StepId
stepIds =
    Ids.make
        { toKey = \(StepId n) -> "step-" ++ String.fromInt n
        , fromKey = \key -> String.toInt (String.dropLeft 5 key) |> Maybe.map StepId
        }


type alias Step =
    { id : StepId
    , title : String
    , place : String
    , fixed : Bool
    }


type alias Model =
    { steps : List Step
    , stepList : Sortable.State StepId
    , chips : List String
    , chipList : Sortable.State String
    , locked : Bool
    , plan : List Step
    , planList : Sortable.State StepId
    , shipments : List String
    , shipmentList : Sortable.State String
    }


type Msg
    = StepsMsg Sortable.Msg
    | ChipsMsg Sortable.Msg
    | PlanMsg Sortable.Msg
    | ShipmentsMsg Sortable.Msg
    | ResetSteps
    | ResetChips
    | SetLocked Bool
    | ClearPlan
    | ResetPlan


init : Model
init =
    { steps = pickSteps
    , stepList = Sortable.init "pick-steps"
    , chips = warehouses
    , chipList = Sortable.init "warehouse-chips"
    , locked = False
    , plan = fixedPlan
    , planList = Sortable.init "plan-steps"
    , shipments = shipmentNumbers
    , shipmentList = Sortable.init "shipments"
    }


pickSteps : List Step
pickSteps =
    [ { id = StepId 1, title = "Pick M6 bolts", place = "Bay A1, 40 pieces", fixed = False }
    , { id = StepId 2, title = "Pick washers", place = "Bay A1, 80 pieces", fixed = False }
    , { id = StepId 3, title = "Pick safety gloves", place = "Bay C3, 6 pairs", fixed = False }
    , { id = StepId 4, title = "Pick packaging foam", place = "Bay D2, 2 sheets", fixed = False }
    , { id = StepId 5, title = "Pick pallet labels", place = "Desk 1, 1 roll", fixed = False }
    ]


fixedPlan : List Step
fixedPlan =
    { id = StepId 10, title = "Scan the tote", place = "Dock 4", fixed = True }
        :: List.map (\step -> { step | id = StepId (20 + stepNumber step.id) }) (List.take 3 pickSteps)
        ++ [ { id = StepId 30, title = "Seal and label the tote", place = "Dock 4", fixed = True } ]


stepNumber : StepId -> Int
stepNumber (StepId n) =
    n


warehouses : List String
warehouses =
    [ "Rotterdam", "Hamburg", "Antwerp", "Gdansk", "Le Havre", "Bremerhaven", "Felixstowe" ]


shipmentNumbers : List String
shipmentNumbers =
    [ "SHP-20418", "SHP-20419", "SHP-20420", "SHP-20421" ]



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        StepsMsg inner ->
            let
                ( list, cmd ) =
                    Sortable.update inner model.stepList
            in
            ( { model
                | stepList = list
                , steps = Sortable.reorder stepIds .id model.stepList list model.steps
              }
            , Cmd.map StepsMsg cmd
            )

        ChipsMsg inner ->
            let
                ( list, cmd ) =
                    Sortable.update inner model.chipList
            in
            ( { model
                | chipList = list
                , chips = Sortable.reorder Ids.string identity model.chipList list model.chips
              }
            , Cmd.map ChipsMsg cmd
            )

        PlanMsg inner ->
            let
                ( list, cmd ) =
                    Sortable.update inner model.planList
            in
            ( { model
                | planList = list
                , plan = Sortable.reorder stepIds .id model.planList list model.plan
              }
            , Cmd.map PlanMsg cmd
            )

        ShipmentsMsg inner ->
            let
                ( list, cmd ) =
                    Sortable.update inner model.shipmentList
            in
            ( { model
                | shipmentList = list
                , shipments = Sortable.reorder Ids.string identity model.shipmentList list model.shipments
              }
            , Cmd.map ShipmentsMsg cmd
            )

        ResetSteps ->
            ( { model | steps = pickSteps }, Cmd.none )

        ResetChips ->
            ( { model | chips = warehouses }, Cmd.none )

        SetLocked value ->
            ( { model | locked = value }, Cmd.none )

        ClearPlan ->
            ( { model | plan = [] }, Cmd.none )

        ResetPlan ->
            ( { model | plan = fixedPlan }, Cmd.none )



-- VIEW


view : Config.Config -> Locale -> Model -> Html Msg
view playground locale model =
    Doc.configuredSection playground
        []
        "Sortable"
        "A list the user puts in a new order. Take hold of the grip with the mouse, a finger or a pen and drag; or tab to the grip and press Space, move with the arrow keys (Home and End jump to the ends), and press Space again to drop (Escape cancels). While an item is held a line shows where it would land, and nothing else moves. A live region says what happens: picked up, moved to position, dropped, cancelled."
        [ pickSequenceExample playground locale model
        , chipsExample playground locale model
        , planExample playground locale model
        , shipmentsExample playground locale model
        ]


order : List String -> String
order names =
    String.join "  >  " names


pickSequenceExample : Config.Config -> Locale -> Model -> Html Msg
pickSequenceExample playground locale model =
    Doc.configuredExample playground
        [ "Sortable" ]
        { title = "A pick sequence, with ids of its own type"
        , description = Just "The application keeps its steps in its own order and draws them in that order. When the user lets go, reorder puts the dropped step in its new place in the same update. The ids are a StepId, written as text once with Klar.Ids; no String ids in the code of the page."
        , code = Just """type StepId = StepId Int

stepIds : Ids StepId
stepIds =
    Ids.make
        { toKey = \\(StepId n) -> "step-" ++ String.fromInt n
        , fromKey = \\key -> String.toInt (String.dropLeft 5 key) |> Maybe.map StepId
        }

-- update
StepsMsg inner ->
    let
        ( list, cmd ) =
            Sortable.update inner model.stepList
    in
    ( { model
        | stepList = list
        , steps = Sortable.reorder stepIds .id model.stepList list model.steps
      }
    , Cmd.map StepsMsg cmd
    )

-- view
Sortable.view StepsMsg
    [ Sortable.ariaLabel "Pick sequence" ]
    model.stepList
    (List.map
        (\\step ->
            Sortable.item stepIds step.id step.title (viewStep step)
        )
        model.steps
    )"""
        }
        (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
            [ Sortable.view StepsMsg
                (Options.klarSortable playground (List.concat [ Config.keep playground "Sortable" "ariaLabel" (Sortable.ariaLabel "Pick sequence"), Config.keep playground "Sortable" "locale" (Sortable.locale locale) ]))
                model.stepList
                (List.map (\step -> Sortable.item stepIds step.id step.title (stepRow playground step)) model.steps)
            , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "alignCenter" Layout.alignCenter, Config.keep playground "Layout" "wrap" Layout.wrap ]))
                [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "icon" (Button.icon Icon.refresh), Config.keep playground "Button" "onClick" (Button.onClick ResetSteps) ])) "Reset"
                , Text.caption
                    (case Sortable.lifted stepIds model.stepList of
                        Just (StepId n) ->
                            "Held: step " ++ String.fromInt n

                        Nothing ->
                            "Nothing is held."
                    )
                ]
            , Text.caption ("Saved order: " ++ order (List.map .title model.steps))
            ]
        )


stepRow : Config.Config -> Step -> Html msg
stepRow playground step =
    Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
        [ Html.span [ Attr.class "klar-truncate" ] [ Html.text step.title ]
        , Layout.spacer
        , Text.caption step.place
        ]


chipsExample : Config.Config -> Locale -> Model -> Html Msg
chipsExample playground locale model =
    Doc.configuredExample playground
        [ "Sortable", "Ids" ]
        { title = "A chip list"
        , description = Just "Left and Right move an item in a horizontal list. The chips wrap onto more lines; the line shows the gap the item would land in. The ids are plain text here."
        , code = Just """Sortable.view ChipsMsg
    [ Sortable.horizontal, Sortable.ariaLabel "Preferred warehouses" ]
    model.chipList
    (List.map (\\name -> Sortable.item Ids.string name name (Html.text name)) model.chips)

-- update
ChipsMsg inner ->
    let
        ( list, cmd ) =
            Sortable.update inner model.chipList
    in
    ( { model
        | chipList = list
        , chips = Sortable.reorder Ids.string identity model.chipList list model.chips
      }
    , Cmd.map ChipsMsg cmd
    )"""
        }
        (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
            [ Sortable.view ChipsMsg
                (Options.klarSortable playground (List.concat [ Config.keep playground "Sortable" "horizontal" Sortable.horizontal, Config.keep playground "Sortable" "ariaLabel" (Sortable.ariaLabel "Preferred warehouses"), Config.keep playground "Sortable" "locale" (Sortable.locale locale) ]))
                model.chipList
                (List.map (\name -> Sortable.item Ids.string name name (Html.text name)) model.chips)
            , Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
                [ Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "icon" (Button.icon Icon.refresh), Config.keep playground "Button" "onClick" (Button.onClick ResetChips) ])) "Reset"
                , Text.caption (order model.chips)
                ]
            ]
        )


planExample : Config.Config -> Locale -> Model -> Html Msg
planExample playground locale model =
    Doc.configuredExample playground
        [ "Switch", "Sortable" ]
        { title = "Fixed steps, a locked list and an empty list"
        , description = Just "The first and the last step are fixed: they have a lock instead of a grip, cannot be moved, and nothing can be moved past them. Lock the list and every grip is dimmed and out of reach of the keyboard. The move buttons stop at the fixed steps too. Clear the list to see the empty state."
        , code = Just """Sortable.view PlanMsg
    [ Sortable.ariaLabel "Plan"
    , Sortable.moveButtons
    , Sortable.disabled model.locked
    , Sortable.emptyText "No steps in the plan."
    ]
    model.planList
    (List.map
        (\\step ->
            let
                row =
                    Sortable.item stepIds step.id step.title (viewStep step)
            in
            if step.fixed then
                Sortable.fixed row

            else
                row
        )
        model.plan
    )"""
        }
        (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
            [ Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3), Config.keep playground "Layout" "alignCenter" Layout.alignCenter, Config.keep playground "Layout" "wrap" Layout.wrap ]))
                [ Switch.view (Options.klarSwitch playground (List.concat [ Config.keep playground "Switch" "label" (Switch.label "Lock the list"), Config.keep playground "Switch" "checked" (Switch.checked model.locked), Config.keep playground "Switch" "onCheck" (Switch.onCheck SetLocked) ]))
                , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "icon" (Button.icon Icon.trash), Config.keep playground "Button" "onClick" (Button.onClick ClearPlan) ])) "Clear the list"
                , Options.buttonView playground (Options.klarButton playground (List.concat [ Config.keep playground "Button" "small" Button.small, Config.keep playground "Button" "icon" (Button.icon Icon.refresh), Config.keep playground "Button" "onClick" (Button.onClick ResetPlan) ])) "Reset"
                ]
            , Sortable.view PlanMsg
                (Options.klarSortable playground
                    (List.concat
                        [ Config.keep playground "Sortable" "ariaLabel" (Sortable.ariaLabel "Plan")
                        , Config.keep playground "Sortable" "moveButtons" Sortable.moveButtons
                        , Config.keep playground "Sortable" "disabled" (Sortable.disabled model.locked)
                        , Config.keep playground "Sortable" "emptyText" (Sortable.emptyText "No steps in the plan.")
                        , Config.keep playground "Sortable" "locale" (Sortable.locale locale)
                        ]
                    )
                )
                model.planList
                (List.map
                    (\step ->
                        let
                            row =
                                Sortable.item stepIds step.id step.title (stepRow playground step)
                        in
                        if step.fixed then
                            Sortable.fixed row

                        else
                            row
                    )
                    model.plan
                )
            , Text.caption ("Order: " ++ order (List.map .title model.plan))
            ]
        )


shipmentsExample : Config.Config -> Locale -> Model -> Html Msg
shipmentsExample playground locale model =
    Doc.configuredExample playground
        [ "Sortable", "Ids", "Badge" ]
        { title = "The whole item as the handle, and move buttons"
        , description = Just "With wholeItem the mouse can take hold of an item anywhere, except on its buttons and links. A finger uses the grip only, so the rest of the item still scrolls the page. moveButtons adds Move up and Move down to every item: the way to reorder for people who cannot drag. A press moves the item one place, through reorder like a drop, says where it went, and the focus stays on the button; at the end the button is dimmed and says that the item cannot move further. Nothing to write in the update."
        , code = Just """Sortable.view ShipmentsMsg
    [ Sortable.wholeItem, Sortable.moveButtons, Sortable.ariaLabel "Shipments" ]
    model.shipmentList
    (List.map (\\number -> Sortable.item Ids.string number number (shipmentRow number)) model.shipments)"""
        }
        (Layout.stack (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 3) ]))
            [ Sortable.view ShipmentsMsg
                (Options.klarSortable playground (List.concat [ Config.keep playground "Sortable" "wholeItem" Sortable.wholeItem, Config.keep playground "Sortable" "moveButtons" Sortable.moveButtons, Config.keep playground "Sortable" "ariaLabel" (Sortable.ariaLabel "Shipments"), Config.keep playground "Sortable" "locale" (Sortable.locale locale) ]))
                model.shipmentList
                (List.map (\number -> Sortable.item Ids.string number number (shipmentRow playground number)) model.shipments)
            , Text.caption ("Order: " ++ order model.shipments)
            ]
        )


shipmentRow : Config.Config -> String -> Html Msg
shipmentRow playground number =
    Layout.row (Options.klarLayout playground (List.concat [ Config.keep playground "Layout" "gap" (Layout.gap 2), Config.keep playground "Layout" "alignCenter" Layout.alignCenter ]))
        [ Html.span [ Attr.class "klar-tabular" ] [ Html.text number ]
        , Options.badgeView playground (Options.klarBadge playground (List.concat [ Config.keep playground "Badge" "tone" (Badge.tone Info) ])) "Ready to ship"
        ]
