module Detail exposing
    ( Effects
    , Env
    , Model
    , Msg
    , init
    , update
    , view
    )

{-| A saved supplier. The name, the website and the preferred flag are edited
in place and saved one by one.
-}

import Api
import Backend exposing (Behaviour, Db)
import Domain exposing (..)
import Html exposing (Html)
import Klar.Alert as Alert
import Klar.Badge as Badge
import Klar.Button as Button
import Klar.Card as Card
import Klar.DescriptionList as DescriptionList
import Klar.Icon as Icon
import Klar.InlineEdit as InlineEdit
import Klar.Layout as Layout
import Klar.Locale as Locale
import Klar.PageHeader as PageHeader
import Klar.Remote as Remote exposing (Remote)
import Klar.Rule as Rule
import Klar.Switch as Switch
import Klar.Text as Text
import Klar.Theme exposing (Tone(..))
import Klar.Validate as Validate


type alias Model =
    { supplier : Supplier
    , name : InlineEdit.State
    , website : InlineEdit.State
    , savingPreferred : Bool
    , preferredError : Maybe String
    , stale : Bool
    }


type Edit
    = EditName String
    | EditWebsite String
    | EditPreferred Bool


type Msg
    = NameMsg InlineEdit.Msg
    | WebsiteMsg InlineEdit.Msg
    | TogglePreferred Bool
    | Replied Edit Db (Result SaveError Supplier)
    | Reload


type alias Env =
    { behaviour : Behaviour
    , db : Db
    , lookups : Remote Lookups
    }


type alias Effects =
    { db : Maybe Db }


init : Supplier -> Model
init supplier =
    { supplier = supplier
    , name = InlineEdit.init "detail-name" supplier.data.company.name
    , website = InlineEdit.init "detail-website" (Maybe.withDefault "" supplier.data.company.website)
    , savingPreferred = False
    , preferredError = Nothing
    , stale = False
    }


apply : Edit -> SupplierData -> SupplierData
apply edit data =
    let
        company =
            data.company
    in
    case edit of
        EditName name ->
            { data | company = { company | name = name } }

        EditWebsite site ->
            { data
                | company =
                    { company
                        | website =
                            if String.isEmpty (String.trim site) then
                                Nothing

                            else
                                Just (String.trim site)
                    }
            }

        EditPreferred flag ->
            { data | company = { company | preferred = flag } }


send : Env -> Model -> Edit -> Cmd Msg
send env model edit =
    Api.save env.behaviour
        env.db
        { id = Just model.supplier.id
        , baseVersion = model.supplier.version
        , data = apply edit model.supplier.data
        }
        (Replied edit)


