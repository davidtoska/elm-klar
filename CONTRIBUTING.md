# Working on Klar

Klar is a UI toolkit for data-intensive applications, written in plain Elm and
plain CSS. This file is for people who change the library. If you only want to
use it, read the [README](README.md).

Design language: **calm, precise, dense**. Gray, white and blue, thin 1px lines,
small radii (2-5px), the system font at 13px, tabular numbers, muted status
colors. Nothing decorative.

## Layout of the repository

```
elm.json                 the package (exposed modules, dependencies, version)
src/Klar.elm             the entry point: stylesheet, conventions, module index
src/Klar/*.elm           one module per component (Klar.Button, Klar.Select, Klar.Table ...)
src/Klar/<Name>/         modules that belong to one component and are not exposed
src/Klar/Icon/           the icon library: one generated module per theme (see ICONS.md)
src/Klar/Internal/       the generated stylesheet module (do not edit)
css/src/*.css            the stylesheet sources (tokens, base, the icon frame, one file per group)
css/klar.css             the generated bundle (do not edit, see "Stylesheet")
scripts/                 development tools (Node, no dependencies)
AI.md, llms.txt          the entry points for an AI that builds an application (AI.md by hand)
ai/                      generated: ai/modules/*.md, ai/klar-index.json, reports (npm run gen:ai-docs)
recipes/                 complete programs for the common screens (each compiled by check:recipes)
template/                a minimal working application
bench/                   the AI benchmark: tasks, how to run it, results
tests/                   unit tests of the pure logic (elm-test)
example/                 the showcase application (its own elm.json)
```

## Commands

```bash
npm install              # elm, elm-test and elm-format, pinned; nothing else
npm run build:css        # css/src/*.css -> css/klar.css + src/Klar/Internal/Css.elm
npm run check            # everything below
npm run check:text       # UTF-8, LF line endings, no byte order mark (npm run format repairs them)
npm run check:css        # the generated stylesheet files are up to date
npm run check:classes    # every CSS class the Elm code uses has a rule
npm run check:icons      # every icon is an Elm value with a valid drawing and a unique name
npm run check:docs       # every exposed name is documented; elm make --docs passes
npm run check:api        # no public signature mentions a type a user cannot name
npm run gen:ai-docs      # docs.json -> ai/modules/*.md, ai/klar-index.json, llms.txt (commit the result)
npm run check:ai-docs    # those files are up to date; AI.md is under 400 lines, names every module, and its program compiles
npm run check:ai-names   # every Module.name in the AI documents and the doc comments exists; complete programs in them compile
npm run check:recipes    # every recipe and the template compile with --optimize; lists the KLAR GAP comments
npm run check:doc-examples  # compiles the complete code examples of the module docs; writes ai/doc-example-report.md
node scripts/check-doc-examples.mjs --strict   # the same, and fails when one does not compile (this is what check runs)
node scripts/bench-workspace.mjs <dir>         # the folder a benchmark builder gets (bench/run.md)
npm run check:format     # elm-format --validate
npm test                 # elm-test
npm run build:example    # compiles the showcase application (optimized)
npm run check:compat     # Elm 0.19.1 and the oldest allowed dependencies (needs the network; not part of check)
npm start                # builds the showcase and serves it on http://localhost:8000
```

Elm 0.19.3 is the reference compiler. The package declares
`0.19.0 <= v < 0.20.0`, as every package should, and uses no language feature
newer than 0.19.0. It also compiles with Elm 0.19.1 and with the oldest versions of
its dependencies that `elm.json` allows (check both before a release, see
[RELEASING.md](RELEASING.md)).

## The rules

1. **Official packages only**: `elm/core`, `elm/html`, `elm/browser`, `elm/json`,
   `elm/time`, and `elm/url` for `Klar.AppShell` alone (the `Url` of a route change; never
   its `percentEncode`, which throws on half of an emoji: use `Klar.Internal.percentEncode`),
   no `elm/svg`, no `elm/http`, no `elm/file`. No ports, no
   kernel code, no `Debug`. If you think you need JavaScript, you do not: see
   "Tricks" below. (Elm tuples have at most three elements: use records.)
2. **The library never imports from an application.** The `example/` application
   imports only exposed `Klar.*` modules; `npm run check:example-imports` checks it.
