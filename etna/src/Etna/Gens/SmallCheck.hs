{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE FlexibleContexts     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
module Etna.Gens.SmallCheck where

import qualified Test.SmallCheck.Series as SC

import Etna.Properties

------------------------------------------------------------------------------
-- Variant 1: an apostrophe-bearing printable ASCII string of bounded length.
-- Enumerated by depth: depth d -> strings up to length d using a small
-- character set, with at least one apostrophe inserted.
------------------------------------------------------------------------------

series_escape_quote_apostrophe_safe :: Monad m => SC.Series m QuoteSafeArgs
series_escape_quote_apostrophe_safe = do
  prefix <- shortString
  suffix <- shortString
  pure (QuoteSafeArgs (prefix ++ "'" ++ suffix))
  where
    -- Hand-rolled small-depth strings (length 0-2) drawn from a tiny
    -- character pool. SmallCheck's depth governs string length.
    shortString :: Monad m => SC.Series m String
    shortString = pure "" SC.\/ fmap (:[]) charSeries SC.\/ do
      a <- charSeries
      b <- charSeries
      pure [a, b]

    charSeries :: Monad m => SC.Series m Char
    charSeries =
      pure 'a' SC.\/ pure 'b' SC.\/ pure '<' SC.\/ pure '>' SC.\/
      pure '&' SC.\/ pure '"' SC.\/ pure ' '

------------------------------------------------------------------------------
-- Variant 2: 1-3 hex digits.
------------------------------------------------------------------------------

series_lookup_numeric_entity_case_insensitive_prefix
  :: Monad m => SC.Series m HexEntityArgs
series_lookup_numeric_entity_case_insensitive_prefix = do
  d  <- pure 1 SC.\/ pure 2 SC.\/ pure 3
  ds <- replicateSeries d hexSeries
  pure (HexEntityArgs ds)
  where
    hexSeries :: Monad m => SC.Series m Char
    hexSeries =
      pure '0' SC.\/ pure '1' SC.\/ pure '4' SC.\/ pure '9' SC.\/
      pure 'a' SC.\/ pure 'e' SC.\/ pure 'A' SC.\/ pure 'F'

    replicateSeries :: Monad m => Int -> SC.Series m a -> SC.Series m [a]
    replicateSeries 0 _ = pure []
    replicateSeries n s = do
      x  <- s
      xs <- replicateSeries (n - 1) s
      pure (x : xs)

------------------------------------------------------------------------------
-- Variant 3: an Integer drawn from a small hand-picked set, biased toward
-- values that exceed maxBound :: Char (0x10FFFF = 1114111).
------------------------------------------------------------------------------

series_lookup_numeric_entity_no_crash
  :: Monad m => SC.Series m OobNumericArgs
series_lookup_numeric_entity_no_crash =
  fmap OobNumericArgs $
        pure 0
   SC.\/ pure 65
   SC.\/ pure 1114111
   SC.\/ pure 1114112
   SC.\/ pure 89439085908539082
   SC.\/ pure 999999999999999
