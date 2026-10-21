module Klar.RuleBuilder.Support exposing
    ( findCondition
    , nodeIds
    , normalize
    , onFocusLeave
    , renumberFrom
    , replaceCondition
    , same
    , signature
    , stub
    )

{-| Small pure helpers shared by `Klar.RuleBuilder`, `Klar.FilterBar` and
`Klar.SavedViews`: rule tree utilities that `Klar.Rule` does not expose, and a
"focus left this popup" event.

Internal to the rules group.

-}

import Html
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Klar.Rule as Rule exposing (Condition, Field, FieldKind, Operator(..), Rule(..))
import Set exposing (Set)



-- TREE


{-| A field with only an id and a kind, for the `Rule` editing functions
that need to know the kind of a field (messages carry the kind, so `update`
does not need the application's fields).
-}
stub : String -> FieldKind -> Field ()
stub id kind =
    let
        base =
            Rule.textField id "" (\_ -> "")
    in
    { base | kind = kind }


findCondition : Int -> Rule -> Maybe Condition
findCondition id rule =
    case rule of
        ConditionRule condition ->
            if condition.id == id then
                Just condition

            else
                Nothing

        GroupRule group ->
            List.foldl
                (\child found ->
                    case found of
                        Just _ ->
                            found

                        Nothing ->
                            findCondition id child
                )
                Nothing
                group.children


nodeIds : Rule -> Set Int
nodeIds rule =
    Set.fromList (allIds rule)


allIds : Rule -> List Int
allIds rule =
    case rule of
        ConditionRule condition ->
            [ condition.id ]

        GroupRule group ->
            group.id :: List.concatMap allIds group.children


{-| Gives every node in the subtree a new id, counting up from `start`.
Returns the new tree and the next unused id.
-}
renumberFrom : Int -> Rule -> ( Rule, Int )
renumberFrom start rule =
    case rule of
        ConditionRule condition ->
            ( ConditionRule { condition | id = start }, start + 1 )

        GroupRule group ->
            let
                ( children, next ) =
                    List.foldl
                        (\child ( done, cursor ) ->
                            let
                                ( renumbered, after ) =
                                    renumberFrom cursor child
                            in
                            ( done ++ [ renumbered ], after )
                        )
                        ( [], start + 1 )
                        group.children
            in
            ( GroupRule { group | id = start, children = children }, next )


{-| A rule as the builder and the filter bar hold it: the root is a group
with id 0 (a lone condition is put in one), and no two nodes share an id
(otherwise every node is renumbered).
-}
normalize : Rule -> Rule
normalize given =
    let
        root =
            case given of
                GroupRule _ ->
                    given

                ConditionRule condition ->
                    GroupRule { id = 0, combinator = Rule.All, negated = False, children = [ ConditionRule { condition | id = 1 } ] }

        ids =
            allIds root
    in
    if Rule.idOf root == 0 && List.length ids == Set.size (Set.fromList ids) then
        root

    else
        renumberFrom 0 root |> Tuple.first


{-| Puts the field, operator and values of `condition` into the node with
the same id.
-}
replaceCondition : Condition -> Rule -> Rule
replaceCondition condition rule =
    let
        id =
            condition.id
    in
    rule
        |> Rule.setField [] id condition.field
        |> Rule.setOperator id IsEmpty
        |> Rule.setOperator id condition.operator
        |> (\withOperator ->
                List.foldl (\( index, value ) acc -> Rule.setValue id index value acc)
                    withOperator
                    (List.indexedMap Tuple.pair condition.values)
           )


{-| The rule without its ids, for comparing rules ("is this view
modified?", "is this preset on?").
-}
signature : Rule -> String
signature rule =
    Encode.encode 0 (Rule.encode rule)


{-| Do two rules say the same thing (ignoring node ids)? A lone condition is
the same as an "all of" group with only that condition, which is how the
builder and the filter bar hold it.
-}
same : Rule -> Rule -> Bool
same a b =
    signature (normalize a) == signature (normalize b)



-- FOCUS


{-| Sends `msg` when keyboard focus moves from inside the element with this
id to somewhere outside it. Focus that goes nowhere (the window lost focus)
is ignored; clicks outside are handled by the click-away layer.
-}
onFocusLeave : String -> msg -> Html.Attribute msg
onFocusLeave id msg =
    Events.on "focusout"
        (Decode.field "relatedTarget" (isInside id)
            |> Decode.andThen
                (\inside ->
                    if inside then
                        Decode.fail "focus stayed inside"

                    else
                        Decode.succeed msg
                )
        )


isInside : String -> Decoder Bool
isInside id =
    Decode.field "id" Decode.string
        |> Decode.andThen
            (\elementId ->
                if elementId == id then
                    Decode.succeed True

                else
                    Decode.oneOf
                        [ Decode.field "parentElement" (Decode.null False)
                        , Decode.field "parentElement" (Decode.lazy (\_ -> isInside id))
                        , Decode.succeed False
                        ]
            )
