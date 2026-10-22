module Detail exposing (Model, Msg, init, load, update, view)

{-| A saved supplier. Some of its fields are edited in place; the rest is changed by
reopening the whole flow.
-}

import Api
import Backend
import Domain exposing (..)
import Flow
import Html exposing (Html)
import Klar.Alert as Alert
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.DescriptionList as DescriptionList
import Klar.Icon as Icon
import Klar.InlineEdit as InlineEdit
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote)
import Klar.Skeleton as Skeleton
import Klar.ErrorState as ErrorState
import Klar.Tag as Tag
import Klar.Theme as Theme
import Klar.Validate as Validate
import RuleFields


type Field
    = NameField
    | WebsiteField
    | LeadTimeField
    | NotesField


type alias Model =
    { id : SupplierId
    , supplier : Remote Supplier
    , name : InlineEdit.State
    , website : InlineEdit.State
    , leadTime : InlineEdit.State
    , notes : InlineEdit.State
    , stale : Maybe Supplier
    }


type Msg
    = Loaded (Result Remote.Problem ())
    | InlineMsg Field InlineEdit.Msg
    | InlineArrived Field String (Result Remote.Problem ())
    | Retry
    | ReloadNow
    | EditAll
    | NoOp


init : SupplierId -> Model
init id =
    { id = id
    , supplier = Remote.Loading
    , name = InlineEdit.init "detail-name" ""
    , website = InlineEdit.init "detail-website" ""
    , leadTime = InlineEdit.init "detail-lead-time" ""
    , notes = InlineEdit.init "detail-notes" ""
    , stale = Nothing
    }


{-| Starts loading the record.
-}
load : Flow.Ctx -> Model -> ( Model, Cmd Msg, List Flow.Out )
load ctx m =
    ( { m | supplier = Remote.Loading, stale = Nothing }, Api.call ctx.sim Loaded, [ Flow.FaultUsed ] )


fill : Supplier -> Model -> Model
fill s m =
    { m
        | supplier = Remote.Success s
        , stale = Nothing
        , name = InlineEdit.setValue s.name m.name
        , website = InlineEdit.setValue s.website m.website
        , leadTime = InlineEdit.setValue (String.fromInt s.delivery.leadTimeDays) m.leadTime
        , notes = InlineEdit.setValue s.delivery.notes m.notes
    }


stateOf : Field -> Model -> InlineEdit.State
stateOf field m =
    case field of
        NameField ->
            m.name

        WebsiteField ->
            m.website

        LeadTimeField ->
            m.leadTime

        NotesField ->
            m.notes


setState : Field -> InlineEdit.State -> Model -> Model
setState field s m =
    case field of
        NameField ->
            { m | name = s }

        WebsiteField ->
            { m | website = s }

        LeadTimeField ->
            { m | leadTime = s }

        NotesField ->
            { m | notes = s }


patch : Field -> String -> Supplier -> Supplier
patch field text s =
    let
        delivery =
            s.delivery
    in
    case field of
        NameField ->
            { s | name = String.trim text }

        WebsiteField ->
            { s | website = String.trim text }

        LeadTimeField ->
            { s | delivery = { delivery | leadTimeDays = String.toInt (String.trim text) |> Maybe.withDefault delivery.leadTimeDays } }

        NotesField ->
            { s | delivery = { delivery | notes = String.trim text } }


backendField : Field -> Backend.Field
backendField field =
    case field of
        NameField ->
            Backend.Name

        WebsiteField ->
            Backend.Website

        LeadTimeField ->
            Backend.LeadTime

        NotesField ->
            Backend.Name


update : Flow.Ctx -> Msg -> Model -> ( Model, Cmd Msg, List Flow.Out )
update ctx msg m =
    case msg of
        NoOp ->
            ( m, Cmd.none, [] )

        Retry ->
            load ctx m

        EditAll ->
            ( m, Cmd.none, [ Flow.Navigate ("#/suppliers/" ++ supplierIdToString m.id ++ "/edit") ] )

        ReloadNow ->
            load ctx m

        Loaded (Err problem) ->
            ( { m | supplier = Remote.Failure problem }, Cmd.none, [ Flow.FaultUsed ] )

        Loaded (Ok ()) ->
            case Backend.supplierById ctx.store m.id of
                Just s ->
                    ( fill s m, Cmd.none, [ Flow.FaultUsed ] )

                Nothing ->
                    ( { m | supplier = Remote.Failure (Remote.problem Remote.notFound |> Remote.withTitle "Supplier not found") }
                    , Cmd.none
                    , [ Flow.FaultUsed ]
                    )

        InlineMsg field inner ->
            let
                before =
                    stateOf field m

                ( after, cmd ) =
                    InlineEdit.update inner before

                starts =
                    InlineEdit.isSaving after && not (InlineEdit.isSaving before)
            in
            ( setState field after m
            , Cmd.batch
                [ Cmd.map (InlineMsg field) cmd
                , case ( starts, InlineEdit.pending after ) of
                    ( True, Just text ) ->
                        Api.call ctx.sim (InlineArrived field text)

                    _ ->
                        Cmd.none
                ]
            , if starts then
                []

              else
                []
            )

        InlineArrived field text result ->
            case ( result, m.supplier ) of
                ( Err problem, _ ) ->
                    ( setState field (InlineEdit.failed problem (stateOf field m)) m, Cmd.none, [ Flow.FaultUsed ] )

                ( Ok (), Remote.Success current ) ->
                    case Backend.save ctx.store (patch field text current) of
                        Ok ( saved, store ) ->
                            ( { m | supplier = Remote.Success saved }
                                |> setState field (InlineEdit.saved (stateOf field m))
                            , Cmd.none
                            , [ Flow.FaultUsed, Flow.StoreChanged store, Flow.ToastOut Theme.Success ("Saved version " ++ String.fromInt saved.version ++ ".") ]
                            )

                        Err (Backend.Invalid problems) ->
                            let
                                message =
                                    List.filter (\p -> p.field == backendField field) problems
                                        |> List.head
                                        |> Maybe.map .message
                                        |> Maybe.withDefault "The server rejected this value."
                            in
                            ( setState field
                                (InlineEdit.failed
                                    (Remote.problem Remote.validation |> Remote.withTitle "Not accepted" |> Remote.withDetail message)
                                    (stateOf field m)
                                )
                                m
                            , Cmd.none
                            , [ Flow.FaultUsed ]
                            )

                        Err (Backend.Conflict theirs) ->
                            ( { m | stale = Just theirs }
                                |> setState field
                                    (InlineEdit.failed
                                        (Remote.problem Remote.conflict |> Remote.withTitle "Changed by someone else")
                                        (stateOf field m)
                                    )
                            , Cmd.none
                            , [ Flow.FaultUsed ]
                            )

                _ ->
                    ( m, Cmd.none, [ Flow.FaultUsed ] )


