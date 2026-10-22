# Proof: the supplier onboarding flow on the finished form model

`Flow.elm` is `apps/round2/onboarding/src/Flow.elm` rewritten on `Klar.Form`,
`Klar.Form.Spec` and `Klar.Ids` (branch `t-form`). It is not compiled by `npm run check`:
it is the evidence for section 10 of [../FORM-MODEL.md](../FORM-MODEL.md).

The rest of the application is the round 2 application, unchanged but for two lines:
`Domain.elm` writes its id types with `Klar.Ids` instead of `Fm.ids`, and `Main.elm` focuses
the first field with `Flow.firstFocus` instead of the hand-typed id `"company-name"`.

To build it, copy `apps/round2/onboarding` to a scratch folder, replace `src/Flow.elm`
with this file, make the two changes above, point `source-directories` of its `elm.json`
at this repository's `src`, and run `elm make src/Main.elm --output=main.js`.

The `KLAR GAP` markers in the file delimit the code that is still the application's because
the price rules are an editor of its own (`custom` is not part of the form model).
