{-# LANGUAGE OverloadedStrings #-}
module SearchPathFragments.DBSpec where

import           Data.List  (isInfixOf)
import           DBHelpers  (runGeneratorFromSchema)
import           Test.Hspec

spec :: Spec
spec = describe "search_path fragments" $ do
  it "supports odd schema names and quoted/unquoted fragments safely" $ do
    outUnquoted <- runGeneratorFromSchema
      "test/SearchPathFragments/weird_schema.sql"
      "SearchPathFragments.Fixture"
      "weird-schema,public"

    outQuoted <- runGeneratorFromSchema
      "test/SearchPathFragments/weird_schema.sql"
      "SearchPathFragments.Fixture"
      "\"weird-schema\",public"

    outUnquoted `shouldSatisfy` isInfixOf "type DB = '[\"weird-schema\" ::: Schema]"
    outQuoted `shouldSatisfy` isInfixOf "type DB = '[\"weird-schema\" ::: Schema]"

    -- Regression: schema fragment should not be used verbatim as the DB schema name.
    outUnquoted `shouldNotSatisfy` isInfixOf "weird-schema,public"
    outQuoted `shouldNotSatisfy` isInfixOf "weird-schema,public"

    -- The generator should not leak psql query output into the generated Haskell module.
    outUnquoted `shouldNotSatisfy` isInfixOf "(1 row)"
