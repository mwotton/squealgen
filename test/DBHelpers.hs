{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE ScopedTypeVariables   #-}
module DBHelpers where

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
