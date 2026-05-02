# tagsoup — Injected Bugs

Parsing and extracting information from (possibly malformed) HTML/XML documents (ndmitchell/tagsoup). Bug fixes mined from upstream history; modern HEAD is the base, each patch reverse-applies a fix to install the original bug.

Total mutations: 3

## Bug Index

| # | Variant | Name | Location | Injection | Fix Commit |
|---|---------|------|----------|-----------|------------|
| 1 | `chr_oob_overflow_synth_1` | `lookupNumericEntity_overflow_crash` | `src/Text/HTML/TagSoup/Entity.hs:47` | `patch` | `f2dcaa682c6d5f7dea34eb09bb5b02532be523c9` |
| 2 | `escape_quote_xml_f37c174_1` | `escapeXML_skips_apostrophe` | `src/Text/HTML/TagSoup/Entity.hs:70` | `patch` | `f37c174a412b6531af88dae379fbbaff4f44d9ad` |
| 3 | `uppercase_hex_entity_6cd85ac6_1` | `lookupNumericEntity_rejects_uppercase_X` | `src/Text/HTML/TagSoup/Entity.hs:37` | `patch` | `6cd85ac6b5c08d37c4f43c262ee36ef9b902773a` |

## Property Mapping

| Variant | Property | Witness(es) |
|---------|----------|-------------|
| `chr_oob_overflow_synth_1` | `LookupNumericEntityNoCrash` | `witness_lookup_numeric_entity_no_crash_case_huge`, `witness_lookup_numeric_entity_no_crash_case_above_max` |
| `escape_quote_xml_f37c174_1` | `EscapeQuoteApostropheSafe` | `witness_escape_quote_apostrophe_safe_case_simple`, `witness_escape_quote_apostrophe_safe_case_pair` |
| `uppercase_hex_entity_6cd85ac6_1` | `LookupNumericEntityCaseInsensitivePrefix` | `witness_lookup_numeric_entity_case_insensitive_prefix_case_4e`, `witness_lookup_numeric_entity_case_insensitive_prefix_case_41` |

## Framework Coverage

| Property | quickcheck | hedgehog | falsify | smallcheck |
|----------|---------:|-------:|------:|---------:|
| `LookupNumericEntityNoCrash` | ✓ | ✓ | ✓ | ✓ |
| `EscapeQuoteApostropheSafe` | ✓ | ✓ | ✓ | ✓ |
| `LookupNumericEntityCaseInsensitivePrefix` | ✓ | ✓ | ✓ | ✓ |

## Bug Details

### 1. lookupNumericEntity_overflow_crash

- **Variant**: `chr_oob_overflow_synth_1`
- **Location**: `src/Text/HTML/TagSoup/Entity.hs:47` (inside `lookupNumericEntity`)
- **Property**: `LookupNumericEntityNoCrash`
- **Witness(es)**:
  - `witness_lookup_numeric_entity_no_crash_case_huge` — lookupNumericEntity "89439085908539082" must not raise
  - `witness_lookup_numeric_entity_no_crash_case_above_max` — lookupNumericEntity "1114112" (one above maxBound :: Char) must not raise
- **Source**: synthesized — Don't crash on malformed characters, replace them with ?
  > An entity like `&#9999999999;` parses as a numeric reference, but its decoded code point exceeds the valid Char range (`0x10FFFF`). The historical fix in commit f2dcaa68 replaced the unguarded `chr` call with one that returns `'?'` on overflow. The modern Entity.hs codebase took a stricter route: an `inRange` test that returns Nothing for out-of-range values. The buggy variant deletes that test, so `chr $ fromInteger a` raises `Prelude.chr: bad argument` for any numeric entity above U+10FFFF. Patch synthesised against modern HEAD because the upstream commit predates the move from Implementation.hs to Entity.hs.
