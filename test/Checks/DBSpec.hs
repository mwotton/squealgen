{-# LANGUAGE ScopedTypeVariables #-}
module Checks.DBSpec where

import           Control.Exception      (SomeException, displayException, try)
import qualified Data.ByteString.Char8  as BS8
import           Checks.Public          ()
import           Database.Postgres.Temp  (cacheConfig, withConfig, withDbCache, toConnectionString)
import           DBHelpers              (runSquealgenScript)
import           Squeal.PostgreSQL      (Definition (UnsafeDefinition), define, withConnection)
import           Test.Hspec

spec :: Spec
spec = describe "Checks" $ do
  it "extracts table/column check constraints and emits fallback expression notes" $ do
    e <- try @SomeException runGenerator :: IO (Either SomeException String)
    case e of
      Left err -> expectationFailure ("setup failed: " <> displayException err)
      Right hs -> do
        hs `shouldContain` "\"amount_positive\" ::: 'Check '[\"amount\"]"
        hs `shouldContain` "\"balance_nonnegative\" ::: 'Check '[\"balance\"]"
        hs `shouldContain` "\"status_guard\" ::: 'Check '[\"status\"]"
        hs `shouldContain` "\"literal_true\" ::: 'Check '[]"
        hs `shouldContain` "-- | CHECK (amount > 0)"
        hs `shouldContain` "-- | CHECK (balance >= 0)"
        hs `shouldContain` "-- | CHECK (status IS NULL OR char_length(status) > 0)"
        hs `shouldContain` "-- | CHECK (1 = 1)"
        hs `shouldContain` "-- Omitted/fallback check constraints:"
        hs `shouldContain` "domain public.positive_amount positive_amount_check: not representable in Domains typedef output (CHECK (VALUE > 0))"

runGenerator :: IO String
runGenerator = withDbCache $ \cache -> do
  result <- withConfig (cacheConfig cache) $ \db -> do
    let connBS = toConnectionString db
    sql <- BS8.readFile "./test/Checks/schemas/Public/structure.sql"
    withConnection connBS $ define (UnsafeDefinition sql)
    runSquealgenScript (BS8.unpack connBS) "Checks.Generated" "public"
  case result of
    Left err -> ioError (userError (displayException err))
    Right out -> pure out
