# Library requests

Things Klar lacked or got wrong while building the twelve benchmark tasks. Each has a `-- KLAR GAP:` comment in the source (where the code is mine) and a section in `LOG.md`.

## Missing

1. **T01, `Table` / `ServerList.viewTable`**: the footer range reads "1–25 of 200"; it cannot be worded "1 to 25 of N" (`Pagination.summary` is not reachable from `Table`).
2. **T05, `Form` with steps**: the application draws each step body; Elm reuses the focused `input` of one step for the field at the same place of the next, and `Form`'s focus move then blurs it and shows "Required" on a field nobody touched. The application has to key the body (`Html.Keyed`). Either offer the keyed step body (`Form.stepBody v step html`) or say so in `Form.md` / `Spec.md`. Also: `Form.stepper` has no addresses; to make steps routes the application follows `Form.currentStep` itself.
3. **T06, `CommandPalette`**: an item cannot name the words that call it ("go to order"); the application strips them from the query before it asks the backend. Picking an item gives no focus back (only Escape does).
4. **T07, `Table`**: with tens of thousands of matching rows a page change or a keystroke costs 150 to 400 ms in my measurement (the documentation says under 100 ms); the footers sum the whole matching set on every message. A cached filtered set, or footers on demand, is missing.
5. **T09, storage**: nothing in Klar stores anything across a reload (and no JavaScript is allowed). The saved views are kept as JSON text in the address (`#views=`). There is also no encoder or decoder for `SavedViews.SavedView` / `Table.Query`.
6. **T11, `Tree`**: it searches only the nodes it has, so a lazy tree needs the application to load every branch for the filter; the match count is a hidden status line only.
7. **T10, `Timeline`**: at the end of the list the "Load more" button stays (dimmed) where the brief says it is gone; the day headings are `h3`, so a page needs an `h2` above them for axe `heading-order`.

## Wrong (reported by axe in the states the tasks name)

8. **T06, `CommandPalette.remote`**: in the loading, failed and "no results" states the `role="listbox"` contains a `role="alert"` and no option: axe `aria-required-children` on `#palette-list`.
9. **T11, `Tree`**: the "Try again" link of a failed branch is 75 x 19 px: axe `target-size` (wcag22aa).
10. **T02, T09 (seen twice)**: right after a toast, or the delete confirmation of a saved view, appears, axe reports `color-contrast` once (the entry animation); a second run is clean.
11. **T09, `SavedViews`**: the list is `role="dialog"` with buttons, not a menu.

## Documentation

12. **`LeaveGuard.md`**: two paragraphs "The browser's own buttons"; the second still describes the `Nav.forward 1` recipe that the first says loops forever.
13. **`AI.md` / `USING.md`**: for an application that has an `AppShell` and a `LeaveGuard`, both want `onUrlChange`; nothing says how to combine them (I used the guard for the page and `AppShell.update` for its own messages only).
14. **Retry buttons lose focus** in `Stat`, `Chart`, `Timeline`, `Tree` (not only `RemoteView` and `ErrorState`, which `AI.md` names): each needs a body id and `RemoteView.focus` or `Tree.focusNode`. T03 and T11 had to do it.
