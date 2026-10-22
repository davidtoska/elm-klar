module Backend exposing
    ( Behaviour
    , Db
    , SaveRequest
    , calm
    , lookups
    , save
    , seed
    , supplierById
    )

{-| A dummy backend: synchronous functions over a `Db`. `Api` puts a delay and
a Cmd around them.
-}

import Domain exposing (..)
import Klar.Remote as Remote
import Klar.Rule as Rule


type alias Db =
    { suppliers : List Supplier
    , nextId : Int
    }


{-| What the pretend network does with the next save.
-}
type alias Behaviour =
    { offline : Bool
    , someoneElseSaved : Bool
    }


calm : Behaviour
calm =
    { offline = False, someoneElseSaved = False }


type alias SaveRequest =
    { id : Maybe SupplierId
    , baseVersion : Int
    , data : SupplierData
    }


lookups : Lookups
lookups =
    { countries =
        [ { id = CountryId "no", name = "Norway" }
        , { id = CountryId "se", name = "Sweden" }
        , { id = CountryId "dk", name = "Denmark" }
        , { id = CountryId "fi", name = "Finland" }
        , { id = CountryId "de", name = "Germany" }
        , { id = CountryId "pl", name = "Poland" }
        , { id = CountryId "nl", name = "Netherlands" }
        , { id = CountryId "gb", name = "United Kingdom" }
        ]
    , categories =
        [ { id = CategoryId "raw", name = "Raw materials" }
        , { id = CategoryId "packaging", name = "Packaging" }
        , { id = CategoryId "electronics", name = "Electronics" }
        , { id = CategoryId "textiles", name = "Textiles" }
        , { id = CategoryId "perishables", name = "Perishables" }
        , { id = CategoryId "machinery", name = "Machinery" }
        ]
    , paymentTerms =
        [ { id = PaymentTermsId "net30", name = "Net 30 days" }
        , { id = PaymentTermsId "net60", name = "Net 60 days" }
        , { id = PaymentTermsId "prepaid", name = "Paid in advance" }
        ]
    }


knownCertifications : List String
knownCertifications =
    [ "ISO 9001", "ISO 14001", "FSC", "GOTS", "HACCP" ]


seed : Db
seed =
    { suppliers =
        [ sample 1 "Nordlys Packaging AS" "912345678" "no" [ "packaging" ] "net30" 5 [ "FSC" ]
        , sample 2 "Fjordfrukt AS" "923456789" "no" [ "perishables" ] "net30" 3 [ "HACCP" ]
        , sample 3 "Kalmar Components AB" "556677889" "se" [ "electronics", "machinery" ] "net60" 21 [ "ISO 9001" ]
        , sample 4 "Baltic Textile Works" "526000124" "pl" [ "textiles" ] "net60" 30 [ "GOTS", "ISO 14001" ]
        ]
    , nextId = 5
    }


sample : Int -> String -> String -> String -> List String -> String -> Float -> List String -> Supplier
sample n name org country categories terms lead certs =
    { id = SupplierId n
    , version = 1
    , data =
        { company =
            { name = name
            , legalName = Nothing
            , orgNumber = org
            , country = CountryId country
            , categories = List.map CategoryId categories
            , paymentTerms = PaymentTermsId terms
            , website = Just ("https://example.com/" ++ String.fromInt n)
            , preferred = n == 1
            }
        , contacts =
            [ { name = "Ada Lovelace"
              , email = "ada@example.com"
              , phone = Just "+47 22 33 44 55"
              , role = Sales
              }
            ]
        , delivery =
            { leadTimeDays = lead
            , minimumOrder = Just 500
            , shipsTo = [ CountryId "no", CountryId "se" ]
            , dropShipping = False
            , notes = Nothing
            }
        , priceRules =
            [ { rule =
                    Rule.GroupRule
                        { id = 0
                        , combinator = Rule.All
                        , negated = False
                        , children =
                            [ Rule.ConditionRule { id = 1, field = "category", operator = Rule.Is, values = [ List.head categories |> Maybe.withDefault "raw" ] }
                            , Rule.ConditionRule { id = 2, field = "quantity", operator = Rule.GreaterThan, values = [ "100" ] }
                            ]
                        }
              , discountPercent = 5
              }
            ]
        , certifications = certs
        , contract = Just { name = "contract-" ++ String.fromInt n ++ ".pdf", size = 120000 }
        }
    }


supplierById : Db -> SupplierId -> Maybe Supplier
supplierById db id =
    List.filter (\s -> s.id == id) db.suppliers |> List.head


