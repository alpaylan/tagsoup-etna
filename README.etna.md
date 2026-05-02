# tagsoup ETNA workload

This workload mines bug fixes from
[ndmitchell/tagsoup](https://github.com/ndmitchell/tagsoup) and turns them
into an ETNA benchmark exercising **QuickCheck**, **Hedgehog**, **Falsify**
and **SmallCheck** against the modern HEAD of the library.

The workload directory is itself a clone of the upstream tagsoup tree.
`src/`, `test/`, `tagsoup.cabal`, etc. are upstream files and are left
untouched. Everything ETNA-specific lives in:

```
etna.toml               -- single source-of-truth manifest
patches/                -- one *.patch per variant; reverse-apply installs the bug
etna/                   -- runner package (cabal sub-package)
  etna-runner.cabal
  src/Etna/...          -- properties, witnesses, per-framework generators
  app/Main.hs           -- CLI dispatcher used by the etna driver
  test/Witnesses.hs     -- cabal test-suite (must be green on base)
BUGS.md                 -- generated; do not hand-edit
TASKS.md                -- generated; do not hand-edit
```

The base tree (commit `294a67dd`) always contains the **fix**. To install
the original bug:

```sh
git apply -R --whitespace=nowarn patches/<variant>.patch
```

To restore the base:

```sh
git apply --whitespace=nowarn patches/<variant>.patch
```

There is exactly one `[[tasks]]` group per variant. The Haskell pipeline
documentation lives in `etna-ify/prompts/run-haskell.md`.

## Variants

| Variant | Property | Source |
|---|---|---|
| `escape_quote_xml_f37c174_1` | `EscapeQuoteApostropheSafe` | tagsoup commit `f37c174` (#75 — escapeXML and apostrophe handling) |
| `uppercase_hex_entity_6cd85ac6_1` | `LookupNumericEntityCaseInsensitivePrefix` | tagsoup commit `6cd85ac6` (#32 — accept `&#X` as well as `&#x`) |
| `chr_oob_overflow_synth_1` | `LookupNumericEntityNoCrash` | synthesised from `f2dcaa68` ("Don't crash on malformed characters"); the modern code base implements the fix as an `inRange` guard inside `lookupNumericEntity`, the patch deletes that guard |

## Build / run

This workload requires GHC 9.6.6 (Falsify ≥ 0.2 needs `base >= 4.18`).
The ghcup-managed compiler at `/Users/akeles/.ghcup/ghc/9.6.6/bin/ghc` is
pinned via `cabal.project`'s `with-compiler:` setting.

```sh
# from workload root
cabal build all

# witness suite (must be PASS on base)
cabal test etna-witnesses

# direct runner invocation
cd etna
cabal run -v0 etna-runner -- quickcheck EscapeQuoteApostropheSafe
cabal run -v0 etna-runner -- hedgehog   LookupNumericEntityCaseInsensitivePrefix
cabal run -v0 etna-runner -- falsify    LookupNumericEntityNoCrash
cabal run -v0 etna-runner -- smallcheck All
```

## Notes on the synthesised variant

`chr_oob_overflow_synth_1` is hand-crafted against modern `HEAD` rather
than `git format-patch`-ed. The original fix from 2011 (commit `f2dcaa68`)
lived in `Text/HTML/TagSoup/Implementation.hs` and replaced the unguarded
`chr` with a range-clamped variant returning `'?'`. Modern tagsoup
re-implemented the same fix in `src/Text/HTML/TagSoup/Entity.hs` as a
`test $ inRange ...` guard that returns `Nothing` for out-of-range inputs.
The synthesised patch deletes that single guard line; reverse-applying it
re-creates the original `Prelude.chr: bad argument` panic for any numeric
entity > U+10FFFF.
