module Backend exposing
    ( Field(..)
    , Problem
    , SaveError(..)
    , Store
    , categories
    , countries
    , initialStore
    , list
    , otherUserEdits
    , paymentTerms
    , save
    , supplierById
    )

{-| The dummy backend: plain synchronous functions over a `Store`. The `Api` module
puts a request/response layer with delay and failures in front of them.
-}

import Domain exposing (..)
import Klar.Rule as Rule exposing (Combinator(..), Operator(..), Rule(..))


type alias Store =
    { suppliers : List Supplier
    , nextId : Int
    }


{-| What a server problem is tied to. The application maps these to its own inputs.
-}
type Field
    = Name
    | LegalName
    | Registration
    | Website
    | CountryField
    | ContactName Int
    | ContactEmail Int
    | ContactPhone Int
    | LeadTime
    | MinimumOrder
    | PricingRule Int


type alias Problem =
    { field : Field, message : String }


type SaveError
    = Invalid (List Problem)
    | Conflict Supplier



-- Reference data


countries : List Country
countries =
    [ Country (CountryId "NO") "Norway" "NO"
    , Country (CountryId "SE") "Sweden" "SE"
    , Country (CountryId "DK") "Denmark" "DK"
    , Country (CountryId "FI") "Finland" "FI"
    , Country (CountryId "DE") "Germany" "DE"
    , Country (CountryId "NL") "Netherlands" "NL"
    , Country (CountryId "FR") "France" "FR"
    , Country (CountryId "PL") "Poland" "PL"
    , Country (CountryId "GB") "United Kingdom" "GB"
    , Country (CountryId "XX") "Eastland (not supported yet)" "XX"
    ]


categories : List Category
categories =
    [ Category (CategoryId 1) "Boxes" "Packaging"
    , Category (CategoryId 2) "Pallets" "Packaging"
    , Category (CategoryId 3) "Tape and film" "Packaging"
    , Category (CategoryId 4) "Cables" "Electronics"
    , Category (CategoryId 5) "Sensors" "Electronics"
    , Category (CategoryId 6) "Batteries" "Electronics"
    , Category (CategoryId 7) "Paper" "Office"
    , Category (CategoryId 8) "Furniture" "Office"
    , Category (CategoryId 9) "Fabric" "Textiles"
    , Category (CategoryId 10) "Workwear" "Textiles"
    , Category (CategoryId 11) "Cleaning" "Chemicals"
    ]


paymentTerms : List PaymentTerms
paymentTerms =
    [ PaymentTerms Prepaid "Prepaid" "Paid before shipping"
    , PaymentTerms Net14 "Net 14" "Due 14 days after the invoice"
    , PaymentTerms Net30 "Net 30" "Due 30 days after the invoice"
    , PaymentTerms Net60 "Net 60" "Due 60 days after the invoice"
    , PaymentTerms EndOfMonth "End of month" "Due at the end of the month after the invoice"
    ]



-- Data


condition : Int -> String -> Operator -> List String -> Rule
condition id field operator values =
    ConditionRule { id = id, field = field, operator = operator, values = values }


initialStore : Store
initialStore =
    { nextId = 4
    , suppliers =
        [ { id = SupplierId 1
          , version = 3
          , name = "Northwind Components"
          , legalName = "Northwind Components AS"
          , registrationNumber = "12345678"
          , website = "https://northwind.example.com"
          , country = CountryId "NO"
          , categories = [ CategoryId 4, CategoryId 5 ]
          , certifications = [ "ISO 9001", "ISO 14001" ]
          , contractFile = Just { name = "northwind-contract-2026.pdf", size = 482113 }
          , contacts =
                [ { name = "Kari Nordmann", email = "kari@northwind.example.com", phone = "+47 22 33 44 55", role = "Account manager", primary = True }
                , { name = "Ola Hansen", email = "ola@northwind.example.com", phone = "", role = "Logistics", primary = False }
                ]
          , delivery =
                { leadTimeDays = 7
                , minimumOrder = 500
                , deliversTo = [ CountryId "NO", CountryId "SE", CountryId "DK" ]
                , paymentTerms = Net30
                , notes = "Deliveries on weekdays before 15:00."
                }
          , priceRules =
                [ { name = "Cable volume discount"
                  , rule =
                        GroupRule
                            { id = 0
                            , combinator = All
                            , negated = False
                            , children =
                                [ condition 1 "category" Is [ "4" ]
                                , condition 2 "quantity" GreaterThan [ "100" ]
                                ]
                            }
                  , discountPercent = 5
                  }
                ]
          }
        , { id = SupplierId 2
          , version = 1
          , name = "Contoso Packaging"
          , legalName = "Contoso Verpackung GmbH"
          , registrationNumber = "87654321"
          , website = "https://contoso-packaging.example.com"
          , country = CountryId "DE"
          , categories = [ CategoryId 1, CategoryId 2, CategoryId 3 ]
          , certifications = [ "FSC" ]
          , contractFile = Nothing
          , contacts =
                [ { name = "Greta Schmidt", email = "greta@contoso-packaging.example.com", phone = "+49 30 1234567", role = "Sales", primary = True } ]
          , delivery =
                { leadTimeDays = 14
                , minimumOrder = 1200
                , deliversTo = [ CountryId "DE", CountryId "NL", CountryId "PL" ]
                , paymentTerms = Net60
                , notes = ""
                }
          , priceRules = []
          }
        , { id = SupplierId 3
          , version = 7
          , name = "Fabrikam Textiles"
          , legalName = "Fabrikam Textil AB"
          , registrationNumber = "55512345"
          , website = ""
          , country = CountryId "SE"
          , categories = [ CategoryId 9, CategoryId 10 ]
          , certifications = []
          , contractFile = Nothing
          , contacts =
                [ { name = "Sven Svensson", email = "sven@fabrikam.example.com", phone = "+46 8 555 12 34", role = "Owner", primary = True } ]
          , delivery =
                { leadTimeDays = 21
                , minimumOrder = 2500
                , deliversTo = [ CountryId "SE", CountryId "FI" ]
                , paymentTerms = EndOfMonth
                , notes = "Seasonal collections ship twice a year."
                }
          , priceRules = []
          }
        ]
    }



