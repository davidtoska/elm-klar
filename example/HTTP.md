# Elm, Go and SQLite: the application boundary

Use the [kitchen-sink consumer](../apps/kitchen-sink/README.md) as the running
example. This guide explains its cross-language contract; public component
contracts remain in the [generated module reference](../ai/modules/README.md).
The client code is generated: edit its application generator when changing it.

## A server-backed list

`ServerList.update` returns state, a command and an optional request. The client
keeps that `ServerList.Request` under an application operation key and sends its
public query/rule data to Go. When the reply arrives, look up the original request
and pass `ServerList.gotPage pending result` back through `ServerList.update`.
The component uses that request to reject obsolete results. Query changes,
paging and saved-view changes stay in the component's normal lifecycle.

See `followServer`, `encodeServerQuery` and `encodeServerRule` in
[Main.elm](../apps/kitchen-sink/src/Main.elm), and `listQuery` / `queryOrders` in
[query.go](../apps/kitchen-sink/server/query.go).

The demo sends `POST /api/orders/query` with an explicit application protocol:

```json
{
  "search": "Fjord",
  "page": 1,
  "pageSize": 25,
  "sort": [{ "field": "total", "descending": true }],
  "filters": [{ "field": "customer", "contains": "Fjord" }],
  "rule": {
    "combinator": "all",
    "negated": false,
    "children": [{ "field": "total", "operator": "atLeast", "values": ["10000"] }]
  }
}
```

The response has `rows` and `total`; total counts matching records before paging.
This demo's totals are integer minor units. Go validates its supported sort fields,
column filters and rule operators. The UI offers the same supported subset.
The encoder maps `Table.ColumnId` through `Table.columnName` and maps each supported
`Rule.Operator` explicitly. This protocol is owned by the application, rather
than a serialization of opaque component state. Extend both ends together.

The Go handler loads persisted rows, filters, sorts and pages them. A larger
service can execute those operations in SQL while preserving the same response
contract. The component owns presentation and request freshness; the server owns
query validation, permissions and persisted data.

## File upload, progress and cancellation

`UploadQueue` stages files and renders transfer statuses; the application keeps
the actual `File` handles and a ticket per transfer. The consumer's
`StartUpload`, `UploadProgress`, `Uploaded` and `CancelUpload` branches in
[Main.elm](../apps/kitchen-sink/src/Main.elm) show the complete wiring:

1. Increment the transfer ticket and set `UploadQueue.transferring`.
2. Send `Http.multipartBody [ Http.filePart "file" entry.file ]` with `elm/http`.
   Give the request a tracker derived from the stable upload id.
3. Subscribe with `Http.track`; accept progress and completion only when the
   upload id and captured ticket still match the current entry.
4. On cancel, invalidate the ticket and use `Http.cancel` for the tracker. On retry,
   start a new ticket. Late replies cannot change the newer transfer state.
5. Move focus to the stable queue region when a focused action disappears.
   The consumer uses `Klar.focus "upload-queue" NoOp` on start/cancel/remove.

The Go [upload handler](../apps/kitchen-sink/server/main.go) accepts multipart field
`file` at `POST /api/uploads`, limits a file to 5 MiB, stores its bytes in SQLite
and returns HTTP 201 with `id`, `name` and `size`. `GET /api/uploads/{id}` returns
the stored bytes. Client cancellation stops waiting for a response; it does not
undo a server write that already committed. The demo's upload endpoint does not
deduplicate retries. Add a server operation/idempotency key if an application
needs that guarantee.

Persisted upload metadata cannot recreate a browser `File` after reload. Keep
unsaved handles in memory and ask the user to select the file again when needed.

## Verification

Run the consumer's own `npm run verify` when changing this integration. Its Go
tests cover queries, persistence and byte-exact uploads; browser checks cover
actual transfer, cancellation and the UI. Its [findings](../apps/kitchen-sink/FINDINGS.md)
and [coverage](../apps/kitchen-sink/coverage.json) distinguish rendered scenarios
from explicit interaction checks. The smaller programs in `src/Examples/` remain
useful for learning one component lifecycle without a real transport.