3. **CSS uses tokens** (`var(--klar-...)`), never hard-coded colors, radii, spacing or
   z-indexes. Class names are BEM with the `klar-` prefix: `klar-select`,
   `klar-select__option`, `klar-select--open`. State is a modifier class
   (`--open`, `--disabled`, `--invalid`), never a bare `.is-open`.
4. **Every component is keyboard-usable and has sensible ARIA** (role,
   `aria-expanded`, `aria-selected`, `aria-sort`, `aria-live` for async changes,
   `aria-label` on icon-only buttons). ARIA references (`aria-controls`,
   `aria-labelledby`, `aria-describedby`) always name ids that exist.
5. **Every component that shows remote data has every state**: loading, failed (with
   retry), empty, data, and data that is being refreshed or is old because the last
   refresh failed (`Remote.Kept`). Use `Klar.Remote`, `Klar.Skeleton`,
   `Klar.Spinner`, `Klar.EmptyState`, `Klar.ErrorState`, and for the last two states
   `Klar.Internal.Freshness`, so that every component says the same thing in the same way.
6. **Text**: no English or Norwegian text is hard-wired into a component except
   through `Klar.Locale` (see "Locale"). Application text always comes from the
   application.
7. **Never change what the user typed behind their back.** `NumberInput` keeps a
   number outside `min` and `max` (55 does not quietly become 50), shows the
   built-in error and reports `isValid` as `False`. Only an explicit action (the
   steppers, the arrow keys) moves a value into range. New components follow the
   same rule: show the problem, never "fix" it.
8. **Keep the public API small and stable.** An exposed custom type with exposed
   constructors can never get a new constructor without a major version (Elm's
   semantic versioning check treats it as a breaking change). Open-ended sets (icons,
   languages) are values of an opaque type; only small closed vocabularies (`Tone`,
   `Size`, `Remote`, `Direction` ...) are exposed unions. `npm run check:api` lists the
   exposed unions, so a new one is a decision, not an accident. (`Klar.Rule.Operator`
   is the largest: adding an operator is a major release.)

   The exposed unions, and why each is public. Applications match on these (a
   server-side translation of a rule, a message for each file problem), so they
   would lose that with opaque types; each is a vocabulary that is complete, and
   adding to it is a major release on purpose:
   `Rule.Rule`, `Rule.Combinator`, `Rule.Operator`, `Rule.Operands` and
   `Rule.FieldKind` (a rule is data an application translates to its own query),
   `Table.Filter`, `Table.Direction` and `Table.Selection` (the answer a server-mode
   table gives), `Remote.Remote` (the five states of a request: the fifth, `Kept`, has an
   opaque payload that only `Remote.refresh` and `Remote.refreshWith` make), `Form.Layout.Status`,
   `FileDrop.Problem`, `Pagination.Item`, `Calendar.Event` and `Avatar.Status`
   (a result or a state an application reads), and the small design vocabularies
   `Theme.Tone`, `Theme.Size`, `Theme.Density`, `Icon.Size`, `Modal.Side` and
   `TextArea.Resize`. `LeaveGuard.Answer` (`Proceed | Hold`) is the one closed answer a
   guard can give: the application does something different in each case and there is
   nothing else a guard can say. Types whose set is open are opaque: `Locale`, `Icon`,
   `Date`, `Remote.Kind`, `Remote.Problem`, `Table.ColumnId`, `Rule.Field`,
   `Shortcut`, `Shortcut.Keys`. Values that an application keeps and compares
   (`Select` values) are of the application's own type.
9. Code is formatted by `elm-format`; modules have documentation (below).

## API conventions

### Stateless components

`view` takes a list of attributes, like `Html`. Required content is positional.

```elm
Button.view [ Button.primary, Button.icon Icon.save, Button.onClick Save ] "Save"
Badge.view [ Badge.tone Success ] "Active"
Card.view [ Card.title "Activity" ] [ content ]
```

An attribute is an opaque function over a config record:

```elm
type Attribute msg
    = Attribute (Config msg -> Config msg)

configure : List (Attribute msg) -> Config msg
configure attributes =
    List.foldl (\(Attribute change) config -> change config) defaults attributes
```

