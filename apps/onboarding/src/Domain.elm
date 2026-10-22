module Domain exposing
    ( Category
    , CategoryId(..)
    , Contact
    , Country
    , CountryId(..)
    , DeliveryTerms
    , PaymentTerms
    , PaymentTermsId(..)
    , PriceRule
    , Supplier
    , SupplierId(..)
    , categoryKey
    , categoryOfKey
    , countryKey
    , countryOfKey
    , paymentTermsKey
    , supplierIdToString
    )

import Klar.Rule exposing (Rule)


{-| The application's own id types. Selects, multi selects and the rule builder
are all supposed to speak these, not strings.
-}
type CountryId
    = CountryId String


type CategoryId
    = CategoryId Int


type PaymentTermsId
    = Prepaid
    | Net14
    | Net30
    | Net60
    | EndOfMonth


type SupplierId
    = SupplierId Int


type alias Country =
    { id : CountryId, name : String, code : String }


type alias Category =
    { id : CategoryId, name : String, group : String }


type alias PaymentTerms =
    { id : PaymentTermsId, label : String, description : String }


type alias Contact =
    { name : String
    , email : String
    , phone : String
    , role : String
    , primary : Bool
    }


type alias DeliveryTerms =
    { leadTimeDays : Int
    , minimumOrder : Float
    , deliversTo : List CountryId
    , paymentTerms : PaymentTermsId
    , notes : String
    }


type alias PriceRule =
    { name : String
    , rule : Rule
    , discountPercent : Float
    }


type alias Supplier =
    { id : SupplierId
    , version : Int
    , name : String
    , legalName : String
    , registrationNumber : String
    , website : String
    , country : CountryId
    , categories : List CategoryId
    , certifications : List String
    , contractFile : Maybe { name : String, size : Int }
    , contacts : List Contact
    , delivery : DeliveryTerms
    , priceRules : List PriceRule
    }


supplierIdToString : SupplierId -> String
supplierIdToString (SupplierId n) =
    String.fromInt n



-- KLAR GAP: keys for the rule builder, whose choices are Strings (O-002)
-- Keys: the rule builder's choices are Strings, so the ids have to be written as text and read back.


countryKey : CountryId -> String
countryKey (CountryId code) =
    code


countryOfKey : String -> CountryId
countryOfKey =
    CountryId


categoryKey : CategoryId -> String
categoryKey (CategoryId n) =
    String.fromInt n


categoryOfKey : String -> Maybe CategoryId
categoryOfKey text =
    String.toInt text |> Maybe.map CategoryId


paymentTermsKey : PaymentTermsId -> String
paymentTermsKey terms =
    case terms of
        Prepaid ->
            "prepaid"

        Net14 ->
            "net14"

        Net30 ->
            "net30"

        Net60 ->
            "net60"

        EndOfMonth ->
            "eom"
