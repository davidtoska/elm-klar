# Multi-step flow with a leave guard

Task: a three-step order flow (customer, delivery, review) with one route per step, validation before "Next", a submit that can fail, and a question before the user leaves with unsaved input.

Klar modules: `Klar.Stepper`, `Klar.LeaveGuard`, `Klar.Overlay`, `Klar.Form`, `Klar.Validate`, `Klar.TextInput`, `Klar.Radio`, `Klar.DescriptionList`, `Klar.Card`, `Klar.PageHeader`, `Klar.Layout`, `Klar.Button`, `Klar.Toast`, `Klar.Remote`.

The pattern:

1. A `Route` and a `Step` type of your own; the address is `#/order/<step>`. A step the user has not reached is `Stepper.disabledStep`.
2. `LeaveGuard.Guard Source Target` in the model; the draft reports with `LeaveGuard.setDirty OrderDraft (draft /= emptyDraft)`.
3. Every way out of the flow asks first: `LinkClicked` calls `LeaveGuard.request (Go route)`. `Proceed` pushes the address, `Hold` opens the dialog. The dialog is in the overlay list, so the page behind it is inert.
4. "Leave" resets the draft and goes to the held route. "Stay" needs no code.
5. "Next" validates only the current step (`Validate.collect`) and shows the error summary; the submit sets `Form.Submitting`, then `Form.Failed problem` (with a retry button) or a toast and the done route.

What it cannot do: stop the browser's Back button or closing the tab (see the `KLAR GAP` comments).