Components that never emit messages use `Attribute` without a `msg` parameter
(`Badge`). Later attributes win over earlier ones. Name attributes after what they
set (`placeholder`, `onInput`), use bare names for flags (`required`, `clearable`) and
`Bool` arguments where the value usually comes from the model (`disabled`,
`loading`).

### Form controls

Every control accepts the common field attributes `label`, `hint`, `error` (and
`errorMaybe`), `required`, `optionalText`, `labelHidden` and `id`, by embedding
`Field.Config` (see `TextInput.elm`) and wrapping the control with `Field.view`.

### Stateful components

A component with its own UI state (open/closed, query, highlighted row, sort ...)
exposes:

```elm
type State                      -- opaque
init : String -> State          -- the String is a DOM id, unique on the page
type Msg                        -- opaque
update : Msg -> State -> ( State, Cmd Msg )
view : (Msg -> msg) -> List (Attribute msg) -> State -> Html msg
subscriptions : State -> Sub Msg    -- only if truly needed; prefer not to
```

plus accessors (`isOpen`, `value`, `query` ...) and setters (`setValue`, `open`,
`close` ...). The application wires it like any Elm architecture child:

```elm
SelectMsg m ->
    let
        ( s, cmd ) =
            Select.update m model.select
    in
    ( { model | select = s }, Cmd.map SelectMsg cmd )
```

**State holds the value too** for the select family, pickers and tables
(selection, sort, page ...): the application reads it through accessors and
compares before and after to react (`Select.value new /= Select.value old`). There
are no out-messages. Row clicks, row actions and other things that are not state
changes are plain `msg` callbacks given as attributes.

### One implementation, several public modules

When one piece is too big for one page of documentation, split the *documentation*,
not the implementation: the form model is `src/Klar/Form/Core.elm` (not exposed, no
documentation to keep), and `Klar.Form` (using a form), `Klar.Form.Spec` (declaring one)
and `Klar.Form.Check` (testing one) are thin modules that carry the docs. Their types are
aliases of the types in `Core` (`type alias Form step fields values = Core.Form step fields
values`), and their functions are `name = Core.name` with the signature and the comment
written out. `npm run check:api` accepts exactly this shape: an alias whose body is only a
type of an internal module, because the user names the type through the alias.

### Remote data

Components that show data from a backend take it as a `Remote`:
`Table.rows (Remote (List row))`, `Select.remote (Remote (List Option))`. They render
the loading skeleton, the failure state with a retry callback (`onRetry : msg`) and
the empty state themselves.

Data that is already on the screen and is refreshed again is `Remote.refresh`; the
answer, good or bad, is `Remote.refreshWith` with the time it came. The result is
`Kept`: a component settles it once on the way in (`Freshness.settle` turns it back
into `Loaded` and says how fresh it is) and then draws what it always drew, plus:

- **Refreshing**: `aria-busy="true"`, `klar-refreshing` on the content (a thin moving
  line and a slight dimming; muted text must stay at 4.5:1, so do not dim below about
  92 %, and check with axe in that state).
- **Old**: `Freshness.notice`, the calm marker "Old data from 14:05" (`role="status"`, a
  retry button when the problem is retryable and the component has an `onRetry`). A
  component that has no room for a button inside (a clickable tile, a combobox list)
  leaves the retry out or makes the tile a plain block, as `Stat` and `Autocomplete` do.
- A `zone : Time.Zone -> Attribute` to show the time in (default UTC), as `Timeline` has.

Never add an attribute or a flag for "stale" or "refreshing": it comes from the `Remote`.
A body for a card, dialog or drawer is `RemoteView.view`, not a `case` in the page.

### Attributes that set related things

Later attributes win over earlier ones, and that is only safe for attributes that set
the same thing (`label`, `placeholder`). Two attributes that look like different
concerns must never cancel each other through one hidden field:

- State flags only add up. `Chart.loading`, `Stat.loading` and `Timeline.loading` are `busy
  OR flag`, and `failed` and `remote` only add a failure; a later `loading False` cannot
  hide what `remote` set (R2S-005: it used to, and showed "No data" while loading).
- If two attributes do set the same thing (`Select.options` and `Select.remote` both set the
  options), say so in both docs: "the later one wins".
