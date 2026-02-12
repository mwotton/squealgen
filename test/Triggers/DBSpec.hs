{-# LANGUAGE ScopedTypeVariables #-}
module Triggers.DBSpec where

import           Control.Exception      (SomeException, displayException, try)
import           Data.List              (findIndex, isPrefixOf, tails)
import           DBHelpers              (runGeneratorFromSchema)
import           Test.Hspec
import           Triggers.Public        ()

spec :: Spec
spec = describe "Triggers" $ do
  it "extracts trigger definitions, excludes other schemas, and emits trigger summary" $ do
    e <- try @SomeException runGenerator :: IO (Either SomeException String)
    case e of
      Left err -> expectationFailure ("setup failed: " <> displayException err)
      Right hs -> do
        hs `shouldContain` "-- triggers"
        hs `shouldContain` "-- Trigger contract: `Triggers` is generated metadata and is not composed into `Schema`."
        hs `shouldContain` "type Triggers ="
        hs `shouldContain` "\"accounts_before_row\""
        hs `shouldContain` "\"accounts_after_stmt\""
        hs `shouldContain` "\"account_view_instead_row\""
        hs `shouldContain` "\"accounts_balance_guard\""
        hs `shouldContain` "CREATE TRIGGER accounts_before_row BEFORE INSERT OR UPDATE ON accounts FOR EACH ROW EXECUTE FUNCTION log_account_row()"
        hs `shouldContain` "CREATE TRIGGER accounts_after_stmt AFTER DELETE ON accounts FOR EACH STATEMENT EXECUTE FUNCTION log_account_stmt()"
        hs `shouldContain` "CREATE TRIGGER account_view_instead_row INSTEAD OF INSERT OR DELETE OR UPDATE ON account_view FOR EACH ROW EXECUTE FUNCTION account_view_iou()"
        hs `shouldContain` "CREATE CONSTRAINT TRIGGER accounts_balance_guard AFTER INSERT OR UPDATE ON accounts DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION check_balance_not_negative()"
        hs `shouldContain` "-- Trigger fallback notes:"
        hs `shouldContain` "none"
        hs `shouldNotContain` "private_only_trigger"
  it "orders duplicate trigger names deterministically across relations and runs" $ do
    out1 <- runGeneratorFromSchema
      "./test/Triggers/fixtures/colliding_structure.sql"
      "Triggers.Colliding.Generated"
      "public"
    out2 <- runGeneratorFromSchema
      "./test/Triggers/fixtures/colliding_structure.sql"
      "Triggers.Colliding.Generated"
      "public"
    out1 `shouldBe` out2

    let aNeedle = "\"shared_trigger\", \"CREATE TRIGGER shared_trigger BEFORE INSERT ON a_accounts FOR EACH ROW EXECUTE FUNCTION shared_trigger_a()\""
        zNeedle = "\"shared_trigger\", \"CREATE TRIGGER shared_trigger BEFORE INSERT ON z_accounts FOR EACH ROW EXECUTE FUNCTION shared_trigger_z()\""
        aIndex = firstIndexOf aNeedle out1
        zIndex = firstIndexOf zNeedle out1
    aIndex `shouldSatisfy` (/= Nothing)
    zIndex `shouldSatisfy` (/= Nothing)
    aIndex `shouldSatisfy` (< zIndex)

runGenerator :: IO String
runGenerator = do
  e <- try @SomeException $
    runGeneratorFromSchema "./test/Triggers/schemas/Public/structure.sql" "Triggers.Generated" "public"
  case e of
    Left err  -> ioError (userError (displayException err))
    Right out -> pure out

firstIndexOf :: String -> String -> Maybe Int
firstIndexOf needle = findIndex (isPrefixOf needle) . tails
