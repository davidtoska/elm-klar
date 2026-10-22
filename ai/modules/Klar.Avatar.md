# Klar.Avatar

Avatars: a person, an organization or a system shown as a small badge with initials, a picture or an icon.

Import: `import Klar.Avatar as Avatar` | Group: Data display

Types: `Status`, `Attribute`, `Entry`

## Signatures

```elm
-- Views
view : List Attribute -> String -> Html msg
group : List Attribute -> List Entry -> Html msg

-- Look
type Attribute  -- opaque: no constructors are exposed
type Status = Online | Away | Busy | Offline
size : Theme.Size -> Attribute
extraSmall : Attribute
extraLarge : Attribute
square : Attribute
image : String -> Attribute
icon : Icon.Icon -> Attribute
status : Status -> Attribute

-- Groups
type alias Entry = { name : String, image : Maybe String }
entry : String -> Entry
maxShown : Int -> Attribute

-- Accessibility and text
decorative : Attribute
locale : Locale.Locale -> Attribute

-- Helpers
initials : String -> String
```

## Documentation

Avatars: a person, an organization or a system shown as a small badge with
initials, a picture or an icon.

    import Klar.Avatar as Avatar
    import Klar.Icon as Icon
    import Klar.Theme exposing (Size(..))

    Avatar.view [] "Ada Lovelace"

    Avatar.view [ Avatar.size Large, Avatar.status Avatar.Online ] "Grace Hopper"

    Avatar.view [ Avatar.image "/images/grace.jpg" ] "Grace Hopper"

    Avatar.view [ Avatar.icon Icon.server, Avatar.square ] "Order service"

    Avatar.group [ Avatar.maxShown 4 ] (List.map (\person -> Avatar.member person.name) people)

Without an image the avatar shows the initials of the name on a muted
background. The color is derived from the name, so the same name has the same
color everywhere. An image is laid over the initials, so a broken image URL
still leaves something readable behind it.

For screen readers an avatar is an image labelled with the name, and with the
status if there is one ("Grace Hopper, online"). When the name is written out
right next to the avatar, add `decorative` so that it is not read twice.

`group` shows several avatars side by side, overlapping, and folds the ones that
do not fit into a "+N" bubble. It takes a list of entries, made with `entry` or
written as records with a name and an optional picture. In a group the `image`
and `status` attributes have no effect: every entry brings its own picture, and
an entry has no status (that is for single avatars).

## Views

### `view`

```elm
view : List Attribute -> String -> Html msg
```

One avatar for the given name: its initials, or the picture or icon you give
it. The name is also the tooltip and the accessible name. An avatar with a blank
name and no status has nothing to say, so it is hidden from assistive technology
like a `decorative` one.

    Avatar.view [ Avatar.status Avatar.Away ] "Ada Lovelace"

### `group`

```elm
group : List Attribute -> List Entry -> Html msg
```

Overlapping avatars for a list of entries, with a "+N" bubble for those that
do not fit (see `maxShown`). The tooltip and the accessible name of the bubble
list the names that are hidden, up to 12 of them. The group as a whole has an
accessible name that tells how many avatars it holds, such as "3 avatars". An
empty list shows nothing.

    Avatar.group [ Avatar.maxShown 3 ]
        [ Avatar.member "Ada Lovelace"
        , Avatar.member "Grace Hopper"
        , { name = "Alan Turing", image = Just "/images/alan.jpg" }
        , Avatar.member "Edsger Dijkstra"
        ]

## Look

### `Attribute`

```elm
type Attribute  -- opaque: no constructors are exposed
```

A setting of an avatar. Make them with the functions below and pass a list
to `view` or `group`; later attributes win over earlier ones.

### `Status`

```elm
type Status = Online | Away | Busy | Offline
```

Whether a person or a system is available, shown as a small colored dot in
the corner of the avatar: `Online` (green), `Away` (amber), `Busy` (red) or
`Offline` (gray). Pass it to `status`.

### `size`

```elm
size : Theme.Size -> Attribute
```

The size of the avatar: `Small` is 22px, `Medium` 30px (the default) and
`Large` 40px. For 18px and 64px see `extraSmall` and `extraLarge`.

### `extraSmall`

```elm
extraSmall : Attribute
```

An 18px avatar, for a byline or a dense table cell.

### `extraLarge`

```elm
extraLarge : Attribute
```

A 64px avatar, for profile headers and the top of a page.

### `square`

```elm
square : Attribute
```

A rounded square instead of a circle. Use it for things that are not people,
such as organizations, systems and warehouses.

### `image`

```elm
image : String -> Attribute
```

The URL of a picture, which covers the avatar. The initials stay behind it,
so something readable remains if the picture cannot be loaded. It has no effect
in a `group`, where every entry has its own picture.

### `icon`

```elm
icon : Icon.Icon -> Attribute
```

An icon instead of the initials, for systems, rooms and organizations. Often
combined with `square`. In a `group` it applies to every avatar.

### `status`

```elm
status : Status -> Attribute
```

A small dot in the corner that shows the status. The status is also added to
the accessible name ("Grace Hopper, online"). It has no effect in a `group`.

## Groups

### `Entry`

```elm
type alias Entry = { name : String, image : Maybe String }
```

One entry of an avatar group: a name and the URL of a picture, if there is
one. Make an entry with `entry`, or write the record yourself to give it a
picture.

    { name = "Grace Hopper", image = Just "/images/grace.jpg" }

### `entry`

```elm
entry : String -> Entry
```

An entry for `group` with this name and no picture.

    Avatar.member "Ada Lovelace"

### `maxShown`

```elm
maxShown : Int -> Attribute
```

How many avatars `group` shows before it folds the rest into a "+N" bubble.
The default is 4, and the smallest value is 1.

## Accessibility and text

### `decorative`

```elm
decorative : Attribute
```

Hides the avatar from screen readers. Use it when the name is written out
right next to the avatar. On a `group` it hides the whole group: the avatars,
the group itself and the "+N" bubble.

### `locale`

```elm
locale : Locale.Locale -> Attribute
```

The language of the built-in text: the status in the accessible name of an
avatar ("online", "away" ...) and the accessible names of a `group` and its "+N"
bubble. The default is `Locale.default`, which is English.

## Helpers

### `initials`

```elm
initials : String -> String
```

The initials an avatar shows for a name: the first letter of the first and of
the last word, in capital letters. A single word gives one letter, and a name
without letters gives "?".

    Avatar.initials "Ada Lovelace" --> "AL"

    Avatar.initials "Warehouse" --> "W"

    Avatar.initials "" --> "?"
