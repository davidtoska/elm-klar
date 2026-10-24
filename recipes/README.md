# Recipes

Complete programs for the screens that every Klar application has. Each folder is a working
application: `elm.json` (it reads Klar from `../../src`), `src/Main.elm`, and a `README.md` with
the task in one sentence, the Klar modules it uses and the pattern in a few lines. Every recipe
is compiled with `--optimize` by `npm run check:recipes`, so none of them is stale.

| I need | Recipe | Shows |
|---|---|---|
| A list that lives on the server, with search, sort, paging, filters and saved views | [inbox](inbox/README.md) | `ServerList`: one state for the server-mode `Table`, the `FilterBar` and `SavedViews`; it compares, resets the page and drops old answers; `ServerList.target` for bulk actions |
| An edit form with validation and a save that can fail | [edit-form](edit-form/README.md) | `Klar.Form` with `Klar.Form.Spec` and `Klar.Form.Layout`, server problems per field, dirty state, retry with focus, toast |
| A confirmation before delete, with a toast and the focus right | [confirm-delete](confirm-delete/README.md) | `ConfirmDialog` (busy, failed, retry), `Toast` with Undo, the overlay list, bulk delete |
| A dashboard where every panel loads and fails on its own | [dashboard](dashboard/README.md) | `Remote` in `Stat`, `Chart`, `Tree`, `Timeline`, a period picker, stale answers dropped |
| A multi-step flow that asks before it is left | [multi-step](multi-step/README.md) | `Stepper`, `LeaveGuard`, one route per step, a review step, a submit that can fail |
| A command palette with a search-as-you-type section | [command-palette](command-palette/README.md) | `CommandPalette.remote`, the ticket counter, debounce, retry |

The starting point for a new application is [../template](../template/README.md).

## Rules the recipes follow

- Only exposed `Klar.*` modules; no `class`, no `style`, no CSS; `Klar.stylesheet` once.
- A backend is a small dummy function in Elm (`Process.sleep`, then data or a `Remote.Problem`),
  so replacing it with `Http` changes one function.
- Where Klar lacked something, the recipe shows the best honest version and a comment
  `-- KLAR GAP: ...` says what is missing. `npm run check:recipes` lists them.

## Copying a recipe

Copy the folder, and either keep `../../src` in `source-directories` (inside the Klar
repository), or point it at where Klar lives in your project (see [USING.md](../USING.md),
section 1). `elm/url` must stay a direct dependency.
