module Klar.Workflow.Codec exposing (encode, decoder)

{-| Versioned JSON for workflow definitions, suitable for file exchange and APIs.

Use when: saving a draft or sending a definition to a workflow server.
Do not use when: only keeping editor state in memory; use `Klar.Workflow` directly.

    import Json.Decode as Decode
    import Klar.Ids as Ids
    import Klar.Workflow.Codec as Codec

    restored =
        Decode.decodeValue (Codec.decoder Ids.string)
            (Codec.encode Ids.string definition)

The decoder accepts incomplete drafts so the builder can show validation errors.
It rejects unknown schema versions, node kinds and identifiers. Always call
`Klar.Workflow.validate` before execution (the engine does this automatically).

@docs encode, decoder

-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Klar.Ids as Ids exposing (Ids)
import Klar.Workflow as W exposing (Definition)


{-| Encode schema version 1, including raw initial-state JSON and loop budgets.
-}
encode : Ids id -> Definition id -> Value
encode ids definition =
    let
        identifier =
            Ids.toKey ids >> Encode.string

        node n =
            Encode.object [ ( "id", identifier n.id ), ( "kind", Encode.string (W.kindKey n.kind) ), ( "title", Encode.string n.title ), ( "instructions", Encode.string n.instructions ), ( "inputKey", Encode.string n.inputKey ), ( "outputKey", Encode.string n.outputKey ), ( "waitSeconds", Encode.int n.waitSeconds ), ( "state", Encode.string n.state ), ( "performerRole", Encode.string n.performerRole ), ( "approverRole", Encode.string n.approverRole ) ]

        edge e =
            Encode.object [ ( "from", identifier e.from ), ( "to", identifier e.to ), ( "label", Encode.string e.label ), ( "maxVisits", Maybe.map Encode.int e.maxVisits |> Maybe.withDefault Encode.null ) ]
    in
    Encode.object [ ( "ownerRole", Encode.string definition.ownerRole ), ( "version", Encode.int 1 ), ( "title", Encode.string definition.title ), ( "nodes", Encode.list node definition.nodes ), ( "edges", Encode.list edge definition.edges ) ]


{-| Decode a version 1 draft using the application's identifier parser.
-}
decoder : Ids id -> Decoder (Definition id)
decoder ids =
    let
        identifier =
            Decode.string |> Decode.andThen (\key -> Ids.fromKey ids key |> Maybe.map Decode.succeed |> Maybe.withDefault (Decode.fail "Unknown node identifier."))

        kind =
            Decode.string |> Decode.andThen (\key -> List.filter (W.kindKey >> (==) key) W.kinds |> List.head |> Maybe.map Decode.succeed |> Maybe.withDefault (Decode.fail "Unknown workflow node kind."))

        node =
            Decode.map8 (\id kind_ title instructions inputKey outputKey waitSeconds state -> { id = id, kind = kind_, title = title, instructions = instructions, inputKey = inputKey, outputKey = outputKey, waitSeconds = waitSeconds, state = state, performerRole = "operator", approverRole = "reviewer" }) (Decode.field "id" identifier) (Decode.field "kind" kind) (Decode.field "title" Decode.string) (Decode.field "instructions" Decode.string) (Decode.field "inputKey" Decode.string) (Decode.field "outputKey" Decode.string) (Decode.field "waitSeconds" Decode.int) (Decode.field "state" Decode.string)

        edge =
            Decode.map4 W.Edge (Decode.field "from" identifier) (Decode.field "to" identifier) (Decode.field "label" Decode.string) (Decode.field "maxVisits" (Decode.nullable Decode.int))
    in
    Decode.field "version" Decode.int
        |> Decode.andThen
            (\version ->
                if version == 1 then
                    Decode.map4 W.Definition (Decode.field "title" Decode.string) (Decode.field "nodes" (Decode.list (Decode.map3 (\n performer approver -> { n | performerRole = performer, approverRole = approver }) node (Decode.field "performerRole" Decode.string) (Decode.field "approverRole" Decode.string)))) (Decode.field "edges" (Decode.list edge)) (Decode.field "ownerRole" Decode.string)

                else
                    Decode.fail "Unsupported workflow schema version."
            )
