# A0 evaluation

Three applications were built with Klar by an AI from the documentation alone
([PLAN.md](PLAN.md)). This is the evaluation of the three logs
([FRICTION.md](FRICTION.md) F-001 to F-020, [stock/FRICTION.md](stock/FRICTION.md) S-001 to
S-023, [onboarding/FRICTION.md](onboarding/FRICTION.md) O-001 to O-022: 65 rows) and the three
`RESULT.md` files.

## What the numbers say

| | Fulfilment | Stock | Onboarding |
|---|---|---|---|
| All 7 tasks working | yes | yes | yes |
| Friction rows | 20 | 23 | 22 |
| Compile errors caused by Klar's API | 9 sites in 3 builds (name clash, missing `elm/url`) | 8 sites in 1 build (name clash) | 2 (missing `elm/url`, a slip) |
| Wrong type / wrong argument order | 0 | 0 | 0 |
| `KLAR GAP` code | about 190 lines, plus 200 lines of boilerplate | about 150 lines | about 270 lines (9 % of the application) |
| Unexposed module or internal needed | 0 | 0 | 0 |
| `class` / `style` / CSS in the application | 0 | 0 | 0 |
| Behaviour wrong after it compiled | 6 | 10 | 8 |
| axe violations left | 3 (with drawer + confirm open) | 0 | 2 rules (heading order, target size) |
| Time | about 25 min | about 2.5 h | about 4 h |

## Verdict

**What is right, and should be protected:**

- The types work. Three applications of 3 000 to 3 800 lines compiled with no type error
  at the first full build. Nobody made a wrong-argument-order mistake. The principle
  "impossible to misuse" holds for what the compiler can see.
- Nobody needed an unexposed module, a class name or a line of CSS. Principle 11 is real.
- `Remote` is the best idea in the library: skeleton, failure with kind-aware text, retry
  and empty came from the same value in `Table`, `Stat`, `Chart`, `Timeline`, `Tree` and
  `Select`. All three builders praise it.
- The typed ids (`Tree.nodeIds`, `Table.rowIds`, `Select.State id`) worked on the first try.
- Reading the documentation as signatures first (Onboarding turned `docs.json` into a
  signature index) caught the wrong examples before compiling. That is the A1 approach, and
  it already works.

**What is wrong:**

- **The compiler cannot see behaviour.** Almost every bug was found in the browser: focus
  falling to `body`, a toast the keyboard cannot reach, a button covered by a toast, a
  popup cut off. The types are good; the behaviour layer is not yet as safe as the types.
- **Klar hides the small things and leaves the big things.** The component-level
  complexity (popups, ARIA, keyboards) is hidden. What is left to the application is the
  glue between components, and it is large and the same in every application: about 90 to
  140 lines for a server-mode list, 45 for a search-as-you-type section, 25 for a clock,
  300 for form state, dirty tracking and server problems. This is where "little code
  outside" is not yet true.
- **The ids principle breaks in four places** (Rule choices, Radio, Validate, DOM ids).
- **Performance is not data-dense yet.** 50 000 rows cost a second per click in `Table`.

**Caveats on the experiment:** the builders are the same model as the author of this
plan, so what is easy for them may not be for another reader. Fulfilment saw a screenshot
of the showcase by accident (declared, not used). Times are rough. Only Chromium.

## Friction, grouped (by how many applications hit it, then cost)

### Seen in all three

| # | Problem | Rows | Fix |
|---|---|---|---|
| 1 | Doc examples do not compile: `Table.text "customer"` (string column id) and `SideNav.item` without `Keys` | F-001, F-002, S-001, O-006, O-007 | Fix the examples; compile every example in `check:docs` (A1) |
| 2 | An application needs `elm/url` and a mounting recipe, nothing says so | F-003, S-006, O-008 | `USING.md` start recipe: `Browser.application`, dependencies, `index.html`, `AppShell`; part of the application template |
| 3 | There is no "which component for what" and no recipes for the common flows | S-003, O-005, O-003, F-016, F-015 | `AI.md`, `klar-index.json`, recipes (A1): server-mode inbox, unsaved changes, multi-step form, dashboard, search section |

### Seen in two

