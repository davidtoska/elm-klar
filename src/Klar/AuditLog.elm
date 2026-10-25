module Klar.AuditLog exposing
    ( view
    , Entry, entry, withDetail, withDiff
    , Attribute, id, search, onLoadMore, onRetry, locale, settings
    )

{-| An immutable activity history with actors, exact times and expandable diffs.

Use when: people need to trace who changed a record and inspect the change.
Do not use when: the events describe a schedule or milestones; use `Klar.Timeline`.

    import Klar.AuditLog as AuditLog
    import Klar.Diff as Diff
    import Klar.Ids as Ids
    import Klar.Remote as Remote
    import Time

    AuditLog.view []
        { label = "Order history"
        , ids = Ids.int
        , entries = Remote.Loaded
            [ AuditLog.entry
                { id = 1, actor = "Ada", action = "Changed delivery address"
                , at = Time.millisToPosix 0
                }
                |> AuditLog.withDiff (Diff.lines [] "Bergen" "Oslo")
            ]
        }

The supplied order is preserved: the application decides chronology and paging.
Search filters only loaded entries and says how many remain. Diffs are built when
data arrives, then revealed with native keyboard-accessible `details`; opening a
diff does not request or mutate data. Unique ids keep an expanded entry attached to
the same event when more entries are added. Exact timestamps use the application's
zone, or explicitly UTC until one is supplied. All `Remote` states are handled.

@docs view


# Entries

@docs Entry, entry, withDetail, withDiff


# Attributes

@docs Attribute, id, search, onLoadMore, onRetry, locale, settings

-}

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Keyed as Keyed
import Klar.Diff as Diff exposing (Diff)
import Klar.Format as Format
import Klar.Ids as Ids exposing (Ids)
import Klar.Internal as Internal
import Klar.Internal.Collection as Collection
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote exposing (Remote)
import Klar.Search as Search
import Klar.Settings as Settings exposing (Settings)
import Klar.TextInput as TextInput
import Time


{-| An event with an application id, actor, action and exact instant.
-}
type Entry id
    = Entry { id : id, actor : String, action : String, at : Time.Posix, detail : String, diff : Maybe Diff }


{-| Creates an event without a description or diff. Actor and action are your text.
-}
entry : { id : id, actor : String, action : String, at : Time.Posix } -> Entry id
entry data =
    Entry { id = data.id, actor = data.actor, action = data.action, at = data.at, detail = "", diff = Nothing }


{-| Adds a plain-text description, also included in search. Replaces an earlier detail.
-}
withDetail : String -> Entry id -> Entry id
withDetail detail (Entry data) =
    Entry { data | detail = detail }


{-| Attaches a precomputed diff, collapsed initially. Replaces an earlier diff.
-}
withDiff : Diff -> Entry id -> Entry id
withDiff diff (Entry data) =
    Entry { data | diff = Just diff }


