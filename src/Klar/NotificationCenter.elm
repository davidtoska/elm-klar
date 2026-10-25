module Klar.NotificationCenter exposing
    ( view
    , Notification, notification
    , Attribute, id, unreadOnly, onOpen, onRead, onDismiss, onReadAll, onLoadMore, onRetry, locale, settings
    )

{-| Persistent notifications with an unread filter and explicit read and dismiss
actions. Merely viewing a notification never marks it read.

Use when: people need a durable inbox of notifications, alongside transient toasts.
Do not use when: feedback should disappear after a few seconds; use `Klar.Toast`.

    import Klar.Ids as Ids
    import Klar.NotificationCenter as Notifications
    import Klar.Remote as Remote
    import Time

    Notifications.view []
        { label = "Notifications"
        , ids = Ids.int
        , items = Remote.Loaded
            [ Notifications.notification
                { id = 1, title = "Export ready", body = "42 orders exported."
                , at = Time.millisToPosix 0, unread = True
                }
            ]
        }

Items remain in the supplied order. All counts and the read-all action refer only
to loaded notifications; the application owns paging, persistence and mutations.
Keep dismissed items in the list until the server confirms removal if a failure
must be recoverable. `Remote.Kept` retains the inbox during refresh and failed
refresh, with the shared old-data notice and retry.

@docs view


# Notifications

@docs Notification, notification


# Attributes

@docs Attribute, id, unreadOnly, onOpen, onRead, onDismiss, onReadAll, onLoadMore, onRetry, locale, settings

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Html.Keyed as Keyed
import Klar.Button as Button
import Klar.Format as Format
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Collection as Collection
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote exposing (Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Switch as Switch
import Time


{-| One notification, with an application-owned id and explicit unread state.
-}
type Notification id
    = Notification { id : id, title : String, body : String, at : Time.Posix, unread : Bool }


{-| Creates a notification. Its timestamp is an instant, formatted in `settings`.
-}
notification : { id : id, title : String, body : String, at : Time.Posix, unread : Bool } -> Notification id
notification =
    Notification


{-| Optional inbox behaviour. All mutations are absent by default.
-}
type Attribute id msg
    = Attribute (Config id msg -> Config id msg)


type alias Config id msg =
    { domId : Maybe String
    , unreadOnly : Maybe ( Bool, Bool -> msg )
    , onOpen : Maybe (id -> msg)
    , onRead : Maybe (id -> msg)
    , onDismiss : Maybe (id -> msg)
    , onReadAll : Maybe (List id -> msg)
    , onLoadMore : Maybe msg
    , onRetry : Maybe msg
    , locale : Locale
    , settings : Settings
    }


{-| A DOM id unique on the page, also a stable focus target after removing an
item or retrying. The unread switch uses this id too, so supply it for multiple
inboxes on one page. Absent by default.
-}
id : String -> Attribute id msg
id value =
    Attribute (\c -> { c | domId = Just value })


{-| Controlled unread filter and its change handler. Without it all items appear.
-}
unreadOnly : Bool -> (Bool -> msg) -> Attribute id msg
unreadOnly value toMsg =
    Attribute (\c -> { c | unreadOnly = Just ( value, toMsg ) })


{-| Opens a notification by id. Opening does not also send `onRead`.
-}
onOpen : (id -> msg) -> Attribute id msg
onOpen toMsg =
    Attribute (\c -> { c | onOpen = Just toMsg })


{-| Adds a mark-as-read action to unread notifications.
-}
onRead : (id -> msg) -> Attribute id msg
onRead toMsg =
    Attribute (\c -> { c | onRead = Just toMsg })


{-| Adds an explicit dismiss action. The application decides when to remove data.
-}
onDismiss : (id -> msg) -> Attribute id msg
onDismiss toMsg =
    Attribute (\c -> { c | onDismiss = Just toMsg })


{-| Adds "Mark loaded as read", sending only the ids of loaded unread items.
The action is disabled when there are none.
-}
onReadAll : (List id -> msg) -> Attribute id msg
onReadAll toMsg =
    Attribute (\c -> { c | onReadAll = Just toMsg })


{-| Adds a load-more button, even when the unread filter has no matches.
-}
onLoadMore : msg -> Attribute id msg
onLoadMore msg =
    Attribute (\c -> { c | onLoadMore = Just msg })


{-| Retry for initial failures and failed refreshes. Absent by default.
-}
onRetry : msg -> Attribute id msg
onRetry msg =
    Attribute (\c -> { c | onRetry = Just msg })


{-| Language of built-in text. Defaults to English.
-}
locale : Locale -> Attribute id msg
locale value =
    Attribute (\c -> { c | locale = value })


{-| Time zone and date formatting. Defaults to `Settings.default`, explicitly UTC.
-}
settings : Settings -> Attribute id msg
settings value =
    Attribute (\c -> { c | settings = value })


{-| A named inbox with unique application ids. Read and dismissed states are
supplied by the application; the component never hides or acknowledges data itself.
-}
view : List (Attribute id msg) -> { label : String, ids : Ids id, items : Remote (List (Notification id)) } -> Html msg
view attributes data =
    let
        c =
            List.foldl (\(Attribute change) acc -> change acc)
                { domId = Nothing, unreadOnly = Nothing, onOpen = Nothing, onRead = Nothing, onDismiss = Nothing, onReadAll = Nothing, onLoadMore = Nothing, onRetry = Nothing, locale = Locale.default, settings = Settings.default }
                attributes

        pick en nb =
            Locale.pick c.locale { en = en, nb = nb }

        render items =
            let
                unread =
                    List.filter (\(Notification item) -> item.unread) items

                visible =
                    if Maybe.map Tuple.first c.unreadOnly == Just True then
                        unread

                    else
                        items

                action handler notificationId label =
                    case handler of
                        Just toMsg ->
                            [ Button.view [ Button.small, Button.ghost, Button.onClick (toMsg notificationId) ] label ]

                        Nothing ->
                            []

                row (Notification item) =
                    ( Ids.toKey data.ids item.id
                    , Html.li [ Internal.classes [ ( "klar-notification-center__item", True ), ( "klar-notification-center__item--unread", item.unread ) ] ]
                        [ Html.div [ Internal.cls [ "klar-notification-center__content" ] ]
                            [ case c.onOpen of
                                Just toMsg ->
                                    Html.button [ Attr.type_ "button", Internal.cls [ "klar-workbench__title-button" ], Events.onClick (toMsg item.id) ] [ Html.text item.title ]

                                Nothing ->
                                    Html.strong [] [ Html.text item.title ]
                            , Html.p [ Internal.cls [ "klar-workbench__prose" ] ] [ Html.text item.body ]
                            , Html.div [ Internal.cls [ "klar-workbench__meta" ] ]
                                [ Html.text (Settings.dateTime c.locale c.settings item.at)
                                , if item.unread then
                                    Html.strong [] [ Html.text (pick "Unread" "Ulest") ]

                                  else
                                    Html.text (pick "Read" "Lest")
                                ]
                            ]
                        , Html.div [ Internal.cls [ "klar-workbench__actions" ] ]
                            ((if item.unread then
                                action c.onRead item.id (pick "Mark as read" "Merk som lest")

                              else
                                []
                             )
                                ++ action c.onDismiss item.id (pick "Dismiss" "Fjern")
                            )
                        ]
                    )
            in
            Html.div []
                [ Html.div [ Internal.cls [ "klar-workbench__bar" ] ]
                    [ Html.span [ Attr.attribute "role" "status" ] [ Html.text (Format.int c.locale (List.length unread) ++ pick " unread of " " uleste av " ++ Format.int c.locale (List.length items) ++ pick " loaded" " innlastede") ]
                    , case c.unreadOnly of
                        Just ( value, toMsg ) ->
                            Switch.view ([ Switch.checked value, Switch.onToggle toMsg, Switch.label (pick "Unread only" "Bare uleste") ] ++ (Maybe.map (\domId -> [ Switch.id (domId ++ "-unread") ]) c.domId |> Maybe.withDefault []))

                        Nothing ->
                            Html.text ""
                    , case c.onReadAll of
                        Just toMsg ->
                            Button.view [ Button.small, Button.disabled (List.isEmpty unread), Button.onClick (toMsg (List.map (\(Notification item) -> item.id) unread)) ] (pick "Mark loaded as read" "Merk innlastede som lest")

                        Nothing ->
                            Html.text ""
                    ]
                , if List.isEmpty visible then
                    Collection.empty (pick "No unread notifications" "Ingen uleste varsler")

                  else
                    Keyed.ul [ Internal.cls [ "klar-notification-center__list" ] ] (List.map row visible)
                , Collection.more c.locale c.onLoadMore
                ]
    in
    Html.section [ Internal.cls [ "klar-notification-center" ], Attr.attribute "aria-label" data.label, Attr.tabindex -1, Internal.attrMaybe Attr.id c.domId ]
        (Collection.view { locale = c.locale, settings = c.settings, onRetry = c.onRetry, onLoadMore = c.onLoadMore } (pick "No notifications" "Ingen varsler") data.items render)
