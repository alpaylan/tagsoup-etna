module Etna.Gens.QuickCheck where

import qualified Test.QuickCheck as QC

import Etna.Properties

-- Variant 1: a printable ASCII string (length 1-32) containing at least one
-- apostrophe so the property doesn't immediately Discard.
gen_escape_quote_apostrophe_safe :: QC.Gen QuoteSafeArgs
gen_escape_quote_apostrophe_safe = do
  n <- QC.choose (1, 16)
  body <- QC.vectorOf n (QC.elements asciiPool)
  -- Ensure at least one apostrophe somewhere.
  pos <- QC.choose (0, n)
  let inserted = take pos body ++ "'" ++ drop pos body
  pure (QuoteSafeArgs (take 32 inserted))
  where
    asciiPool =
      ['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++
      " !\"#$%&'()*+,-./:;<=>?@[]^_`{|}~"

-- Variant 2: 1-4 hex digits, lower or upper case.
gen_lookup_numeric_entity_case_insensitive_prefix
  :: QC.Gen HexEntityArgs
gen_lookup_numeric_entity_case_insensitive_prefix = do
  n  <- QC.choose (1, 4)
  ds <- QC.vectorOf n (QC.elements hexPool)
  pure (HexEntityArgs ds)
  where
    hexPool = ['0' .. '9'] ++ ['a' .. 'f'] ++ ['A' .. 'F']

-- Variant 3: a non-negative Integer biased toward huge values that would
-- overflow Char's range (0x10FFFF = 1114111).
gen_lookup_numeric_entity_no_crash :: QC.Gen OobNumericArgs
gen_lookup_numeric_entity_no_crash = do
  k <- QC.choose (0, 18 :: Int) -- digit count
  ds <- QC.vectorOf (max 1 k) (QC.elements ['0' .. '9'])
  let parsed = readDigits ds
  pure (OobNumericArgs parsed)
  where
    readDigits :: String -> Integer
    readDigits []     = 0
    readDigits (c:cs) = foldl (\acc d -> acc * 10 + toInt d) (toInt c) cs
    toInt c = fromIntegral (fromEnum c - fromEnum '0')
