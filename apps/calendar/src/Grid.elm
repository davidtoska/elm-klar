module Grid exposing
    ( Config
    , agenda
    , clock
    , colorOf
    , hourHeight
    , month
    , monthName
    , textColorOn
    , timeRange
    , week
    , weekdayName
    )

{-| The calendar itself: the time grid of a day or a week, the month and the
agenda.

KLAR GAP: Klar has a month picker (`Klar.Calendar`) but no time grid with
events placed by the hour, so this module draws one with inline styles on Klar's
tokens (`var(--klar-...)`). Event colors are data (Google's colors), so they are
set as values.

-}

import Gcal exposing (AccessRole(..), ResponseStatus(..))
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Klar.Date as Date exposing (Date)
import Klar.Format as Format
import Klar.ListItem as ListItem
import Klar.Locale as Locale
import Klar.Text as Text
import Occurrence exposing (Occurrence, Placed)


type alias Config msg =
    { today : Date
    , nowMinute : Int
    , onSlot : Date -> Int -> msg
    , onOpen : Occurrence -> msg
    , onDay : Date -> msg
    }


hourHeight : Int
hourHeight =
    48


px : Int -> String
px n =
    String.fromInt n ++ "px"


styles : List ( String, String ) -> List (Html.Attribute msg)
styles =
    List.map (\( k, v ) -> Attr.style k v)



-- TEXT


weekdayName : Date -> String
weekdayName date =
    case Date.weekday date of
        1 ->
            "Mon"

        2 ->
            "Tue"

        3 ->
            "Wed"

        4 ->
            "Thu"

        5 ->
            "Fri"

        6 ->
            "Sat"

        _ ->
            "Sun"


monthName : Int -> String
monthName m =
    case m of
        1 ->
            "January"

        2 ->
            "February"

        3 ->
            "March"

        4 ->
            "April"

        5 ->
            "May"

        6 ->
            "June"

        7 ->
            "July"

        8 ->
            "August"

        9 ->
            "September"

        10 ->
            "October"

        11 ->
            "November"

        _ ->
            "December"


clock : Int -> String
clock minutes =
    let
        m =
            modBy 1440 minutes
    in
    String.padLeft 2 '0' (String.fromInt (m // 60)) ++ ":" ++ String.padLeft 2 '0' (String.fromInt (modBy 60 m))


{-| "10:00 – 11:30", "All day", or with dates when it spans days.
-}
timeRange : Occurrence -> String
timeRange occ =
    let
        startDay =
            occ.start // 1440

        endDay =
            (occ.end - 1) // 1440

        dayText d =
            Format.date Locale.en (Date.fromEpochDay d)
    in
    if occ.allDay then
        if endDay <= startDay then
            "All day"

        else
            dayText startDay ++ " – " ++ dayText endDay

    else if occ.end // 1440 == startDay || occ.end == (startDay + 1) * 1440 then
        clock occ.start ++ " – " ++ clock occ.end

    else
        dayText startDay ++ " " ++ clock occ.start ++ " – " ++ dayText (occ.end // 1440) ++ " " ++ clock occ.end


title : Occurrence -> String
title occ =
    if occ.calendar.accessRole == FreeBusyReader then
        "Busy"

    else if occ.event.summary == "" then
        "(No title)"

    else
        occ.event.summary



-- COLORS


colorOf : Occurrence -> String
colorOf occ =
    Gcal.eventColors
        |> List.filter (\c -> c.id == occ.event.colorId)
        |> List.head
        |> Maybe.map .hex
        |> Maybe.withDefault occ.calendar.backgroundColor


{-| Black or white text, whichever reads better on a background color.
-}
textColorOn : String -> String
textColorOn hex =
    let
        channel i =
            String.slice (1 + i * 2) (3 + i * 2) hex |> hexValue

        luminance =
            0.299 * channel 0 + 0.587 * channel 1 + 0.114 * channel 2
    in
    if luminance > 150 then
        "#1f1f1f"

    else
        "#ffffff"


hexValue : String -> Float
hexValue text =
    String.toList (String.toLower text)
        |> List.foldl
            (\c acc ->
                acc
                    * 16
                    + toFloat
                        (Maybe.withDefault 0
                            (List.head
                                (List.filterMap
                                    (\( k, v ) ->
                                        if k == c then
                                            Just v

                                        else
                                            Nothing
                                    )
                                    hexDigits
                                )
                            )
                        )
            )
            0


hexDigits : List ( Char, Int )
hexDigits =
    List.indexedMap (\i c -> ( c, i )) (String.toList "0123456789abcdef")


{-| How an occurrence looks: filled when the person goes, outlined while they
have not answered or said maybe, struck through when they said no.
-}
eventStyle : Occurrence -> List ( String, String )
eventStyle occ =
    let
        color =
            colorOf occ

        answer =
            Gcal.selfAttendee occ.event |> Maybe.map .responseStatus
    in
    case answer of
        Just Declined ->
            [ ( "background", "var(--klar-surface)" ), ( "color", "var(--klar-text-muted)" ), ( "border", "1px dashed " ++ color ), ( "text-decoration", "line-through" ) ]

        Just NeedsAction ->
            [ ( "background", "var(--klar-surface)" ), ( "color", "var(--klar-text)" ), ( "border", "1px solid " ++ color ) ]

        Just Tentative ->
            [ ( "background", "repeating-linear-gradient(45deg, var(--klar-surface), var(--klar-surface) 6px, " ++ color ++ "33 6px, " ++ color ++ "33 12px)" ), ( "color", "var(--klar-text)" ), ( "border", "1px solid " ++ color ) ]

        _ ->
            [ ( "background", color ), ( "color", textColorOn color ), ( "border", "1px solid var(--klar-surface)" ) ]


ariaLabel : Occurrence -> String
ariaLabel occ =
    title occ ++ ", " ++ Format.dateLong Locale.en occ.date ++ ", " ++ timeRange occ ++ ", " ++ occ.calendar.summary



-- WEEK AND DAY


{-| The time grid for one or more days, with the all-day row above it. The
scrolling part has the id `time-grid`.
-}
week : Config msg -> List Date -> List Occurrence -> Html msg
week config days occurrences =
    let
        columns =
            "56px repeat(" ++ String.fromInt (List.length days) ++ ", minmax(0, 1fr))"

        allDayOf day =
            let
                from =
                    Date.toEpochDay day * 1440
            in
            occurrences
                |> List.filter (\o -> (o.allDay || o.end - o.start >= 1440) && Occurrence.covers from (from + 1440) o)
                |> List.sortBy (\o -> ( o.start, o.calendar.summary ))
    in
    Html.div (styles [ ( "border", "1px solid var(--klar-border)" ), ( "border-radius", "var(--klar-radius-lg)" ), ( "background", "var(--klar-surface)" ), ( "overflow", "hidden" ) ])
        [ Html.div (styles [ ( "display", "grid" ), ( "grid-template-columns", columns ), ( "border-bottom", "1px solid var(--klar-border)" ) ])
            (Html.div [] []
                :: List.map (dayHeader config) days
            )
        , Html.div (styles [ ( "display", "grid" ), ( "grid-template-columns", columns ), ( "border-bottom", "1px solid var(--klar-border)" ), ( "min-height", "28px" ) ])
            (Html.div (styles [ ( "font-size", "var(--klar-text-xs)" ), ( "color", "var(--klar-text-muted)" ), ( "padding", "var(--klar-space-1)" ), ( "text-align", "right" ) ]) [ Html.text "All day" ]
                :: List.map
                    (\day ->
                        Html.div (styles [ ( "border-left", "1px solid var(--klar-border-subtle)" ), ( "padding", "2px" ), ( "display", "flex" ), ( "flex-direction", "column" ), ( "gap", "2px" ), ( "min-width", "0" ) ])
                            (List.map (chip config True) (allDayOf day))
                    )
                    days
            )
        , Html.div
            (Attr.id "time-grid"
                :: Attr.tabindex 0
                :: Attr.attribute "aria-label" "Hours"
                :: styles [ ( "overflow-y", "auto" ), ( "height", "calc(100vh - 290px)" ), ( "min-height", "360px" ), ( "position", "relative" ) ]
            )
            [ Html.div (styles [ ( "display", "grid" ), ( "grid-template-columns", columns ), ( "position", "relative" ) ])
                (hourLabels
                    :: List.map (dayColumn config occurrences) days
                )
            ]
        ]


dayHeader : Config msg -> Date -> Html msg
dayHeader config day =
    let
        isToday =
            day == config.today
    in
    Html.div (styles [ ( "border-left", "1px solid var(--klar-border-subtle)" ), ( "padding", "var(--klar-space-2) var(--klar-space-1)" ), ( "text-align", "center" ) ])
        [ Html.button
            (Events.onClick (config.onDay day)
                :: Attr.attribute "aria-label" (Format.dateLong Locale.en day)
                :: styles
                    [ ( "border", "none" )
                    , ( "background", "none" )
                    , ( "cursor", "pointer" )
                    , ( "font", "inherit" )
                    , ( "color"
                      , if isToday then
                            "var(--klar-primary)"

                        else
                            "var(--klar-text-secondary)"
                      )
                    ]
            )
            [ Html.div (styles [ ( "font-size", "var(--klar-text-xs)" ), ( "text-transform", "uppercase" ), ( "letter-spacing", "0.04em" ) ]) [ Html.text (weekdayName day) ]
            , Html.div
                (styles
                    ([ ( "font-size", "var(--klar-text-xl)" )
                     , ( "font-weight", "var(--klar-weight-medium)" )
                     , ( "width", "36px" )
                     , ( "height", "36px" )
                     , ( "line-height", "36px" )
                     , ( "margin", "2px auto 0" )
                     , ( "border-radius", "var(--klar-radius-full)" )
                     ]
                        ++ (if isToday then
                                [ ( "background", "var(--klar-primary)" ), ( "color", "var(--klar-on-primary)" ) ]

                            else
                                [ ( "color", "var(--klar-text)" ) ]
                           )
                    )
                )
                [ Html.text (String.fromInt (Date.day day)) ]
            ]
        ]


hourLabels : Html msg
hourLabels =
    Html.div (Attr.attribute "aria-hidden" "true" :: styles [ ( "position", "relative" ), ( "height", px (24 * hourHeight) ) ])
        (List.map
            (\h ->
                Html.div
                    (styles
                        [ ( "position", "absolute" )
                        , ( "top", px (h * hourHeight - 7) )
                        , ( "right", "var(--klar-space-2)" )
                        , ( "font-size", "var(--klar-text-xs)" )
                        , ( "color", "var(--klar-text-muted)" )
                        ]
                    )
                    [ Html.text (clock (h * 60)) ]
            )
            (List.range 1 23)
        )


dayColumn : Config msg -> List Occurrence -> Date -> Html msg
dayColumn config occurrences day =
    let
        timed =
            List.filter (\o -> not o.allDay && o.end - o.start < 1440) occurrences

        placed =
            Occurrence.layoutDay 20 day timed
    in
    Html.div
        (styles
            [ ( "position", "relative" )
            , ( "height", px (24 * hourHeight) )
            , ( "border-left", "1px solid var(--klar-border-subtle)" )
            , ( "background-image", "repeating-linear-gradient(to bottom, var(--klar-border-subtle) 0, var(--klar-border-subtle) 1px, transparent 1px, transparent " ++ px hourHeight ++ ")" )
            ]
        )
        (List.map (slot config day) (List.range 0 23)
            ++ List.map (block config) placed
            ++ (if day == config.today then
                    [ Html.div
                        (Attr.attribute "aria-hidden" "true"
                            :: styles
                                [ ( "position", "absolute" )
                                , ( "left", "0" )
                                , ( "right", "0" )
                                , ( "top", px (config.nowMinute * hourHeight // 60) )
                                , ( "border-top", "2px solid var(--klar-danger)" )
                                , ( "z-index", "2" )
                                , ( "pointer-events", "none" )
                                ]
                        )
                        []
                    ]

                else
                    []
               )
        )


slot : Config msg -> Date -> Int -> Html msg
slot config day hour =
    Html.button
        (Events.onClick (config.onSlot day (hour * 60))
            :: Attr.attribute "aria-label" ("New event, " ++ Format.dateLong Locale.en day ++ ", " ++ clock (hour * 60))
            :: Attr.tabindex -1
            :: styles
                [ ( "position", "absolute" )
                , ( "left", "0" )
                , ( "right", "0" )
                , ( "top", px (hour * hourHeight) )
                , ( "height", px hourHeight )
                , ( "border", "none" )
                , ( "background", "transparent" )
                , ( "cursor", "pointer" )
                , ( "padding", "0" )
                ]
        )
        []


block : Config msg -> Placed -> Html msg
block config p =
    let
        occ =
            p.occurrence

        heightPx =
            (p.bottom - p.top) * hourHeight // 60 - 2

        widthPercent =
            100 / toFloat p.columns

        short =
            heightPx < 34
    in
    Html.button
        (Events.onClick (config.onOpen occ)
            :: Attr.attribute "aria-label" (ariaLabel occ)
            :: styles
                ([ ( "position", "absolute" )
                 , ( "top", px (p.top * hourHeight // 60 + 1) )
                 , ( "height", px (max 14 heightPx) )
                 , ( "left", "calc(" ++ String.fromFloat (widthPercent * toFloat p.column) ++ "% + 1px)" )
                 , ( "width", "calc(" ++ String.fromFloat widthPercent ++ "% - 3px)" )
                 , ( "border-radius", "var(--klar-radius-sm)" )
                 , ( "padding", "1px var(--klar-space-1)" )
                 , ( "font", "inherit" )
                 , ( "font-size", "var(--klar-text-xs)" )
                 , ( "line-height", "1.25" )
                 , ( "text-align", "left" )
                 , ( "overflow", "hidden" )
                 , ( "cursor", "pointer" )
                 , ( "z-index", "1" )
                 , ( "box-shadow", "var(--klar-shadow-xs)" )
                 ]
                    ++ eventStyle occ
                )
        )
        (if short then
            [ Html.div (styles [ ( "white-space", "nowrap" ), ( "overflow", "hidden" ), ( "text-overflow", "ellipsis" ) ])
                [ Html.strong [] [ Html.text (title occ) ], Html.text (", " ++ clock occ.start) ]
            ]

         else
            [ Html.div (styles [ ( "font-weight", "var(--klar-weight-medium)" ), ( "overflow", "hidden" ), ( "text-overflow", "ellipsis" ) ]) [ Html.text (title occ) ]
            , Html.div [] [ Html.text (timeRange occ) ]
            , if occ.event.location == "" || occ.calendar.accessRole == FreeBusyReader then
                Html.text ""

              else
                Html.div (styles [ ( "white-space", "nowrap" ), ( "overflow", "hidden" ), ( "text-overflow", "ellipsis" ) ]) [ Html.text occ.event.location ]
            ]
        )


{-| A one-line event: filled for all-day events, a colored dot for timed ones.
-}
chip : Config msg -> Bool -> Occurrence -> Html msg
chip config filled occ =
    let
        color =
            colorOf occ

        solid =
            filled || occ.allDay
    in
    Html.button
        (Events.onClick (config.onOpen occ)
            :: Attr.attribute "aria-label" (ariaLabel occ)
            :: styles
                ([ ( "display", "flex" )
                 , ( "align-items", "center" )
                 , ( "gap", "4px" )
                 , ( "width", "100%" )
                 , ( "min-width", "0" )
                 , ( "border-radius", "var(--klar-radius-sm)" )
                 , ( "padding", "1px var(--klar-space-1)" )
                 , ( "font", "inherit" )
                 , ( "font-size", "var(--klar-text-xs)" )
                 , ( "text-align", "left" )
                 , ( "white-space", "nowrap" )
                 , ( "overflow", "hidden" )
                 , ( "cursor", "pointer" )
                 ]
                    ++ (if solid then
                            eventStyle occ

                        else
                            [ ( "background", "transparent" ), ( "border", "1px solid transparent" ), ( "color", "var(--klar-text)" ) ]
                       )
                )
        )
        ((if solid then
            []

          else
            [ Html.span (styles [ ( "flex", "none" ), ( "width", "8px" ), ( "height", "8px" ), ( "border-radius", "50%" ), ( "background", color ) ]) []
            , Html.span (styles [ ( "flex", "none" ), ( "color", "var(--klar-text-secondary)" ) ]) [ Html.text (clock occ.start) ]
            ]
         )
            ++ [ Html.span (styles [ ( "overflow", "hidden" ), ( "text-overflow", "ellipsis" ) ]) [ Html.text (title occ) ] ]
        )



-- MONTH


{-| Six weeks from Monday, with at most three events a day and a link to the
day for the rest.
-}
month : Config msg -> Date -> List Occurrence -> Html msg
month config focus occurrences =
    let
        weeks =
            Date.monthGrid 1 (Date.year focus) (Date.month focus)

        ofDay day =
            let
                from =
                    Date.toEpochDay day * 1440
            in
            occurrences
                |> List.filter (Occurrence.covers from (from + 1440))
                |> List.sortBy
                    (\o ->
                        ( if o.allDay then
                            0

                          else
                            1
                        , o.start
                        )
                    )
    in
    Html.div (styles [ ( "border", "1px solid var(--klar-border)" ), ( "border-radius", "var(--klar-radius-lg)" ), ( "background", "var(--klar-surface)" ), ( "overflow", "hidden" ) ])
        [ Html.div (styles [ ( "display", "grid" ), ( "grid-template-columns", "repeat(7, minmax(0, 1fr))" ), ( "border-bottom", "1px solid var(--klar-border)" ) ])
            (List.map
                (\day ->
                    Html.div (styles [ ( "padding", "var(--klar-space-1)" ), ( "text-align", "center" ), ( "font-size", "var(--klar-text-xs)" ), ( "color", "var(--klar-text-muted)" ), ( "text-transform", "uppercase" ) ])
                        [ Html.text (weekdayName day) ]
                )
                (List.head weeks |> Maybe.withDefault [])
            )
        , Html.div (styles [ ( "display", "grid" ), ( "grid-template-columns", "repeat(7, minmax(0, 1fr))" ), ( "grid-auto-rows", "minmax(112px, 1fr)" ) ])
            (List.concatMap (List.map (\day -> monthCell config focus day (ofDay day))) weeks)
        ]


monthCell : Config msg -> Date -> Date -> List Occurrence -> Html msg
monthCell config focus day occs =
    let
        inMonth =
            Date.month day == Date.month focus

        isToday =
            day == config.today

        shown =
            List.take 3 occs

        more =
            List.length occs - List.length shown
    in
    Html.div
        (styles
            [ ( "border-right", "1px solid var(--klar-border-subtle)" )
            , ( "border-bottom", "1px solid var(--klar-border-subtle)" )
            , ( "padding", "2px" )
            , ( "min-width", "0" )
            , ( "display", "flex" )
            , ( "flex-direction", "column" )
            , ( "gap", "1px" )
            , ( "background"
              , if inMonth then
                    "var(--klar-surface)"

                else
                    "var(--klar-surface-subtle)"
              )
            ]
        )
        (Html.button
            (Events.onClick (config.onDay day)
                :: Attr.attribute "aria-label" (Format.dateLong Locale.en day)
                :: styles
                    ([ ( "align-self", "center" )
                     , ( "border", "none" )
                     , ( "cursor", "pointer" )
                     , ( "font", "inherit" )
                     , ( "font-size", "var(--klar-text-xs)" )
                     , ( "min-width", "24px" )
                     , ( "height", "24px" )
                     , ( "border-radius", "var(--klar-radius-full)" )
                     ]
                        ++ (if isToday then
                                [ ( "background", "var(--klar-primary)" ), ( "color", "var(--klar-on-primary)" ) ]

                            else
                                [ ( "background", "none" )
                                , ( "color"
                                  , if inMonth then
                                        "var(--klar-text)"

                                    else
                                        "var(--klar-text-muted)"
                                  )
                                ]
                           )
                    )
            )
            [ Html.text
                (if Date.day day == 1 then
                    String.left 3 (monthName (Date.month day)) ++ " 1"

                 else
                    String.fromInt (Date.day day)
                )
            ]
            :: List.map (chip config False) shown
            ++ (if more > 0 then
                    [ Html.button
                        (Events.onClick (config.onDay day)
                            :: styles [ ( "border", "none" ), ( "background", "none" ), ( "cursor", "pointer" ), ( "font", "inherit" ), ( "font-size", "var(--klar-text-xs)" ), ( "color", "var(--klar-text-secondary)" ), ( "text-align", "left" ), ( "padding", "0 var(--klar-space-1)" ) ]
                        )
                        [ Html.text (String.fromInt more ++ " more") ]
                    ]

                else
                    []
               )
        )



-- AGENDA


{-| The events of the next days, a heading for each day that has any.
-}
agenda : Config msg -> Date -> Int -> List Occurrence -> Html msg
agenda config from days occurrences =
    let
        dates =
            List.map (\i -> Date.addDays i from) (List.range 0 (days - 1))

        ofDay day =
            let
                start =
                    Date.toEpochDay day * 1440
            in
            occurrences
                |> List.filter (Occurrence.covers start (start + 1440))
                |> List.sortBy (\o -> ( o.start, o.event.summary ))

        sections =
            List.filterMap
                (\day ->
                    case ofDay day of
                        [] ->
                            Nothing

                        occs ->
                            Just
                                (Html.section (styles [ ( "margin-bottom", "var(--klar-space-4)" ) ])
                                    [ Html.h2
                                        (styles
                                            [ ( "font-size", "var(--klar-text-md)" )
                                            , ( "margin", "0 0 var(--klar-space-2)" )
                                            , ( "color"
                                              , if day == config.today then
                                                    "var(--klar-primary)"

                                                else
                                                    "var(--klar-text)"
                                              )
                                            ]
                                        )
                                        [ Html.text (Format.dateLong Locale.en day) ]
                                    , ListItem.list [ ListItem.bordered, ListItem.ariaLabel (Format.dateLong Locale.en day) ]
                                        (List.map
                                            (\o ->
                                                ListItem.view
                                                    [ ListItem.leading (Html.span (styles [ ( "display", "inline-block" ), ( "width", "10px" ), ( "height", "10px" ), ( "border-radius", "50%" ), ( "background", colorOf o ) ]) [])
                                                    , ListItem.secondary
                                                        (String.join " · "
                                                            (List.filter ((/=) "")
                                                                [ o.calendar.summary
                                                                , if o.calendar.accessRole == FreeBusyReader then
                                                                    ""

                                                                  else
                                                                    o.event.location
                                                                ]
                                                            )
                                                        )
                                                    , ListItem.meta (timeRange o)
                                                    , ListItem.onClick (config.onOpen o)
                                                    ]
                                                    (title o)
                                            )
                                            occs
                                        )
                                    ]
                                )
                )
                dates
    in
    if List.isEmpty sections then
        Html.div (styles [ ( "padding", "var(--klar-space-8)" ), ( "text-align", "center" ) ])
            [ Text.muted ("Nothing planned in the " ++ String.fromInt days ++ " days from " ++ Format.dateLong Locale.en from ++ ".") ]

    else
        Html.div [] sections