update : Env -> Msg -> Model -> ( Model, Cmd Msg, Effects )
update env msg model =
    case msg of
        NameMsg m ->
            let
                ( name, cmd ) =
                    InlineEdit.update m model.name

                starts =
                    InlineEdit.isSaving name && not (InlineEdit.isSaving model.name)
            in
            ( { model | name = name }
            , Cmd.batch
                [ Cmd.map NameMsg cmd
                , case ( starts, InlineEdit.pending name ) of
                    ( True, Just text ) ->
                        send env model (EditName text)

                    _ ->
                        Cmd.none
                ]
            , { db = Nothing }
            )

        WebsiteMsg m ->
            let
                ( website, cmd ) =
                    InlineEdit.update m model.website

                starts =
                    InlineEdit.isSaving website && not (InlineEdit.isSaving model.website)
            in
            ( { model | website = website }
            , Cmd.batch
                [ Cmd.map WebsiteMsg cmd
                , case ( starts, InlineEdit.pending website ) of
                    ( True, Just text ) ->
                        send env model (EditWebsite text)

                    _ ->
                        Cmd.none
                ]
            , { db = Nothing }
            )

        TogglePreferred flag ->
            ( { model | savingPreferred = True, preferredError = Nothing }
            , send env model (EditPreferred flag)
            , { db = Nothing }
            )

        Replied edit db result ->
            let
                fx =
                    { db = Just db }
            in
            case result of
                Ok supplier ->
                    let
                        fresh =
                            { model
                                | supplier = supplier
                                , savingPreferred = False
                                , preferredError = Nothing
                                , stale = False
                            }
                    in
                    ( case edit of
                        EditName _ ->
                            { fresh | name = InlineEdit.saved model.name }

                        EditWebsite _ ->
                            { fresh | website = InlineEdit.saved model.website }

                        EditPreferred _ ->
                            fresh
                    , Cmd.none
                    , fx
                    )

                Err error ->
                    let
                        ( problem, message ) =
                            case error of
                                Invalid violations ->
                                    let
                                        text =
                                            violations |> List.head |> Maybe.map .message |> Maybe.withDefault "The server did not accept this."
                                    in
                                    ( Remote.problem Remote.validation |> Remote.withTitle text, text )

                                Conflict _ ->
                                    ( Remote.problem Remote.conflict |> Remote.withTitle "Someone else changed this supplier.", "Someone else changed this supplier." )

                                Unavailable p ->
                                    ( p, "Could not reach the server." )

                        stale =
                            case error of
                                Conflict _ ->
                                    True

                                _ ->
                                    model.stale
                    in
                    ( case edit of
                        EditName _ ->
                            { model | name = InlineEdit.failed problem model.name, stale = stale }

                        EditWebsite _ ->
                            { model | website = InlineEdit.failed problem model.website, stale = stale }

                        EditPreferred _ ->
                            { model | savingPreferred = False, preferredError = Just message, stale = stale }
                    , Cmd.none
                    , fx
                    )

        Reload ->
            case Backend.supplierById env.db model.supplier.id of
                Just current ->
                    ( init current, Cmd.none, { db = Nothing } )

                Nothing ->
                    ( model, Cmd.none, { db = Nothing } )


locale : Locale.Locale
locale =
    Locale.default


