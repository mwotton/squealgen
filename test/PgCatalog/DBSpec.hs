{-# LANGUAGE OverloadedStrings #-}
module PgCatalog.DBSpec where

import           Control.Exception        (SomeException, displayException, try)
import qualified Data.ByteString.Char8    as BS8
import           DBHelpers                (runSquealgenScript)
import           Database.Postgres.Temp
import           Test.Hspec

spec :: Spec
spec = describe "pg_catalog generation" $ do
  it "includes oid column for system catalogs (e.g. pg_class)" $ do
    res <- try @SomeException run :: IO (Either SomeException String)
    case res of
      Left e   -> expectationFailure ("setup failed: " <> displayException e)
      Right hs -> do
        hs `shouldContain` "type PgClassColumns"
        hs `shouldContain` "\"oid\" ::: 'NoDef :=> 'NotNull PGoid"

  it "defines View type for pg_stat_user_indexes" $ do
    res <- try @SomeException run :: IO (Either SomeException String)
    case res of
      Left e   -> expectationFailure ("setup failed: " <> displayException e)
      Right hs -> do
        hs `shouldContain` "type PgStatUserIndexesView = "

run :: IO String
run = withDbCache $ \cache -> do
  e <- withConfig (cacheConfig cache) $ \db -> do
    let conn = BS8.unpack (toConnectionString db)
    runSquealgenScript conn "PgCatalogGenerated" "pg_catalog"
  case e of
    Left err -> ioError (userError (displayException err))
    Right x  -> pure x
