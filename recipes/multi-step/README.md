# Multi-step flow with a leave guard

Task: a three-step order flow (customer, delivery, review) with a stepper, validation before "Next", a submit that can fail, and a question before the user leaves with unsaved input, also when the user presses the browser Back button.

Klar modules: `Klar.Form` (the form model, which owns the steps), `Klar.Form.Spec`, `Klar.Form.Layout`, `Klar.LeaveGuard`, `Klar.Overlay`, `Klar.Validate`, `Klar.DescriptionList`, `Klar.Card`, `Klar.PageHeader`, `Klar.Layout`, `Klar.Button`, `Klar.Toast`, `Klar.Remote`.

The pattern:

1. Declare the steps with the fields: `Spec.step Customer "Customer" |> Spec.with ... |> Spec.step Review "Review"`. A last step with no fields is the review step. The form keeps which step the user is on; the application has only `Home | Order | Done` routes.
2. "Next" and "Place order" are one button: `Form.advance` checks the current step (or the whole form on the last), shows the problems, focuses the summary, and gives `submit = Just values` when everything passed. "Back" is `Form.back`. `Form.stepper` draws the steps and marks the ones with problems; `Form.summary` on the review step lists every problem with a button that goes there.
3. `LeaveGuard.Guard Source Route` is made with `initAt` and told `LeaveGuard.setDirty OrderForm (Form.isDirty state)` after each form message.
4. Links ask first: `LeaveGuard.request`. The browser Back and Forward buttons are answered by `LeaveGuard.onUrlChange` in `UrlChanged`: with unsaved input the page stays and the dialog opens. "Leave" resets the form and pushes the held route; "Stay" needs no code.
5. The submit sets `FormLayout.Submitting`, then `FormLayout.Failed problem` (with a retry button) or a toast, a clean form and the done route. Try the customer `Crash` for a failure.
