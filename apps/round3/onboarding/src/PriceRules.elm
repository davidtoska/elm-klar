module PriceRules exposing
    ( Msg
    , State
    , addButtonId
    , fieldsFor
    , init
    , isDirty
    , load
    , markClean
    , problems
    , rules
    , sentence
    , serverProblems
    , setAttempted
    , update
    , view
    )

{-| The price rules of a supplier: "if the order matches these conditions, give this discount".
Each rule is a rule builder (the conditions) and a number (the discount). The list is not part of
`Klar.Form`: its problems go to the form through `Form.outside`.
-}

import Domain exposing (CategoryId, CountryId, PriceRule)
import Html exposing (Html)
import Klar.Button as Button
import Klar.Card as Card
import Klar.EmptyState as EmptyState
import Klar.Form as Form
import Klar.Form.Layout as FormLayout
import Klar.Icon as Icon
import Klar.Layout as Layout
import Klar.Locale as Locale exposing (Locale)
import Klar.NumberInput as NumberInput
import Klar.Rule as Rule
import Klar.RuleBuilder as RuleBuilder
import Klar.Select.Option as Option
import Klar.Text as Text
import SupplierForm exposing (Step(..))


type alias Entry =
    { key : Int
    , builder : RuleBuilder.State
    , discount : NumberInput.State
    , serverError : Maybe String
    }


type alias State =
    { entries : List Entry
    , nextKey : Int
    , baseline : List ( Rule.Rule, Maybe Float )
    , attempted : Bool
    }


type Msg
    = Add
    | Remove Int
    | BuilderMsg Int RuleBuilder.Msg
    | DiscountMsg Int NumberInput.Msg
    | NoOp


init : State
init =
    { entries = [], nextKey = 1, baseline = [], attempted = False }


addButtonId : String
addButtonId =
    "price-rules-add"


builderId : Int -> String
builderId key =
    "price-rule-" ++ String.fromInt key


discountId : Int -> String
discountId key =
    "price-rule-" ++ String.fromInt key ++ "-discount"


newEntry : Int -> Entry
newEntry key =
    { key = key
    , builder = RuleBuilder.init (builderId key)
    , discount = NumberInput.init (discountId key)
    , serverError = Nothing
    }


{-| What a rule can talk about. The rows do not exist in the browser, so the getters give nothing.
-}
fieldsFor :
    { categories : List (Option.Option CategoryId), countries : List (Option.Option CountryId) }
    -> List (Rule.Field ())
fieldsFor options =
    [ Rule.choiceFieldOf Domain.categoryIds Domain.categoryFieldId "Category" options.categories (always Nothing)
        |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf ]
    , Rule.numberField Domain.quantityFieldId "Quantity" (always Nothing)
    , Rule.choiceFieldOf Domain.countryIds Domain.countryFieldId "Delivery country" options.countries (always Nothing)
        |> Rule.withOperators [ Rule.Is, Rule.IsNot, Rule.IsAnyOf ]
    ]


snapshot : State -> List ( Rule.Rule, Maybe Float )
snapshot state =
    List.map (\e -> ( RuleBuilder.rule e.builder, NumberInput.value e.discount )) state.entries


isDirty : State -> Bool
isDirty state =
    snapshot state /= state.baseline


markClean : State -> State
markClean state =
    { state | baseline = snapshot state }


load : List PriceRule -> State -> State
load priceRules state =
    let
        entries =
            List.indexedMap
                (\i r ->
                    let
                        entry =
                            newEntry (state.nextKey + i)
                    in
                    { entry
                        | builder = RuleBuilder.setRule r.condition entry.builder
                        , discount = NumberInput.setValue (Just r.discountPercent) entry.discount
                    }
                )
                priceRules
    in
    markClean { state | entries = entries, nextKey = state.nextKey + List.length priceRules, attempted = False }


rules : State -> List PriceRule
rules state =
    List.filterMap
        (\e ->
            NumberInput.value e.discount
                |> Maybe.map (\d -> { condition = RuleBuilder.rule e.builder, discountPercent = d })
        )
        state.entries


