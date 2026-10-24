module IdsCodecTest exposing (suite)

{-| `Klar.Ids`: a key reads back only in the spelling `toKey` writes, `Ids.list`
reads back the first value written alike, and `Ids.map` wraps an inner codec.
-}

import Expect
import Fuzz
import Klar.Ids as Ids exposing (Ids)
import Test exposing (Test, describe, fuzz, test)


type CustomerId
    = CustomerId Int


customerIds : Ids CustomerId
customerIds =
    Ids.int |> Ids.map CustomerId (\(CustomerId n) -> n)


type Code
    = Code String


codeIds : Ids Code
codeIds =
    Ids.string |> Ids.map Code (\(Code text) -> text)


suite : Test
suite =
    describe "Klar.Ids"
        [ describe "Ids.int reads only the spelling it writes"
            [ test "7 is written \"7\" and read back" <|
                \_ -> Expect.equal (Just 7) (Ids.fromKey Ids.int (Ids.toKey Ids.int 7))
            , test "negative numbers too" <|
                \_ -> Expect.equal (Just -12) (Ids.fromKey Ids.int "-12")
            , test "other spellings of a number are no id" <|
                \_ ->
                    Expect.equal [ Nothing, Nothing, Nothing, Nothing, Nothing, Nothing ]
                        (List.map (Ids.fromKey Ids.int) [ "007", "+7", "-0", "7.0", "1e3", " 7" ])
            , test "a number too long to hold exactly is no id" <|
                \_ -> Expect.equal Nothing (Ids.fromKey Ids.int "123456789012345678901234567890")
            , fuzz Fuzz.int "every whole number reads back" <|
                \n -> Expect.equal (Just n) (Ids.fromKey Ids.int (Ids.toKey Ids.int n))
            ]
        , describe "Ids.list"
            [ test "reads a value back by its text" <|
                \_ ->
                    Expect.equal (Just 3) (Ids.fromKey (Ids.list String.fromInt (List.range 1 5000)) "3")
            , test "two values written alike read back as the first" <|
                \_ ->
                    Expect.equal (Just "Apple")
                        (Ids.fromKey (Ids.list (String.left 1) [ "Apple", "Avocado", "Banana" ]) "A")
            , test "text that is none of the values is Nothing" <|
                \_ -> Expect.equal Nothing (Ids.fromKey (Ids.list String.fromInt [ 1, 2 ]) "9")
            ]
        , describe "Ids.map"
            [ test "writes the inner key" <|
                \_ -> Expect.equal "42" (Ids.toKey customerIds (CustomerId 42))
            , test "reads it back wrapped" <|
                \_ -> Expect.equal (Just (CustomerId 42)) (Ids.fromKey customerIds "42")
            , test "keeps the inner rules: \"042\" is no id" <|
                \_ -> Expect.equal Nothing (Ids.fromKey customerIds "042")
            , test "over text" <|
                \_ -> Expect.equal (Just (Code "SKU-1")) (Ids.fromKey codeIds (Ids.toKey codeIds (Code "SKU-1")))
            ]
        ]