| # | Problem | Rows | Fix |
|---|---|---|---|
| 4 | `Success` is a constructor of both `Theme.Tone` and `Remote` (17 compile errors) | F-004, S-005 | Rename one. Cheapest, surest fix in the whole log |
| 5 | Overlays do not own focus: focus lost when the focused control is replaced, `modalOpen` assembled by hand, toast unreachable inside a trap, toast covers the dialog footer, duplicate landmarks | F-005, F-006, F-010, F-013, F-020, O-011 | One overlay layer that owns focus, derives `modalOpen`, and places the toast region inside the trap |
| 6 | Containers do not know `Remote` (Drawer, Modal, Card) and nothing knows "stale" | F-012, S-013 | `Remote`-aware containers; a stale state (`Remote` that can say "old data, refresh failed") |
| 7 | Layout cannot size things: no fill-the-rest, no fixed width, `minColumn` leaves empty columns, sidebar width | F-017, S-004, S-011, S-017 | `Layout.fillRest`, `Layout.width`, `auto-fit`, `AppShell` sidebar width |
| 8 | Accessibility bugs found by axe | F-020, S-012, O-015, O-016 | Fix, and run axe on every showcase page in `npm run check` |
| 9 | The help for keys that components handle themselves is missing | F-007, S-014 | `ShortcutHelp` lists component keys; `VirtualList` gets a keyboard model |

### Seen in one, but large

| # | Problem | Rows | Fix |
|---|---|---|---|
| 10 | **A form's values live in ten component states.** Dirty detection, loading a record, a draft, server problems tied to fields, steps, and the stepper status are all written by the application (270 lines, 9 %) | O-003, O-018, O-019, O-022, O-001 | A form model: one `Form.State` that owns every field's value, knows when it is dirty, takes a record in and gives one out, takes server problems per field, and knows steps. The largest design item |
| 11 | **Ids are strings in four places**: `Rule.Choice`, `Radio`, `Validate`, and DOM ids | O-002, O-004, O-010, O-001, O-021 | Generic `Rule` choices over `Select.Option`, generic `Radio`, validators over any value; derive DOM ids from the state instead of asking for them |
| 12 | **`Table` is too slow at 50 000 rows** (1 s per click) and cannot scroll virtually; `Search` takes 750 ms | S-008, S-009, S-010, S-019 | Cache the sorted and filtered index; virtual rows; pre-filter in `Search`; one row type for Table and VirtualList |
| 13 | **`VirtualList` row contract**: the application must know the row height, and there is no keyboard model | S-002, S-007, S-014 | `VirtualList` owns its row (height from the density), roving tabindex and arrow keys |
| 14 | **Server-mode list glue** | F-016, F-015 | One helper that does "compare, reset the page, ticket the answer, debounce" (a `Query` state), used by `Table`, `FilterBar`, `SavedViews` and the palette section |
| 15 | **Density only reaches `Table`**; every other component spells it differently | S-022 | One `Theme.Density` on `AppShell` that all components follow |

### Small, cheap, certain

`Date.toPosix` (F-014), `Format.iso8601` (S-020), `Stat.change` for a zero base (S-018),
`Text` block against inline naming (O-020), `Select` popup width (O-013), `Form.actions`
wrapping (O-012), `InlineEdit` retry for non-retryable failures (O-014), `RuleBuilder`
wording for an empty rule (O-009), `SavedViews.askToSave` and sharing (F-008), `Tree`
clearing (S-015), chart palette slots against tones (S-016), footer sum width (F-009),
`ConfirmDialog` failure clearing (F-011), `Shortcut` and `?` (F-019), a clock helper for
`Timeline` (F-018), responsive columns (S-023), `Form.section` heading level (O-015),
`Table` header and clock plumbing.

## What this changes in the roadmap

1. **Phase A gets a new part, A8, "Fixes from the real applications"**, ahead of the
   documentation work: the sure fixes (1, 2, 4, small items), then the design items in this
   order of value: 10 (form model), 5 (overlay layer), 12 and 13 (data-dense performance),
   14 (server-mode helper), 6 (stale and `Remote` containers), 11 (ids), 7 and 15.
2. **Phase C ("table family") waits** until item 12 is done: building `Grid` and
   `TreeTable` on a core that cannot do 50 000 rows would repeat the problem.
3. **Phase B (Sortable and so on) waits** until A8 is done. The log shows that what hurts
   is the glue between existing components, not a lack of new ones.
4. The AI benchmark (A3) gets its baseline from these three runs: compile errors,
   iterations, `KLAR GAP` lines, behaviour bugs. They may not get worse.
5. The admission test gets one more question: *does it need glue code that every
   application will repeat?*

## Next steps

1. Fix item 4 (`Success`) and the doc examples (item 1). Same day.
2. Write the mounting recipe and the template (item 2).
3. Design the form model (item 10) on paper with the Onboarding application as the test.
4. Decide the overlay layer (item 5) and the performance work (item 12) as separate pieces.
5. Rebuild the three applications after each group of fixes and compare the numbers.
