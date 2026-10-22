# The Klar icon library

500 line icons, all in one style, all plain Elm. Part of the package
`davidtoska/elm-klar`; modules `Klar.Icon` and `Klar.Icon.*`.

```elm
import Klar.Icon as Icon
import Klar.Icon.Logistics as Logistics

Icon.view Icon.search                      -- decorative, 16px
Icon.sized Icon.Large Logistics.forklift   -- a size: 12, 14, 16, 20, 24 or 32px
Icon.labelled "Delete" Icon.trash          -- an icon that stands alone: gets a name

Button.view [ Button.icon Logistics.truckElectric ] "Ship"   -- anywhere a component takes an icon
```

## One family

Every icon is drawn on a 24 by 24 grid with a 2 pixel stroke, round ends and round
corners, and no fill. The icon takes the color of the text around it, so it follows
hover, disabled and danger states without extra work. The built-in icons come from
two sets that are drawn this way, [Feather](https://feathericons.com) and
[Lucide](https://lucide.dev) (see `THIRD-PARTY-NOTICES.md`), so the old and the new
ones sit well next to each other.

## Elm code, and nothing else

An icon is an Elm value:

```elm
forklift : Icon
forklift =
    Icon.fromSvg "forklift" "<path d='M12 12H5a2 2 0 0 0-2 2v5'/>..."
```

It carries its own SVG and sets it as a CSS mask on its element. There is no icon
font, no sprite and no per-icon CSS rule. The consequence is the point of the design:
**`elm make --optimize` leaves out every icon your application does not use.** An
application that shows ten icons carries ten drawings, however large the library is.
(The one exception is `Klar.Icon.Library`, which refers to every icon and so puts all
of them in your program; it is for galleries and pickers.)

## The modules

| Module | What is in it |
| --- | --- |
| `Klar.Icon` | The everyday icons (186): arrows, chevrons, status, files, people, text, actions. The ones the components use. Also `Icon`, `Size`, `view`, `sized`, `labelled`, `fromSvg`, `custom`. |
| `Klar.Icon.Arrows` | Arrows and movement |
| `Klar.Icon.Business` | Business and finance |
| `Klar.Icon.Calendar` | Calendar and time |
| `Klar.Icon.Communication` | Mail, messages, phone |
| `Klar.Icon.Data` | Data and charts: databases, chart types, tables, formulas |
| `Klar.Icon.Developer` | Developer tools: git, bugs, containers, code |
| `Klar.Icon.Devices` | Devices and hardware |
| `Klar.Icon.Documents` | Files, folders, books, notes, clipboards |
| `Klar.Icon.Editor` | Text editing: headings, lists, case, tables |
| `Klar.Icon.Interface` | Panels, layouts, controls, pointers |
| `Klar.Icon.Logistics` | Transport, parcels, maps and places |
| `Klar.Icon.Media` | Media and sound |
| `Klar.Icon.Nature` | Weather, plants and animals |
| `Klar.Icon.People` | People, faces, accessibility |
| `Klar.Icon.Science` | Science, health and everyday objects |
| `Klar.Icon.Library` | Every icon in one list: `all`, `groups`, `count`. For galleries. |

Names follow Lucide, in camel case: `chevron-down` is `Icon.chevronDown`, and
`package-search` is `Logistics.packageSearch`. The documentation of each icon lists a
few other words people search for. The showcase (`npm start`, page *Foundations*)
shows all of them with a search box.

## Your own icons

```elm
invoice : Icon
invoice =
    Icon.fromSvg "invoice"
        "<path d='M5 3h14v18l-2.5-2-2.5 2-2.5-2-2.5 2-2.5-2-1.5 2z'/><line x1='9' y1='8' x2='15' y2='8'/>"
```

Draw on a 24 by 24 grid, with strokes only (the stroke width and the round ends are
set for you, so your icon fits in), and use single quotes inside the markup.
`Icon.custom "name"` is the other way: the drawing is then a CSS rule in your own
stylesheet.

## Adding an icon to the library

The modules under `src/Klar/Icon/` are generated; do not edit them.

1. Find the icon at [lucide.dev](https://lucide.dev/icons) and add its name to a group
   in `scripts/icons-spec.mjs`. Names after a group's `limit` are a reserve (about 320
   are ready to be taken in: raise the limit).
2. Download the icon data and run the generator:

   ```bash
   mkdir lucide && cd lucide && npm pack lucide-static && tar xzf lucide-static-*.tgz
   cd .. && node scripts/generate-icons.mjs lucide/package
   npm run format
   npm run check
   ```

3. `npm run check:icons` checks every icon: a unique kebab-case name, only the shapes
   `path`, `circle`, `rect`, `line`, `polyline`, `polygon` and `ellipse`, no characters that
   break a CSS `url()`, and that `Klar.Icon.Library` lists every module.

An icon for `Klar.Icon` itself (the everyday set) is written by hand in
`src/Klar/Icon.elm`, with `Icon.fromSvg`, and listed in `all` and in the module
documentation. Add icons there only when a component needs them.

## What it costs

A drawing is 100 to 500 bytes. The stylesheet no longer carries any icon: it shrank
by about 65 KB when the 186 icons that were CSS rules became Elm values. In the DOM, an
icon is a `span` with a `style` attribute holding its drawing, which is more than a
class name; for a table with thousands of icons, test it with your data. Strict
content security policies need `style-src 'unsafe-inline'` (or a nonce), as
`Klar.stylesheet` itself already does.
