module Etna.Gens.Falsify where

import           Data.List.NonEmpty             (NonEmpty (..))
import qualified Test.Falsify.Generator         as F
import qualified Test.Falsify.Range             as FR

import Etna.Properties

ne :: [a] -> NonEmpty a
ne []     = error "Etna.Gens.Falsify.ne: empty"
ne (x:xs) = x :| xs

gen_escape_quote_apostrophe_safe :: F.Gen QuoteSafeArgs
gen_escape_quote_apostrophe_safe = do
  bodyLen <- F.integral (FR.between (0 :: Word, 16))
  body    <- F.list (FR.between (0 :: Word, bodyLen)) (F.elem (ne asciiPool))
  posMax  <- F.integral (FR.between (0 :: Word, fromIntegral (length body)))
  let with = take (fromIntegral posMax) body ++ "'" ++ drop (fromIntegral posMax) body
  pure (QuoteSafeArgs (take 32 with))
  where
    asciiPool =
      ['a' .. 'z'] ++ ['A' .. 'Z'] ++ ['0' .. '9'] ++
      " !\"#$%&'()*+,-./:;<=>?@[]^_`{|}~"

gen_lookup_numeric_entity_case_insensitive_prefix :: F.Gen HexEntityArgs
gen_lookup_numeric_entity_case_insensitive_prefix = do
  ds <- F.list (FR.between (1 :: Word, 4)) (F.elem (ne hexPool))
  pure (HexEntityArgs ds)
  where
    hexPool = ['0' .. '9'] ++ ['a' .. 'f'] ++ ['A' .. 'F']

gen_lookup_numeric_entity_no_crash :: F.Gen OobNumericArgs
gen_lookup_numeric_entity_no_crash = do
  ds <- F.list (FR.between (1 :: Word, 18)) (F.elem (ne ['0' .. '9']))
  let parsed = readDigits ds
  pure (OobNumericArgs parsed)
  where
    readDigits :: String -> Integer
    readDigits []     = 0
    readDigits (c:cs) = foldl (\acc d -> acc * 10 + toInt d) (toInt c) cs
    toInt c = fromIntegral (fromEnum c - fromEnum '0')
