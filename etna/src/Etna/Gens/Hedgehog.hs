module Etna.Gens.Hedgehog where

import           Hedgehog        (Gen)
import qualified Hedgehog.Gen    as Gen
import qualified Hedgehog.Range  as Range

import Etna.Properties

gen_escape_quote_apostrophe_safe :: Gen QuoteSafeArgs
gen_escape_quote_apostrophe_safe = do
  body <- Gen.string (Range.linear 0 16) (Gen.element asciiPool)
  pos  <- Gen.int (Range.linear 0 (length body))
  let with = take pos body ++ "'" ++ drop pos body
  pure (QuoteSafeArgs (take 32 with))
  where
    asciiPool =
      ['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++
      " !\"#$%&'()*+,-./:;<=>?@[]^_`{|}~"

gen_lookup_numeric_entity_case_insensitive_prefix :: Gen HexEntityArgs
gen_lookup_numeric_entity_case_insensitive_prefix = do
  ds <- Gen.string (Range.linear 1 4) (Gen.element hexPool)
  pure (HexEntityArgs ds)
  where
    hexPool = ['0' .. '9'] ++ ['a' .. 'f'] ++ ['A' .. 'F']

gen_lookup_numeric_entity_no_crash :: Gen OobNumericArgs
gen_lookup_numeric_entity_no_crash = do
  ds <- Gen.string (Range.linear 1 18) (Gen.element ['0' .. '9'])
  let parsed = readDigits ds
  pure (OobNumericArgs parsed)
  where
    readDigits :: String -> Integer
    readDigits []     = 0
    readDigits (c:cs) = foldl (\acc d -> acc * 10 + toInt d) (toInt c) cs
    toInt c = fromIntegral (fromEnum c - fromEnum '0')
