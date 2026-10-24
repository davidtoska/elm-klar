# Design notes

Decision records for the larger pieces of Klar: the problem, the designs that were weighed, what
was chosen and why. Every design here is built. They are history, not guidance: names in them may
be older than the code, and the current API is the module documentation (`ai/modules/*.md`, made
from the doc comments in `src/`).

| Note | Built as |
|---|---|
| [FORM-MODEL.md](FORM-MODEL.md) | `Klar.Form`, `Klar.Form.Spec`, `Klar.Form.Check`, `Klar.Form.Layout`, `Klar.Ids` (sections 1 to 9 use the old names; section 10 and 11 are what was built) |
| [FORM-MODEL-ERRORS.md](FORM-MODEL-ERRORS.md) | What the compiler says for common mistakes with the form model (`form-model-errors/`, `node design/form-model-errors/run.mjs`). The doc of `Klar.Form.Spec` links it by URL: do not move it |
| [ROWS-EXTRAS.md](ROWS-EXTRAS.md) | Rows of a form that hold a rule builder (`Spec.conditions`, `Form.ruleBuilder`) |
| [SERVER-LIST.md](SERVER-LIST.md) | `Klar.ServerList` |
| [SETTINGS.md](SETTINGS.md) | `Klar.Settings` (density and time zone; the themes came later) |
| [STALE-DATA.md](STALE-DATA.md) | `Remote.Kept`, `Remote.refresh`, `Remote.refreshWith`, `Klar.RemoteView`, `Alert.stale` |
| [form-model-proof/](form-model-proof/README.md) | The onboarding flow rewritten on the form model, frozen at the branch `t-form` |
