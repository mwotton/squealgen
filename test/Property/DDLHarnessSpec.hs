module Property.DDLHarnessSpec (spec) where

import           Test.Hspec

import qualified Data.List as List

spec :: Spec
spec = describe "Property.DDL harness" $
  it "does not use global unsafe IORef execution state" $ do
    source <- readFile "test/Property/DDLSpec.hs"
    source `shouldSatisfy` not . hasForbiddenExecutionGlobals

hasForbiddenExecutionGlobals :: String -> Bool
hasForbiddenExecutionGlobals source =
  any (`List.isInfixOf` source) forbiddenMarkers
  where
    forbiddenMarkers =
      [ "ddlInvalidAppendExecutedRef :: IORef Bool"
      , "ddlLargeSchemaExecutedRef :: IORef Bool"
      , "unsafePerformIO (newIORef False)"
      ]
