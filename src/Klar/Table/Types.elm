module Klar.Table.Types exposing (..)

{-| Internal data vocabulary shared by table logic and rendering; it has no table-view dependency.
-}

import Array exposing (Array)
import Dict exposing (Dict)
import Html exposing (Html)
import Klar.EmptyState as EmptyState
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Internal.Window as Window
import Klar.Locale as Locale exposing (Locale)
import Klar.Menu as Menu
import Klar.Money as Money exposing (Money)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Table.Index as Index exposing (Index)
import Klar.Table.Texts as Texts exposing (Texts)
import Klar.Theme as Theme exposing (Density(..), Tone)
import Set exposing (Set)


type Direction
    = Ascending
    | Descending


type Filter
    = Contains String
    | OneOf (List String)
    | Between (Maybe Float) (Maybe Float)


type ColumnId
    = ColumnId String


type alias Query =
    { search : String
    , sort : List ( ColumnId, Direction )
    , filters : List ( ColumnId, Filter )
    , page : Int
    , pageSize : Int
    }


type Selection id
    = Selected (List id)
    | AllMatching { except : List id }


type State id
    = State Model


type alias Model =
    { id : String
    , sort : List ( String, Direction )
    , page : Int
    , pageSize : Int
    , searchInput : String
    , search : String
    , inputs : Dict String Draft
    , filters : Dict String Filter
    , debounce : Int
    , selection : Picked
    , expanded : Set String
    , visibility : Dict String Bool
    , density : Density
    , popup : Popup
    , optionQuery : String
    , rowMenu : Maybe ( String, Menu.State )
    , activeRow : Int
    , scroll : Float

    -- the row the user last selected or deselected by itself: where a Shift range starts
    , anchor : Maybe String
    }


{-| What the filter inputs show; becomes a `Filter` when it is not empty.
-}
type Draft
    = TextDraft String
    | ChoiceDraft (Set String)
    | RangeDraft String String


type Picked
    = Picked (Set String)
    | AllPicked (Set String)


type Popup
    = NoPopup
    | FilterPopup String
    | ColumnsPopup
    | ExportPopup
    | BulkExportPopup
    | FiltersPopup


type Msg
    = NoOp
    | SortClicked String Bool
    | PageChanged Int
    | PageSizeChanged Int
    | SearchChanged String Int
    | FilterTextChanged String String Int
    | FilterRangeChanged String Bool String Int
    | FilterChoiceToggled String String Bool
    | FilterChoicesSet String (List String)
    | OptionQueryChanged String
    | FilterCleared String
    | FiltersCleared
    | AllCleared
    | Debounced Int
    | PopupOpened Popup (List String)
    | PopupClosed
    | PopupLeft
    | RowMenu String String (List String) Menu.Msg
    | RowMenuOpened String String (List String)
    | RowSelected String Bool
    | RowsSelected (List String) Bool
    | RangeSelected (List String) Bool String
    | MatchingSelected (List String)
    | AllMatchingPicked
    | SelectionCleared String
    | ExpandToggled String
    | DensityChanged Density
    | ColumnToggled String Bool
    | ColumnsReset
    | RowFocused Int
    | FocusRow Int String
    | FocusVirtualRow Int String Window.Geometry
    | Scrolled Float
    | RetryClicked
    | FirstPageClicked
    | ExportClicked String String


type Column row msg
    = Column (ColumnConfig row msg)


type ColumnAttribute row msg
    = ColumnAttribute (ColumnConfig row msg -> ColumnConfig row msg)


type alias ColumnConfig row msg =
    { id : String
    , title : String
    , value : Locale -> row -> String
    , cell : Maybe (Locale -> row -> Html msg)
    , sortBy : SortBy row
    , number : Maybe (row -> Maybe Float)
    , decimals : Int
    , export : Maybe (Locale -> row -> String)
    , align : Align
    , width : Maybe Int
    , minWidth : Int
    , pinned : Bool
    , hiddenByDefault : Bool
    , hideable : Bool
    , wrap : Bool
    , tooltip : Bool
    , searchable : Bool
    , exported : Bool
    , filter : Maybe FilterKind
    , filterOptions : Maybe (List { value : String, label : String })
    , filterValue : Maybe (row -> String)
    , footer : Maybe (Footer row)
    , hint : Maybe String
    , controls : Bool
    , numeric : Bool
    , boolean : Bool

    -- a money column: its footers add the amounts exactly, per currency
    , money : Maybe (row -> Money)
    }


