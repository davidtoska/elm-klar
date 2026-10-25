module Klar.Chart.Types exposing (..)

{-| Internal chart data, configuration, axis and prepared-geometry contracts; no chart rendering.
-}

import Array exposing (Array)
import Klar.Date exposing (Date)
import Klar.Internal.Freshness as Freshness exposing (Freshness)
import Klar.Locale as Locale exposing (Locale)
import Klar.Remote as Remote exposing (Problem, Remote)
import Klar.Settings as Settings exposing (Settings)
import Klar.Theme as Theme exposing (Tone(..))


{-| A named row of values, one per category: the data of a line or bar chart.
Make one with `series` or `seriesMaybe`, adjust it with `withSlot`, `withTone`
and `dashed`, and pass a list of them to `line` or `bar`.
-}
type Series
    = Series
        { name : String
        , values : List (Maybe Float)
        , color : Maybe Int
        , tone : Maybe Tone
        , dashed : Bool
        }


{-| One slice of a donut. Make one with `segment`, adjust it with
`segmentSlot` and `segmentTone`, and pass a list of them to `donut`.
-}
type Segment
    = Segment
        { label : String
        , value : Float
        , color : Maybe Int
        , tone : Maybe Tone
        }


{-| A setting of a chart. Make them with the functions below and pass a list to a
chart function (`line`, `bar` and so on); later attributes win over earlier ones.
-}
type Attribute msg
    = Attribute (Config msg -> Config msg)


type State
    = Ready
    | Busy
    | Failed Problem


type alias Config msg =
    { title : Maybe String
    , description : Maybe String
    , ariaLabel : Maybe String
    , categories : List String
    , dates : List Date
    , height : Maybe Int
    , width : Maybe Int
    , area : Bool
    , pointsOnHover : Bool
    , stacked : Bool
    , horizontal : Bool
    , valueLabels : Bool
    , legend : Maybe Bool
    , yMin : Maybe Float
    , yMax : Maybe Float
    , includeZero : Bool
    , valueFormat : Maybe (Float -> String)
    , unit : String
    , locale : Locale
    , settings : Settings
    , tone : Maybe Tone
    , busy : Bool
    , failure : Maybe Problem
    , freshness : Freshness
    , fromRemote : Bool
    , onRetry : Maybe msg
    , onSelect : Maybe (Int -> msg)
    , id : Maybe String
    , emptyText : Maybe String
    , centerLabel : Maybe String
    , centerCaption : Maybe String
    , thresholds : List ( Float, Tone )
    , rangeMin : Float
    , rangeMax : Float
    , maxLabels : Maybe Int
    }


type alias Texts =
    { noData : String
    , loading : String
    , line : String
    , bar : String
    , donut : String
    , gauge : String
    , meter : String
    , sparkline : String
    , category : String
    , value : String
    , share : String
    , total : String
    , other : String
    , tableTruncated : Int -> String
    , seriesCount : Int -> String
    , pointCount : Int -> String
    , segmentCount : Int -> String
    , of_ : String
    , low : String
    , high : String
    , last : String
    , noValue : String
    }


type alias PSeries =
    { name : String
    , values : Array (Maybe Float)
    , cls : String
    , dashed : Bool
    }


type alias Prepared =
    { n : Int
    , cats : Array String
    , short : Array String
    , series : List PSeries
    }


type alias Axis =
    { lo : Float
    , hi : Float
    , ticks : List Float
    , decimals : Int
    }


type alias LegendItem msg =
    { label : String
    , cls : String
    , detail : String
    , dashed : Bool
    , select : Maybe msg
    }


type alias Piece =
    { series : PSeries
    , index : Int
    , value : Float
    , from : Float
    , to : Float
    , outer : Bool
    }


type alias Slice =
    { label : String
    , value : Float
    , color : Maybe Int
    , tone : Maybe Tone

    -- the position in the list of segments; Nothing for "Other"
    , index : Maybe Int
    }


{-| The data of a line or bar chart from a `Remote` (`lineRemote`, `barRemote`):
its categories and its series in one value, made in the `Remote.map` that shapes
the response, so the labels can never come from another request than the values.
-}
type Data
    = Data { categories : List String, dates : List Date, series : List Series }
