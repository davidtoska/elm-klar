module Domain exposing
    ( Category
    , CategoryId(..)
    , Company
    , Contact
    , ContactRole(..)
    , ContractFile
    , Country
    , CountryId(..)
    , Delivery
    , Field(..)
    , Lookups
    , PaymentTerms
    , PaymentTermsId(..)
    , PriceRule
    , SaveError(..)
    , Supplier
    , SupplierData
    , SupplierId(..)
    , Violation
    , categoryIds
    , categoryKey
    , countryKey
    , paymentTermsKey
    , contactRoleIds
    , contactRoleLabel
    , contactRoles
    , countryIds
    , paymentTermsIds
    , supplierIdFromString
    , supplierIdToString
    )

import Klar.Form.Model as Fm
import Klar.Remote as Remote
import Klar.Rule as Rule


type CountryId
    = CountryId String


type CategoryId
    = CategoryId String


type PaymentTermsId
    = PaymentTermsId String


type SupplierId
    = SupplierId Int


type ContactRole
    = Sales
    | Finance
    | Logistics


type alias Country =
    { id : CountryId, name : String }


type alias Category =
    { id : CategoryId, name : String }


type alias PaymentTerms =
    { id : PaymentTermsId, name : String }


type alias Lookups =
    { countries : List Country
    , categories : List Category
    , paymentTerms : List PaymentTerms
    }


type alias Company =
    { name : String
    , legalName : Maybe String
    , orgNumber : String
    , country : CountryId
    , categories : List CategoryId
    , paymentTerms : PaymentTermsId
    , website : Maybe String
    , preferred : Bool
    }


type alias Contact =
    { name : String
    , email : String
    , phone : Maybe String
    , role : ContactRole
    }


type alias Delivery =
    { leadTimeDays : Float
    , minimumOrder : Maybe Float
    , shipsTo : List CountryId
    , dropShipping : Bool
    , notes : Maybe String
    }


type alias PriceRule =
    { rule : Rule.Rule
    , discountPercent : Float
    }


type alias ContractFile =
    { name : String, size : Int }


{-| Everything a person enters; what the server stores besides id and version.
-}
type alias SupplierData =
    { company : Company
    , contacts : List Contact
    , delivery : Delivery
    , priceRules : List PriceRule
    , certifications : List String
    , contract : Maybe ContractFile
    }


type alias Supplier =
    { id : SupplierId
    , version : Int
    , data : SupplierData
    }


{-| A field the server can complain about. The `Int` is the position in the list
that was sent.
-}
type Field
    = FName
    | FOrgNumber
    | FCountry
    | FCategories
    | FPaymentTerms
    | FWebsite
    | FCertifications
    | FContract
    | FContactEmail Int
    | FContactName Int
    | FLeadTime
    | FShipsTo
    | FRule Int
    | FRuleDiscount Int


type alias Violation =
    { field : Field, message : String }


type SaveError
    = Invalid (List Violation)
    | Conflict Supplier
    | Unavailable Remote.Problem


countryKey : CountryId -> String
countryKey (CountryId s) =
    s


categoryKey : CategoryId -> String
categoryKey (CategoryId s) =
    s


paymentTermsKey : PaymentTermsId -> String
paymentTermsKey (PaymentTermsId s) =
    s


countryIds : Fm.Ids CountryId
countryIds =
    Fm.ids { toKey = countryKey, fromKey = CountryId >> Just }


categoryIds : Fm.Ids CategoryId
categoryIds =
    Fm.ids { toKey = categoryKey, fromKey = CategoryId >> Just }


paymentTermsIds : Fm.Ids PaymentTermsId
paymentTermsIds =
    Fm.ids { toKey = paymentTermsKey, fromKey = PaymentTermsId >> Just }


contactRoles : List ContactRole
contactRoles =
    [ Sales, Finance, Logistics ]


contactRoleLabel : ContactRole -> String
contactRoleLabel role =
    case role of
        Sales ->
            "Sales"

        Finance ->
            "Finance"

        Logistics ->
            "Logistics"


contactRoleIds : Fm.Ids ContactRole
contactRoleIds =
    Fm.ids
        { toKey =
            \role ->
                case role of
                    Sales ->
                        "sales"

                    Finance ->
                        "finance"

                    Logistics ->
                        "logistics"
        , fromKey =
            \key ->
                case key of
                    "sales" ->
                        Just Sales

                    "finance" ->
                        Just Finance

                    "logistics" ->
                        Just Logistics

                    _ ->
                        Nothing
        }


supplierIdToString : SupplierId -> String
supplierIdToString (SupplierId n) =
    String.fromInt n


supplierIdFromString : String -> Maybe SupplierId
supplierIdFromString text =
    String.toInt text |> Maybe.map SupplierId
