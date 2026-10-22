module Effect exposing (Effects, Notice, map, none, notify)

{-| What a page asks of the application around it: a toast, a change of the
database, opening an order.
-}

import Backend exposing (Db)
import Domain exposing (OrderId)
import Klar.Theme exposing (Tone)


type alias Notice msg =
    { tone : Tone
    , title : String
    , message : String
    , retry : Maybe msg
    }


type alias Effects msg =
    { notices : List (Notice msg)
    , change : Maybe (Db -> Db)
    , open : Maybe OrderId
    , close : Bool
    }


none : Effects msg
none =
    { notices = [], change = Nothing, open = Nothing, close = False }


notify : Notice msg -> Effects msg
notify notice =
    { none | notices = [ notice ] }


map : (a -> b) -> Effects a -> Effects b
map f effects =
    { notices = List.map (\n -> { tone = n.tone, title = n.title, message = n.message, retry = Maybe.map f n.retry }) effects.notices
    , change = effects.change
    , open = effects.open
    , close = effects.close
    }
