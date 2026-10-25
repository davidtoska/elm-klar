module Showcase.CalendarApplication exposing (view)

{-| The same complete calendar application, embedded in the Calendar component
page and the application examples. The application owns its server and storage.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Klar.Layout as Layout


view : Html msg
view =
    Layout.stack [ Layout.gap 3 ]
        [ Layout.row [ Layout.gap 3, Layout.wrap ]
            [ Html.text "Choose Ada, Bob or Cleo to try the calendar. Demo changes are saved locally."
            , Html.a [ Attr.href "/calendar-app/", Attr.target "_blank", Attr.rel "noopener" ] [ Html.text "Open full calendar" ]
            ]
        , Html.iframe
            [ Attr.src "/calendar-app/"
            , Attr.title "Google Calendar-style application"
            , Attr.class "showcase-calendar"
            ]
            []
        ]