- Test the pair in both orders when you add a component that has such a pair
  (`tests/StaleDataTest.elm`, "attributes that used to cancel each other").

### Locale

Built-in text (placeholders, "Rows per page", aria-labels) lives in the component,
in a small record, picked with `Locale.pick`. Every component with built-in text has
a `locale : Locale -> Attribute msg` (default `Locale.default`, which is `Locale.en`)
and, where it makes sense, an attribute to override single strings. Write both `nb`
and `en`. `Locale` is an opaque type (`Locale.en`, `Locale.nb`), so that a language
can be added in a minor version: never `case` on a locale, choose with `Locale.pick`.

## Popups: the recipe

Dropdowns, menus, date pickers and popovers share one mechanism (`css/src/base.css`):

```html
<div class="klar-anchor">                      <!-- wrapper: trigger + popup, also the CSS anchor -->
  <button ...>trigger</button>
  <div class="klar-layer" onClick=close>       <!-- transparent full-viewport click-away layer -->
    <div class="klar-popup" ...>content</div>  <!-- fixed, anchored below the wrapper, flips when no room -->
  </div>
</div>
```

- `.klar-popup` is `position: fixed` and anchored with CSS anchor positioning, so it
  is never clipped by `overflow` on tables, cards or modal bodies and flips above
  when there is no room. Browsers without anchor positioning get an absolute
  fallback. **Never use percentage widths on a popup** (they resolve against the
  viewport); use `min-width: anchor-size(width)` inside the `@supports (position-anchor: ...)`
  block, as `.klar-menu__popup` does.
- **Closing** needs no subscriptions: a click on the layer closes. A click on
  something *inside* the popup bubbles up to the layer too, so a menu item can send
  its own message and the menu closes in the same event (see `Menu.elm`). Popup
  content that must stay open (a search box, a calendar, checkboxes) is better
  protected by deciding on the layer: decode the click target and ignore clicks that
  started inside the popup (`outsideClick` in `Klar.Table`, `insidePopup` in
  `Klar.Modal` and `Klar.Popover`). `Internal.onClickStop` around form controls is
  risky: stopping the click makes Elm re-render in the middle of it, which can undo a
  checkbox under the pointer.
- Escape and Tab are handled on the layer with `Internal.onKeysPassive`; the popup
  (or its search input) is focused on open with `Internal.focus`, and focus returns
  to the trigger on close.
- Do not put `transform`, `filter` or `will-change` on a component that contains a
  popup: it turns the fixed popup into a box relative to that element. Animate with
  `animation` and no `fill-mode` (the transform is gone when the animation ends).
- Lists inside popups have a fixed row height (`--klar-option-h`) so keyboard
  navigation can use `Internal.ensureVisible`. For thousands of rows, window them
  (`Klar.VirtualList`).

## Tricks you need

- **Custom properties and inline styles**: `Html.Attributes.style` cannot set
  `--vars`. Use `Internal.styleVars [ ( "--klar-w", "120px" ), ( "width", "30%" ) ]`:
  one `style` attribute per element, never mixed with `Html.Attributes.style`.
- **Conditional attributes**: `Internal.attrIf cond attr`, `Internal.attrMaybe f maybe`.
- **preventDefault and a message**: `Html.Events.preventDefaultOn`; `Internal.onKeys`
  does it for keys.
- **Focus**: `Internal.focus id NoOp` (Elm waits one frame, so it works right after
  the element is created in the same update).
- **Download without JavaScript**: `<a href="data:text/csv;charset=utf-8,<percent-encoded>" download="file.csv">`
  (`Url.percentEncode`).
- **Mounted and timers**: `Process.sleep ms |> Task.perform (always Tick)`; compare a
  counter in the message to the model to ignore stale timers.
- **Reading browser measurements** without ports: `Browser.Dom.getElement`,
  `getViewportOf`.
- **Graphics without an SVG package**: do not try `Html.Attributes.property "innerHTML"`.
  Icons are Elm values that carry a `data:` SVG and set it as a CSS mask (`Icon.fromSvg`); charts are positioned HTML
  elements, with lines drawn by an SVG written as a `data:` URI and used as a CSS mask
  (see `Klar.Chart`).
