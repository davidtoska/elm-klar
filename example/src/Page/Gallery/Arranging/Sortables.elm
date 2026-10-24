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
import Showcase.Doc as Doc



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


view : Locale -> Model -> Html Msg
view locale model =
    Doc.section "Sortable"
        "A list the user puts in a new order. Take hold of the grip with the mouse, a finger or a pen and drag; or tab to the grip and press Space, move with the arrow keys (Home and End jump to the ends), and press Space again to drop (Escape cancels). While an item is held a line shows where it would land, and nothing else moves. A live region says what happens: picked up, moved to position, dropped, cancelled."
        [ pickSequenceExample locale model
        , chipsExample locale model
        , planExample locale model
        , shipmentsExample locale model
        ]


order : List String -> String
order names =
    String.join "  >  " names


pickSequenceExample : Locale -> Model -> Html Msg
pickSequenceExample locale model =
    Doc.example
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
        (Layout.stack [ Layout.gap 3 ]
            [ Sortable.view StepsMsg
                [ Sortable.ariaLabel "Pick sequence", Sortable.locale locale ]
                model.stepList
                (List.map (\step -> Sortable.item stepIds step.id step.title (stepRow step)) model.steps)
            , Layout.row [ Layout.gap 2, Layout.alignCenter, Layout.wrap ]
                [ Button.view [ Button.small, Button.icon Icon.refresh, Button.onClick ResetSteps ] "Reset"
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


stepRow : Step -> Html msg
stepRow step =
    Layout.row [ Layout.gap 2, Layout.alignCenter ]
        [ Html.span [ Attr.class "klar-truncate" ] [ Html.text step.title ]
        , Layout.spacer
        , Text.caption step.place
        ]


chipsExample : Locale -> Model -> Html Msg
chipsExample locale model =
    Doc.example
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
        (Layout.stack [ Layout.gap 3 ]
            [ Sortable.view ChipsMsg
                [ Sortable.horizontal, Sortable.ariaLabel "Preferred warehouses", Sortable.locale locale ]
                model.chipList
                (List.map (\name -> Sortable.item Ids.string name name (Html.text name)) model.chips)
            , Layout.row [ Layout.gap 2, Layout.alignCenter ]
                [ Button.view [ Button.small, Button.icon Icon.refresh, Button.onClick ResetChips ] "Reset"
                , Text.caption (order model.chips)
                ]
            ]
        )


planExample : Locale -> Model -> Html Msg
planExample locale model =
    Doc.example
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
        (Layout.stack [ Layout.gap 3 ]
            [ Layout.row [ Layout.gap 3, Layout.alignCenter, Layout.wrap ]
                [ Switch.view [ Switch.label "Lock the list", Switch.checked model.locked, Switch.onToggle SetLocked ]
                , Button.view [ Button.small, Button.icon Icon.trash, Button.onClick ClearPlan ] "Clear the list"
                , Button.view [ Button.small, Button.icon Icon.refresh, Button.onClick ResetPlan ] "Reset"
                ]
            , Sortable.view PlanMsg
                [ Sortable.ariaLabel "Plan"
                , Sortable.moveButtons
                , Sortable.disabled model.locked
                , Sortable.emptyText "No steps in the plan."
                , Sortable.locale locale
                ]
                model.planList
                (List.map
                    (\step ->
                        let
                            row =
                                Sortable.item stepIds step.id step.title (stepRow step)
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


shipmentsExample : Locale -> Model -> Html Msg
shipmentsExample locale model =
    Doc.example
        { title = "The whole item as the handle, and move buttons"
        , description = Just "With wholeItem the mouse can take hold of an item anywhere, except on its buttons and links. A finger uses the grip only, so the rest of the item still scrolls the page. moveButtons adds Move up and Move down to every item: the way to reorder for people who cannot drag. A press moves the item one place, through reorder like a drop, says where it went, and the focus stays on the button; at the end the button is dimmed and says that the item cannot move further. Nothing to write in the update."
        , code = Just """Sortable.view ShipmentsMsg
    [ Sortable.wholeItem, Sortable.moveButtons, Sortable.ariaLabel "Shipments" ]
    model.shipmentList
    (List.map (\\number -> Sortable.item Ids.string number number (shipmentRow number)) model.shipments)"""
        }
        (Layout.stack [ Layout.gap 3 ]
            [ Sortable.view ShipmentsMsg
                [ Sortable.wholeItem, Sortable.moveButtons, Sortable.ariaLabel "Shipments", Sortable.locale locale ]
                model.shipmentList
                (List.map (\number -> Sortable.item Ids.string number number (shipmentRow number)) model.shipments)
            , Text.caption ("Order: " ++ order model.shipments)
            ]
        )


shipmentRow : String -> Html Msg
shipmentRow number =
    Layout.row [ Layout.gap 2, Layout.alignCenter ]
        [ Html.span [ Attr.class "klar-tabular" ] [ Html.text number ]
        , Badge.view [ Badge.tone Info ] "Ready to ship"
        ]
