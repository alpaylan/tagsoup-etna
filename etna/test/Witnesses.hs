module Main where

import           Etna.Result    (PropertyResult (..))
import qualified Etna.Witnesses as W
import           System.Exit    (exitFailure, exitSuccess)

main :: IO ()
main = do
  let cases =
        [ ("witness_escape_quote_apostrophe_safe_case_simple",
             W.witness_escape_quote_apostrophe_safe_case_simple)
        , ("witness_escape_quote_apostrophe_safe_case_pair",
             W.witness_escape_quote_apostrophe_safe_case_pair)
        , ("witness_lookup_numeric_entity_case_insensitive_prefix_case_4e",
             W.witness_lookup_numeric_entity_case_insensitive_prefix_case_4e)
        , ("witness_lookup_numeric_entity_case_insensitive_prefix_case_41",
             W.witness_lookup_numeric_entity_case_insensitive_prefix_case_41)
        , ("witness_lookup_numeric_entity_no_crash_case_huge",
             W.witness_lookup_numeric_entity_no_crash_case_huge)
        , ("witness_lookup_numeric_entity_no_crash_case_above_max",
             W.witness_lookup_numeric_entity_no_crash_case_above_max)
        ]
      failures =
        [ (n, msg) | (n, Fail msg) <- cases ] ++
        [ (n, "discard")            | (n, Discard) <- cases ]
  if null failures
    then exitSuccess
    else do
      mapM_ (\(n, m) -> putStrLn (n ++ ": " ++ m)) failures
      exitFailure
