{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE ScopedTypeVariables   #-}
module DBHelpers where

import           Control.Exception       (displayException)
import qualified Data.ByteString.Char8  as BS8
import           Database.Postgres.Temp
import           Squeal.PostgreSQL      hiding (with)
import           System.Exit            (ExitCode (..))
import qualified System.IO              as IO
import           System.Process         (proc, readCreateProcessWithExitCode)
import           UnliftIO

runSession :: String
           -> String
           -> PQ schema schema IO a
           -> IO a
runSession testname schema f = either (error . show)  pure =<< do
  let sqlFile = "./test/" <> testname <> "/schemas/" <> schema <> "/structure.sql"
  sql <- BS8.readFile sqlFile
  withDbCache $ \cache -> do
    withConfig (cacheConfig cache) $ \db -> do
      withConnection (toConnectionString db) $ do
        define (UnsafeDefinition sql)
        f

runSquealgenScript :: String -> String -> String -> IO String
runSquealgenScript conn moduleName chosen = do
  script <- IO.readFile "squealgen.sql"
  let cmd = proc "psql"
        [ "-X"
        , "-q"
        , "-v", "chosen_schema=" <> chosen
        , "-v", "modulename=" <> moduleName
        , "-v", "extra_imports="
        , "-d", conn
        ]
  (exitCode, out, err) <- readCreateProcessWithExitCode cmd script
  case exitCode of
    ExitSuccess   -> pure out
    ExitFailure c -> ioError (userError (unlines ["psql exited with code " <> show c, err]))

runGeneratorFromSchema :: FilePath -> String -> String -> IO String
runGeneratorFromSchema sqlPath moduleName chosen = withDbCache $ \cache -> do
  result <- withConfig (cacheConfig cache) $ \db -> do
    let connBS = toConnectionString db
    sql <- BS8.readFile sqlPath
    withConnection connBS $ define (UnsafeDefinition sql)
    runSquealgenScript (BS8.unpack connBS) moduleName chosen
  case result of
    Left err  -> ioError (userError (displayException err))
    Right out -> pure out