- **Fix commit**: `f2dcaa682c6d5f7dea34eb09bb5b02532be523c9` — Don't crash on malformed characters, replace them with ?
- **Invariant violated**: lookupNumericEntity must never raise an exception. For any non-negative Integer N rendered as a decimal numeric entity, lookupNumericEntity (show N) must terminate with either Nothing or Just c where ord c <= ord (maxBound :: Char).
- **How the mutation triggers**: Reverse-applying the patch removes the inRange test guarding `chr $ fromInteger a`. Calling lookupNumericEntity "1114112" (or any larger digit string) then raises `Prelude.chr: bad argument`.

### 2. escapeXML_skips_apostrophe

- **Variant**: `escape_quote_xml_f37c174_1`
- **Location**: `src/Text/HTML/TagSoup/Entity.hs:70` (inside `escapeXML`)
- **Property**: `EscapeQuoteApostropheSafe`
- **Witness(es)**:
  - `witness_escape_quote_apostrophe_safe_case_simple` — escapeXML "it's" must contain `&#39;`
  - `witness_escape_quote_apostrophe_safe_case_pair` — escapeXML "a''b" must contain two `&#39;` sequences
- **Source**: internal — #75, change the escapeXML so that ' isn't in xmlEntities
  > escapeXML used to be defined over `xmlEntities` only, which lists `quot/amp/lt/gt`. The single-quote entry `("#39", "'")` lived in that list, but it had broken case semantics elsewhere — Ryan Scott's PR #75 moved it out of `xmlEntities` and prepended it directly to the IntMap consulted by escapeXML, so `'` would still be expanded to `&#39;` while no longer polluting the named-entity table. Reverse-applying the patch removes the `("#39",\"'\"):` prefix, so `escapeXML` no longer escapes apostrophes.
- **Fix commit**: `f37c174a412b6531af88dae379fbbaff4f44d9ad` — #75, change the escapeXML so that ' isn't in xmlEntities
- **Invariant violated**: Every literal apostrophe (U+0027) appearing in the input to escapeXML must be expanded to `&#39;` in the output. The number of `&#39;` occurrences in the output equals the number of apostrophes in the input.
- **How the mutation triggers**: Reverse-applying the patch drops the `("#39","\'"):` prefix from the IntMap consulted by escapeXML. Calling escapeXML "it's" then returns "it's" (apostrophe passes through) instead of "it&#39;s".

### 3. lookupNumericEntity_rejects_uppercase_X

- **Variant**: `uppercase_hex_entity_6cd85ac6_1`
- **Location**: `src/Text/HTML/TagSoup/Entity.hs:37` (inside `lookupNumericEntity`)
- **Property**: `LookupNumericEntityCaseInsensitivePrefix`
- **Witness(es)**:
  - `witness_lookup_numeric_entity_case_insensitive_prefix_case_4e` — lookupNumericEntity "X4e" must equal lookupNumericEntity "x4e"
  - `witness_lookup_numeric_entity_case_insensitive_prefix_case_41` — lookupNumericEntity "X41" must equal lookupNumericEntity "x41"
- **Source**: internal — #32, make sure upper case &#X works in lookupEntity
  > Per HTML5, both `&#x...;` and `&#X...;` are valid hex character references. The buggy implementation matched only the lowercase `'x'` prefix in `lookupNumericEntity`, so any input prefixed with capital `'X'` was rejected as if it were a named entity. The fix replaces the literal `'x'` with a membership test against `"xX"`.
- **Fix commit**: `6cd85ac6b5c08d37c4f43c262ee36ef9b902773a` — #32, make sure upper case &#X works in lookupEntity
- **Invariant violated**: For every string of valid hex digits, `lookupNumericEntity ("x" ++ ds)` and `lookupNumericEntity ("X" ++ ds)` produce the same Just-result.
- **How the mutation triggers**: Reverse-applying the patch restores the literal `'x'` pattern on the hex branch. Calling lookupNumericEntity "X4e" then returns Nothing instead of Just "N".