- **Integer math**: Elm's `//` cuts numbers to 32 bits, so do not use it on
  milliseconds or large amounts (`Format` splits big numbers as text and uses `floor`
  on Floats).
- **Links in a `Browser.application`**: every `<a href>` click is reported as
  `UrlRequested`, even with `preventDefault`. Anything that is not a navigation (an
  error-summary link, a skip link) must be a button, or the application must ignore
  fragments it does not own.
- **Page-level keyboard**: use `Klar.Shortcut`; do not add document listeners of your
  own.
- **Overlays are values, not `Html`.** A component that draws on top of the page
  (a dialog, a drawer, a palette, a stack of toasts) returns a `Klar.Overlay.Overlay`
  from its `view`, built with `Overlay.dialog` or `Overlay.toasts`. The page
  (`Overlay.host`, `AppShell.overlays`) takes the list, so it knows by itself whether
  a dialog is open (`inert` page), which is on top, and where the toasts go; an
  application cannot forget one, and no function goes into a `Msg` or a `State`. A
  closed dialog still sits in the list: it listens to the focus on the page (`Seen`)
  so that it can give focus back to an element that still exists, also when
  something else than a click opened it.
- **Lost focus has no event.** When the focused element of a dialog is removed or
  disabled, browsers send nothing. `Modal` puts an invisible `.klar-modal__guard` in
  the dialog on top; the stylesheet runs an animation on it exactly while no
  overlay contains focus (`:root:not(:has(... :focus-within))`), and `animationstart`
  is the message. A new surface that can hold focus (like the palette panel and the
  toasts) has to be added to that selector list in `css/src/overlay.css`.
- **Focus must survive a re-render.** When an element that has focus is replaced or
  moved in the DOM (a control that moves into the `Field` wrapper when its first error
  appears, a keyed child that Elm moves instead of inserting around), the browser drops
  focus to the page. A control that makes messages of its own while the user types uses
  `Field.viewStable`; a list of chips in front of an input lives in its own wrapper
  (`TagInput`); a button that is replaced by "Saving ..." hands focus to a region that
  stays (`Form.focusStatus`). Test with real key presses and look at
  `document.activeElement` afterwards: `BODY` is the bug.
- **Keys right after a list opens.** Focus reaches the search box one frame after
  `Open`, and a fast typist gets keys in between. The trigger of `Select` and
  `MultiSelect` handles those keys itself and works out the effect in `update` from the
  latest state, never from the state the view had when it sent the message.
- **A retry button that goes away takes focus with it.** The stale marker is replaced by
  nothing when the data is fresh again, so focus on its button falls to `BODY` unless
  something takes it: `Table` focuses its own scroll area (a second `click` handler on the
  marker, as for its failure retry); `Modal`, `Drawer` and the palette take focus back
  through their guard; the other components cannot do it without a `Cmd`, and the
  application moves focus in its own `update` when that matters.
- **Notices that appear while the user types** (an "unsaved changes" mark) must not
  interrupt a screen reader (`Alert.polite`) and must not push the form around.
- **A file dropped outside a drop zone** is opened by the browser and replaces the
  application: `AppShell.onStrayDrop` cancels such drops.
- **`<html lang>` cannot change without JavaScript**, so `AppShell` puts `lang` on its
  own root (from `AppShell.locale`). Screen readers use the nearest `lang`.
- Tabular numbers: class `klar-tabular`; ellipsis: `klar-truncate`; screen-reader
  only: `klar-sr-only`.

## Stylesheet

The sources are `css/src/*.css`, imported in order by `css/src/index.css`. Run
`npm run build:css` after changing them. It writes

- `css/klar.css`: the readable bundle, for applications that link a file, and
- `src/Klar/Internal/Css.elm`: the same CSS (comments and blank lines removed) as an Elm
  string, which `Klar.stylesheet` renders. This is what makes the package usable
  without any build step on the application side.

Both are committed. `npm run check:css` fails when they are out of date.

## Documentation

Elm packages are documented by their source. `elm make --docs` (and `elm publish`)
refuse a module unless every exposed name appears in the module documentation in a
`@docs` line, and has a documentation comment. `npm run check:docs` runs the same
check for all modules (or just some: `node scripts/check-docs.mjs Klar.Button`).

