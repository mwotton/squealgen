{-# LANGUAGE OverloadedStrings #-}
module CrossSchemaEnums.DBSpec where

import           Control.Exception        (SomeException, displayException, try)
import qualified Data.ByteString.Char8    as BS8
import           Database.Postgres.Temp
import           System.Exit              (ExitCode (..))
import           System.IO                as IO
import           System.Process           (proc, readCreateProcessWithExitCode)
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
    runSquealgen (BS8.unpack connBS) "CrossSchemaGenerated" "one"
  case e of
    Left err -> ioError (userError (displayException err))
    Right x  -> pure x

runSquealgen :: String -> String -> String -> IO String
runSquealgen conn moduleName' chosen = do
  script <- IO.readFile "squealgen.sql"
  let cmd = proc "psql"
        [ "-X"
        , "-q"
        , "-v", "chosen_schema=" <> chosen
        , "-v", "modulename=" <> moduleName'
        , "-v", "extra_imports="
        , "-d", conn
        ]
  (exitCode, out, err) <- readCreateProcessWithExitCode cmd script
  case exitCode of
    ExitSuccess   -> pure out
    ExitFailure c -> ioError (userError (unlines ["psql exited with code " <> show c, err]))
