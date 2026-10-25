module Klar.Internal.TextField exposing
    ( composing
    , controlAttributes
    , counter
    , generatedId
    , isOver
    )

{-| What the text fields of the package share: the guard against keys of an
input method composition, the character counter of `TextInput` and `TextArea`,
the attributes of the control with ids of their own in `aria-describedby`, and
the id a field makes for itself when the application gives it none.
-}

import Html exposing (Html)
import Html.Attributes as Attr
import Json.Decode as Decode exposing (Decoder)
import Klar.Field as Field
import Klar.Internal as Internal
import Klar.Locale as Locale exposing (Locale)



-- INPUT METHODS


{-| Is the event part of an input method composition (Japanese, Chinese, Korean
...)? Then Enter confirms the composed word and the arrows pick a candidate: they
are not keys for the field. Browsers say so with `isComposing`, and some give the
key that ends a composition the key code 229. An input event while composing
holds text that is not final yet.
-}
composing : Decoder Bool
composing =
    Decode.map2 (||)
        (Decode.oneOf [ Decode.field "isComposing" Decode.bool, Decode.succeed False ])
        (Decode.oneOf [ Decode.field "keyCode" Decode.int |> Decode.map (\code -> code == 229), Decode.succeed False ])



-- COUNTER


{-| Is the text longer than the limit?
-}
isOver : Int -> Int -> Bool
isOver limit length =
    length > limit


type Stage
    = Far
    | Near
    | AtLimit
    | Over


{-| How many characters left count as near the limit: a tenth of the limit, or
a fifth up to 10 characters, whichever is more. A short field (a postal code of
4, a PIN of 6) is near only at its last character or two, and never at 0.
-}
nearAt : Int -> Int
nearAt limit =
    Basics.max (Basics.min 10 (limit // 5)) (limit // 10)


stageOf : Int -> Int -> Stage
stageOf limit length =
    let
        remaining =
            limit - length
    in
    if remaining < 0 then
        Over

    else if remaining == 0 then
        AtLimit

    else if remaining <= nearAt limit then
        Near

    else
        Far


{-| The character counter at the end of the line under a field (the aside of
`Field.viewWithAside`). It never cuts the text: a text over the limit is shown as
such.

  - For the eye: `12/200`, amber when the limit is near (a tenth of the limit
    left, or a fifth up to 10 characters, whichever is more), red past it.
  - For `aria-describedby`, with the given id: "12 of 200 characters" (and "60 too
    many" past the limit), read when the field gets focus.
  - A live region that is always there and speaks only when the text comes near
    the limit, reaches it and passes it, not on every keystroke.

-}
counter : { id : String, locale : Locale, length : Int, limit : Int } -> Html msg
counter { id, locale, length, limit } =
    let
        stage =
            stageOf limit length

        characters n =
            Locale.pick locale
                { nb = "tegn"
                , en =
                    if n == 1 then
                        "character"

                    else
                        "characters"
                }

        count =
            Locale.pick locale
                { nb = String.fromInt length ++ " av " ++ String.fromInt limit ++ " " ++ characters limit
                , en = String.fromInt length ++ " of " ++ String.fromInt limit ++ " " ++ characters limit
                }

        description =
            if stage == Over then
                count
                    ++ Locale.pick locale
                        { nb = ", " ++ String.fromInt (length - limit) ++ " for mange"
                        , en = ", " ++ String.fromInt (length - limit) ++ " too many"
                        }

            else
                count

        limitText =
            String.fromInt limit ++ " " ++ characters limit

        spoken =
            case stage of
                Far ->
                    ""

                Near ->
                    Locale.pick locale
                        { nb = "Nesten ved grensen på " ++ limitText
                        , en = "Almost at the limit of " ++ limitText
                        }

                AtLimit ->
                    Locale.pick locale
                        { nb = "Grensen på " ++ limitText ++ " er nådd"
                        , en = "Limit of " ++ limitText ++ " reached"
                        }

                Over ->
                    Locale.pick locale
                        { nb = "Over grensen på " ++ limitText
                        , en = "Over the limit of " ++ limitText
                        }
    in
    Html.span
        [ Internal.cls
            [ "klar-counter"
            , case stage of
                Over ->
                    "klar-counter--over"

                AtLimit ->
                    "klar-counter--near"

                Near ->
                    "klar-counter--near"

                Far ->
                    ""
            ]
        ]
        [ Html.span [ Attr.attribute "aria-hidden" "true" ] [ Html.text (String.fromInt length ++ "/" ++ String.fromInt limit) ]
        , Html.span [ Internal.cls [ "klar-sr-only" ], Internal.attrIf (id /= "") (Attr.id id) ] [ Html.text description ]
        , Html.span [ Internal.cls [ "klar-sr-only" ], Attr.attribute "role" "status" ] [ Html.text spoken ]
        ]



-- THE CONTROL


{-| The attributes of the element that takes the focus, like
`Field.controlAttributes`, with more ids for `aria-describedby` (a counter) and
`aria-invalid` also when `invalid` says so (a text over its limit). A field
without an id gets none, and nothing points at it.
-}
controlAttributes : Field.Config -> { describedBy : List String, invalid : Bool } -> List (Html.Attribute msg)
controlAttributes field extra =
    let
        own =
            if field.id == "" then
                []

            else
                List.filterMap identity
                    [ Maybe.map (\_ -> Field.hintId field) field.hint
                    , Maybe.map (\_ -> field.id ++ "-error") field.error
                    ]

        described =
            own ++ List.filter (\id -> id /= "") extra.describedBy
    in
    [ Internal.attrIf (field.id /= "") (Attr.id field.id)
    , case described of
        [] ->
            Internal.noAttr

        ids ->
            Attr.attribute "aria-describedby" (String.join " " ids)
    , Internal.attrIf (field.error /= Nothing || extra.invalid) (Attr.attribute "aria-invalid" "true")
    , Internal.attrIf field.required (Attr.attribute "aria-required" "true")
    ]



-- IDS


{-| The id of a field that was given none: the prefix and the first of the texts
that is not blank (the label, then the placeholder, the name, the hint and the
error), in lower case and with the characters that cannot be in an id replaced.
Without any of them the field gets no id (an empty text): it has no label, hint
or error that must point at it, and two such fields never share one.
-}
generatedId : String -> List (Maybe String) -> String
generatedId prefix seeds =
    case List.filterMap (Maybe.andThen Internal.nonEmpty) seeds of
        seed :: _ ->
            prefix ++ Internal.sanitizeId (String.toLower (String.trim seed))

        [] ->
            ""