{-| The server refused the discount of the rule at this position.
-}
serverProblems : List ( Int, String ) -> State -> State
serverProblems found state =
    { state
        | entries =
            List.indexedMap
                (\i e -> { e | serverError = List.filter (\( at, _ ) -> at == i) found |> List.head |> Maybe.map Tuple.second })
                state.entries
    }


setAttempted : Bool -> State -> State
setAttempted attempted state =
    { state
        | attempted = attempted
        , entries =
            List.map
                (\e ->
                    { e
                        | builder =
                            if attempted then
                                RuleBuilder.showIssues e.builder

                            else
                                RuleBuilder.hideIssues e.builder
                    }
                )
                state.entries
    }


update : Msg -> State -> ( State, Cmd Msg )
update msg state =
    case msg of
        Add ->
            let
                entry =
                    newEntry state.nextKey
            in
            ( setAttempted state.attempted { state | entries = state.entries ++ [ entry ], nextKey = state.nextKey + 1 }
            , FormLayout.focusField (discountId entry.key) NoOp
            )

        Remove key ->
            let
                remaining =
                    List.filter (\e -> e.key /= key) state.entries
            in
            ( { state | entries = remaining }
            , case List.head remaining of
                Just first ->
                    FormLayout.focusField (discountId first.key) NoOp

                Nothing ->
                    FormLayout.focusField addButtonId NoOp
            )

        BuilderMsg key inner ->
            updateEntry key
                (\e ->
                    let
                        ( builder, cmd ) =
                            RuleBuilder.update inner e.builder
                    in
                    ( { e | builder = builder }, Cmd.map (BuilderMsg key) cmd )
                )
                state

        DiscountMsg key inner ->
            updateEntry key
                (\e ->
                    let
                        ( discount, cmd ) =
                            NumberInput.update inner e.discount
                    in
                    ( { e | discount = discount, serverError = Nothing }, Cmd.map (DiscountMsg key) cmd )
                )
                state

        NoOp ->
            ( state, Cmd.none )


updateEntry : Int -> (Entry -> ( Entry, Cmd Msg )) -> State -> ( State, Cmd Msg )
updateEntry key change state =
    let
        results =
            List.map
                (\e ->
                    if e.key == key then
                        change e

                    else
                        ( e, Cmd.none )
                )
                state.entries
    in
    ( { state | entries = List.map Tuple.first results }, Cmd.batch (List.map Tuple.second results) )



-- PROBLEMS, for Form.outside


problems : Locale -> List (Rule.Field ()) -> State -> List (Form.Problem Step)
problems locale fields state =
    state.entries
        |> List.indexedMap (entryProblems locale fields)
        |> List.concat


entryProblems : Locale -> List (Rule.Field ()) -> Int -> Entry -> List (Form.Problem Step)
entryProblems locale fields index entry =
    let
        name =
            "Price rule " ++ String.fromInt (index + 1)

        rule =
            RuleBuilder.rule entry.builder

        conditionProblem =
            if Rule.isEmpty rule then
                [ { field = focusTarget entry.key rule 0, label = name ++ ", conditions", message = "Add at least one condition.", step = Just Pricing } ]

            else
                case Rule.validate locale fields rule of
                    issue :: _ ->
                        [ { field = focusTarget entry.key rule issue.nodeId, label = name ++ ", conditions", message = issue.message, step = Just Pricing } ]

                    [] ->
                        []

        discountProblem =
            case ( NumberInput.value entry.discount, entry.serverError ) of
                ( Nothing, _ ) ->
                    [ { field = discountId entry.key, label = name ++ ", discount", message = "Enter the discount in percent.", step = Just Pricing } ]

                ( Just d, _ ) ->
                    if d <= 0 || d > 100 then
                        [ { field = discountId entry.key, label = name ++ ", discount", message = "The discount must be above 0 and at most 100 %.", step = Just Pricing } ]

                    else
                        case entry.serverError of
                            Just text ->
                                [ { field = discountId entry.key, label = name ++ ", discount", message = text, step = Just Pricing } ]

                            Nothing ->
                                []
    in
    conditionProblem ++ discountProblem


