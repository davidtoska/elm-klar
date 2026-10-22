module Backend exposing
    ( Db
    , Failure(..)
    , Field(..)
    , Named
    , Patch(..)
    , Problem
    , categories
    , countries
    , create
    , find
    , init
    , otherUserEdits
    , paymentTerms
    , patch
    , setOffline
    , update
    )

{-| The dummy backend: synchronous functions over a `Db`. The layer `Api` puts a delay and a
`Cmd` in front of them. Nothing here knows Klar except the types of the domain.

The server can say no in four ways:

  - the organisation number is taken, a website is blocked, an e-mail belongs to another
    supplier, a discount is too high: `Invalid` with a problem tied to a field;
  - the record was changed by someone else since it was loaded: `Conflict` with the current record;
  - the legal name "Crash" (or the switch "server is down"): `Down`;
  - the record does not exist: `Gone`.

-}

import Domain exposing (..)
import Klar.Ids as Ids
import Klar.Rule as Rule


type alias Named id =
    { id : id, name : String }


type alias Db =
    { suppliers : List Supplier
    , nextId : Int
    , offline : Bool
    }


type Field
    = LegalName
    | TradingName
    | OrgNumber
    | Website
    | ContactEmail Int
    | PriceDiscount Int


type alias Problem =
    { field : Field, message : String }


type Failure
    = Down
    | Invalid (List Problem)
    | Conflict Supplier
    | Gone


type Patch
    = SetTradingName (Maybe String)
    | SetWebsite (Maybe String)


countries : List (Named CountryId)
countries =
    [ { id = CountryId "no", name = "Norway" }
    , { id = CountryId "se", name = "Sweden" }
    , { id = CountryId "dk", name = "Denmark" }
    , { id = CountryId "fi", name = "Finland" }
    , { id = CountryId "de", name = "Germany" }
    , { id = CountryId "pl", name = "Poland" }
    , { id = CountryId "nl", name = "Netherlands" }
    ]


categories : List (Named CategoryId)
categories =
    [ { id = CategoryId 1, name = "Fasteners" }
    , { id = CategoryId 2, name = "Packaging" }
    , { id = CategoryId 3, name = "Electronics" }
    , { id = CategoryId 4, name = "Chemicals" }
    , { id = CategoryId 5, name = "Textiles" }
    , { id = CategoryId 6, name = "Food and beverages" }
    ]


paymentTerms : List (Named PaymentTermsId)
paymentTerms =
    [ { id = PaymentTermsId "net14", name = "Net 14 days" }
    , { id = PaymentTermsId "net30", name = "Net 30 days" }
    , { id = PaymentTermsId "net60", name = "Net 60 days" }
    , { id = PaymentTermsId "prepaid", name = "Prepayment" }
    ]


init : Db
init =
    { suppliers =
        [ { id = SupplierId 1
          , version = 3
          , profile =
                { legalName = "Aurora Fasteners AS"
                , tradingName = Just "Aurora"
                , orgNumber = "912345678"
                , country = CountryId "no"
                , website = Just "https://aurora-fasteners.example"
                , categories = [ CategoryId 1, CategoryId 2 ]
                , certifications = [ "ISO 9001", "ISO 14001" ]
                , contacts =
                    [ { name = "Ingrid Moe", email = "ingrid@aurora-fasteners.example", phone = Just "+47 22 33 44 55", primary = True }
                    , { name = "Per Hansen", email = "per@aurora-fasteners.example", phone = Nothing, primary = False }
                    ]
                , paymentTerms = PaymentTermsId "net30"
                , deliveryCountries = [ CountryId "no", CountryId "se", CountryId "dk" ]
                , leadTimeDays = 7
                , minOrderValue = Just 500
                , contract = { name = "aurora-contract-2026.pdf", size = 182340, mime = "application/pdf" }
                , notes = Just "Preferred supplier for stainless steel."
                }
          , priceRules =
                [ { condition = seedRule
                  , discountPercent = 5
                  }
                ]
          }
        , { id = SupplierId 2
          , version = 1
          , profile =
                { legalName = "Fjord Packaging Ltd"
                , tradingName = Nothing
                , orgNumber = "987654321"
                , country = CountryId "se"
                , website = Nothing
                , categories = [ CategoryId 2 ]
                , certifications = [ "FSC" ]
                , contacts = [ { name = "Maja Berg", email = "maja@fjordpack.example", phone = Nothing, primary = True } ]
                , paymentTerms = PaymentTermsId "net14"
                , deliveryCountries = [ CountryId "se", CountryId "no" ]
                , leadTimeDays = 14
                , minOrderValue = Nothing
                , contract = { name = "fjord-contract.pdf", size = 99120, mime = "application/pdf" }
                , notes = Nothing
                }
          , priceRules = []
          }
        ]
    , nextId = 3
    , offline = False
    }


find : SupplierId -> Db -> Maybe Supplier
find id db =
    List.filter (\s -> s.id == id) db.suppliers |> List.head


