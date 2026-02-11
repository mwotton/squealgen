{-# LANGUAGE OverloadedStrings #-}
module CrossSchemaEnums.DBSpec where

import           Control.Exception        (SomeException, displayException, try)
import qualified Data.ByteString.Char8    as BS8
import           DBHelpers                (runSquealgenScript)
import           Database.Postgres.Temp
import           Test.Hspec
import           Squeal.PostgreSQL        (define, withConnection, Definition (UnsafeDefinition))

spec :: Spec
spec = describe "Cross-schema Enums" $ do
  it "includes used enums from other schemas but not unrelated ones" $ do
    res <- try @SomeException run :: IO (Either SomeException String)
    case res of
      Left e   -> expectationFailure ("setup failed: " <> displayException e)
      Right hs -> do
        -- should include the used enum
        hs `shouldContain` "type PGtraffic_light = 'PGenum"
        -- should not include unrelated enums from other schemas
        hs `shouldNotContain` "type PGunused_enum = 'PGenum"

run :: IO String
run = withDbCache $ \cache -> do
  e <- withConfig (cacheConfig cache) $ \db -> do
    let connBS = toConnectionString db
    -- Setup two schemas, enum in schema two, table in schema one referencing that enum
    let setup = unlines
          [ "CREATE SCHEMA one;"
          , "CREATE SCHEMA two;"
          , "CREATE TYPE two.traffic_light AS ENUM ('Red','Yellow','Green');"
          , "CREATE TYPE two.unused_enum AS ENUM ('A','B');"
          , "CREATE TABLE one.things (light two.traffic_light NOT NULL);"
          ]
    withConnection connBS $ define (UnsafeDefinition (BS8.pack setup))
    runSquealgenScript (BS8.unpack connBS) "CrossSchemaGenerated" "one"
  case e of
    Left err -> ioError (userError (displayException err))
    Right x  -> pure x
