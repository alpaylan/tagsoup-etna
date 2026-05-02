module Etna.Witnesses where

import Etna.Properties
import Etna.Result

------------------------------------------------------------------------------
-- Variant 1: escape_quote_xml_f37c174_1
------------------------------------------------------------------------------

witness_escape_quote_apostrophe_safe_case_simple :: PropertyResult
witness_escape_quote_apostrophe_safe_case_simple =
  property_escape_quote_apostrophe_safe (QuoteSafeArgs "it's")

witness_escape_quote_apostrophe_safe_case_pair :: PropertyResult
witness_escape_quote_apostrophe_safe_case_pair =
  property_escape_quote_apostrophe_safe (QuoteSafeArgs "a''b")

------------------------------------------------------------------------------
-- Variant 2: uppercase_hex_entity_6cd85ac6_1
------------------------------------------------------------------------------

witness_lookup_numeric_entity_case_insensitive_prefix_case_4e :: PropertyResult
witness_lookup_numeric_entity_case_insensitive_prefix_case_4e =
  property_lookup_numeric_entity_case_insensitive_prefix (HexEntityArgs "4e")

witness_lookup_numeric_entity_case_insensitive_prefix_case_41 :: PropertyResult
witness_lookup_numeric_entity_case_insensitive_prefix_case_41 =
  property_lookup_numeric_entity_case_insensitive_prefix (HexEntityArgs "41")

------------------------------------------------------------------------------
-- Variant 3: chr_oob_overflow_synth_1
------------------------------------------------------------------------------

witness_lookup_numeric_entity_no_crash_case_huge :: PropertyResult
witness_lookup_numeric_entity_no_crash_case_huge =
  property_lookup_numeric_entity_no_crash (OobNumericArgs 89439085908539082)

witness_lookup_numeric_entity_no_crash_case_above_max :: PropertyResult
witness_lookup_numeric_entity_no_crash_case_above_max =
  property_lookup_numeric_entity_no_crash (OobNumericArgs 1114112)
