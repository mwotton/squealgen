module Property.DDLHarnessSpec (spec) where

import           Test.Hspec

import qualified Property.DDLSpec as DDL

spec :: Spec
spec = describe "Property.DDL harness" $
  it "runs repeated invalid-append checks without shared one-time state" $ do
    runInvalidAppendProbe
    runInvalidAppendProbe

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
