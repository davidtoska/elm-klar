# Edit form with validation and a save that can fail

Task: load a customer, edit it, validate it, and save it, where the backend can answer with a problem for one field or with a failure of its own.

Klar modules: `Klar.Form` (the form model), `Klar.Form.Spec` (its declaration), `Klar.Form.Layout` (frame, status line, unsaved banner), `Klar.Ids`, `Klar.Remote`, `Klar.Select`, `Klar.Validate`, `Klar.Toast`, `Klar.Overlay`, `Klar.Card`, `Klar.Skeleton`, `Klar.ErrorState`, `Klar.PageHeader`, `Klar.Layout`, `Klar.Button`, `Klar.Locale`.

The pattern:

1. Declare the form once (`Spec.define ... |> Spec.with ... |> Spec.build`); the n-th `with` fills the n-th field of `Fields` and of `Customer`. Keep one `Form.State ()` and one `Form.Msg` in the model. The country id type is written as text once, with `Ids.make`.
2. Load into the form with `Form.set` and then `Form.markClean`; `Form.isDirty` drives `FormLayout.unsavedChanges`, and `Form.revert` is Discard.
3. On submit: `Form.toValues` gives the record or the problems; on problems call `Form.reveal` (shows all, focuses the summary).
4. A save sets `FormLayout.Submitting`; the answer is `Form.markClean` plus a toast, or `Form.rejected` with `Form.problem field message` for each field problem (shown at the field and in the summary until that field is edited), or `FormLayout.Failed problem` for a failure with a retry button.
5. The retry button of a failure gets its own message (`Retry`): it runs `Submit` and `FormLayout.focusStatus`, because "Try again" is replaced by "Saving ..." the moment it is pressed and focus would fall to the page. `Form.rejected` (field problems from the server) already moves focus to the summary.
6. `Form.summary` draws the list of problems and receives the focus; the application writes no DOM id and no draft record.

Try the e-mail `taken@example.com` (field problem) and the name `Crash` (failure).
