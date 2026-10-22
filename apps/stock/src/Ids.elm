module Ids exposing
    ( appShell
    , kindFilter
    , movementList
    , movementSearch
    , movementViewer
    , period
    , tabs
    , table
    , tree
    )

{-| Every DOM id of the page, in one place, so none is used twice.
-}


appShell : String
appShell =
    "stock-shell"


tree : String
tree =
    "stock-locations"


period : String
period =
    "stock-period"


movementSearch : String
movementSearch =
    "stock-movement-search"


kindFilter : String
kindFilter =
    "stock-movement-kind"


movementList : String
movementList =
    "stock-movement-list"


movementViewer : String
movementViewer =
    "stock-movement-json"


tabs : String
tabs =
    "stock-movement-tabs"


table : String
table =
    "stock-movement-table"
