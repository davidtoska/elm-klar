module Domain exposing
    ( CategoryId(..)
    , Contact
    , CountryId(..)
    , PaymentTermsId(..)
    , PriceRule
    , Profile
    , Supplier
    , SupplierId(..)
    , categoryFieldId
    , categoryIds
    , countryFieldId
    , countryIds
    , paymentTermsIds
    , quantityFieldId
    , supplierIdFromString
    , supplierIdToString
    )

{-| The application's own types: the ids that the selects, the form and the rule builder share,
and the supplier record.
-}

import Klar.FileDrop as FileDrop
import Klar.Ids as Ids exposing (Ids)
import Klar.Rule as Rule


type CountryId
    = CountryId String


type CategoryId
    = CategoryId Int


type PaymentTermsId
    = PaymentTermsId String


type SupplierId
    = SupplierId Int


categoryFieldId : String
categoryFieldId =
    "category"


quantityFieldId : String
quantityFieldId =
    "quantity"


countryFieldId : String
countryFieldId =
    "country"


countryIds : Ids CountryId
countryIds =
    Ids.make { toKey = \(CountryId code) -> code, fromKey = Just << CountryId }


categoryIds : Ids CategoryId
categoryIds =
    Ids.make { toKey = \(CategoryId n) -> String.fromInt n, fromKey = Maybe.map CategoryId << String.toInt }


paymentTermsIds : Ids PaymentTermsId
paymentTermsIds =
    Ids.make { toKey = \(PaymentTermsId key) -> key, fromKey = Just << PaymentTermsId }


supplierIdToString : SupplierId -> String
supplierIdToString (SupplierId n) =
    String.fromInt n


supplierIdFromString : String -> Maybe SupplierId
supplierIdFromString =
    Maybe.map SupplierId << String.toInt


type alias Contact =
    { name : String
    , email : String
    , phone : Maybe String
    , primary : Bool
    }


{-| What the onboarding form produces (the fields of the first four steps except the price rules).
-}
type alias Profile =
    { legalName : String
    , tradingName : Maybe String
    , orgNumber : String
    , country : CountryId
    , website : Maybe String
    , categories : List CategoryId
    , certifications : List String
    , contacts : List Contact
    , paymentTerms : PaymentTermsId
    , deliveryCountries : List CountryId
    , leadTimeDays : Float
    , minOrderValue : Maybe Float
    , contract : FileDrop.FileInfo
    , notes : Maybe String
    }


{-| "If the order matches `condition`, give `discountPercent`."
-}
type alias PriceRule =
    { condition : Rule.Rule
    , discountPercent : Float
    }


type alias Supplier =
    { id : SupplierId
    , version : Int
    , profile : Profile
    , priceRules : List PriceRule
    }
