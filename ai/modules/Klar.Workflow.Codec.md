# Klar.Workflow.Codec

Versioned JSON for workflow definitions, suitable for file exchange and APIs.

Import: `import Klar.Workflow.Codec as Codec` | Group: Processes and state

## Signatures

```elm
encode : Ids.Ids id -> Workflow.Definition id -> Json.Encode.Value
decoder : Ids.Ids id -> Json.Decode.Decoder (Workflow.Definition id)
```

## Documentation

Versioned JSON for workflow definitions, suitable for file exchange and APIs.

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

### `encode`

```elm
encode : Ids.Ids id -> Workflow.Definition id -> Json.Encode.Value
```

Encode schema version 1, including raw initial-state JSON and loop budgets.

### `decoder`

```elm
decoder : Ids.Ids id -> Json.Decode.Decoder (Workflow.Definition id)
```

Decode a version 1 draft using the application's identifier parser.
