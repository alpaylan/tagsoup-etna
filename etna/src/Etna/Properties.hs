{-# LANGUAGE BangPatterns #-}
module Etna.Properties where

import Control.Exception (SomeException, evaluate, try)
import Data.Char (chr, ord)
import Etna.Result
import System.IO.Unsafe (unsafePerformIO)
import Text.HTML.TagSoup.Entity (escapeXML, lookupNumericEntity)

------------------------------------------------------------------------------
-- Variant 1: escape_quote_xml_f37c174_1
-- "#75, change the escapeXML so that ' isn't in xmlEntities"
-- Fix sha: f37c174a412b6531af88dae379fbbaff4f44d9ad
--
-- Buggy escapeXML did NOT escape the apostrophe character. The fix adds
-- ("#39","'") to the entity table consulted by escapeXML so a stray
-- apostrophe always renders as "&#39;".
------------------------------------------------------------------------------

-- | A printable ASCII string fed through escapeXML. We assert that every
-- single-quote in the input becomes "&#39;" in the output. This is the
-- weakest property that distinguishes the buggy build (apostrophe passes
-- through unchanged) from the fixed build (apostrophe becomes &#39;).
newtype QuoteSafeArgs = QuoteSafeArgs { quoteSafeInput :: String }
  deriving (Show, Eq)

property_escape_quote_apostrophe_safe :: QuoteSafeArgs -> PropertyResult
property_escape_quote_apostrophe_safe (QuoteSafeArgs s)
  | not (validQuoteInput s) = Discard
  | not ('\'' `elem` s)     = Discard
  | otherwise =
      let escaped = escapeXML s
          -- Every literal apostrophe in the source must be expanded to "&#39;".
          rebuilt  = expand escaped
          original = countApos s
          rendered = countAposEscape escaped
      in if original == rendered && original > 0
           then Pass
           else Fail $
             "escapeXML " ++ show s ++ " = " ++ show escaped ++
             "; expected " ++ show original ++ " &#39; sequences, got " ++
             show rendered ++ " (rebuilt=" ++ show rebuilt ++ ")"
  where
    validQuoteInput xs =
      not (null xs) && length xs <= 32 && all printableAscii xs
    printableAscii c = ord c >= 32 && ord c < 127
    countApos = length . filter (== '\'')
    -- Count the number of "&#39;" sequences in the rendered output.
    countAposEscape xs = case xs of
      []       -> 0
      ('&':'#':'3':'9':';':rest) -> 1 + countAposEscape rest
      (_:rest) -> countAposEscape rest
    expand = id

------------------------------------------------------------------------------
-- Variant 2: uppercase_hex_entity_6cd85ac6_1
-- "#32, make sure upper case &#X works in lookupEntity"
-- Fix sha: 6cd85ac6b5c08d37c4f43c262ee36ef9b902773a
--
-- Buggy lookupNumericEntity only matched lowercase 'x' as the hex prefix.
-- The fix accepts both 'x' and 'X'. Property: for any string of hex digits
-- whose lowercase-prefixed form resolves to Just c, the uppercase-prefixed
-- form must resolve to the same Just c.
------------------------------------------------------------------------------

newtype HexEntityArgs = HexEntityArgs { hexEntityDigits :: String }
  deriving (Show, Eq)

property_lookup_numeric_entity_case_insensitive_prefix
  :: HexEntityArgs -> PropertyResult
property_lookup_numeric_entity_case_insensitive_prefix (HexEntityArgs digits)
  | not (validHexDigits digits) = Discard
  | otherwise =
      let lowerInput = 'x' : digits
          upperInput = 'X' : digits
          lowerRes   = lookupNumericEntity lowerInput
          upperRes   = lookupNumericEntity upperInput
      in case (lowerRes, upperRes) of
           (Just a, Just b) | a == b -> Pass
           _ ->
             Fail $
               "lookupNumericEntity " ++ show lowerInput ++ " = " ++
               show lowerRes ++ "; lookupNumericEntity " ++ show upperInput ++
               " = " ++ show upperRes ++ " (expected equal Just _)"
  where
    validHexDigits xs =
      not (null xs)
        && length xs <= 4
        && all isHex xs
    isHex c =
      (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')

------------------------------------------------------------------------------
-- Variant 3: chr_oob_overflow_synth_1
-- (Synthesised against modern Entity.hs; mirrors the fix from
-- f2dcaa682c6d5f7dea34eb09bb5b02532be523c9 "Don't crash on malformed
-- characters, replace them with ?".)
--
-- Buggy lookupNumericEntity does not bound-check the parsed integer before
-- calling 'chr', so a numeric entity larger than maxBound :: Char raises
-- "Prelude.chr: bad argument". The fix adds an inRange test that returns
-- Nothing for out-of-range values.
------------------------------------------------------------------------------

newtype OobNumericArgs = OobNumericArgs { oobInteger :: Integer }
  deriving (Show, Eq)

property_lookup_numeric_entity_no_crash :: OobNumericArgs -> PropertyResult
property_lookup_numeric_entity_no_crash (OobNumericArgs n)
  | n < 0                    = Discard
  | otherwise =
      let s = show n
          observed = unsafeTry (lookupNumericEntity s)
      in case observed of
           Right (Just out)
             | length out == 1 && ord (head out) <= ord (maxBound :: Char) ->
                 Pass
             | otherwise ->
                 Fail $
                   "lookupNumericEntity " ++ show s ++
                   " returned out-of-range Just " ++ show out
           Right Nothing -> Pass
           Left e ->
             Fail $
               "lookupNumericEntity " ++ show s ++ " raised " ++ e

-- | Fully force a Maybe String to NF (forcing every Char) and trap any
-- exception thrown during forcing. Implemented via an IO walk so the
-- evaluate-to-WHNF semantics of @evaluate@ doesn't leave inner thunks
-- un-forced.
unsafeTry :: Maybe String -> Either String (Maybe String)
unsafeTry m = unsafePerformIO $ do
  r <- try (forceMaybeStr m)
  pure $ case r of
    Right v -> Right v
    Left e  -> Left (show (e :: SomeException))

forceMaybeStr :: Maybe String -> IO (Maybe String)
forceMaybeStr Nothing  = pure Nothing
forceMaybeStr (Just s) = do
  s' <- forceStr s
  pure (Just s')

forceStr :: String -> IO String
forceStr []     = pure []
forceStr (c:cs) = do
  !c'  <- evaluate c
  cs' <- forceStr cs
  pure (c' : cs')
