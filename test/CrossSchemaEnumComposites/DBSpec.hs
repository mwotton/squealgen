{-# LANGUAGE OverloadedStrings #-}
module CrossSchemaEnumComposites.DBSpec where

import           Control.Exception        (SomeException, displayException, try)
import qualified Data.ByteString.Char8    as BS8
import           DBHelpers                (runSquealgenScript)
import           Database.Postgres.Temp
import           Test.Hspec
import           Squeal.PostgreSQL        (define, withConnection, Definition (UnsafeDefinition))

spec :: Spec
spec = describe "Cross-schema Enums in Composites" $ do
  it "includes enums used inside composite types but not unrelated ones" $ do
    res <- try @SomeException run :: IO (Either SomeException String)
    case res of
      Left e   -> expectationFailure ("setup failed: " <> displayException e)
      Right hs -> do
        -- enum referenced by a composite field in chosen schema should be present
        hs `shouldContain` "type PGtraffic_light = 'PGenum"
        -- unrelated enum from other schema should not be present
        hs `shouldNotContain` "type PGunused_enum = 'PGenum"

run :: IO String
run = withDbCache $ \cache -> do
  e <- withConfig (cacheConfig cache) $ \db -> do
    let connBS = toConnectionString db
    let setup = unlines
          [ "CREATE SCHEMA one;"
          , "CREATE SCHEMA two;"
          , "CREATE TYPE two.traffic_light AS ENUM ('Red','Yellow','Green');"
          , "CREATE TYPE two.unused_enum AS ENUM ('A','B');"
          , "CREATE TYPE one.composite_thing AS ( status two.traffic_light );"
          ]
    withConnection connBS $ define (UnsafeDefinition (BS8.pack setup))
    runSquealgenScript (BS8.unpack connBS) "CrossSchemaCompositeGenerated" "one"
  case e of
    Left err -> ioError (userError (displayException err))
    Right x  -> pure x
