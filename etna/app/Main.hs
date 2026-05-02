{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import           Control.Exception     (SomeException, bracket, try)
import           Data.IORef            (newIORef, readIORef, modifyIORef')
import           Data.Time.Clock       (diffUTCTime, getCurrentTime)
import           GHC.IO.Handle         (hDuplicate, hDuplicateTo)
import           System.Environment    (getArgs)
import           System.Exit           (exitWith, ExitCode (..))
import           System.IO             (Handle, IOMode (..), hClose, hFlush,
                                         openFile, stderr, stdout, withFile)
import           Text.Printf           (printf)

import           Etna.Result           (PropertyResult (..))
import qualified Etna.Properties       as P
import qualified Etna.Witnesses        as W
import qualified Etna.Gens.QuickCheck  as GQ
import qualified Etna.Gens.Hedgehog    as GH
import qualified Etna.Gens.Falsify     as GF
import qualified Etna.Gens.SmallCheck  as GS

import qualified Test.QuickCheck                    as QC
import qualified Hedgehog                           as HH
import qualified Test.Falsify.Generator             as FG
import qualified Test.Falsify.Interactive           as FI
import qualified Test.Falsify.Property              as FP
import qualified Test.SmallCheck                    as SC
import qualified Test.SmallCheck.Drivers             as SCD
import qualified Test.SmallCheck.Series              as SCS

allProperties :: [String]
allProperties =
  [ "EscapeQuoteApostropheSafe"
  , "LookupNumericEntityCaseInsensitivePrefix"
  , "LookupNumericEntityNoCrash"
  ]

data Outcome = Outcome
  { oStatus :: String
  , oTests  :: Int
  , oCex    :: Maybe String
  , oErr    :: Maybe String
  }

main :: IO ()
main = do
  argv <- getArgs
  case argv of
    [tool, prop] -> dispatch tool prop
    _            -> do
      putStrLn "{\"status\":\"aborted\",\"error\":\"usage: etna-runner <tool> <property>\"}"
      hFlush stdout
      exitWith (ExitFailure 2)

dispatch :: String -> String -> IO ()
dispatch tool prop
  | prop /= "All" && prop `notElem` allProperties =
      emit tool prop "aborted" 0 0 Nothing (Just $ "unknown property: " ++ prop)
  | otherwise = do
      let targets = if prop == "All" then allProperties else [prop]
      mapM_ (runOne tool) targets

runOne :: String -> String -> IO ()
runOne tool prop = do
  t0 <- getCurrentTime
  result <- try (driver tool prop) :: IO (Either SomeException Outcome)
  t1 <- getCurrentTime
  let us = round ((realToFrac (diffUTCTime t1 t0) :: Double) * 1e6) :: Int
  case result of
    Left e  -> emit tool prop "aborted" 0 us Nothing (Just (show e))
    Right (Outcome status tests cex err) ->
      emit tool prop status tests us cex err

driver :: String -> String -> IO Outcome
driver "etna"       p = runWitnesses p
driver "quickcheck" p = runQuickCheck p
driver "hedgehog"   p = runHedgehog   p
driver "falsify"    p = runFalsify    p
driver "smallcheck" p = runSmallCheck p
driver tool         _ = pure (Outcome "aborted" 0 Nothing (Just ("unknown tool: " ++ tool)))

------------------------------------------------------------------------------
-- Tool: etna (witness replay)
------------------------------------------------------------------------------

runWitnesses :: String -> IO Outcome
runWitnesses prop = case witnessesFor prop of
  []    -> pure (Outcome "aborted" 0 Nothing (Just ("no witnesses for " ++ prop)))
  cs    -> go cs 0
  where
    go [] n = pure (Outcome "passed" n Nothing Nothing)
    go ((name, r):rest) n = case r of
      Pass     -> go rest (n + 1)
      Discard  -> go rest (n + 1)
      Fail msg -> pure (Outcome "failed" (n + 1) (Just name) (Just msg))

witnessesFor :: String -> [(String, PropertyResult)]
witnessesFor "EscapeQuoteApostropheSafe" =
  [ ("witness_escape_quote_apostrophe_safe_case_simple",
       W.witness_escape_quote_apostrophe_safe_case_simple)
  , ("witness_escape_quote_apostrophe_safe_case_pair",
       W.witness_escape_quote_apostrophe_safe_case_pair)
  ]
witnessesFor "LookupNumericEntityCaseInsensitivePrefix" =
  [ ("witness_lookup_numeric_entity_case_insensitive_prefix_case_4e",
       W.witness_lookup_numeric_entity_case_insensitive_prefix_case_4e)
  , ("witness_lookup_numeric_entity_case_insensitive_prefix_case_41",
       W.witness_lookup_numeric_entity_case_insensitive_prefix_case_41)
  ]
witnessesFor "LookupNumericEntityNoCrash" =
  [ ("witness_lookup_numeric_entity_no_crash_case_huge",
       W.witness_lookup_numeric_entity_no_crash_case_huge)
  , ("witness_lookup_numeric_entity_no_crash_case_above_max",
       W.witness_lookup_numeric_entity_no_crash_case_above_max)
  ]
witnessesFor _ = []

------------------------------------------------------------------------------
-- Tool: quickcheck
------------------------------------------------------------------------------

runQuickCheck :: String -> IO Outcome
runQuickCheck "EscapeQuoteApostropheSafe" =
  qcDrive (QC.forAll GQ.gen_escape_quote_apostrophe_safe
            (qcProp P.property_escape_quote_apostrophe_safe))
runQuickCheck "LookupNumericEntityCaseInsensitivePrefix" =
  qcDrive (QC.forAll GQ.gen_lookup_numeric_entity_case_insensitive_prefix
            (qcProp P.property_lookup_numeric_entity_case_insensitive_prefix))
runQuickCheck "LookupNumericEntityNoCrash" =
  qcDrive (QC.forAll GQ.gen_lookup_numeric_entity_no_crash
            (qcProp P.property_lookup_numeric_entity_no_crash))
runQuickCheck p = pure (Outcome "aborted" 0 Nothing (Just ("unknown property: " ++ p)))

qcProp :: Show a => (a -> PropertyResult) -> a -> QC.Property
qcProp f args = case f args of
  Pass     -> QC.property True
  Discard  -> QC.discard
  Fail msg -> QC.counterexample msg (QC.property False)

qcDrive :: QC.Property -> IO Outcome
qcDrive p = do
  result <- QC.quickCheckWithResult
              QC.stdArgs { QC.maxSuccess = 200, QC.chatty = False }
              p
  case result of
    QC.Success { QC.numTests = n } -> pure (Outcome "passed" n Nothing Nothing)
    QC.Failure { QC.numTests = n, QC.failingTestCase = tc } ->
      pure (Outcome "failed" n (Just (concat tc)) Nothing)
    QC.GaveUp  { QC.numTests = n } -> pure (Outcome "aborted" n Nothing (Just "QuickCheck gave up"))
    QC.NoExpectedFailure { QC.numTests = n } ->
      pure (Outcome "aborted" n Nothing (Just "no expected failure"))

------------------------------------------------------------------------------
-- Tool: hedgehog
------------------------------------------------------------------------------

runHedgehog :: String -> IO Outcome
runHedgehog "EscapeQuoteApostropheSafe" =
  hhDrive GH.gen_escape_quote_apostrophe_safe P.property_escape_quote_apostrophe_safe
runHedgehog "LookupNumericEntityCaseInsensitivePrefix" =
  hhDrive GH.gen_lookup_numeric_entity_case_insensitive_prefix
          P.property_lookup_numeric_entity_case_insensitive_prefix
runHedgehog "LookupNumericEntityNoCrash" =
  hhDrive GH.gen_lookup_numeric_entity_no_crash
          P.property_lookup_numeric_entity_no_crash
runHedgehog p = pure (Outcome "aborted" 0 Nothing (Just ("unknown property: " ++ p)))

hhDrive :: Show a => HH.Gen a -> (a -> PropertyResult) -> IO Outcome
hhDrive gen f = do
  let test = HH.property $ do
        args <- HH.forAll gen
        case f args of
          Pass     -> pure ()
          Discard  -> HH.discard
          Fail msg -> do
            HH.annotate msg
            HH.failure
  ok <- silenceStdout (HH.check test)
  if ok
    then pure (Outcome "passed" 200 Nothing Nothing)
    else pure (Outcome "failed" 1 Nothing Nothing)

-- | Run an IO action while redirecting stdout to /dev/null, restoring it
-- afterwards. Used for adapters whose underlying library writes progress
-- to stdout (e.g. Hedgehog's HH.check).
silenceStdout :: IO a -> IO a
silenceStdout act = do
  hFlush stdout
  bracket
    (do oldOut <- hDuplicate stdout
        devNull <- openFile "/dev/null" WriteMode
        hDuplicateTo devNull stdout
        pure (oldOut, devNull))
    (\(oldOut, devNull) -> do
        hFlush stdout
        hDuplicateTo oldOut stdout
        hClose devNull
        hClose oldOut)
    (\_ -> act)

------------------------------------------------------------------------------
-- Tool: falsify
------------------------------------------------------------------------------

runFalsify :: String -> IO Outcome
runFalsify "EscapeQuoteApostropheSafe" =
  fsDrive GF.gen_escape_quote_apostrophe_safe P.property_escape_quote_apostrophe_safe
runFalsify "LookupNumericEntityCaseInsensitivePrefix" =
  fsDrive GF.gen_lookup_numeric_entity_case_insensitive_prefix
          P.property_lookup_numeric_entity_case_insensitive_prefix
runFalsify "LookupNumericEntityNoCrash" =
  fsDrive GF.gen_lookup_numeric_entity_no_crash
          P.property_lookup_numeric_entity_no_crash
runFalsify p = pure (Outcome "aborted" 0 Nothing (Just ("unknown property: " ++ p)))

fsDrive :: Show a => FG.Gen a -> (a -> PropertyResult) -> IO Outcome
fsDrive gen f = do
  let prop = do
        args <- FP.gen gen
        case f args of
          Pass     -> pure ()
          Discard  -> FP.discard
          Fail msg -> FP.testFailed (show args ++ ": " ++ msg)
  mFailure <- silenceStdout (FI.falsify prop)
  case mFailure of
    Nothing  -> pure (Outcome "passed" 100 Nothing Nothing)
    Just msg -> pure (Outcome "failed" 1 (Just msg) Nothing)

------------------------------------------------------------------------------
-- Tool: smallcheck
------------------------------------------------------------------------------

runSmallCheck :: String -> IO Outcome
runSmallCheck "EscapeQuoteApostropheSafe" =
  scDrive GS.series_escape_quote_apostrophe_safe P.property_escape_quote_apostrophe_safe
runSmallCheck "LookupNumericEntityCaseInsensitivePrefix" =
  scDrive GS.series_lookup_numeric_entity_case_insensitive_prefix
          P.property_lookup_numeric_entity_case_insensitive_prefix
runSmallCheck "LookupNumericEntityNoCrash" =
  scDrive GS.series_lookup_numeric_entity_no_crash
          P.property_lookup_numeric_entity_no_crash
runSmallCheck p = pure (Outcome "aborted" 0 Nothing (Just ("unknown property: " ++ p)))

scDrive :: Show a => SCS.Series IO a -> (a -> PropertyResult) -> IO Outcome
scDrive series f = do
  countRef <- newIORef (0 :: Int)
  let depth = 5
      check args = SC.monadic $ do
        modifyIORef' countRef (+1)
        pure $ case f args of
          Pass    -> True
          Discard -> True
          Fail _  -> False
      smTest = SC.over series check
  res <- try (SCD.smallCheckM depth smTest)
           :: IO (Either SomeException (Maybe SCD.PropertyFailure))
  n <- readIORef countRef
  case res of
    Left e          -> pure (Outcome "failed" n Nothing (Just (show e)))
    Right Nothing   -> pure (Outcome "passed" n Nothing Nothing)
    Right (Just pf) -> pure (Outcome "failed" n (Just (show pf)) Nothing)

------------------------------------------------------------------------------
-- Output (single JSON line, exit 0 except on argv error)
------------------------------------------------------------------------------

emit :: String -> String -> String -> Int -> Int -> Maybe String -> Maybe String -> IO ()
emit tool prop status tests us cex err = do
  let q = quoteJSON
      esc Nothing  = "null"
      esc (Just s) = q s
  printf "{\"status\":%s,\"tests\":%d,\"discards\":0,\"time\":\"%dus\",\"counterexample\":%s,\"error\":%s,\"tool\":%s,\"property\":%s}\n"
    (q status) tests us (esc cex) (esc err) (q tool) (q prop)
  hFlush stdout

quoteJSON :: String -> String
quoteJSON s = '"' : concatMap esc s ++ "\""
  where
    esc '"'  = "\\\""
    esc '\\' = "\\\\"
    esc '\n' = "\\n"
    esc '\r' = "\\r"
    esc '\t' = "\\t"
    esc c | fromEnum c < 0x20 = printf "\\u%04x" (fromEnum c)
          | otherwise = [c]
