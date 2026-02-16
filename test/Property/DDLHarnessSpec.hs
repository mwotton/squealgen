module Property.DDLHarnessSpec (spec) where

import           Test.Hspec

import qualified Property.DDLSpec as DDL

spec :: Spec
spec = describe "Property.DDL harness" $ do
  it "runs repeated invalid-append checks without shared one-time state" $ do
    -- This test verifies that removing the old runOnce hack was safe.
    -- The probe should fail (invalid code appended) both times.
    runInvalidAppendProbe
    runInvalidAppendProbe

  it "runs large schema compilation without skipping" $ do
    -- Verify the large schema test actually exercises the codepath.
    -- A timeout or exception here indicates a real problem.
    result <- DDL.compileLargeSchemaWithin (DDL.largeSchema 10) 60
    case result of
      Left err -> expectationFailure ("small large-schema probe failed: " <> err)
      Right () -> pure ()

runInvalidAppendProbe :: IO ()
runInvalidAppendProbe = do
  let schema = DDL.SchemaDDL "CREATE TABLE gen_table_1 (id SERIAL PRIMARY KEY)\n"
  schemaResult <- DDL.checkSchema schema
  case schemaResult of
    Left err -> expectationFailure ("schema generation failed: " <> err)
    Right moduleSource -> do
      let broken = moduleSource <> "\n\nfoo::Bool\nfoo=\"banana\"\n"
      compileResult <- DDL.compileModule broken "GeneratedSchema"
      case compileResult of
        Left _   -> pure ()
        Right () -> expectationFailure "expected compilation to fail for invalid appended code"
