# Klar.CodeBlock

Read-only source code with lexical highlighting, line numbers and an honest preview limit; source is always escaped text and is never executed.

Import: `import Klar.CodeBlock as CodeBlock` | Group: Text and change

Types: `Language`, `Attribute`

## Signatures

```elm
view : List Attribute -> { id : String, label : String, source : String } -> Html msg

-- Languages
type Language  -- opaque: no constructors are exposed
plain : Language
json : Language
elm : Language

-- Attributes
type Attribute  -- opaque: no constructors are exposed
language : Language -> Attribute
lineNumbers : Bool -> Attribute
highlightLines : List Int -> Attribute
maxLines : Int -> Attribute
maxHeight : Int -> Attribute
download : String -> Attribute
locale : Locale.Locale -> Attribute
```

## Documentation

Read-only source code with lexical highlighting, line numbers and an honest
preview limit; source is always escaped text and is never executed.

Use when: a person must inspect a payload, query, configuration or generated code.
Do not use when: the text must be edited, use `Klar.TextArea` or `Klar.MarkdownEditor`.

    import Klar.CodeBlock as CodeBlock

    CodeBlock.view
        [ CodeBlock.language CodeBlock.json
        , CodeBlock.lineNumbers True
        , CodeBlock.highlightLines [ 2 ]
        , CodeBlock.download "order.json"
        ]
        { id = "order-payload", label = "Order payload", source = "{\n  \"quantity\": 12\n}" }

The named scroll region is a keyboard stop. Lines do not wrap, so indentation and
long values remain exact. The line-number gutter cannot be selected and is hidden
from screen readers. The code itself preserves every character, including tabs,
CRLF and a final newline; no trimming, parsing or formatting is applied.

`json` and `elm` are lexical guides, not validators. Unfinished strings and Elm's
nested comments remain visible. Highlighting is bounded to 30,000 characters of
the visible source; beyond that the source is plain text in full. A preview limit
is always accompanied by its visible and total line counts, while `download`
always contains the complete original source. There is no clipboard action: select
the source and use the browser's native copy command.

Without marked lines, large plain sources use a single source text node. Marking
lines requires one span per visible line; use `maxLines` for very large marked
documents. Rendering is otherwise unrestricted and the complete text is retained.

This component receives local text. For backend data put it inside `Klar.RemoteView`.

### `view`

```elm
view : List Attribute -> { id : String, label : String, source : String } -> Html msg
```

Draws exact local source. `id` must be unique on the page; `label` names the
keyboard-accessible scroll region and its download action.

## Languages

### `Language`

```elm
type Language  -- opaque: no constructors are exposed
```

An opaque lexical-highlighting mode. The default is `plain`.

### `plain`

```elm
plain : Language
```

Plain, uncoloured source. No syntax is assumed.

### `json`

```elm
json : Language
```

JSON strings, numbers and literal words. This does not validate JSON.

### `elm`

```elm
elm : Language
```

Elm keywords, strings, character literals and nested comments. Not a parser.

## Attributes

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

Optional source-view settings; later attributes win.

### `language`

```elm
language : Language -> Attribute
```

Lexical highlighting. Defaults to `plain`.

### `lineNumbers`

```elm
lineNumbers : Bool -> Attribute
```

Shows an unselectable gutter. Defaults to `False`.

### `highlightLines`

```elm
highlightLines : List Int -> Attribute
```

One-based lines to mark, with an underline as well as a background.
Nonpositive and nonexistent lines have no effect. No lines are marked by default.

### `maxLines`

```elm
maxLines : Int -> Attribute
```

Limits the preview to this many lines; zero or negative values show no source
lines. The footer always discloses truncation. Unrestricted by default.

### `maxHeight`

```elm
maxHeight : Int -> Attribute
```

Maximum scroll-region height in pixels, at least 80. Unrestricted by default.

### `download`

```elm
download : String -> Attribute
```

Adds a native download link for the complete source with this suggested file
name. The browser may sanitize the name. No download link by default.

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

Built-in text language. Defaults to English.
