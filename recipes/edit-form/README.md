# Edit form with validation and a save that can fail

Task: load a customer, edit it, validate it, and save it, where the backend can answer with a problem for one field or with a failure of its own.

Klar modules: `Klar.Form.Model` (the form), `Klar.Form` (the frame, status line, unsaved banner), `Klar.Remote`, `Klar.Select`, `Klar.Validate`, `Klar.Toast`, `Klar.Overlay`, `Klar.Card`, `Klar.Skeleton`, `Klar.ErrorState`, `Klar.PageHeader`, `Klar.Layout`, `Klar.Button`, `Klar.Locale`.

The pattern:

1. Declare the form once (`Fm.define ... |> Fm.with ... |> Fm.build`); the n-th `with` fills the n-th field of `Fields` and of `Customer`. Keep one `Fm.State ()` and one `Fm.Msg` in the model.
2. Load into the form with `Fm.set` and then `Fm.markClean`; `Fm.isDirty` drives `Form.unsavedChanges`.
3. On submit: `Fm.toValues` gives the record or the problems; on problems call `Fm.reveal` (shows all, focuses the summary).
4. A save sets `Form.Submitting`; the answer is `Fm.markClean` plus a toast, or `Fm.rejected` with `Fm.problem field message` for each field problem, or `Form.Failed problem` for a failure with a retry button.
5. `Fm.summary` draws the list of problems; nothing else is needed for focus.

Try the e-mail `taken@example.com` (field problem) and the name `Crash` (failure).