view : Remote Lookups -> Model -> Html Msg
view lookups model =
    let
        s =
            model.supplier

        c =
            s.data.company

        d =
            s.data.delivery

        names =
            Remote.withDefault { countries = [], categories = [], paymentTerms = [] } lookups

        countryName id =
            names.countries |> List.filter (\x -> x.id == id) |> List.head |> Maybe.map .name |> Maybe.withDefault (countryKey id)

        categoryName id =
            names.categories |> List.filter (\x -> x.id == id) |> List.head |> Maybe.map .name |> Maybe.withDefault (categoryKey id)

        termsName id =
            names.paymentTerms |> List.filter (\x -> x.id == id) |> List.head |> Maybe.map .name |> Maybe.withDefault (paymentTermsKey id)

        ruleFields =
            [ Rule.bareField "category" "Category" (Rule.ChoiceKind (List.map (\x -> { value = categoryKey x.id, label = x.name }) names.categories))
            , Rule.bareField "quantity" "Quantity" Rule.NumberKind
            , Rule.bareField "orderTotal" "Order total" Rule.NumberKind
            , Rule.bareField "destination" "Destination country" (Rule.ChoiceKind (List.map (\x -> { value = countryKey x.id, label = x.name }) names.countries))
            ]
    in
    Layout.stack [ Layout.gap 4 ]
        [ PageHeader.view
            [ PageHeader.title c.name
            , PageHeader.backLink { href = "#/suppliers", label = "All suppliers" }
            , PageHeader.badges
                [ if c.preferred then
                    Badge.view [ Badge.tone Success ] "Preferred"

                  else
                    Badge.view [] "Standard"
                ]
            , PageHeader.meta
                [ PageHeader.metaItem "Supplier" (supplierIdToString s.id)
                , PageHeader.metaItem "Version" (String.fromInt s.version)
                ]
            , PageHeader.actions
                [ Button.view
                    [ Button.primary
                    , Button.icon Icon.edit
                    , Button.href ("#/suppliers/" ++ supplierIdToString s.id ++ "/edit")
                    ]
                    "Edit all details"
                ]
            ]
        , if model.stale then
            Alert.view
                [ Alert.tone Warning
                , Alert.title "This page is out of date"
                , Alert.actions [ Button.view [ Button.small, Button.onClick Reload ] "Load the latest version" ]
                ]
                "Someone else saved this supplier. Your change was not saved."

          else
            Html.text ""
        , Card.view [ Card.headingLevel 2, Card.title "Company" ]
            [ DescriptionList.view [ DescriptionList.columns 2, DescriptionList.compact ]
                [ DescriptionList.html "Name"
                    (InlineEdit.view NameMsg
                        [ InlineEdit.label "Supplier name"
                        , InlineEdit.maxLength 80
                        , InlineEdit.validate (Validate.run locale Validate.required)
                        ]
                        model.name
                    )
                , DescriptionList.html "Website"
                    (InlineEdit.view WebsiteMsg
                        [ InlineEdit.label "Website"
                        , InlineEdit.emptyText "No website"
                        , InlineEdit.validate
                            (\text ->
                                if String.isEmpty text || String.startsWith "https://" text || String.startsWith "http://" text then
                                    Nothing

                                else
                                    Just "The address must start with https://"
                            )
                        ]
                        model.website
                    )
                , DescriptionList.maybe "Legal name" c.legalName
                , DescriptionList.text "Organisation number" c.orgNumber
                , DescriptionList.text "Country" (countryName c.country)
                , DescriptionList.text "Categories" (c.categories |> List.map categoryName |> String.join ", ")
                , DescriptionList.text "Payment terms" (termsName c.paymentTerms)
                , DescriptionList.html "Preferred supplier"
                    (Switch.view
                        [ Switch.ariaLabel "Preferred supplier"
                        , Switch.checked c.preferred
                        , Switch.loading model.savingPreferred
                        , Switch.onToggle TogglePreferred
                        , Switch.id "detail-preferred"
                        , case model.preferredError of
                            Just m ->
                                Switch.error m

                            Nothing ->
                                Switch.description (yesNo c.preferred)
                        ]
                    )
                , DescriptionList.text "Certifications" (String.join ", " s.data.certifications)
                , DescriptionList.maybe "Contract" (s.data.contract |> Maybe.map .name)
                ]
            ]
        , Card.view [ Card.headingLevel 2, Card.title "Contacts" ]
            [ DescriptionList.view [ DescriptionList.columns 2, DescriptionList.compact ]
                (s.data.contacts
                    |> List.map (\x -> DescriptionList.text (contactRoleLabel x.role) (x.name ++ ", " ++ x.email ++ Maybe.withDefault "" (Maybe.map (\p -> ", " ++ p) x.phone)))
                )
            ]
        , Card.view [ Card.headingLevel 2, Card.title "Delivery terms" ]
            [ DescriptionList.view [ DescriptionList.columns 2, DescriptionList.compact ]
                [ DescriptionList.text "Lead time" (String.fromFloat d.leadTimeDays ++ " days")
                , DescriptionList.maybe "Minimum order" (d.minimumOrder |> Maybe.map (\n -> "NOK " ++ String.fromFloat n))
                , DescriptionList.text "Ships to" (d.shipsTo |> List.map countryName |> String.join ", ")
                , DescriptionList.text "Drop shipping" (yesNo d.dropShipping)
                , DescriptionList.maybe "Notes" d.notes
                ]
            ]
        , Card.view [ Card.headingLevel 2, Card.title "Pricing rules" ]
            [ if List.isEmpty s.data.priceRules then
                Text.muted "No price rules."

              else
                DescriptionList.view [ DescriptionList.columns 1, DescriptionList.compact ]
                    (s.data.priceRules
                        |> List.indexedMap
                            (\i r ->
                                DescriptionList.text ("Rule " ++ String.fromInt (i + 1))
                                    ("If " ++ String.toLower (Rule.describe locale ruleFields r.rule) ++ ": " ++ String.fromFloat r.discountPercent ++ "% off")
                            )
                    )
            ]
        ]


yesNo : Bool -> String
yesNo flag =
    if flag then
        "Yes"

    else
        "No"