type SortBy row
    = SortByValue
    | SortByText (row -> String)
    | SortByNumber (row -> Maybe Float)
    | SortByComparator (row -> row -> Order)
    | NotSortable


type Align
    = AlignLeft
    | AlignRight
    | AlignCenter


type FilterKind
    = TextFilter
    | SelectFilter
    | RangeFilter


type Footer row
    = FooterSum
    | FooterAverage
    | FooterCustom (List row -> String)


{-| The amounts of one currency in a money column added up exactly, with how many
there are. A total beyond the range of `Money` is `Nothing`.
-}
type alias MoneyTotal =
    { total : Maybe Money
    , count : Int
    }


type Attribute id row msg
    = Attribute (Config row msg -> Config row msg)


type alias Config row msg =
    { columns : List (Column row msg)
    , rows : Remote (Source row)
    , rowId : Maybe (row -> String)
    , rowLabel : Maybe (row -> String)
    , server : Maybe Int
    , label : Maybe String
    , locale : Locale
    , settings : Settings
    , searchable : Bool
    , searchPlaceholder : Maybe String
    , searchDebounce : Maybe Int
    , rowFilter : Maybe (row -> Bool)
    , externalFilters : Int
    , onResetFilters : Maybe msg
    , selectable : Bool
    , bulkActions : List (Html msg)
    , rowActions : Maybe (row -> List (Menu.Item msg))
    , onRowClick : Maybe (row -> msg)
    , expandedRow : Maybe (row -> Html msg)
    , rowTone : Maybe (row -> Maybe Tone)
    , rowDisabled : Maybe (row -> Bool)
    , currentRow : Maybe (row -> Bool)
    , toolbarActions : List (Html msg)
    , onRefresh : Maybe msg
    , refreshing : Bool
    , freshness : Freshness
    , onRetry : Maybe msg
    , export : Maybe String
    , csvSeparator : Maybe Char
    , columnChooser : Bool
    , densityToggle : Bool
    , pageSizes : List Int
    , rangeText : Maybe (Int -> Int -> Int -> String)
    , paged : Bool
    , virtual : Bool
    , multiSort : Bool
    , zebra : Bool
    , maxHeight : Maybe Int
    , fillHeight : Bool
    , emptyState : List (EmptyState.Attribute msg)
    }


type Rows row
    = Rows
        { array : Array row
        , locale : Locale
        , columnIds : List String
        , searchIds : List String
        , index : Index

        -- the exact totals of the money columns with a footer, over every row
        , moneyTotals : Dict String (List MoneyTotal)
        }


type Source row
    = FromList (List row)
    | FromRows (Rows row)


type alias Data row =
    { status : DataStatus
    , pageRows : List row
    , pageAll : List row
    , first : Int
    , rowCount : Int
    , matchingRows : () -> List row

    -- How many matching rows pass a test that gets the place of the row among the
    -- matching rows and the row itself: a count that never builds the list of rows.
    , countMatching : (Int -> row -> Bool) -> Int
    , totals : String -> Maybe Index.Totals

    -- the exact totals of a money column, kept by prepared rows while no row is left out
    , moneyTotals : String -> Maybe (List MoneyTotal)
    , total : Int
    , available : Int
    , page : Int
    , pageCount : Int
    , offset : Int
    }


type DataStatus
    = Waiting
    | Failed Problem
    | Ready


type alias Ctx row msg =
    { toMsg : Msg -> msg
    , config : Config row msg
    , model : Model
    , t : Texts
    , loc : Locale
    , allColumns : List (ColumnConfig row msg)
    , visible : List (ColumnConfig row msg)
    , data : Data row
    , keyOf : Int -> row -> String
    , labelOf : row -> String
    , delay : Int
    , hasSelect : Bool
    , hasExpand : Bool
    , hasMenu : Bool
    , pinnedFirst : Bool
    , colCount : Int
    , interactiveRows : Bool
    , activeRow : Int
    , rowCount : Int
    , pageKeys : List String
    , geometry : Window.Geometry
    }


type alias RowInfo msg =
    { index : Int
    , key : String
    , domId : String
    , disabled : Bool
    , selected : Bool
    , expanded : Bool
    , click : Maybe msg
    , menu : Maybe msg
    , menuTrigger : String
    }