{-| Saves a new supplier (`id = Nothing`) or a change to an existing one. The
reply always carries the database as it is afterwards.
-}
save : Behaviour -> Db -> SaveRequest -> ( Db, Result SaveError Supplier )
save behaviour db0 request =
    if behaviour.offline then
        ( db0, Err (Unavailable (Remote.problem Remote.network)) )

    else
        let
            db =
                case ( behaviour.someoneElseSaved, request.id ) of
                    ( True, Just id ) ->
                        touchedByOthers id db0

                    _ ->
                        db0
        in
        case request.id of
            Nothing ->
                case violations db Nothing request.data of
                    [] ->
                        let
                            created =
                                { id = SupplierId db.nextId, version = 1, data = request.data }
                        in
                        ( { suppliers = db.suppliers ++ [ created ], nextId = db.nextId + 1 }
                        , Ok created
                        )

                    problems ->
                        ( db, Err (Invalid problems) )

            Just id ->
                case supplierById db id of
                    Nothing ->
                        ( db, Err (Unavailable (Remote.problem Remote.notFound)) )

                    Just current ->
                        if current.version /= request.baseVersion then
                            ( db, Err (Conflict current) )

                        else
                            case violations db (Just id) request.data of
                                [] ->
                                    let
                                        updated =
                                            { current | version = current.version + 1, data = request.data }
                                    in
                                    ( { db | suppliers = List.map (\s -> if s.id == id then updated else s) db.suppliers }
                                    , Ok updated
                                    )

                                problems ->
                                    ( db, Err (Invalid problems) )


{-| Somebody else saved the record in the meantime: payment terms and the
preferred flag changed, and the version went up.
-}
touchedByOthers : SupplierId -> Db -> Db
touchedByOthers id db =
    let
        touch s =
            if s.id == id then
                let
                    data =
                        s.data

                    company =
                        data.company
                in
                { s
                    | version = s.version + 1
                    , data =
                        { data
                            | company =
                                { company
                                    | paymentTerms = PaymentTermsId "net60"
                                    , preferred = not company.preferred
                                }
                        }
                }

            else
                s
    in
    { db | suppliers = List.map touch db.suppliers }


violations : Db -> Maybe SupplierId -> SupplierData -> List Violation
violations db editing data =
    let
        others =
            List.filter (\s -> Just s.id /= editing) db.suppliers

        company =
            data.company
    in
    List.concat
        [ if List.any (\s -> String.toLower s.data.company.name == String.toLower company.name) others then
            [ { field = FName, message = "A supplier with this name already exists." } ]

          else
            []
        , if List.any (\s -> s.data.company.orgNumber == company.orgNumber) others then
            [ { field = FOrgNumber, message = "This organisation number is registered to another supplier." } ]

          else
            []
        , if company.paymentTerms == PaymentTermsId "prepaid" && company.preferred then
            [ { field = FPaymentTerms, message = "A preferred supplier cannot be paid in advance." } ]

          else
            []
        , if company.country == CountryId "gb" && company.orgNumber == "000000000" then
            [ { field = FCountry, message = "Not a valid registration for the United Kingdom." } ]

          else
            []
        , data.certifications
            |> List.filter (\c -> not (List.member c knownCertifications))
            |> List.map (\c -> { field = FCertifications, message = "Unknown certification \"" ++ c ++ "\". Known: " ++ String.join ", " knownCertifications ++ "." })
            |> List.take 1
        , case data.contract of
            Just file ->
                if String.contains "draft" (String.toLower file.name) then
                    [ { field = FContract, message = "A draft cannot be the signed contract." } ]

                else
                    []

            Nothing ->
                []
        , data.contacts
            |> List.indexedMap
                (\i c ->
                    if String.endsWith "@mailinator.com" (String.toLower c.email) then
                        [ { field = FContactEmail i, message = "Disposable email addresses are not accepted." } ]

                    else if List.any (\( j, o ) -> j < i && String.toLower o.email == String.toLower c.email) (List.indexedMap Tuple.pair data.contacts) then
                        [ { field = FContactEmail i, message = "Already used by an earlier contact." } ]

                    else
                        []
                )
            |> List.concat
        , if List.member (CategoryId "perishables") company.categories && data.delivery.leadTimeDays > 14 then
            [ { field = FLeadTime, message = "Perishables must be delivered within 14 days." } ]

          else
            []
        , data.priceRules
            |> List.indexedMap
                (\i r ->
                    if r.discountPercent > 25 then
                        [ { field = FRuleDiscount i, message = "A discount above 25% needs approval from purchasing." } ]

                    else
                        []
                )
            |> List.concat
        ]
