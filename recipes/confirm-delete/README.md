# Confirm before delete

Delete one row or a selection only after a confirmation that shows the request busy, failed (with
"Try again") and done, followed by a toast with an Undo, and with focus kept right.

Modules: `Klar.Table` (`selectable`, `bulkActions`, `rowActions`, `rowIds`), `Klar.Menu`,
`Klar.ConfirmDialog`, `Klar.Toast`, `Klar.Overlay` (`host`), `Klar.Remote` (the problem),
`Klar.PageHeader`, `Klar.Button`, `Klar.Icon`.

The pattern:

1. `ConfirmDialog.open` on the click, with the ids to delete kept in your model (`pending`).
2. `onConfirm` -> `ConfirmDialog.setBusy` and send the request. While busy nothing closes it.
3. Failure -> `ConfirmDialog.setFailed problem` (the dialog offers "Try again", which sends
   `onConfirm` again). Success -> `ConfirmDialog.close`, change the model, `Toast.push` with
   `Toast.action "Undo"`.
4. Both the dialog and the toasts are in the overlay list. No focus code: the layer returns focus,
   and `Table.focus` takes it to the table after the bulk bar is gone.

The dummy backend fails the first request on purpose.
