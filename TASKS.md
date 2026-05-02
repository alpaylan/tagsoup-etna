# tagsoup — ETNA Tasks

Total tasks: 12

## Task Index

| Task | Variant | Framework | Property | Witness |
|------|---------|-----------|----------|---------|
| 001 | `chr_oob_overflow_synth_1` | quickcheck | `LookupNumericEntityNoCrash` | `witness_lookup_numeric_entity_no_crash_case_huge` |
| 002 | `chr_oob_overflow_synth_1` | hedgehog | `LookupNumericEntityNoCrash` | `witness_lookup_numeric_entity_no_crash_case_huge` |
| 003 | `chr_oob_overflow_synth_1` | falsify | `LookupNumericEntityNoCrash` | `witness_lookup_numeric_entity_no_crash_case_huge` |
| 004 | `chr_oob_overflow_synth_1` | smallcheck | `LookupNumericEntityNoCrash` | `witness_lookup_numeric_entity_no_crash_case_huge` |
| 005 | `escape_quote_xml_f37c174_1` | quickcheck | `EscapeQuoteApostropheSafe` | `witness_escape_quote_apostrophe_safe_case_simple` |
| 006 | `escape_quote_xml_f37c174_1` | hedgehog | `EscapeQuoteApostropheSafe` | `witness_escape_quote_apostrophe_safe_case_simple` |
| 007 | `escape_quote_xml_f37c174_1` | falsify | `EscapeQuoteApostropheSafe` | `witness_escape_quote_apostrophe_safe_case_simple` |
| 008 | `escape_quote_xml_f37c174_1` | smallcheck | `EscapeQuoteApostropheSafe` | `witness_escape_quote_apostrophe_safe_case_simple` |
| 009 | `uppercase_hex_entity_6cd85ac6_1` | quickcheck | `LookupNumericEntityCaseInsensitivePrefix` | `witness_lookup_numeric_entity_case_insensitive_prefix_case_4e` |
| 010 | `uppercase_hex_entity_6cd85ac6_1` | hedgehog | `LookupNumericEntityCaseInsensitivePrefix` | `witness_lookup_numeric_entity_case_insensitive_prefix_case_4e` |
| 011 | `uppercase_hex_entity_6cd85ac6_1` | falsify | `LookupNumericEntityCaseInsensitivePrefix` | `witness_lookup_numeric_entity_case_insensitive_prefix_case_4e` |
| 012 | `uppercase_hex_entity_6cd85ac6_1` | smallcheck | `LookupNumericEntityCaseInsensitivePrefix` | `witness_lookup_numeric_entity_case_insensitive_prefix_case_4e` |

## Witness Catalog

- `witness_lookup_numeric_entity_no_crash_case_huge` — lookupNumericEntity "89439085908539082" must not raise
- `witness_lookup_numeric_entity_no_crash_case_above_max` — lookupNumericEntity "1114112" (one above maxBound :: Char) must not raise
- `witness_escape_quote_apostrophe_safe_case_simple` — escapeXML "it's" must contain `&#39;`
- `witness_escape_quote_apostrophe_safe_case_pair` — escapeXML "a''b" must contain two `&#39;` sequences
- `witness_lookup_numeric_entity_case_insensitive_prefix_case_4e` — lookupNumericEntity "X4e" must equal lookupNumericEntity "x4e"
- `witness_lookup_numeric_entity_case_insensitive_prefix_case_41` — lookupNumericEntity "X41" must equal lookupNumericEntity "x41"
