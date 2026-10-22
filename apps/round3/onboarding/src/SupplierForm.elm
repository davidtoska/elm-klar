module SupplierForm exposing
    ( ContactFields
    , Fields
    , Step(..)
    , f
    , fill
    , form
    )

{-| The onboarding form, declared once: five steps, the contacts as rows, the application's own
id types in the selects, tags and a file. The price rules are not here (see `PriceRules`).
-}

import Domain exposing (..)
import Klar.FileDrop as FileDrop
import Klar.Form as Form
import Klar.Form.Spec as Spec
import Klar.Locale as Locale
import Klar.Validate as Validate


type Step
    = Company
    | Contacts
    | Delivery
    | Pricing
    | Review


type alias ContactFields =
    { name : Form.Field String
    , email : Form.Field String
    , phone : Form.Field String
    , primary : Form.Field Bool
    }


contact : Form.Form () ContactFields Contact
contact =
    Spec.define "contact" ContactFields Contact
        |> Spec.with (Spec.text "Name" |> Spec.required |> Spec.rules [ Validate.maxLength 80 ])
        |> Spec.with (Spec.text "Email" |> Spec.required |> Spec.rules [ Validate.email ])
        |> Spec.with (Spec.text "Phone" |> Spec.rules [ Validate.phone ])
        |> Spec.with (Spec.toggle "Primary contact")
        |> Spec.build


type alias Fields =
    { legalName : Form.Field String
    , tradingName : Form.Field String
    , orgNumber : Form.Field String
    , country : Form.Field (Maybe CountryId)
    , website : Form.Field String
    , categories : Form.Field (List CategoryId)
    , certifications : Form.Field (List String)
    , contacts : Form.Field (Form.Rows ContactFields)
    , paymentTerms : Form.Field (Maybe PaymentTermsId)
    , deliveryCountries : Form.Field (List CountryId)
    , leadTimeDays : Form.Field (Maybe Float)
    , minOrderValue : Form.Field (Maybe Float)
    , contract : Form.Field (List FileDrop.FileInfo)
    , notes : Form.Field String
    }


form : Form.Form Step Fields Profile
form =
    Spec.define "supplier" Fields Profile
        |> Spec.step Company "Company"
        |> Spec.with (Spec.text "Legal name" |> Spec.required |> Spec.rules [ Validate.maxLength 80 ])
        |> Spec.with (Spec.text "Trading name" |> Spec.rules [ Validate.maxLength 80 ])
        |> Spec.with
            (Spec.text "Organisation number"
                |> Spec.required
                |> Spec.hint "Nine digits."
                |> Spec.rules
                    [ Validate.custom (\text -> String.length text == 9 && String.all Char.isDigit text)
                        { nb = "Oppgi ni siffer", en = "Enter nine digits" }
                    ]
            )
        |> Spec.with (Spec.choice countryIds "Country" |> Spec.required)
        |> Spec.with
            (Spec.text "Website"
                |> Spec.rules
                    [ Validate.custom
                        (\text -> (String.startsWith "http://" text || String.startsWith "https://" text) && String.contains "." text)
                        { nb = "Start med http:// eller https://", en = "Start with http:// or https://" }
                    ]
            )
        |> Spec.with (Spec.choices categoryIds "Categories" |> Spec.atLeast 1)
        |> Spec.with (Spec.tags "Certifications" |> Spec.hint "Type a certification and press Enter.")
        |> Spec.step Contacts "Contacts"
        |> Spec.with
            (Spec.rows { label = "Contacts", item = "Contact" } contact
                |> Spec.atLeast 1
                |> Spec.rule
                    (\contacts -> List.length (List.filter .primary contacts) == 1)
                    (\lang -> Locale.pick lang { nb = "Merk nøyaktig én kontakt som hovedkontakt", en = "Mark exactly one contact as primary" })
            )
        |> Spec.step Delivery "Delivery terms"
        |> Spec.with (Spec.choice paymentTermsIds "Payment terms" |> Spec.required)
        |> Spec.with (Spec.choices countryIds "Delivers to" |> Spec.atLeast 1)
        |> Spec.with (Spec.number "Lead time" |> Spec.required |> Spec.whole |> Spec.range 1 365 |> Spec.hint "Days from order to delivery.")
        |> Spec.with (Spec.number "Minimum order value" |> Spec.range 0 1000000 |> Spec.hint "In euros.")
        |> Spec.with (Spec.files "Signed contract" |> Spec.one |> Spec.required)
        |> Spec.with (Spec.text "Notes" |> Spec.rules [ Validate.maxLength 500 ])
        |> Spec.step Pricing "Pricing rules"
        |> Spec.step Review "Review"
        |> Spec.build


f : Fields
f =
    Form.fields form


{-| Load a profile into the form: the baseline is the profile.
-}
fill : Profile -> Form.State Step -> Form.State Step
fill p =
    Form.set f.legalName p.legalName
        >> Form.set f.tradingName (Maybe.withDefault "" p.tradingName)
        >> Form.set f.orgNumber p.orgNumber
        >> Form.set f.country (Just p.country)
        >> Form.set f.website (Maybe.withDefault "" p.website)
        >> Form.set f.categories p.categories
        >> Form.set f.certifications p.certifications
        >> Form.fillRows f.contacts
            (\c row ->
                Form.set row.name c.name
                    >> Form.set row.email c.email
                    >> Form.set row.phone (Maybe.withDefault "" c.phone)
                    >> Form.set row.primary c.primary
            )
            p.contacts
        >> Form.set f.paymentTerms (Just p.paymentTerms)
        >> Form.set f.deliveryCountries p.deliveryCountries
        >> Form.set f.leadTimeDays (Just p.leadTimeDays)
        >> Form.set f.minOrderValue p.minOrderValue
        >> Form.set f.contract [ p.contract ]
        >> Form.set f.notes (Maybe.withDefault "" p.notes)
        >> Form.markClean
