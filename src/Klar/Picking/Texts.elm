module Klar.Picking.Texts exposing (Texts, texts)

{-| The built-in text of `Klar.TreeSelect`, `Klar.Cascader` and `Klar.Transfer`,
in English and Norwegian Bokmål. A title that the application gave to a list is
put in quotes wherever it is part of a sentence.

Not for application code.

-}

import Klar.Format as Format
import Klar.Locale as Locale exposing (Locale)


type alias Texts =
    { placeholder : String
    , searchPlaceholder : String
    , searchLabel : String
    , noMatches : String
    , noMatchesFor : String -> String
    , noOptions : String
    , loading : String
    , unavailable : String
    , unknownValue : String
    , clearSelection : String
    , clearAll : String
    , clearChosen : String
    , clearQuery : String
    , tryAgain : String
    , couldNotLoadChildren : String
    , loadingChildren : String
    , selected : Int -> String
    , matches : Int -> Int -> String
    , options : Int -> String
    , results : Int -> String
    , choose : String -> String
    , path : String

    -- Transfer
    , available : String
    , chosen : String
    , selectedOf : Int -> Int -> String
    , selectedOfFiltered : Int -> Int -> Int -> String
    , filterLabel : String -> String
    , filterPlaceholder : String
    , moveSelected : String -> String
    , moveAll : String -> String
    , noItems : String
    , selectAllIn : String -> String
    , movedTo : Int -> String -> String
    , lockedItem : String
    , filtered : Int -> String -> String
    , moveUp : String
    , moveDown : String
    , moveToTop : String
    , moveToBottom : String
    , movedToPlace : String -> Int -> Int -> String
    , movedManyToPlace : Int -> Int -> Int -> String
    }


texts : Locale -> Texts
texts locale =
    let
        num =
            Format.int locale
    in
    Locale.pick locale
        { nb =
            { placeholder = "Velg ..."
            , searchPlaceholder = "Søk ..."
            , searchLabel = "Søk i alternativene"
            , noMatches = "Ingen treff"
            , noMatchesFor = \query -> "Ingen alternativer passer til «" ++ query ++ "»."
            , noOptions = "Ingen alternativer"
            , loading = "Laster ..."
            , unavailable = "Kunne ikke hentes"
            , unknownValue = "Ukjent verdi"
            , clearSelection = "Fjern valget"
            , clearAll = "Fjern alle"
            , clearChosen = "Fjern alle valgte"
            , clearQuery = "Tøm søket"
            , tryAgain = "Prøv igjen"
            , couldNotLoadChildren = "Kunne ikke hentes"
            , loadingChildren = "Laster ..."
            , selected = \n -> num n ++ " valgt"
            , matches = \shown total -> num shown ++ " av " ++ num total ++ " treff"
            , options =
                \n ->
                    num n
                        ++ (if n == 1 then
                                " alternativ"

                            else
                                " alternativer"
                           )
            , results = \n -> num n ++ " treff"
            , choose = \name -> "Velg «" ++ name ++ "»"
            , path = "Sti"
            , available = "Tilgjengelige"
            , chosen = "Valgte"
            , selectedOf = \n total -> num n ++ " av " ++ num total ++ " markert"
            , selectedOfFiltered = \n shown total -> num n ++ " av " ++ num shown ++ " markert (" ++ num total ++ " totalt)"
            , filterLabel = \title -> "Filtrer «" ++ title ++ "»"
            , filterPlaceholder = "Filtrer ..."
            , moveSelected = \title -> "Flytt markerte til «" ++ title ++ "»"
            , moveAll = \title -> "Flytt alle viste til «" ++ title ++ "»"
            , noItems = "Ingen elementer"
            , selectAllIn = \title -> "Marker alle i «" ++ title ++ "»"
            , movedTo =
                \n title ->
                    num n
                        ++ (if n == 1 then
                                " element"

                            else
                                " elementer"
                           )
                        ++ " flyttet til «"
                        ++ title
                        ++ "»"
            , lockedItem = "Låst"
            , filtered = \n title -> num n ++ " vist i «" ++ title ++ "»"
            , moveUp = "Flytt opp"
            , moveDown = "Flytt ned"
            , moveToTop = "Flytt øverst"
            , moveToBottom = "Flytt nederst"
            , movedToPlace = \what place count -> what ++ " flyttet til plass " ++ num place ++ " av " ++ num count
            , movedManyToPlace = \moved place count -> num moved ++ " elementer flyttet til plass " ++ num place ++ " av " ++ num count
            }
        , en =
            { placeholder = "Select ..."
            , searchPlaceholder = "Search ..."
            , searchLabel = "Search the options"
            , noMatches = "No matches"
            , noMatchesFor = \query -> "No options match “" ++ query ++ "”."
            , noOptions = "No options"
            , loading = "Loading ..."
            , unavailable = "Could not be loaded"
            , unknownValue = "Unknown value"
            , clearSelection = "Clear selection"
            , clearAll = "Clear all"
            , clearChosen = "Clear the selection"
            , clearQuery = "Clear search"
            , tryAgain = "Try again"
            , couldNotLoadChildren = "Could not be loaded"
            , loadingChildren = "Loading ..."
            , selected = \n -> num n ++ " selected"
            , matches = \shown total -> num shown ++ " of " ++ num total ++ " matches"
            , options =
                \n ->
                    num n
                        ++ (if n == 1 then
                                " option"

                            else
                                " options"
                           )
            , results =
                \n ->
                    num n
                        ++ (if n == 1 then
                                " match"

                            else
                                " matches"
                           )
            , choose = \name -> "Select “" ++ name ++ "”"
            , path = "Path"
            , available = "Available"
            , chosen = "Chosen"
            , selectedOf = \n total -> num n ++ " of " ++ num total ++ " selected"
            , selectedOfFiltered = \n shown total -> num n ++ " of " ++ num shown ++ " selected (" ++ num total ++ " in all)"
            , filterLabel = \title -> "Filter “" ++ title ++ "”"
            , filterPlaceholder = "Filter ..."
            , moveSelected = \title -> "Move selected to “" ++ title ++ "”"
            , moveAll = \title -> "Move all shown to “" ++ title ++ "”"
            , noItems = "No items"
            , selectAllIn = \title -> "Select all in “" ++ title ++ "”"
            , movedTo =
                \n title ->
                    num n
                        ++ (if n == 1 then
                                " item"

                            else
                                " items"
                           )
                        ++ " moved to “"
                        ++ title
                        ++ "”"
            , lockedItem = "Locked"
            , filtered = \n title -> num n ++ " shown in “" ++ title ++ "”"
            , moveUp = "Move up"
            , moveDown = "Move down"
            , moveToTop = "Move to the top"
            , moveToBottom = "Move to the bottom"
            , movedToPlace = \what place count -> what ++ " moved to place " ++ num place ++ " of " ++ num count
            , movedManyToPlace = \moved place count -> num moved ++ " items moved to place " ++ num place ++ " of " ++ num count
            }
        }