**Module documentation** (`{-| ... -}` straight after the `module` line):

1. One sentence that says what the module is for.
2. One or two short paragraphs: when to use it (and when to use its neighbor
   instead), the behavior a reader would otherwise have to discover: keyboard
   support, accessibility, what the state remembers, how remote data and the locale
   are handled.
3. A small, realistic example, indented by four spaces. Show the pieces an
   application needs to write: for a stateful component the model field, the message
   handling and the `view` call.
4. Sections with `# Heading` lines, each followed by `@docs name, name, name`.
   Group by what a reader does: *State*, *Value and popup*, *Options*, *Attributes*,
   *Texts*. Put the `view` first. Lists can be long; keep each `@docs` on one line.

**Every exposed name** has a comment that says what it does for the *user of the
library*, in one to three sentences, and mentions the default when there is one.
Show an example when the use is not obvious. Say what the `String` of an `init` is,
what a `msg` callback receives, what is sent when. Opaque types (`State`, `Msg`,
`Attribute`) get one sentence on how to obtain and use them.

**Examples** use English and a neutral business domain: orders, customers,
products, invoices, shipments, warehouses. No people records beyond names such as
"Ada Lovelace", nothing medical or personal. Keep the examples short enough to read
at a glance and make sure they would compile with the imports shown or implied.

Link to other modules with `[Klar.Button](Klar-Button)`.

### How the AI documents are kept true

The main reader of Klar is an AI that builds an application from `AI.md`, `llms.txt`,
`ai/`, `USING.md`, `recipes/` and `template/`. If two of them disagree, or a name does not
exist, it loses the time it was meant to save. Never edit `ai/` or `llms.txt` by hand: they
are written from the doc comments in `src/` by `npm run gen:ai-docs`. Each script of
`npm run check` catches one kind of lie:

| Script | Catches |
|---|---|
| `check:ai-docs` (`gen-ai-docs.mjs --check`, `check-ai-md.mjs`) | a generated file that is older than the doc comments; `AI.md` at 400 lines or more, a module it does not name, a broken link, its program not compiling; a module without a "Use when" or "Do not use when" line |
| `check:ai-names` (`check-ai-names.mjs`) | a `Module.name` in backticks or a code block, in the hand-written documents and in the doc comments, where the module is not exposed or does not expose that name (`Modal.host`, `Form.focusField`); a name in an `import Klar.X exposing (...)` line that does not exist; a complete program (a fenced block with `module`) that does not compile; the same top-level name declared in two code blocks of `AI.md` or `USING.md` |
| `check-doc-examples.mjs --strict` | a complete example in a doc comment that the compiler rejects |
| `check:recipes` | a recipe or the template that does not compile, imports a module that is not exposed, or uses `class` / `style` |
| `check:api` | a type in a public signature that a user cannot name |

What no script can check, you check when you write: a **claim** (what a component waits for,
how long something takes, what a heading level is) must be read from the code or measured,
with the number in the text; a "Do not use when" line must be a decision that names the
alternative and must not forbid what the module does; and **there is one way to do each
thing**. Where `AI.md` shows how the frame is wired, the template, `USING.md`, the
`AppShell` and `SideNav` docs show the same; an example name that an AI could copy into
the same module as another (`changed`, `model`) is made distinct. When a fix touches an AI
document, run `npm run gen:ai-docs` and then the three checks above.

## Adding a component

1. `src/Klar/<Name>.elm`: module doc with a usage example, opaque `Attribute`/`Config`,
   built-in text through `Locale.pick`, ARIA and keyboard from the start. Stateful?
   Follow "Stateful components". Add it to `exposed-modules` in `elm.json`.
2. Styles in the matching group file under `css/src/` (tokens only, `klar-<name>` BEM),
   then `npm run build:css`.
3. A section on the showcase page of its group in `example/`.
4. Pure logic (parsing, filtering, evaluation) gets tests in `tests/`.
5. `npm run check`, then look at it in a browser: every interaction must work with the
   mouse **and** the keyboard, popups must open in the right place (also near the
   bottom edge and inside a scrolling container), nothing may overflow, the layout
   must hold at 1024px width, and the console must have no errors.

## Releasing

See [RELEASING.md](RELEASING.md).