discountError : State -> Entry -> Maybe String
discountError state entry =
    let
        value =
            NumberInput.value entry.discount
    in
    case entry.serverError of
        Just text ->
            Just text

        Nothing ->
            if not state.attempted then
                Nothing

            else
                case value of
                    Nothing ->
                        Just "Enter the discount in percent."

                    Just d ->
                        if d <= 0 || d > 100 then
                            Just "The discount must be above 0 and at most 100 %."

                        else
                            Nothing



-- THE READABLE FORM


sentence : Locale -> List (Rule.Field ()) -> PriceRule -> String
sentence locale fields priceRule =
    let
        discount =
            String.fromFloat priceRule.discountPercent ++ " % discount"
    in
    if Rule.isEmpty priceRule.condition then
        "Every order: " ++ discount

    else
        "If " ++ Rule.describe locale fields priceRule.condition ++ ": " ++ discount



-- VIEW


view : (Msg -> msg) -> Locale -> List (Rule.Field ()) -> State -> Html msg
view toMsg locale fields state =
    Layout.stack []
        [ if List.isEmpty state.entries then
            EmptyState.view [ EmptyState.compact, EmptyState.title "No price rules", EmptyState.description "Without a rule the supplier gets no volume discount." ]

          else
            Layout.stack [] (List.indexedMap (viewEntry toMsg locale fields state) state.entries)
        , Button.view [ Button.id addButtonId, Button.icon Icon.plus, Button.onClick (toMsg Add) ] "Add price rule"
        ]


viewEntry : (Msg -> msg) -> Locale -> List (Rule.Field ()) -> State -> Int -> Entry -> Html msg
viewEntry toMsg locale fields state index entry =
    let
        name =
            "Price rule " ++ String.fromInt (index + 1)
    in
    Card.view
        [ Card.title name
        , Card.actions [ Button.iconOnly [ Button.ghost, Button.onClick (toMsg (Remove entry.key)) ] Icon.trash ("Remove " ++ String.toLower name) ]
        ]
        [ Layout.stack []
            [ RuleBuilder.view (BuilderMsg entry.key >> toMsg)
                [ RuleBuilder.fields fields
                , RuleBuilder.label ("Conditions of " ++ String.toLower name)
                , RuleBuilder.locale locale
                ]
                entry.builder
            , NumberInput.view (DiscountMsg entry.key >> toMsg)
                [ NumberInput.label "Discount"
                , NumberInput.required
                , NumberInput.suffixText "%"
                , NumberInput.hint "The discount in percent when the conditions hold."
                , NumberInput.errorMaybe (discountError state entry)
                ]
                entry.discount
            , case NumberInput.value entry.discount of
                Just d ->
                    Text.secondary (sentence locale fields { condition = RuleBuilder.rule entry.builder, discountPercent = d })

                Nothing ->
                    Text.secondary "Enter a discount to see the rule in words."
            ]
        ]


{-| Where the focus goes for a problem in the conditions.

KLAR GAP: the rule builder documents no id to focus. These are the ids it puts in the DOM
(`<id>-n<node>-field` for a condition, `<id>-n<node>-add-rule` for a group), found by looking at
the page, not by reading the documentation.

-}
focusTarget : Int -> Rule.Rule -> Int -> String
focusTarget key rule nodeId =
    if isGroupNode nodeId rule then
        builderId key ++ "-n" ++ String.fromInt nodeId ++ "-add-rule"

    else
        builderId key ++ "-n" ++ String.fromInt nodeId ++ "-field"


isGroupNode : Int -> Rule.Rule -> Bool
isGroupNode nodeId node =
    case node of
        Rule.GroupRule group ->
            group.id == nodeId || List.any (isGroupNode nodeId) group.children

        Rule.ConditionRule _ ->
            False
