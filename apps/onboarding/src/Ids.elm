module Ids exposing
    ( contactEmail
    , contactName
    , contactPhone
    , contactPrimary
    , contactRole
    , contacts
    , contract
    , country
    , categories
    , certifications
    , conflictModal
    , deliversTo
    , flowForm
    , leaveDialog
    , leadTime
    , legalName
    , minimumOrder
    , name
    , notes
    , paymentTerms
    , priceRuleDiscount
    , priceRuleEditor
    , priceRuleName
    , priceRuleRow
    , priceRules
    , registration
    , reloadDialog
    , ruleBuilder
    , website
    )

{-| The DOM ids of the whole application, in one place, as Klar's documentation advises.
Ids that depend on a row are functions.
-}


flowForm : String
flowForm =
    "supplier-flow"


name : String
name =
    "company-name"


legalName : String
legalName =
    "company-legal-name"


registration : String
registration =
    "company-registration"


website : String
website =
    "company-website"


country : String
country =
    "company-country"


categories : String
categories =
    "company-categories"


certifications : String
certifications =
    "company-certifications"


contract : String
contract =
    "company-contract"


contacts : String
contacts =
    "contacts-list"


contactName : Int -> String
contactName i =
    "contact-" ++ String.fromInt i ++ "-name"


contactEmail : Int -> String
contactEmail i =
    "contact-" ++ String.fromInt i ++ "-email"


contactPhone : Int -> String
contactPhone i =
    "contact-" ++ String.fromInt i ++ "-phone"


contactRole : Int -> String
contactRole i =
    "contact-" ++ String.fromInt i ++ "-role"


contactPrimary : Int -> String
contactPrimary i =
    "contact-" ++ String.fromInt i ++ "-primary"


leadTime : String
leadTime =
    "delivery-lead-time"


minimumOrder : String
minimumOrder =
    "delivery-minimum-order"


deliversTo : String
deliversTo =
    "delivery-countries"


paymentTerms : String
paymentTerms =
    "delivery-payment-terms"


notes : String
notes =
    "delivery-notes"


priceRules : String
priceRules =
    "pricing-rules"


priceRuleRow : Int -> String
priceRuleRow i =
    "pricing-rule-" ++ String.fromInt i


priceRuleEditor : String
priceRuleEditor =
    "pricing-rule-editor"


priceRuleName : String
priceRuleName =
    "pricing-rule-name"


priceRuleDiscount : String
priceRuleDiscount =
    "pricing-rule-discount"


ruleBuilder : String
ruleBuilder =
    "pricing-rule-builder"


leaveDialog : String
leaveDialog =
    "leave-dialog"


conflictModal : String
conflictModal =
    "conflict-modal"


reloadDialog : String
reloadDialog =
    "reload-dialog"
