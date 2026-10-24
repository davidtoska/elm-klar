# Klar.Search

Text matching for search fields, selects and command palettes: forgiving about case and accents, and ranked, so the best match comes first.

Import: `import Klar.Search as Search` | Group: Data and utilities

Types: `Query`, `Prepared`

## Signatures

```elm
-- Searching a list
filter : (a -> String) -> String -> List a -> List a
filterBy : List (a -> String) -> String -> List a -> List a
rank : (a -> String) -> String -> List a -> List ( Int, a )

-- Scoring one text
score : String -> String -> Maybe Int
matches : String -> String -> Bool
highlight : String -> String -> List (Html msg)

-- Preparing texts and queries
type Prepared  -- opaque: no constructors are exposed
type Query  -- opaque: no constructors are exposed
prepare : String -> Prepared
prepareMany : List String -> List Prepared
query : String -> Query
scorePrepared : Query -> Prepared -> Maybe Int

-- Normalizing
normalize : String -> String
```

## Documentation

Text matching for search fields, selects and command palettes: forgiving
about case and accents, and ranked, so the best match comes first.

Use when: a search field, a select or a list needs forgiving, ranked text matching.
Do not use when: the match must be exact, such as an id (compare the strings yourself).

Matching ignores case and diacritics (`ø` matches `o`, `é` matches `e`), and
treats a query as several words that must all match somewhere:
`"ada london"` finds "Ada Lovelace, London".

    import Klar.Search as Search

    Search.score "ada" "Ada Lovelace" -- Just 1  (lower is better)

    Search.score "xyz" "Ada Lovelace" -- Nothing

    Search.filter .name "ada" customers -- matching items, best first

    Search.filterBy [ .name, .city ] "ada london" customers -- over several texts, the name first

    Search.highlight "ada" "Ada Lovelace" -- the text, with <mark> around "Ada"

A smaller score is a better match:

  - `0` the text is the query
  - `1` the text starts with the query
  - `2` a word in the text starts with the query
  - `3` the query is somewhere inside the text
  - `6` the letters of the query appear in order and close together, within about
    twice their number: letters left out are forgiven ("brgn" finds "Bergen"), a
    wrong or swapped letter is not. Only for words of three letters or more.

Sort by the score and keep the order of equal scores (`filter` and `rank` do); do not
rely on the numbers themselves, which a later version may spread out to fit a tier
between them.

For long lists this is fast because the texts are normalized in one go (`filter` and
`rank` do that for you). If you search the same texts again and again, prepare them
once and keep the result:

    prepared =
        Search.prepareMany (List.map .name customers)

    q =
        Search.query "ada"

    List.map (Search.scorePrepared q) prepared

## Searching a list

### `filter`

```elm
filter : (a -> String) -> String -> List a -> List a
```

Keeps the items that match, best matches first. Items with equal scores
keep their original order. A query that is empty or only spaces returns the
list unchanged.

    Search.filter identity "ber" [ "Åsberg", "Oslo", "Bergen" ] -- [ "Bergen", "Åsberg" ]

### `filterBy`

```elm
filterBy : List (a -> String) -> String -> List a -> List a
```

Like `filter`, over several texts of each item: the first is the main one (a name),
the others count less (a city, a description, keywords). Every word of the query is
scored against each text and takes the best; a word found only in a later text scores
3 more, so a name that starts with the word comes before a city that does. All words
must match, each in any of the texts: `"fjord oslo"` finds the customer "Fjord Foods"
in Oslo. With no texts nothing matches.

    Search.filterBy [ .name, .city ] "acme" customers

### `rank`

```elm
rank : (a -> String) -> String -> List a -> List ( Int, a )
```

Like `filter`, but keeps the scores: `( score, item )`, best first.

## Scoring one text

### `score`

```elm
score : String -> String -> Maybe Int
```

How well `text` matches `queryText`: `Nothing` if it does not, otherwise a
score where lower is better (see the list at the top of this page). An empty
query matches everything with 0. With several words in the query the scores of
the words are added, and every word has to match.

    Search.score "ada" "Ada Lovelace" -- Just 1

    Search.score "lovelace" "Ada Lovelace" -- Just 2

    Search.score "ada lovelace" "Ada Lovelace" -- Just 3

    Search.score "lvlc" "Ada Lovelace" -- Just 6

### `matches`

```elm
matches : String -> String -> Bool
```

Whether the text matches the query at all.

    Search.matches "ber" "Bergen" -- True

### `highlight`

```elm
highlight : String -> String -> List (Html msg)
```

Splits `text` into plain parts and highlighted parts (`<mark>` elements), to
show why a result matched: for each word of the query, the place that `score`
used. That is the start of the text, else the start of a word ("ber" marks
"Bergen" in "Åsberg Bergen", not the "berg" inside "Åsberg"), else the first place
inside the text; for a match of letters in order, each of those letters. Matching
is done on the normalized text, so `"orsted"` highlights "Ørsted". The parts put
together are always the whole text.

    Search.highlight "ber" "Bergen" -- "Ber" in a <mark>, then "gen"

    Search.highlight "lvlc" "Ada Lovelace" -- the L, v, l and c each in a <mark>

## Preparing texts and queries

### `Prepared`

```elm
type Prepared  -- opaque: no constructors are exposed
```

A text prepared for matching with `scorePrepared`. Make one with `prepare`
or `prepareMany` and keep it as long as the text does not change.

### `Query`

```elm
type Query  -- opaque: no constructors are exposed
```

A query, split into words once. Make one with `query`.

### `prepare`

```elm
prepare : String -> Prepared
```

Prepares one text for matching.

### `prepareMany`

```elm
prepareMany : List String -> List Prepared
```

Prepares many texts at once. All texts are joined, normalized in one go
and split again, which is much faster than normalizing thousands of short
strings one by one. The result has one entry for every text, in the same order.

### `query`

```elm
query : String -> Query
```

Splits what the user typed into words, to be scored against many texts. An
empty query has no words and matches every text.

### `scorePrepared`

```elm
scorePrepared : Query -> Prepared -> Maybe Int
```

Like `score`, for a query and a text that are prepared already.

## Normalizing

### `normalize`

```elm
normalize : String -> String
```

Lowercases a text and strips diacritics: `"Ørsted"` becomes `"orsted"`, `"Škoda"`
becomes `"skoda"` and `"Łódź"` becomes `"lodz"`. The letters of the Latin-1 and Latin
Extended-A blocks are covered; Norwegian "æ" becomes "a" and "ø" "o". The result
has as many characters as the input, so a match position in the normalized text is
the same position in the original. Useful for sorting and comparing texts the way
the search does.