view : Flow.Ctx -> Model -> Html Msg
view ctx m =
    case m.supplier of
        Remote.NotAsked ->
            Html.text ""

        Remote.Loading ->
            Layout.stack [ Layout.gap 4 ]
                [ Skeleton.line 240
                , Skeleton.paragraph 6
                ]

        Remote.Failure problem ->
            ErrorState.view [ ErrorState.onRetry Retry ] problem

        Remote.Success s ->
            viewSupplier ctx m s


viewSupplier : Flow.Ctx -> Model -> Supplier -> Html Msg
viewSupplier ctx m s =
    let
        ref =
            { countries = Remote.withDefault [] ctx.countries
            , categories = Remote.withDefault [] ctx.categories
            }

        countryName id =
            List.filter (\c -> c.id == id) ref.countries |> List.head |> Maybe.map .name |> Maybe.withDefault (countryKey id)

        categoryName id =
            List.filter (\c -> c.id == id) ref.categories |> List.head |> Maybe.map .name |> Maybe.withDefault (categoryKey id)

        termsName id =
            Remote.withDefault [] ctx.terms
                |> List.filter (\t -> t.id == id)
                |> List.head
                |> Maybe.map .label
                |> Maybe.withDefault (paymentTermsKey id)

        inline field label inlineLabel emptyText validators =
            DescriptionList.html label
                (InlineEdit.view (InlineMsg field)
                    [ InlineEdit.label inlineLabel
                    , InlineEdit.emptyText emptyText
                    , InlineEdit.validate (Validate.run Locale.en validators)
                    ]
                    (stateOf field m)
                )
    in
    Layout.stack [ Layout.gap 5 ]
        [ PageHeader.view
            [ PageHeader.title s.name
            , PageHeader.subtitle (s.legalName ++ " · " ++ countryName s.country)
            , PageHeader.badges [ Badge.view [ Badge.tone Theme.Info ] ("Version " ++ String.fromInt s.version) ]
            , PageHeader.actions
                [ Button.view [ Button.primary, Button.icon Icon.edit, Button.onClick EditAll ] "Edit full record" ]
            ]
        , case m.stale of
            Just theirs ->
                Alert.view
                    [ Alert.tone Theme.Warning
                    , Alert.title "This supplier changed"
                    , Alert.actions [ Button.view [ Button.small, Button.onClick ReloadNow ] "Load latest version" ]
                    ]
                    ("Someone else saved version " ++ String.fromInt theirs.version ++ ". Your edit was not saved; load the latest version and try again.")

            Nothing ->
                Html.text ""
        , DescriptionList.view [ DescriptionList.bordered, DescriptionList.columns 1 ]
            [ inline NameField "Name" "Supplier name" "No name" (Validate.all [ Validate.required, Validate.maxLength 80 ])
            , DescriptionList.text "Registration number" s.registrationNumber
            , inline WebsiteField "Website" "Website" "Add a website" (Validate.custom (\t -> String.trim t == "" || String.startsWith "http" t) { nb = "Må starte med http", en = "Must start with http" })
            , DescriptionList.text "Country" (countryName s.country)
            , DescriptionList.values "Categories" (List.map (\c -> Tag.view [] (categoryName c)) s.categories)
            , DescriptionList.values "Certifications"
                (if List.isEmpty s.certifications then
                    [ Html.text "-" ]

                 else
                    List.map (Tag.view []) s.certifications
                )
            , DescriptionList.text "Contract" (s.contractFile |> Maybe.map .name |> Maybe.withDefault "-")
            , DescriptionList.text "Contacts" (s.contacts |> List.map (\c -> c.name ++ " (" ++ c.email ++ ")") |> String.join ", ")
            , inline LeadTimeField "Lead time in days" "Lead time in days" "Add lead time" (Validate.integerBetween 1 365)
            , DescriptionList.text "Minimum order" (String.fromFloat s.delivery.minimumOrder ++ " EUR")
            , DescriptionList.text "Delivers to" (s.delivery.deliversTo |> List.map countryName |> String.join ", ")
            , DescriptionList.text "Payment terms" (termsName s.delivery.paymentTerms)
            , inline NotesField "Delivery notes" "Delivery notes" "Add a note" (Validate.maxLength 300)
            , DescriptionList.values "Pricing rules"
                (if List.isEmpty s.priceRules then
                    [ Html.text "-" ]

                 else
                    List.map (\r -> Html.div [] [ Html.text (r.name ++ ": " ++ RuleFields.describe ref r.rule ++ ", " ++ String.fromFloat r.discountPercent ++ "%") ]) s.priceRules
                )
            ]
        ]
