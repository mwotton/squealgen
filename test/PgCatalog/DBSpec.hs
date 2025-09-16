{-# LANGUAGE OverloadedStrings #-}
module PgCatalog.DBSpec where

import           Control.Exception        (SomeException, displayException, try)
import qualified Data.ByteString.Char8    as BS8
import           Database.Postgres.Temp
import           System.Exit              (ExitCode (..))
import           System.IO                as IO
import           System.IO.Temp           (withSystemTempFile)
import           System.Process           (proc, readCreateProcessWithExitCode)
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

run :: IO String
run = withDbCache $ \cache -> do
  e <- withConfig (cacheConfig cache) $ \db -> do
    let conn = BS8.unpack (toConnectionString db)
    runSquealgen conn "PgCatalogGenerated"
  case e of
    Left err -> ioError (userError (displayException err))
    Right x  -> pure x

runSquealgen :: String -> String -> IO String
runSquealgen conn moduleName' = withSystemTempFile "squealgen.sql" $ \path h -> do
  script <- IO.readFile "squealgen.sql"
  IO.hPutStr h script
  IO.hClose h
  let cmd = proc "psql"
        [ "-X"
        , "-q"
        , "-v", "chosen_schema=pg_catalog"
        , "-v", "modulename=" <> moduleName'
        , "-v", "extra_imports="
        , "-d", conn
        , "-f", path
        ]
  (exitCode, out, err) <- readCreateProcessWithExitCode cmd ""
  case exitCode of
    ExitSuccess   -> pure out
    ExitFailure c -> ioError (userError (unlines ["psql exited with code " <> show c, err]))