setOffline : Bool -> Db -> Db
setOffline offline db =
    { db | offline = offline }


{-| The demo's "someone else": changes the payment terms and the lead time and bumps the version.
-}
otherUserEdits : SupplierId -> Db -> Db
otherUserEdits id db =
    replace id
        (\s ->
            let
                profile =
                    s.profile
            in
            { s
                | version = s.version + 1
                , profile =
                    { profile
                        | paymentTerms = PaymentTermsId "net60"
                        , leadTimeDays = profile.leadTimeDays + 3
                        , notes = Just "Terms renegotiated by purchasing."
                    }
            }
        )
        db


create : Profile -> List PriceRule -> Db -> ( Db, Result Failure Supplier )
create profile priceRules db =
    case check Nothing profile priceRules db of
        Err failure ->
            ( db, Err failure )

        Ok () ->
            let
                supplier =
                    { id = SupplierId db.nextId, version = 1, profile = profile, priceRules = priceRules }
            in
            ( { db | suppliers = db.suppliers ++ [ supplier ], nextId = db.nextId + 1 }, Ok supplier )


{-| Save a whole record. `expected` is the version the client started from.
-}
update : SupplierId -> Int -> Profile -> List PriceRule -> Db -> ( Db, Result Failure Supplier )
update id expected profile priceRules db =
    case find id db of
        Nothing ->
            ( db, Err Gone )

        Just current ->
            if current.version /= expected then
                ( db, Err (Conflict current) )

            else
                case check (Just id) profile priceRules db of
                    Err failure ->
                        ( db, Err failure )

                    Ok () ->
                        let
                            saved =
                                { current | version = current.version + 1, profile = profile, priceRules = priceRules }
                        in
                        ( replace id (always saved) db, Ok saved )


patch : SupplierId -> Int -> Patch -> Db -> ( Db, Result Failure Supplier )
patch id expected change db =
    case find id db of
        Nothing ->
            ( db, Err Gone )

        Just current ->
            if db.offline then
                ( db, Err Down )

            else if current.version /= expected then
                ( db, Err (Conflict current) )

            else
                let
                    profile =
                        current.profile

                    changed =
                        case change of
                            SetTradingName name ->
                                { profile | tradingName = name }

                            SetWebsite site ->
                                { profile | website = site }
                in
                case check (Just id) changed current.priceRules db of
                    Err failure ->
                        ( db, Err failure )

                    Ok () ->
                        let
                            saved =
                                { current | version = current.version + 1, profile = changed }
                        in
                        ( replace id (always saved) db, Ok saved )


replace : SupplierId -> (Supplier -> Supplier) -> Db -> Db
replace id f db =
    { db | suppliers = List.map (\s -> if s.id == id then f s else s) db.suppliers }


{-| The server's rules, beyond what the client checks.
-}
check : Maybe SupplierId -> Profile -> List PriceRule -> Db -> Result Failure ()
check self profile priceRules db =
    let
        others =
            List.filter (\s -> Just s.id /= self) db.suppliers

        orgTaken =
            List.any (\s -> s.profile.orgNumber == profile.orgNumber) others

        emailTaken email =
            List.any (\s -> List.any (\c -> String.toLower c.email == String.toLower email) s.profile.contacts) others

        problems =
            List.concat
                [ if orgTaken then
                    [ { field = OrgNumber, message = "This organisation number belongs to another supplier." } ]

                  else
                    []
                , case profile.website of
                    Just site ->
                        if String.contains "blocked" site then
                            [ { field = Website, message = "This domain is on the procurement blocklist." } ]

                        else
                            []

                    Nothing ->
                        []
                , profile.contacts
                    |> List.indexedMap
                        (\i c ->
                            if emailTaken c.email then
                                [ { field = ContactEmail i, message = "This e-mail address is registered on another supplier." } ]

                            else
                                []
                        )
                    |> List.concat
                , priceRules
                    |> List.indexedMap
                        (\i r ->
                            if r.discountPercent > 40 then
                                [ { field = PriceDiscount i, message = "Discounts above 40 % need approval from purchasing." } ]

                            else
                                []
                        )
                    |> List.concat
                ]
    in
    if db.offline || profile.legalName == "Crash" then
        Err Down

    else if List.isEmpty problems then
        Ok ()

    else
        Err (Invalid problems)


{-| Seed rules are written as data; the app builds the same shape with the rule builder.
-}
seedRule : Rule.Rule
seedRule =
    Rule.GroupRule
        { id = 0
        , combinator = Rule.All
        , negated = False
        , children =
            [ Rule.ConditionRule { id = 1, field = Domain.categoryFieldId, operator = Rule.Is, values = [ Ids.toKey categoryIds (CategoryId 1) ] }
            , Rule.ConditionRule { id = 2, field = Domain.quantityFieldId, operator = Rule.GreaterThan, values = [ "1000" ] }
            ]
        }