-- Queries


list : Store -> List Supplier
list store =
    store.suppliers


supplierById : Store -> SupplierId -> Maybe Supplier
supplierById store id =
    List.filter (\s -> s.id == id) store.suppliers |> List.head



-- Saving


save : Store -> Supplier -> Result SaveError ( Supplier, Store )
save store submitted =
    if submitted.id == SupplierId 0 then
        case validate store submitted of
            [] ->
                let
                    created =
                        { submitted | id = SupplierId store.nextId, version = 1 }
                in
                Ok ( created, { store | suppliers = store.suppliers ++ [ created ], nextId = store.nextId + 1 } )

            problems ->
                Err (Invalid problems)

    else
        case supplierById store submitted.id of
            Nothing ->
                Err (Invalid [ { field = Name, message = "This supplier no longer exists." } ])

            Just current ->
                if current.version /= submitted.version then
                    Err (Conflict current)

                else
                    case validate store submitted of
                        [] ->
                            let
                                updated =
                                    { submitted | version = current.version + 1 }
                            in
                            Ok
                                ( updated
                                , { store
                                    | suppliers =
                                        List.map
                                            (\s ->
                                                if s.id == updated.id then
                                                    updated

                                                else
                                                    s
                                            )
                                            store.suppliers
                                  }
                                )

                        problems ->
                            Err (Invalid problems)


{-| Somebody else saves a change to the record: the version moves on.
-}
otherUserEdits : SupplierId -> Store -> Store
otherUserEdits id store =
    let
        bump s =
            if s.id == id then
                let
                    delivery =
                        s.delivery
                in
                { s
                    | version = s.version + 1
                    , delivery = { delivery | leadTimeDays = delivery.leadTimeDays + 3, notes = "Lead time changed by Grace Hopper." }
                }

            else
                s
    in
    { store | suppliers = List.map bump store.suppliers }


validate : Store -> Supplier -> List Problem
validate store s =
    let
        others =
            List.filter (\o -> o.id /= s.id) store.suppliers

        indexed f items =
            List.indexedMap f items |> List.concat
    in
    List.concat
        [ if List.any (\o -> String.toLower o.name == String.toLower (String.trim s.name)) others then
            [ { field = Name, message = "A supplier with this name already exists." } ]

          else
            []
        , if List.any (\o -> o.registrationNumber == String.trim s.registrationNumber) others then
            [ { field = Registration, message = "This registration number belongs to another supplier." } ]

          else
            []
        , if s.website /= "" && not (String.startsWith "http" s.website) then
            [ { field = Website, message = "The website must start with http:// or https://." } ]

          else
            []
        , if s.country == CountryId "XX" then
            [ { field = CountryField, message = "We cannot onboard suppliers in this country yet." } ]

          else
            []
        , indexed
            (\i c ->
                List.concat
                    [ if String.endsWith "@blocked.example" (String.toLower c.email) then
                        [ { field = ContactEmail i, message = "This email domain is blocked." } ]

                      else
                        []
                    , if String.startsWith "+999" c.phone then
                        [ { field = ContactPhone i, message = "This phone prefix is not in use." } ]

                      else
                        []
                    ]
            )
            s.contacts
        , if s.delivery.leadTimeDays > 90 then
            [ { field = LeadTime, message = "Lead times above 90 days need a framework agreement." } ]

          else
            []
        , indexed
            (\i r ->
                if r.discountPercent > 25 then
                    [ { field = PricingRule i, message = "Discounts above 25% need a signed approval." } ]

                else
                    []
            )
            s.priceRules
        ]
