module View.Labels exposing
    ( priorityBadge
    , priorityTone
    , statusBadge
    , statusTone
    )

{-| How the domain words look: the tone of each order status and priority, and
small badges that show them. Shared by the pages so an order looks the same
everywhere.
-}

import Api.Types exposing (OrderStatus(..), Priority(..), orderStatusLabel, priorityLabel)
import Html exposing (Html)
import Klar.Badge as Badge
import Klar.Theme exposing (Tone(..))


statusTone : OrderStatus -> Tone
statusTone status =
    case status of
        Draft ->
            Neutral

        Confirmed ->
            Info

        Picking ->
            Warning

        Shipped ->
            Primary

        Delivered ->
            Success

        Cancelled ->
            Danger


priorityTone : Priority -> Tone
priorityTone priority =
    case priority of
        Low ->
            Neutral

        Normal ->
            Info

        High ->
            Warning

        Urgent ->
            Danger


statusBadge : OrderStatus -> Html msg
statusBadge status =
    Badge.view [ Badge.tone (statusTone status) ] (orderStatusLabel status)


{-| A dot and a word, without a box: calmer in a table full of badges.
-}
priorityBadge : Priority -> Html msg
priorityBadge priority =
    Badge.status (priorityTone priority) (priorityLabel priority)
