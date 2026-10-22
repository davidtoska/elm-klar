# Klar.Icon.Library

The whole icon library in one place, for galleries, pickers and tests.

Import: `import Klar.Icon.Library as Library` | Group: Icon library

Types: `Group`

## Signatures

```elm
type alias Group = { title : String, moduleName : String, icons : List Icon.Icon }
groups : List Group
all : List Icon.Icon
count : Int
```

## Documentation

The whole icon library in one place, for galleries, pickers and tests.

Use when: you need a gallery, a picker or a test that goes through every icon.
Do not use when: the application only shows some icons (import them from their modules, or `Klar.Icon` for the everyday set).

Each group is a module: `Klar.Icon` has the everyday icons, and the other modules
(`Klar.Icon.Arrows`, `Klar.Icon.Business` and so on) hold the rest. Using this
module puts every icon in your program; the compiler cannot leave any out. An
application that only shows icons should import the icons it needs from their
modules.

### `Group`

```elm
type alias Group = { title : String, moduleName : String, icons : List Icon.Icon }
```

A named set of icons: a module of the library.

### `groups`

```elm
groups : List Group
```

The groups of the library, with the everyday icons first.

### `all`

```elm
all : List Icon.Icon
```

Every icon of the library.

### `count`

```elm
count : Int
```

How many icons the library has.
