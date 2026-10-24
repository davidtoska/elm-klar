# Releasing

Elm packages are published from a git tag. The package registry downloads the
tagged source from GitHub, builds the documentation and checks the version against
the public API of the last release.

## Before the first release

1. The package name in `elm.json` (`davidtoska/elm-klar`) must be `<github user or
   organization>/<repository name>`. Create the repository on GitHub with that name
   and add it as `origin`.
2. `npm install` once, then run all checks:

   ```bash
   npm run check
   ```

   This checks the text files, builds and verifies the stylesheet, checks that every
   exposed name is documented and that no public signature mentions a type nobody
   can name, checks the formatting, runs the tests and compiles the showcase.
3. Check that the package still builds with the previous compiler (Elm 0.19.1) and
   with the oldest version of every dependency that `elm.json` allows:

   ```bash
   npm run check:compat
   ```

   It needs the network the first time.
4. Look at the documentation the way package.elm-lang.org will show it:

   ```bash
   elm make --docs=docs.json
   ```

   (`docs.json` is ignored by git.) The preview at <https://elm-doc-preview.netlify.app>
   can open it.
5. Read the README and `CHANGELOG.md` once more. They are the front page of the package.

## Publishing a version

```bash
git add -A
git commit -m "Release 1.0.0"
git tag -a 1.0.0 -m "1.0.0"
git push origin main --tags
elm publish
```

`elm publish` checks that

- the working tree is clean and the tag exists on GitHub,
- `README.md` and `LICENSE` exist,
- the version in `elm.json` is the one that `elm bump` would choose,
- every exposed module compiles and is documented.

The first release must be `1.0.0`.

## Later releases

1. Change the code. Keep the public API small; adding to it is a minor release,
   changing or removing anything is a major release.
2. See what Elm thinks of the change: `elm diff`.
3. `elm bump` writes the next version into `elm.json`.
4. Add a section to `CHANGELOG.md`, then commit, tag and `elm publish` as above.

A published version can never be removed or changed, so run `npm run check` first.

## Which Elm versions

`elm.json` says `0.19.0 <= v < 0.20.0`, which is what package.elm-lang.org expects
of every package. The package is built and tested with Elm 0.19.3 and uses no
language feature that is newer than 0.19.0. The only things that depend on the
compiler version are the `elm-version` of the applications in this repository
(`example/`, `recipes/*/`, `template/`, `design/form-model-errors/`) and the version of
`elm-test`.