{-| Optional history behaviour. Later attributes win.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type alias Config msg =
    { id : Maybe String
    , search : Maybe ( String, String -> msg )
    , onLoadMore : Maybe msg
    , onRetry : Maybe msg
    , locale : Locale
    , settings : Settings
    }


{-| A DOM id unique on the page, and a stable focus target after retry. It also
names the search input, so use it when two histories appear on the same page.
Absent by default; then the search field derives its id from its label.
-}
id : String -> Attribute msg
id value =
    Attribute (\c -> { c | id = Just value })


{-| Adds a controlled search of actor, action and detail in loaded entries.
Search ignores case and accents. No search field by default.
-}
search : String -> (String -> msg) -> Attribute msg
search query toMsg =
    Attribute (\c -> { c | search = Just ( query, toMsg ) })


{-| Adds a load-more button; it also appears when search has no matches.
-}
onLoadMore : msg -> Attribute msg
onLoadMore msg =
    Attribute (\c -> { c | onLoadMore = Just msg })


{-| Retry for initial failures and failed refreshes. Absent by default.
-}
onRetry : msg -> Attribute msg
onRetry msg =
    Attribute (\c -> { c | onRetry = Just msg })


{-| Built-in text language. Defaults to English.
-}
locale : Locale -> Attribute msg
locale value =
    Attribute (\c -> { c | locale = value })


{-| Time zone and timestamp formatting. Defaults to `Settings.default`, explicitly UTC.
-}
settings : Settings -> Attribute msg
settings value =
    Attribute (\c -> { c | settings = value })


{-| A named history of uniquely identified entries. Neither events nor their
order are changed by the component.
-}
view : List (Attribute msg) -> { label : String, ids : Ids id, entries : Remote (List (Entry id)) } -> Html msg
view attributes data =
    let
        c =
            List.foldl (\(Attribute change) acc -> change acc)
                { id = Nothing, search = Nothing, onLoadMore = Nothing, onRetry = Nothing, locale = Locale.default, settings = Settings.default }
                attributes

        pick en nb =
            Locale.pick c.locale { en = en, nb = nb }

        render entries =
            let
                query =
                    Maybe.map Tuple.first c.search |> Maybe.withDefault ""

                visible =
                    List.filter (\(Entry e) -> Search.matches query (e.actor ++ " " ++ e.action ++ " " ++ e.detail)) entries

                row (Entry e) =
                    ( Ids.toKey data.ids e.id
                    , Html.li [ Internal.cls [ "klar-audit-log__entry" ] ]
                        [ Html.div [ Internal.cls [ "klar-audit-log__rail" ], Attr.attribute "aria-hidden" "true" ] []
                        , Html.div [ Internal.cls [ "klar-audit-log__body" ] ]
                            [ Html.div [ Internal.cls [ "klar-audit-log__head" ] ]
                                [ Html.span [] [ Html.strong [] [ Html.text e.actor ], Html.text (" · " ++ e.action) ]
                                , Html.span [ Internal.cls [ "klar-workbench__meta" ] ] [ Html.text (Settings.dateTime c.locale c.settings e.at) ]
                                ]
                            , if e.detail == "" then
                                Html.text ""

                              else
                                Html.p [ Internal.cls [ "klar-workbench__prose" ] ] [ Html.text e.detail ]
                            , case e.diff of
                                Just diff ->
                                    Html.details [ Internal.cls [ "klar-audit-log__diff" ] ]
                                        [ Html.summary [] [ Html.text (pick "Inspect changes" "Undersøk endringer") ]
                                        , Diff.viewStatic [ Diff.locale c.locale, Diff.ariaLabel (pick "Changes: " "Endringer: " ++ e.action) ] diff
                                        ]

                                Nothing ->
                                    Html.text ""
                            ]
                        ]
                    )
            in
            Html.div []
                [ Html.div [ Internal.cls [ "klar-workbench__bar" ] ]
                    [ case c.search of
                        Just ( value, toMsg ) ->
                            TextInput.view ([ TextInput.label (pick "Search loaded history" "Søk i innlastet historikk"), TextInput.value value, TextInput.onInput toMsg, TextInput.search, TextInput.locale c.locale ] ++ (Maybe.map (\domId -> [ TextInput.id (domId ++ "-search") ]) c.id |> Maybe.withDefault []))

                        Nothing ->
                            Html.text ""
                    , Html.span [ Attr.attribute "role" "status" ] [ Html.text (Format.int c.locale (List.length visible) ++ pick " of " " av " ++ Format.int c.locale (List.length entries) ++ pick " loaded events" " innlastede hendelser") ]
                    ]
                , if List.isEmpty visible then
                    Collection.empty (pick "No matching events" "Ingen samsvarende hendelser")

                  else
                    Keyed.ol [ Internal.cls [ "klar-audit-log__list" ] ] (List.map row visible)
                , Collection.more c.locale c.onLoadMore
                ]
    in
    Html.section [ Internal.cls [ "klar-audit-log" ], Attr.attribute "aria-label" data.label, Attr.tabindex -1, Internal.attrMaybe Attr.id c.id ]
        (Collection.view { locale = c.locale, settings = c.settings, onRetry = c.onRetry, onLoadMore = c.onLoadMore } (pick "No activity yet" "Ingen aktivitet ennå") data.entries render)
