module Api.Problem exposing (fieldError, fieldErrors, toProblem)

{-| Turns what the API reports into what the interface components show.

`ApiError` belongs to the contract with the backend; `Remote.Problem` is the
library's plain-data description of a failure (title, detail, code). This is the
one place that knows both.

-}

import Api.Types exposing (ApiError(..), FieldError)
import Klar.Remote as Remote exposing (Problem)


toProblem : ApiError -> Problem
toProblem error =
    case error of
        NetworkDown ->
            Remote.problem Remote.network
                |> Remote.withCode "ERR_NETWORK"

        TimedOut ->
            Remote.problem Remote.timeout
                |> Remote.withCode "ETIMEDOUT"

        ServerFailed status ->
            Remote.problem Remote.server
                |> Remote.withCode ("HTTP " ++ String.fromInt status)

        NotFound ->
            Remote.problem Remote.notFound
                |> Remote.withCode "HTTP 404"

        Conflict message ->
            Remote.problem Remote.conflict
                |> Remote.withDetail message
                |> Remote.withCode "HTTP 409"

        ValidationFailed errors ->
            Remote.problem Remote.validation
                |> Remote.withCode ("HTTP 422 · " ++ String.fromInt (List.length errors))


{-| The message for one field, if the server reported one.
-}
fieldError : String -> ApiError -> Maybe String
fieldError field error =
    fieldErrors error
        |> List.filter (\item -> item.field == field)
        |> List.head
        |> Maybe.map .message


fieldErrors : ApiError -> List FieldError
fieldErrors error =
    case error of
        ValidationFailed errors ->
            errors

        _ ->
            []
